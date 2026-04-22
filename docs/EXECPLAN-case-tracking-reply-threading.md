# Implement Standard Reply Threading And Open Tracking In Case Tracking

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `/mnt/c/dev/PLAN.md`.

## Purpose / Big Picture

After this change, the case manager will behave like a normal support ticket system instead of a loose email logger. An operator will be able to open a case, click reply on an earlier case message, send that reply from the case manager, have the external recipient’s response come back into the same case automatically, and see whether a tracked outbound HTML message has been opened. The visible proof is:

- the case detail page shows a real conversation thread rather than unrelated inbound and outbound rows
- a reply sent from the case manager appears in Gmail as part of the existing conversation
- a customer reply to that message is imported back into the same case without relying only on manual Gmail labels
- tracked outbound HTML messages show `Not Opened` until the tracking pixel is requested, then show `Opened` with timestamps

In this repository, “standard reply threading” means storing and using the normal Internet mail headers that email clients use to join a conversation:

- `Message-ID`: the unique identifier of one email message
- `In-Reply-To`: the parent `Message-ID` being answered
- `References`: the chain of prior `Message-ID` values in the thread

This plan assumes the existing case-tracking feature in `/mnt/c/dev/avondale-n8n/workflows/` is the implementation base and that Gmail remains the mail transport.

For this feature, open tracking is intentionally simple and best-effort:

- only outbound HTML emails are eligible for tracking
- each tracked outbound `case_emails` row gets one opaque token
- the email body includes a 1x1 tracking pixel URL that updates the row when requested
- image blocking and privacy protections mean “not opened” is not absolute proof the recipient did not read the message

## Progress

- [x] (2026-04-22 09:05Z) Reviewed `/mnt/c/dev/avondale-n8n/docs/CASE_TRACKING.md`, the current case-tracking schema migrations, and the checked-in n8n workflows.
- [x] (2026-04-22 09:05Z) Confirmed the current send flow creates a fresh Gmail message and logs Gmail ids after send, but does not carry explicit reply-thread headers or local parent-message linkage.
- [x] (2026-04-22 09:05Z) Confirmed the Gmail import flow already parses Gmail thread detail and `Message-ID` headers, so inbound matching can be upgraded without replacing the whole import architecture.
- [x] (2026-04-22 09:05Z) Wrote this ExecPlan as a concrete implementation plan tied to the current repository files.
- [x] (2026-04-22 08:40Z) Added the additive schema migration file `sql/044_case_tracking_reply_threading.sql` for reply-thread metadata and simple open-tracking fields on `public.case_emails`.
- [x] (2026-04-22 10:29Z) Applied `sql/044_case_tracking_reply_threading.sql` to the target PostgreSQL database on `homedb` and verified the new columns, check constraint, and indexes on `public.case_emails`.
- [x] (2026-04-22 11:12Z) Updated `workflows/case-tracking-app.json` and synced live `Case Tracking App` so the case detail page now exposes reply links for email activity rows, carries `reply_to_case_email_id` into the preview URL, and shows the stored open-tracking status/summary on outbound messages.
- [x] (2026-04-22 11:38Z) Updated `workflows/preview-case-tracking-email.json` and synced live `Preview Case Tracking Email` so the preview now supports explicit `new` vs `reply` mode, derives reply recipient/subject context from the selected parent email, exposes open-tracking choice for HTML email, and uses a non-editable signature dropdown that still updates the rendered preview.
- [ ] Add a simple tracking-pixel webhook flow.
- [ ] Replace or wrap the current Gmail send step so outbound replies can set `threadId`, `In-Reply-To`, `References`, and optionally inject a tracking pixel for HTML messages.
- [ ] Extend Gmail import so replies attach to cases by stored message headers before falling back to label-based case matching.
- [ ] Verify the full round trip with a real reply chain: new outbound, external reply, second outbound reply, and correct case/thread linkage.

## Surprises & Discoveries

