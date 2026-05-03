# Add Bulk BCC Member List Mailout

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with [/mnt/c/dev/PLAN.md](/mnt/c/dev/PLAN.md).

## Purpose / Big Picture

After this change, an operator will be able to open a dedicated member-mailout page, choose a predefined recipient list such as members who have not renewed this year, choose a message template and signature, preview and edit the rendered message in a rich editor, and then send the message through the shared Gmail transport with all real recipients placed in `BCC`.

The visible proof is simple. The operator opens one page, selects a recipient list, clicks preview, sees a rendered compose surface with a live preview panel, and then sends the email. In production mode the message goes out with a visible `To` address owned by the club and the selected list is sent in `BCC` chunks. In test mode the same page still works, but the real recipient list is replaced by the configured test recipient.

This is intentionally a generic list mailout surface, not a one-off non-renewal script. The first list we will support is non-renewers, but the page and send path should be structured so more predefined lists can be added without redesigning the UI.

## Progress

- [x] (2026-04-30 20:46Z) Created GitHub issue `#96`, added it to the `avondale-n8n board`, moved the project item to `In Progress`, and added an implementation note.
- [x] (2026-04-30 20:52Z) Confirmed the repository already has the necessary building blocks for this feature: active email templates, signature templates, HTML-capable preview pages, and the shared `email-send-core` transport with `bcc` support.
- [x] (2026-04-30 20:57Z) Confirmed there is no existing generic “bulk member mailout” page, so this should be implemented as a standalone workflow rather than by overloading the single-member detail email flow.
- [x] (2026-04-30 21:05Z) Confirmed the current raw membership data is only for the current season, so non-renewers must be resolved from `member_signups` plus current contacts rather than from historical `raw_members` snapshots alone.
- [x] (2026-04-30 21:09Z) Confirmed a viable first non-renewer cohort exists by matching prior-season signup rows to current contacts with email and excluding anyone who now has a current-season raw membership row.
- [x] (2026-04-30 21:18Z) Wrote this ExecPlan and checked it into `docs/EXECPLAN-bulk-bcc-member-list-mailout.md`.
- [x] (2026-04-30 21:32Z) Confirmed the existing Metabase saved query `List of Members Not Renewed - Current Year` (card `1489`) should be treated as the source-of-truth shape for the non-renewer cohort rather than a simpler ad hoc signup-only heuristic.
- [x] (2026-04-30 21:35Z) Confirmed junior mailouts should prefer the adult/main-contact email and that the available inputs are `vw_junior_main_contacts` plus historical `raw_members_main_contacts` rows.
- [x] (2026-04-30 21:18Z) Added `member-list-mailout-app.json` as the standalone selector page for predefined recipient cohorts and template/signature selection.
- [x] (2026-05-01 12:15Z) Added `preview-member-list-email.json` with server-side cohort resolution, list token rendering, and a rich HTML/plain-text preview surface.
- [x] (2026-05-01 12:23Z) Added `send-member-list-email.json` with server-side re-resolution, recipient dedupe, and production BCC chunking through `email-send-core`.
- [x] (2026-05-01 12:31Z) Validated `member-list-mailout-app.json`, `preview-member-list-email.json`, and `send-member-list-email.json` with `jq` plus JavaScript syntax checks over each code node.
- [x] (2026-05-02 14:00Z) Deployed and executed first live production mailout (job `7e053691-69db-4653-90fc-3cc21ec46e2c`): 59 intended recipients, 32 delivered before execution error at 14:10:13 UTC.
- [x] (2026-05-03) Recovered sent/open status for job `7e053691-…`: inserted 31 missing recipient rows, patched liz.pitt open data, updated sent_count to 32, and patched job metadata with `included_recipient_keys` and render fields (recovered from n8n execution data).
- [x] (2026-05-03) Added `member-list-mailout-open-pixel.json`, `member-list-mailout-report.json`, `member-list-mailout-resume.json`, `member-list-mailout-delete-job.json` to the repo.
- [x] (2026-05-03) Updated `send-member-list-email.json`, `preview-member-list-email.json`, `member-list-mailout-app.json` to match live n8n state (includes 6 logging nodes and Resume/Delete UI).
- [x] (2026-05-03) Report page updated with Resume button (shown for Paused/Sending jobs) and Delete job form (with confirmation dialog) on both job detail and job list views.

## Surprises & Discoveries

- Observation: the shared send helper already supports `bcc`, so this feature does not need a new Gmail transport.
  Evidence: `workflows/email-send-core.json` already normalizes `to`, `cc`, and `bcc` and emits a `Bcc` header in the generated MIME message.

- Observation: the single-member preview/send path is not the right place to bolt this on.
  Evidence: `workflows/preview-member-template-email.json` and `workflows/send-member-template-email.json` assume one resolved member record, one final recipient, and member-specific token substitution.

- Observation: non-renewers are not directly recoverable from current `raw_members` alone because the current raw membership export is already season-specific.
  Evidence: querying `public.raw_members` showed current rows for `2026` memberships and no current `2025` rows, while `member_signups` still contains prior-season package rows.

