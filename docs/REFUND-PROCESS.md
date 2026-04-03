# Refund Process Documentation

## Overview

This document describes the refund management system built with n8n workflows, webhooks, and PostgreSQL.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    REFUND PROCESS                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

[1. CREATE REFUND]
                    ┌─────────────────────────────────────────────┐
                    │  /webhook/refund-form (GET)                  │
                    │  Refund Form Workflow                        │
                    │  Displays HTML form for data entry          │
                    └─────────────────────┬───────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                      USER FILLS FORM                                 │
│  name, refund_for, reason, membership, amount, from_date, to_date                   │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼ POST
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              /webhook/add-refund (POST)                             │
│                              Add Refund Workflow                                    │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Resolve Inputs│───▶│Build Insert  │───▶│Insert Refund │                        │
│  │              │    │SQL           │    │              │                        │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                        │
│                                                   │                                 │
│                                                   ▼                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Respond Success│◀───│Build Success │◀───│Check Result │                        │
│  │(HTML)        │    │HTML          │    │(IF: ok?)    │                        │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                        │
│                                                   │ False                           │
│                                                   ▼                                 │
│                                    ┌──────────────────────────┐                     │
│                                    │Build Error HTML          │                     │
│                                    │Respond Error (400)       │                     │
│                                    └──────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          │ Success: Redirect to Status Form
                                          ▼

[2. VIEW & MANAGE REFUNDS]
                    ┌─────────────────────────────────────────────┐
                    │  /webhook/refund-status-form (GET)         │
                    │  Refund Status Form Workflow               │
                    │  Lists all refunds, shows detail panel    │
                    └─────────────────────┬───────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              USER SELECTS A REFUND                                  │
│  - Views refund details (amount, status, dates)                                     │
│  - Updates status via dropdown                                                     │
│  - Sends emails (Member Calc, Treasury, Bank Details)                            │
└─────────────────────────────────────────────────────────────────────────────────────┘

                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
         ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
         │ Update Status    │  │ Request Bank     │  │ Send to         │
         │ (dropdown)      │  │ Details Button   │  │ Treasury Button │
         └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
                  │                      │                      │
                  │ POST                 │ POST                 │ POST
                  ▼                     ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    /webhook/update-refund-status (POST)                             │
│                    Update Refund Status Workflow                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Resolve Update│───▶│Check Request │───▶│Update Refund │                        │
│  │Request       │    │Error (IF)   │    │Status (SQL)  │                        │
│  └──────────────┘    └──────────────┘    └──────────────┘                        │
│                           │ False                 │                                 │
│                           ▼                       ▼                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Respond Error │    │Build Success │    │Build Success │                        │
│  │(400 HTML)    │    │HTML          │    │HTML          │                        │
│  └──────────────┘    └──────┬───────┘    └──────────────┘                        │
│                               │                                                │
│                               ▼                                                │
│                    ┌──────────────────────┐                                     │
│                    │Respond Success (200)│                                     │
│                    │(HTML + redirect)    │                                     │
│                    └──────────────────────┘                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

[3. REQUEST BANK DETAILS]
                    ┌─────────────────────────────────────────────┐
                    │  User clicks "Request Bank Details" button    │
                    │  (visible when status = Requested or        │
                    │   Awaiting Bank Details)                    │
                    └─────────────────────┬───────────────────────┘
                                          │
                                          │ POST with template_key=request_bank_details
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│               /webhook/preview-refund-request-email (POST)                          │
│               Preview Refund Request Email Workflow                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Resolve Preview│───▶│Load Refund   │───▶│Merge Refund  │                        │
│  │Request       │    │Data (if     │    │Data         │                        │
│  │              │    │refund_id)   │    │              │                        │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                        │
│                                                   │                                 │
│                                                   ▼                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Respond Error │    │Render Preview│───▶│Build Preview │                        │
│  │(400 HTML)    │    │Data         │    │HTML          │                        │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                        │
│                                                   │                                 │
│                                                   ▼                                 │
│                                    ┌──────────────────────────┐                     │
│                                    │Respond Preview (200)    │                     │
│                                    │HTML email preview form   │                     │
│                                    └──────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          │ User edits email, clicks Send
                                          │ POST with rendered_subject, rendered_message
                                          ▼

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                /webhook/send-refund-request-email (POST)                           │
│                Send Refund Request Email Workflow                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                       │
│  │Resolve Send  │───▶│Check Request│───▶│Build Send    │                        │
│  │Request       │    │Error (IF)   │    │Payload      │                        │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                        │
│                                                   │                                 │
│                                                   ▼                                 │
│                                    ┌──────────────────────────┐                     │
│                                    │Send Gmail Message       │                     │
│                                    │                        │                     │
│                                    └────────────┬───────────┘                     │
│                                                 │                                 │
│                                                 │ (if refund_id present)          │
│                                                 ▼                                 │
│                                    ┌──────────────────────────┐                     │
│                                    │Update Refund Status     │                     │
│                                    │(set to Awaiting Bank   │                     │
│                                    │Details)                │                     │
│                                    └────────────┬───────────┘                     │
│                                                 │                                 │
│                                                 ▼                                 │
│                                    ┌──────────────────────────┐                     │
│                                    │Build Success HTML       │                     │
│                                    │Respond Success (200)    │                     │
│                                    └──────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Pages

