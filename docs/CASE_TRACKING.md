# Case Tracking

## Overview

This feature adds a lightweight case-tracking UI implemented entirely with n8n webhooks,
PostgreSQL, and DaisyUI-rendered HTML. It reuses the existing Avondale data sources where
they already exist:

- contacts from `raw_contacts`, `raw_members`, and `vw_best_current_contacts`
- message templates and signatures from `email_templates`
- operational defaults from `global_settings`

The implementation is intended as a pragmatic MVP:

- users can create and manage cases
- internal notes and outbound emails are stored against each case
- contacts can seed new cases
- signatures and selected email settings can be edited from the case-tracking UI

Inbound Gmail-to-case sync is intentionally deferred.

## Database

Migration: `sql/041_case_tracking_schema.sql`

Tables:

- `public.cases`
  - case header record
  - contact details, status, priority, timestamps, freeform metadata
- `public.case_emails`
  - case activity log
  - stores internal notes plus outbound email records

Current activity types:

- `incoming`
- `outgoing`
- `note`

## Routes

### App routes

- `GET /webhook/case-tracking`
  - main application entry point
  - `view=dashboard|case|contacts|signatures|settings`

### Mutation routes

- `POST /webhook/case-tracking-actions`
  - `action=create_case`
  - `action=update_case`
  - `action=add_note`
  - `action=save_signature`
  - `action=save_settings`

### Email routes

- `GET /webhook/preview-case-tracking-email`
  - renders a composed case email for review/edit before send
- `POST /webhook/send-case-tracking-email`
  - sends the email via Gmail
  - logs the outbound message in `case_emails`
  - updates the case to `Waiting`

## Reused data

### Contacts

The contacts page searches across existing club data instead of creating a new contacts
table. It uses:

- `public.vw_best_current_contacts`
- `public.raw_members`

That keeps case initiation aligned with the same cleaned contact data already used
elsewhere in the repo.

### Templates and signatures

Templates come from `public.email_templates`:

- `template_type = 0` for message templates
- `template_type = 2` for signatures

The signatures page edits signature templates in place. The case composer reuses active
message templates and the selected signature template key from `global_settings`.

### Settings

The settings page reads and writes existing `global_settings` keys:

- `email_delivery_mode`
- `email_test_recipient`
- `email_sender_name`
- `email_reply_to`
- `email_signature_template_key`
- `n8n_base_url`

## Email behavior

The case email preview/send workflows follow the same pattern already used for the member
and refund email flows:

1. resolve request
2. load settings and case/template context
3. render subject/body tokens
4. present an editable preview
5. send via Gmail
6. log the outbound activity in `case_emails`

Supported case tokens:

- `{{case_title}}`
- `{{case_status}}`
- `{{case_priority}}`
- `{{contact_name}}`
- `{{contact_email}}`
- `{{contact_phone}}`
- `{{today}}`

The composer currently supports a single `to` recipient and stores it in `case_emails.recipients`.

## Current limitations

- No inbound Gmail parsing or auto-threading yet.
- `gmail_thread_id` is stored when available, but the initial implementation focuses on
  outbound messages and manual notes.
- The UI is served from n8n webhooks, so it is intentionally simple and self-contained.