- Observation: `raw_contacts` with no current membership is broader than “non-renewed member”.
  Evidence: a contact can exist without being a prior member, so the first non-renewer list should anchor on prior signup history and then use contacts to recover the best email address.

- Observation: the repo already has a better non-renewer query than the initial workflow draft.
  Evidence: Metabase card `1489`, `List of Members Not Renewed - Current Year`, already implements the club’s prior-vs-current membership comparison against `membership_packages` and should be reused as the resolver shape.

- Observation: junior recipient resolution cannot rely only on the member’s own email row.
  Evidence: `vw_junior_main_contacts` exposes `main_contact_email`, `main_contact_phone`, and address data, and historical rows remain available in `raw_members_main_contacts` for prior-season matching.

## Decision Log

- Decision: build a standalone member-mailout app page instead of adding this to the member detail page.
  Rationale: the user goal is list-based outreach, not a different variation of single-member email. A separate page keeps the contract clear and avoids destabilizing the existing member-detail workflow.
  Date/Author: 2026-04-30 / Codex

- Decision: send generic list emails as BCC mailouts, not one personalized send per recipient.
  Rationale: the user explicitly wants all emails sent BCC. That means the message body must be shared across the list and cannot depend on per-recipient token substitution.
  Date/Author: 2026-04-30 / Codex

- Decision: keep v1 schema-free and resolve recipient lists directly in workflow SQL.
  Rationale: this feature can be delivered without introducing a new table or view. That keeps the first slice smaller and lets us prove the UX before deciding whether recipient-list definitions need to become data-driven later.
  Date/Author: 2026-04-30 / Codex

- Decision: make non-renewers the first supported list, but structure the UI around predefined list keys so more lists can be added later.
  Rationale: the user’s motivating example is non-renewers, but the request is clearly for reusable list-based emailing, not a one-off page.
  Date/Author: 2026-04-30 / Codex

- Decision: drive the non-renewer recipient resolver from the existing Metabase query logic instead of a workflow-local signup heuristic.
  Rationale: the Metabase card is already the club’s working definition of non-renewers and avoids creating a second, slightly different answer in n8n.
  Date/Author: 2026-04-30 / Codex

- Decision: prefer the main-contact email for juniors whenever a reliable main-contact row exists.
  Rationale: outreach about membership renewal should go to the adult/main contact for juniors, not blindly to the junior member row.
  Date/Author: 2026-04-30 / Codex

- Decision: chunk production BCC sends.
  Rationale: very large BCC lists are fragile and can run into provider limits. Chunking the BCC list keeps the contract safe and predictable without changing the user-facing UI.
  Date/Author: 2026-04-30 / Codex

## Outcomes & Retrospective

- Implemented a standalone preview/send flow for list-based member mailouts with shared Gmail transport reuse.
- First live production mailout (2026-05-02) delivered 32 of 59 emails before an n8n execution timeout. Recovered via DB surgery: extracted chunk payloads and open-pixel hits from n8n execution data, inserted missing recipient rows, patched job metadata with the original recipient list so Resume can safely continue.
- Resume workflow deduplicates against already-sent rows so re-running after a partial failure is safe.
- Report page gained Resume and Delete actions. Delete workflow (`member-list-mailout-delete-job.json`) cascades recipients before removing the job row.
- All seven mailout workflows are now in sync between repo and live n8n.

## Context and Orientation

The relevant repository is `/mnt/c/dev/avondale-n8n`.

The reusable email pieces already in place are:

- [workflows/email-send-core.json](/mnt/c/dev/avondale-n8n/workflows/email-send-core.json)
- [workflows/preview-member-template-email.json](/mnt/c/dev/avondale-n8n/workflows/preview-member-template-email.json)
- [workflows/send-member-template-email.json](/mnt/c/dev/avondale-n8n/workflows/send-member-template-email.json)
- [workflows/email-template-editor-app.json](/mnt/c/dev/avondale-n8n/workflows/email-template-editor-app.json)
- [sql/004_email_templates.sql](/mnt/c/dev/avondale-n8n/sql/004_email_templates.sql)
- [sql/025_email_template_types_and_consent_request.sql](/mnt/c/dev/avondale-n8n/sql/025_email_template_types_and_consent_request.sql)
- [sql/045_html_templates_table.sql](/mnt/c/dev/avondale-n8n/sql/045_html_templates_table.sql)

The relevant recipient data sources are:

- `public.member_signups`
- `public.raw_contacts`
- `public.raw_members`
- `public.resolve_best_contact_row(...)`

The initial recipient-list requirement is:

- members who have not renewed this year

The first implementation will also leave room for additional predefined list keys without assuming that every possible list must be supported now.

## Target UX

### 1. Member Mailout Page

Add a new GET workflow page, for example `member-list-mailout`, that shows:

- recipient list selector
- message template selector
- signature selector
- test mode checkbox or equivalent existing mode control
- clear note that production sends are BCC-only
- button to open the preview page

The first recipient lists should be hardcoded in the page/workflow, not stored in the database:

- `non_renewed_members`
- `current_members`
- `contacts_without_current_membership`