- Observation: the current case-tracking feature already has a pragmatic two-way Gmail sync loop, but it is label-centric rather than reply-centric.
  Evidence: `/mnt/c/dev/avondale-n8n/docs/CASE_TRACKING.md` and `workflows/sync-case-tracking-gmail-to-db.json` show Gmail labels are used to seed/import cases and reflect status back into Gmail.

- Observation: the existing outbound send workflow does not carry any explicit thread metadata into the send step.
  Evidence: in `workflows/send-case-tracking-email.json`, the `Send Gmail Message` node only sends `to`, `subject`, `message`, `replyTo`, and `senderName`, and the log SQL writes only the Gmail ids returned after send.

- Observation: the current Gmail import workflow already extracts enough data to support proper reply matching.
  Evidence: `Build Thread Upsert SQL` in `workflows/sync-case-tracking-gmail-to-db.json` parses message headers, stores `message_id_header` in metadata, and normalizes per-message sender/recipient context.

- Observation: the current schema is missing the fields needed to make reply threading first-class.
  Evidence: `sql/041_case_tracking_schema.sql` defines `public.case_emails` with `gmail_message_id` and `gmail_thread_id`, but not `internet_message_id`, `in_reply_to_message_id`, `references_header`, or `parent_case_email_id`.

- Observation: the current case manager has no first-class concept of whether an outbound message was opened.
  Evidence: `sql/041_case_tracking_schema.sql` and `docs/CASE_TRACKING.md` contain no tracking token, open status, or open timestamps for `public.case_emails`, and none of the checked-in workflows expose a tracking pixel endpoint.

- Observation: the current preview/send contract supports only “send to recipient” and not “reply to specific case email”.
  Evidence: `Resolve Send Request` in `workflows/send-case-tracking-email.json` validates only `case_id`, `to`, `rendered_subject`, and `rendered_message`; there is no parent email id or reply mode.

- Observation: migration number `043` is already taken by a later case-tracking status adjustment.
  Evidence: the repository already contains `/mnt/c/dev/avondale-n8n/sql/043_case_tracking_new_status.sql`, so the reply-threading migration must use `044` to preserve the real sequence.

## Decision Log

- Decision: treat RFC mail headers as the canonical reply-thread contract and Gmail `threadId` as a transport-specific helper.
  Rationale: Gmail `threadId` is useful but proprietary. `Message-ID`, `In-Reply-To`, and `References` are the standard identifiers that let replies remain coherent even if Gmail-side behavior changes.
  Date/Author: 2026-04-22 / Codex

- Decision: keep the existing case-tracking workflows and extend them instead of replacing the case manager with a separate ticketing product.
  Rationale: the current feature already has working UI routes, database tables, Gmail sync, and email composition. Threading is a capability gap, not evidence that the current architecture is invalid.
  Date/Author: 2026-04-22 / Codex

- Decision: separate “new outbound email” and “reply” as explicit send modes in the workflow contract.
  Rationale: replying needs different defaults, different validation, and parent-message linkage. Keeping the modes explicit will make both UI behavior and logging clearer.
  Date/Author: 2026-04-22 / Codex

- Decision: prefer a Gmail raw-MIME send path for replies if the stock n8n Gmail send node cannot set `threadId` and custom headers.
  Rationale: proper threading requires control over the mail headers and Gmail conversation target. The current Gmail node parameters do not expose that control.
  Date/Author: 2026-04-22 / Codex

- Decision: use `sql/044_case_tracking_reply_threading.sql` instead of `043`.
  Rationale: `043_case_tracking_new_status.sql` already exists in the repository, and reusing the number would make the migration chain ambiguous and unsafe.
  Date/Author: 2026-04-22 / Codex

- Decision: implement open tracking as a simple 1x1 pixel for outbound HTML email only.
  Rationale: this gives a pragmatic opened/not-opened signal with minimal schema and workflow change, while avoiding complex mail-provider-specific read-receipt logic.
  Date/Author: 2026-04-22 / Codex

## Outcomes & Retrospective

This plan is not implemented yet. The current outcome is a concrete implementation path that fits the existing case-tracking MVP and names the exact schema, workflow, and validation work needed. The most important conclusion is that the current system is close to a real ticket workflow already; the missing pieces are explicit message-thread identity across outbound send and inbound import, plus a lightweight outbound open-status signal for operators.

