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
- Gmail-labeled threads can now be imported into the case-tracking database
- the dashboard supports free-text search plus explicit status and priority filters

## Database

Migrations:

- `sql/041_case_tracking_schema.sql`
- `sql/042_case_tracking_gmail_sync.sql`

Tables:

- `public.cases`
  - case header record
  - contact details, status (`New`, `In Progress`, `Waiting`, `Completed`), priority, timestamps, freeform metadata
- `public.case_emails`
  - case activity log
  - stores imported inbound/outbound thread messages, internal notes, and outbound email records

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

## Background sync workflows

### `Sync Case Tracking Gmail To DB`

Scheduled every 10 minutes and runnable manually from n8n.

Responsibilities:

- reads Gmail threads with any of the case labels:
  - `!New Case`
  - `!In Progress`
  - `!Waiting`
  - `!Completed`
- also treats legacy Gmail labels as import aliases:
  - `To Do`
  - `To Do/Done`
- creates a new case if the thread has not been imported before
- imports thread messages into `case_emails`
- updates case status from the Gmail label
- stores Gmail thread metadata in `cases.metadata`

Label mapping:

- `!New Case` -> `New`
- `!In Progress` -> `In Progress`
- `!Waiting` -> `Waiting`
- `!Completed` -> `Completed`
- `To Do` -> `New`
- `To Do/Done` -> `Completed`

### `Sync Case Tracking DB To Gmail Labels`

Scheduled every 10 minutes and runnable manually from n8n.

Responsibilities:

- reads cases that already have a Gmail thread id in metadata
- applies the Gmail label that matches the current case status
- removes the other case labels from the thread, including legacy `To Do` / `To Do/Done`
- records the last label sync time in `cases.metadata`

This gives the MVP a practical two-way sync loop:

- Gmail labels can seed/import cases into the database
- database status changes can be pushed back to Gmail labels

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

- Gmail import currently relies on the case labels already being present on the thread.
- Imported message direction is inferred from the sender and the configured reply-to address,
  so edge cases with shared/personal club mailboxes may need refinement later.
- The UI is served from n8n webhooks, so it is intentionally simple and self-contained.