Only the first one is critical for the user request; the others make the surface genuinely reusable.

### 2. Preview Page

Add a preview workflow that:

- loads the chosen list
- resolves the actual recipients
- loads the chosen message template and signature
- renders list-level tokens into the subject/body
- shows a rich HTML editor when the template has HTML
- shows a plain textarea when the template is text-only
- shows a live preview panel
- shows recipient count and a small recipient sample
- posts the edited message to the send workflow

This preview is generic-list oriented, not member oriented. Useful tokens should be list-level values such as:

- `{{$json.list_name}}`
- `{{$json.recipient_count}}`
- `{{$json.current_season}}`
- `{{$json.previous_season}}`

### 3. Send Path

Add a send workflow that:

- resolves the same recipient list again server-side
- deduplicates recipient emails
- sends production mail with `to = club visible address` and `bcc = recipient chunk`
- sends test mail with `to = club visible address` and `bcc = configured test recipient`
- reuses `email-send-core`
- returns a success page summarizing list name, recipient count, mode, and chunk count

## Recipient Resolution Rules

### Non-renewed members

The first non-renewer query should:

1. determine the current season from the same `membership_packages` / current-membership logic used by the existing Metabase card
2. treat the previous season as `current_season - 1`
3. reuse the same current-vs-previous member comparison shape already used in Metabase
4. for juniors, prefer `main_contact_email` from `vw_junior_main_contacts` and then historical `raw_members_main_contacts` matching
5. otherwise recover the best email with `resolve_best_contact_row`
6. exclude anyone who now has a current-season membership row
7. deduplicate by final recipient email

This is intentionally “people the club already treats as non-renewers in Metabase”, not merely “any contact without a current membership”.

### Current members

Resolve from current `raw_members` rows that match the current season and recover the best email via `resolve_best_contact_row`.

### Contacts without current membership

Resolve from `raw_contacts` rows that have an email address and no matching current `raw_members` row for the same person.

## Plan of Work

### 1. Add the standalone selector page

Create a new workflow export, likely [member-list-mailout-app.json](/mnt/c/dev/avondale-n8n/workflows/member-list-mailout-app.json), that loads:

- default delivery mode
- default test recipient
- sender name
- reply-to
- default signature template key
- active message templates
- active signature templates

The page should submit to the preview workflow using query parameters.

### 2. Add the preview workflow

Create a new workflow export, likely [preview-member-list-email.json](/mnt/c/dev/avondale-n8n/workflows/preview-member-list-email.json), that:

- validates the request
- resolves the recipient list server-side
- loads the chosen template and signature
- performs list-level token substitution
- renders a rich-edit compose surface
- posts to the send workflow

This should match the interaction quality of the newer email preview pages, but it does not need per-recipient token substitution because the message is generic to the whole BCC list.

### 3. Add the send workflow

Create a new workflow export, likely [send-member-list-email.json](/mnt/c/dev/avondale-n8n/workflows/send-member-list-email.json), that:

- validates the edited compose payload
- resolves the recipient list again
- builds one or more BCC chunks
- posts each chunk to `http://127.0.0.1:5678/webhook/email-send-core`
- aggregates the result
- returns an HTML success page

### 4. Keep the visible `To` address stable

Use the club address from the resolved mail settings as the visible `To` target. The real recipients go only in `BCC`.

For v1, `reply_to` is an acceptable visible-address fallback because the existing mail settings already point at the club mailbox.

## Concrete Steps

Work from `/mnt/c/dev/avondale-n8n`.

Validate the new workflow exports after editing:

```bash
cd /mnt/c/dev/avondale-n8n
jq empty \
  workflows/member-list-mailout-app.json \
  workflows/preview-member-list-email.json \
  workflows/send-member-list-email.json
```

If the workflows are later synced into n8n, use the existing repository sync path once stable:

```bash
cd /mnt/c/dev/avondale-n8n
node scripts/sync-workflow-json-to-n8n-db.mjs <workflow-id> workflows/member-list-mailout-app.json
node scripts/sync-workflow-json-to-n8n-db.mjs <workflow-id> workflows/preview-member-list-email.json
node scripts/sync-workflow-json-to-n8n-db.mjs <workflow-id> workflows/send-member-list-email.json
```

## Validation and Acceptance

Acceptance is behavioral.

The feature is accepted only when a human can do all of the following:

1. Open the new member-mailout page.
2. Choose `Members who have not renewed this year`.
3. Choose a message template and a signature.
4. Open the preview page and see a recipient count plus a live preview panel.
5. Edit the subject and body in the preview surface.
6. Send in test mode and confirm that only the configured test recipient receives the message.
7. Confirm that the visible `To` address is the club mailbox and that the actual recipients are handled through `BCC`.

Repository acceptance is `jq empty` passing for all new workflow JSON exports.

## Idempotence and Recovery

This work is additive. It introduces new workflows and does not need to replace the existing single-member preview/send path.

If the new page or send path is not ready, it can remain undeployed without affecting the current email features.

If production BCC chunking proves too aggressive or too small, the chunk size can be adjusted in the send workflow without changing the page contract.