| Page | URL | Method | Description |
|------|-----|--------|-------------|
| Refund Form | `/webhook/refund-form` | GET | Displays HTML form to create new refunds |
| Add Refund | `/webhook/add-refund` | POST | Receives form submission, creates refund record |
| Refund Status Form | `/webhook/refund-status-form` | GET | Lists all refunds, detail panel with actions |
| Update Refund Status | `/webhook/update-refund-status` | POST | Updates refund status in database |
| Preview Email | `/webhook/preview-refund-request-email` | GET/POST | Preview/edit email before sending |
| Send Email | `/webhook/send-refund-request-email` | POST | Sends email via Gmail |

## Webhooks

| Webhook | Workflow | HTTP Method | Path ID |
|---------|----------|------------|---------|
| `refund-form` | Refund Form | GET | `SBKU9imIYUrlRVDR` |
| `add-refund` | Add Refund | POST | `FmFGVKMxZLcPv6d7` |
| `refund-status-form` | Refund Status Form | GET | `u7bO4JKVEaqtn2hl` |
| `update-refund-status` | Update Refund Status | POST | `ouYD0m2No7IBTYH4` |
| `preview-refund-request-email` | Preview Refund Request Email | GET | `KJ7Ys7oAxo0yGYhi` |
| `send-refund-request-email` | Send Refund Request Email | POST | `ovfzjVKGfC2dt8qw` |

## Workflows

### 1. Refund Form (`SBKU9imIYUrlRVDR`)
**Purpose**: Display HTML form for creating new refunds

**Nodes**:
- `Refund Form Webhook` - GET endpoint
- `Load Global Settings` - Load n8n_base_url
- `Build Form HTML` - Generates HTML with form fields
- `Respond Form` - Returns HTML response

**Form Fields**:
- name
- refund_for
- reason
- membership
- amount
- from_date
- to_date
- status (default: Request Bank Details)

---

### 2. Add Refund (`FmFGVKMxZLcPv6d7`)
**Purpose**: Create new refund record in database

**Nodes**:
- `Add Refund Webhook` - POST endpoint (responseMode: responseNode)
- `Resolve Inputs` - Parse form body fields
- `Load Global Settings` - Load configuration
- `Build Insert SQL` - Build INSERT statement with validation
- `Insert Refund` - Execute SQL
- `Check Result` - IF node: check if ok field is present
- `Build Success HTML` - Generate success HTML with redirect
- `Build Error HTML` - Generate error HTML
- `Respond Success` - Return 200 HTML
- `Respond Error` - Return 400 HTML

**Status Flow**: Created → Requested → Awaiting Bank Details → Bank Details Received → Ready For Treasury → Sent To Treasury → Paid

---

### 3. Refund Status Form (`u7bO4JKVEaqtn2hl`)
**Purpose**: List all refunds with detail panel and action buttons

**Nodes**:
- `Refund Status Form Webhook` - GET endpoint
- `Load Global Settings` - Load configuration
- `List Refunds` - Query all refunds (ORDER BY id DESC LIMIT 50)
- `Build Form HTML` - Generate HTML with:
  - Refund table (ID, Member, Membership, Amount, Status, Created)
  - Detail panel (shows when row selected)
  - Action buttons based on status

**Action Buttons**:
| Status | Button | Action |
|--------|--------|--------|
| Requested, Awaiting Bank Details | Request Bank Details | POST to preview email |
| Requested | Send Calculation Email | POST to send-member-calculation-email |
| Ready For Treasury | Send to Treasury | POST to send-treasury-refund-request |
| Any | Update Status | POST to update-refund-status |

---

### 4. Update Refund Status (`ouYD0m2No7IBTYH4`)
**Purpose**: Update refund status and record in database

**Nodes**:
- `Update Refund Status Webhook` - POST endpoint
- `Load Global Settings` - Load n8n_base_url
- `Resolve Update Request` - Parse body, validate, derive base URL
- `Check Request Error` - IF node: check for error_message
- `Build Error HTML` - Generate error page
- `Respond Error` - Return 400 HTML
- `Build Update SQL` - Build UPDATE statement
- `Update Refund Status` - Execute SQL
- `Build Success HTML` - Generate success page with redirect
- `Respond Success` - Return 200 HTML