## Context and Orientation

The current case-tracking system lives in three places:

- schema in `/mnt/c/dev/avondale-n8n/sql/041_case_tracking_schema.sql` and `/mnt/c/dev/avondale-n8n/sql/042_case_tracking_gmail_sync.sql`
- application UI in `/mnt/c/dev/avondale-n8n/workflows/case-tracking-app.json`
- case mutations and email send/import flows in:
  - `/mnt/c/dev/avondale-n8n/workflows/case-tracking-actions.json`
  - `/mnt/c/dev/avondale-n8n/workflows/preview-case-tracking-email.json`
  - `/mnt/c/dev/avondale-n8n/workflows/send-case-tracking-email.json`
  - `/mnt/c/dev/avondale-n8n/workflows/sync-case-tracking-gmail-to-db.json`
  - `/mnt/c/dev/avondale-n8n/workflows/sync-case-tracking-db-to-gmail-labels.json`

The database table `public.cases` stores the case header row: title, contact details, status, priority, timestamps, and freeform metadata. The table `public.case_emails` stores case activity rows: inbound messages, outbound messages, and internal notes.

Today, `public.case_emails` supports:

- `direction`
- subject/body
- recipients JSON
- template/signature keys
- delivery mode
- Gmail internal ids
- metadata JSON

That is enough for a journal but not enough for reply logic or message-open status. There is no durable local pointer from one case email to the email it replies to, there is no first-class storage for Internet message headers, and there is no token or status model for a tracking pixel.

The case detail page in `workflows/case-tracking-app.json` currently loads the case row plus `activity_rows`, then renders the timeline. The composer is template-driven and sends through `preview-case-tracking-email.json` and `send-case-tracking-email.json`. The current send flow builds a message body, sends it through the Gmail node, logs the outbound row, and moves the case to `Waiting`.

The Gmail import flow in `workflows/sync-case-tracking-gmail-to-db.json` is stronger than the outbound flow. It already fetches full Gmail thread detail, walks each message, parses header values, and imports them into `case_emails`. It also stores Gmail thread metadata in `cases.metadata`. That means the inbound side already has most of the raw information needed for proper reply matching.

For this plan, “parent case email” means the earlier `public.case_emails` row that the operator is replying to. “Reply context” means the combination of:

- parent local row id
- parent RFC `Message-ID`
- existing `References` chain
- Gmail `threadId`
- default external recipient

For this plan, “open tracking” means:

- `open_tracking_enabled = true` for outbound HTML emails where the sender wants open status
- `open_tracking_token` identifies one outbound `case_emails` row
- `open_tracking_status` is one of `Not Tracked`, `Not Opened`, or `Opened`
- `first_opened_at`, `last_opened_at`, and `open_count` are updated by a simple webhook that returns a 1x1 pixel

## Plan of Work

Use the following numbered implementation steps in order. The order is deliberate: each step adds one safe layer, keeps the current feature usable, and reduces the chance of breaking both outbound send and inbound import at the same time.

### 1. Add schema support without changing behavior

Create `sql/044_case_tracking_reply_threading.sql` after `sql/043_case_tracking_new_status.sql`. This migration must extend `public.case_emails` with the fields needed to treat one activity row as a reply to another, to match inbound mail by standard headers, and to track whether an outbound HTML message has been opened:

- `internet_message_id text`
- `in_reply_to_message_id text`
- `references_header text`
- `parent_case_email_id uuid REFERENCES public.case_emails(id) ON DELETE SET NULL`
- `open_tracking_token text`
- `open_tracking_enabled boolean NOT NULL DEFAULT false`
- `open_tracking_status text NOT NULL DEFAULT 'Not Tracked'`
- `first_opened_at timestamptz`
- `last_opened_at timestamptz`
- `open_count integer NOT NULL DEFAULT 0`
- optionally `gmail_history_id text` if later Gmail re-sync logic needs it

The migration must also add the lookup indexes needed by the later workflow steps:

- unique or partial unique index on `internet_message_id` where not null
- index on `in_reply_to_message_id`
- index on `parent_case_email_id`
- unique or partial unique index on `open_tracking_token` where not null
- index on `open_tracking_status`
- keep the existing Gmail message and thread indexes

If historical rows already contain header information inside `case_emails.metadata`, backfill those values into the new dedicated columns. This migration must be safe to rerun and should update only rows where the new columns are still null or empty. No workflow should depend on the new columns yet; this step is schema-only.

### 2. Expose reply context in the case page without changing send logic

Update `workflows/case-tracking-app.json`. The “case” view already loads `activity_rows`; extend that SQL so it also returns the fields needed to support reply actions later:

- `case_emails.id`
- `internet_message_id`
- `in_reply_to_message_id`
- `references_header`
- `parent_case_email_id`
- sender and recipient summary extracted from `recipients`

Then update the rendered HTML so each inbound or outbound email row can expose a reply action. Internal notes must not expose reply. At this stage the reply action only needs to navigate to the preview workflow with query parameters; it does not yet require a changed send path. The link must carry at least:

- `case_id`
- `reply_to_case_email_id`
- `template_key`
- optional `return_url`

This same step must also expose simple open-status display for outbound email rows:

- `Not Tracked`
- `Not Opened`
- `Opened`
- optional summary text from `first_opened_at`, `last_opened_at`, and `open_count`

This step is safe because it only changes navigation and display. The existing send flow remains untouched.

### 3. Add explicit reply mode to the preview flow

Update `workflows/preview-case-tracking-email.json` so it supports two preview modes:

- `mode = new`
- `mode = reply`

Extend `Resolve Preview Request` and `Build Send Context SQL` so reply mode can:

- load the selected parent email row
- derive the default recipient from the external participant on that row
- derive the subject as `Re: <base subject>` without stacking repeated `Re:` prefixes
- carry the parent row id, parent `internet_message_id`, parent `references_header`, and parent `gmail_thread_id` into the rendered form

The preview flow must also support a simple operator choice for open tracking:

- default `open_tracking_enabled = true` for outbound HTML email
- force `open_tracking_enabled = false` for text-only outbound email
- carry the chosen tracking flag into the send request

Do not replace the existing “new outbound email” path. Reply mode must be additive so the existing case email composer keeps working if the next step is delayed or fails.

### 4. Add a simple tracking-pixel webhook before changing the send path

Add a dedicated n8n workflow for the tracking pixel, for example `workflows/case-tracking-open-pixel.json`. It must expose a stable webhook URL that accepts an opaque token, returns a 1x1 image payload, and updates the matching `public.case_emails` row:

- increment `open_count`
- set `first_opened_at` on the first hit only
- set `last_opened_at` on every hit
- set `open_tracking_status = 'Opened'`

The workflow must do nothing destructive if the token is missing, invalid, or already used before. The image response must still succeed so mail clients do not show a broken image. This step is safe because no outbound email depends on it yet; it only creates the endpoint and database update behavior.

### 5. Upgrade outbound send to a thread-aware implementation

Update `workflows/send-case-tracking-email.json`. Right now it assumes every send is a new top-level message. Replace that contract with explicit mode handling:

- `mode = new`
- `mode = reply`

In reply mode, `Resolve Send Request` must require:

- `reply_to_case_email_id`
- a valid recipient
- rendered subject and body

`Build Send Context SQL` must join the selected parent case email row and expose:

- parent local id
- parent `internet_message_id`
- parent `references_header`
- parent `gmail_thread_id`

The current Gmail node should be kept only if it can set `threadId`, `In-Reply-To`, and `References`. If it cannot, replace the send step with a safer two-part path:

- Code node that builds the raw MIME message with the exact headers
- HTTP Request node using the Gmail OAuth credential to call `users.messages.send`

In reply mode, the outbound payload must include:

- Gmail `threadId`
- `In-Reply-To: <parent internet_message_id>`
- `References: <existing references chain + parent internet_message_id>`

When `open_tracking_enabled = true` and the outbound format is HTML, the send workflow must:

- generate a new opaque `open_tracking_token`
- persist `open_tracking_enabled = true`
- persist `open_tracking_status = 'Not Opened'`
- append a 1x1 pixel image pointing at the tracking webhook URL

When tracking is disabled or the message is not HTML, the send workflow must persist:

- `open_tracking_enabled = false`
- `open_tracking_status = 'Not Tracked'`
- no tracking pixel in the outbound body

After send, fetch the sent Gmail message detail so the workflow stores the real `Message-ID` header returned by Gmail, not a guessed local value. Then update `Build Log SQL` so the outbound `case_emails` row writes:

- `internet_message_id`
- `in_reply_to_message_id`
- `references_header`
- `parent_case_email_id`
- `open_tracking_token`
- `open_tracking_enabled`
- `open_tracking_status`
- `gmail_message_id`
- `gmail_thread_id`

The send workflow should continue to move the case to `Waiting` after a successful outbound reply. It should still preserve test mode, and the logged row must keep both intended recipient and actual recipient in `recipients`.

### 6. Upgrade inbound Gmail sync to match replies by headers first

Only after outbound replies are storing proper thread metadata, update `workflows/sync-case-tracking-gmail-to-db.json`.

The current `Build Thread Upsert SQL` already parses message headers into per-message objects. Extend those objects and the SQL so import matching uses this safe precedence:

1. If a message’s `In-Reply-To` matches a stored `case_emails.internet_message_id`, attach the message to that case.
2. Else if any `References` entry matches a stored `case_emails.internet_message_id`, attach the message to that case.
3. Else if the Gmail `threadId` matches an existing case or case email, attach it there.
4. Else create a new case using the current label-based import logic.

When an inbound message matches an existing outbound parent, store:

- `parent_case_email_id`
- `internet_message_id`
- `in_reply_to_message_id`
- `references_header`

The imported message should also update the case status to `In Progress` unless there is a stronger reason to preserve another state. This is the expected operator behavior for a received customer reply.

This step is deliberately last because it depends on the outbound path already writing durable parent and header data.

### 7. Update the design note after the feature works

Update `docs/CASE_TRACKING.md` only after the schema and workflows are working. It should no longer say only that the composer supports a single `to` recipient and stores it in `case_emails.recipients`; it should document:

- reply mode
- parent-message linkage
- stored RFC message headers
- header-first inbound matching
- the fallback role of Gmail labels

## Concrete Steps

Work from the repository root:

    cd /mnt/c/dev/avondale-n8n

Follow these numbered steps exactly.

1. Inspect the current schema and workflow state before editing:

       sed -n '1,220p' sql/041_case_tracking_schema.sql
       sed -n '1,220p' sql/042_case_tracking_gmail_sync.sql
       jq -r '.name, (.nodes[] | [.name,.type] | @tsv)' workflows/case-tracking-app.json
       jq -r '.name, (.nodes[] | [.name,.type] | @tsv)' workflows/preview-case-tracking-email.json
       jq -r '.name, (.nodes[] | [.name,.type] | @tsv)' workflows/send-case-tracking-email.json
       jq -r '.name, (.nodes[] | [.name,.type] | @tsv)' workflows/sync-case-tracking-gmail-to-db.json

2. Create `sql/044_case_tracking_reply_threading.sql` and make it additive and rerunnable.

3. Apply the migration to the target PostgreSQL database.

4. Verify the schema before touching any workflow files:

       SELECT column_name
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'case_emails'
         AND column_name IN (
           'internet_message_id',
           'in_reply_to_message_id',
           'references_header',
           'parent_case_email_id',
           'open_tracking_token',
           'open_tracking_enabled',
           'open_tracking_status',
           'first_opened_at',
           'last_opened_at',
           'open_count'
         )
       ORDER BY column_name;

   The expected output must list the reply-thread columns and the six open-tracking columns.

5. Update `workflows/case-tracking-app.json` to expose reply actions and the supporting activity-row fields. Then validate it:

       jq empty workflows/case-tracking-app.json

6. Update `workflows/preview-case-tracking-email.json` to support explicit reply mode. Then validate it:

       jq empty workflows/preview-case-tracking-email.json