---

### 5. Preview Refund Request Email (`KJ7Ys7oAxo0yGYhi`)
**Purpose**: Preview and edit email before sending

**Nodes**:
- `Preview Refund Request Email Webhook` - GET/POST endpoint
- `Load Global Settings` - Load email settings
- `Resolve Preview Request` - Parse query/body, detect bank details request
- `Load Refund Data` - Load refund by ID (if refund_id provided)
- `Merge Refund Data` - Merge refund data with request
- `Check Request Error` - IF node
- `Build Error HTML` - Error page
- `Respond Error` - Return 400
- `Build Preview Context SQL` - Load email template
- `Load Preview Context` - Execute template query
- `Check Context Error` - IF node for template errors
- `Render Preview Data` - Fill template tokens
- `Build Preview HTML` - Generate editable email preview form
- `Respond Preview` - Return 200 HTML

**Email Templates**:
- `refund_request_treasury` - Initial refund request
- `request_bank_details` - Request bank details from member

---

### 6. Send Refund Request Email (`ovfzjVKGfC2dt8qw`)
**Purpose**: Send email via Gmail

**Nodes**:
- `Send Refund Request Email Webhook` - POST endpoint
- `Load Global Settings` - Load email settings
- `Resolve Send Request` - Parse body, detect bank details request
- `Check Request Error` - IF node
- `Build Error HTML` - Error page
- `Respond Error` - Return 400
- `Build Send Payload` - Prepare email data
- `Send Gmail Message` - Send via Gmail OAuth2
- `Update Refund Status` - Update to "Awaiting Bank Details" (if applicable)
- `Build Success HTML` - Success page
- `Respond Success` - Return 200

## Email Templates

| Template Key | Name | Purpose |
|--------------|------|---------|
| `refund_request_treasury` | Refund Request Treasury | Initial refund request email |
| `request_bank_details` | Request Bank Details | Request bank details from member |
| `signature` | Email Signature | Email footer signature |

## Database Tables

### refunds
```sql
CREATE TABLE public.refunds (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  refund_for VARCHAR(255),
  reason TEXT,
  membership VARCHAR(255),
  amount DECIMAL(10,2),
  from_date DATE,
  to_date DATE,
  months INTEGER,
  refund DECIMAL(10,2),
  status VARCHAR(50) DEFAULT 'Requested',
  explanation TEXT,
  notes TEXT,
  request_email_message_id VARCHAR(255),
  bank_details_message_id VARCHAR(255),
  treasury_email_message_id VARCHAR(255),
  paid_at TIMESTAMP,
  rejected_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  created_by VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### email_templates
```sql
CREATE TABLE public.email_templates (
  id SERIAL PRIMARY KEY,
  template_key VARCHAR(100) UNIQUE,
  template_name VARCHAR(255),
  template_type INTEGER,  -- 0=message, 1=?, 2=signature
  subject_template TEXT,
  text_template TEXT,
  html_template TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### global_settings
```sql
CREATE TABLE public.global_settings (
  id SERIAL PRIMARY KEY,
  key VARCHAR(100),
  value TEXT,
  UNIQUE(key)
);
```

**Known Keys**:
- `n8n_base_url` - Base URL for n8n (e.g., `http://n8n:5678`)
- `email_test_recipient` - Default test email recipient
- `email_sender_name` - Sender name for emails
- `email_reply_to` - Reply-to email address

## Status Flow

```
┌─────────────┐
│  Requested │
└──────┬──────┘
       │
       ▼
┌──────────────────────────┐
│ Awaiting Bank Details    │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Bank Details Received    │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Ready For Treasury       │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Sent To Treasury         │
└──────┬───────────────────┘
       │
       ▼
┌─────┐
│ Paid│
└─────┘

Terminal States: Rejected, Cancelled
```

## Environment

- **n8n URL**: http://n8n:5678
- **Database**: PostgreSQL on `192.168.1.248:5432`
- **Credentials**: See `~/.codex/config.toml` for database credentials

## Troubleshooting

### Webhook returns 404
1. Check workflow is active (`active = true` in database)
2. Check webhook is registered in `n8n.webhook_entity`
3. Check `httpMethod` matches (GET/POST)

### Webhook returns JSON instead of HTML
1. Check webhook `responseMode` is set to `responseNode`
2. Check final node connects to Respond node
3. Check Respond node has `html` in `responseBody`

### Workflow errors with "Cannot read properties of undefined"
1. Check node connections are correct
2. Check referenced node names match exactly
3. Check IF node conditions use correct format (`operation`, not `operator`)

## Future Enhancements

- [ ] Add validation for duplicate refunds
- [ ] Add bulk status update capability
- [ ] Add refund history/audit log
- [ ] Add PDF generation for refund requests
- [ ] Add notification emails for status changes