7. Create and validate the tracking-pixel workflow:

       jq empty workflows/case-tracking-open-pixel.json

8. Update `workflows/send-case-tracking-email.json` to support explicit reply mode, thread-aware send, and optional tracking-pixel injection. Then validate it:

       jq empty workflows/send-case-tracking-email.json

9. If a new Gmail raw-send node is added through an HTTP request workflow path, validate the request contract explicitly by exporting the final node configuration and confirming it includes:

   - `threadId` in reply mode
   - a base64url raw MIME payload
   - `In-Reply-To`
   - `References`
   - the tracking pixel URL in HTML mode when `open_tracking_enabled = true`

10. Update `workflows/sync-case-tracking-gmail-to-db.json` so inbound import matches replies by headers before falling back to thread id and then labels. Then validate it:

       jq empty workflows/sync-case-tracking-gmail-to-db.json

11. Update `workflows/sync-case-tracking-db-to-gmail-labels.json` only if the status-sync assumptions need adjusting after the reply-thread changes. Validate it if touched:

       jq empty workflows/sync-case-tracking-db-to-gmail-labels.json

12. Run the round-trip validation scenario described below with a real case and real Gmail replies, including one tracked HTML outbound email.

13. Only after the workflow behavior is proven, update `docs/CASE_TRACKING.md` to describe the final reply-threading and open-tracking behavior.

## Validation and Acceptance

This feature is complete only when all of the following are true.

First, a case detail page in `/webhook/case-tracking?view=case&id=<uuid>` shows existing message activity with reply controls on real emails and no reply control on internal notes.

Second, clicking reply on an existing case email opens the preview flow with:

- the same case id
- the selected parent case email id
- the default recipient prefilled from the external participant
- a subject rendered as a single `Re: ...`

Third, sending that reply creates one new `public.case_emails` row that contains:

- `direction = 'outgoing'`
- `parent_case_email_id`
- `internet_message_id`
- `in_reply_to_message_id`
- `references_header`
- Gmail internal ids

Fourth, if the outbound message is HTML with open tracking enabled, that new row also contains:

- `open_tracking_enabled = true`
- `open_tracking_status = 'Not Opened'`
- a non-null `open_tracking_token`
- `open_count = 0`

Fifth, requesting the tracking-pixel URL updates the same `public.case_emails` row to:

- `open_tracking_status = 'Opened'`
- `first_opened_at` set on the first hit
- `last_opened_at` updated on every hit
- `open_count` incremented

Sixth, the Gmail message appears inside the existing Gmail conversation rather than as a separate conversation.

Seventh, when the external recipient replies to that message, the scheduled or manual run of `Sync Case Tracking Gmail To DB` imports the reply into the same case without needing a manually created new case.

Eighth, that imported inbound row stores:

- `direction = 'incoming'`
- `internet_message_id`
- `in_reply_to_message_id`
- `references_header`
- `parent_case_email_id` when the parent outbound row is known

Ninth, the case status moves:

- to `Waiting` after an outbound reply
- to `In Progress` after an inbound external reply

Use direct SQL checks to prove the linkage exists. After a test round-trip, this query should show a coherent parent/child chain:

    SELECT
      ce.id,
      ce.direction,
      ce.subject,
      ce.internet_message_id,
      ce.in_reply_to_message_id,
      ce.parent_case_email_id,
      ce.open_tracking_status,
      ce.open_count,
      ce.first_opened_at,
      ce.last_opened_at,
      ce.gmail_thread_id,
      ce.sent_at,
      ce.created_at
    FROM public.case_emails ce
    WHERE ce.case_id = '<case uuid>'::uuid
    ORDER BY COALESCE(ce.sent_at, ce.created_at);

Acceptance requires that the inbound reply row points back to the same conversation by either `parent_case_email_id`, `in_reply_to_message_id`, or both, and that all related rows share the same Gmail thread id.

For a tracked outbound HTML message, acceptance also requires that requesting the tracking pixel changes the stored row from `Not Opened` to `Opened` without creating a duplicate `case_emails` row.

## Idempotence and Recovery

The schema migration must be additive and safe to rerun. Every new column or index should use `IF NOT EXISTS` where PostgreSQL supports it. Backfill statements should update only rows that still need the values copied out of `metadata`.

The workflow edits are recoverable because the checked-in JSON files are the source of truth. If a workflow import or live sync fails midway, restore the last-good workflow JSON from git and re-import it. Do not hand-edit live workflow state without reflecting the change in the checked-in file.

For send-flow recovery, keep the old Gmail-node send shape available until the raw-MIME reply path is proven. If the new reply send path fails during implementation, the fallback is to preserve “new outbound email” behavior temporarily while reply mode remains disabled in the UI.

For tracking-pixel recovery, the safest failure mode is to leave `open_tracking_status = 'Not Opened'` when the webhook is unreachable or the client blocks images. The tracking endpoint must not block outbound send and must not mutate unrelated rows.

For import recovery, keep Gmail label-based thread import as the final fallback even after header-based matching is added. That way a partially populated older case can still be re-imported or repaired without losing all matching capability.

## Artifacts and Notes

The most important current artifacts are:

- `/mnt/c/dev/avondale-n8n/docs/CASE_TRACKING.md`
- `/mnt/c/dev/avondale-n8n/sql/041_case_tracking_schema.sql`
- `/mnt/c/dev/avondale-n8n/sql/042_case_tracking_gmail_sync.sql`
- `/mnt/c/dev/avondale-n8n/workflows/case-tracking-app.json`
- `/mnt/c/dev/avondale-n8n/workflows/preview-case-tracking-email.json`
- `/mnt/c/dev/avondale-n8n/workflows/send-case-tracking-email.json`
- `/mnt/c/dev/avondale-n8n/workflows/sync-case-tracking-gmail-to-db.json`
- `/mnt/c/dev/avondale-n8n/workflows/case-tracking-open-pixel.json`

Important current evidence gathered before implementation:

    jq -r '.nodes[] | select(.name=="Send Gmail Message") | .parameters | tostring' workflows/send-case-tracking-email.json

This currently shows a plain Gmail send with no `threadId`, no custom RFC headers, and no parent-message context.

    sed -n '1,220p' sql/041_case_tracking_schema.sql

This currently shows `public.case_emails` without standard reply-thread fields.

    jq -r '.nodes[] | select(.name=="Build Thread Upsert SQL") | .parameters.jsCode' workflows/sync-case-tracking-gmail-to-db.json

This currently shows inbound parsing that already extracts enough header information to support a stronger matching strategy.

## Interfaces and Dependencies

This implementation must continue to use:

- PostgreSQL for `public.cases` and `public.case_emails`
- n8n workflow JSON files under `/mnt/c/dev/avondale-n8n/workflows`
- Gmail as the mail transport and import source
- `public.email_templates` and `public.global_settings` for message composition defaults

At the end of implementation, the schema contract for `public.case_emails` must include:

- `id uuid`
- `case_id uuid`
- `direction text`
- `internet_message_id text`
- `in_reply_to_message_id text`
- `references_header text`
- `parent_case_email_id uuid`
- `open_tracking_token text`
- `open_tracking_enabled boolean`
- `open_tracking_status text`
- `first_opened_at timestamptz`
- `last_opened_at timestamptz`
- `open_count integer`
- `gmail_message_id text`
- `gmail_thread_id text`
- subject/body/recipient fields already present

At the end of workflow work, the repository must expose these user-visible interfaces:

- case detail page with reply actions
- preview flow that supports reply mode
- a tracking-pixel webhook that updates outbound open status
- send flow that creates thread-aware outbound replies
- send flow support for optional tracking-pixel injection on HTML outbound email
- Gmail import flow that attaches inbound replies to existing cases by message headers before falling back to label-only matching

Revision note: created this ExecPlan after inspecting the current case-tracking schema and workflows. The plan reflects that the inbound Gmail sync is already richer than the outbound send flow, so the implementation focus is explicit reply context, header storage, thread-aware send behavior, and a minimal open-tracking signal for outbound HTML email.
