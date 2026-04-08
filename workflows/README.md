# n8n Workflow Artifacts

This folder contains the workflow JSON files for the batch-processing implementation.

Files:

- `process-clubspark-member-signups.live-export.json`: the older workflow export preserved from the local live-export artifact.
- `new-member-email-parser.json`: the live local parser workflow. It polls unread Gmail messages on a local `Schedule Trigger` at `15` minutes past each hour, writes to local `member_signups` with `status = 'New'`, updates `email_status`, marks the Gmail messages as read, and then calls the local batch workflow.
- `create-signup-batch.json`: the live local batch-creation workflow. It now includes `When Executed by Another Workflow` so the parser can call it directly.
- `complete-signup-batch.json`: the manual batch-completion workflow.
- `clubspark-contacts-export.json`: the preferred local ClubSpark contacts export workflow. It calls the `clubspark-exporter` Playwright service on the `n8n` host, then imports the CSV into `raw_contacts`.
- `clubspark-members-export.json`: the preferred local ClubSpark members export workflow. It calls the `clubspark-exporter` Playwright service on the `n8n` host, then imports the CSV into `raw_members`.
- `sync-raw-tables-to-cloud.json`: the local source-of-truth sync workflow. It full-syncs `raw_contacts`, `raw_members`, `membership_history`, and `membership_history_snapshots`, upserts `member_signups` and `signup_batches` into cloud by default, and also syncs `n8n.workflow_entity` and `n8n.execution_entity` so the cloud Metabase execution cards reflect the local server.
- `clubspark-full-refresh.json`: the parent orchestration workflow for local n8n. It runs the contacts export, members export, and cloud sync workflows in sequence while keeping them independent, and ends in explicit success or error summary nodes.
- `send-no-address-batch-emails.json`: the local workflow that emails batch recipients who have email but do not have a valid postal address. It uses the `shoe_tag_pigeon_hole` template, supports `production` and `test` delivery modes, respects `signup_batches.no_address_email_sent`, and allows a webhook `override=true` resend.
- `create-missing-signup-capture.json`: the local workflow that backfills a missing `member_signups` row from `raw_members` and `raw_contacts`. It is intended for members flagged by the Metabase missing-signup detector, tags inserted rows with `source = 'missing_signup_capture'`, and for family memberships prefers the best household contact with a usable address rather than a sparse child contact row.
- `add-manual-batch-item.json`: the local workflow that adds shoe tags, parent tags, and keys directly to a batch without creating a fake `member_signups` row. It inserts into `signup_batch_manual_items` with `source = 'manual'`.
- `manual-batch-item-form.json`: the local workflow that serves the HTML form used from Metabase. It lets an operator choose manual shoe tag / parent tag / key counts for a selected member, then submits to `add-manual-batch-item`.
- `capture-membership-history-season-snapshot.json`: the local workflow that captures the current season membership counts into `membership_history_snapshots` and refreshes the matching wide-year column in `membership_history`. It is scheduled for `:30` every hour.
- `metabase-report-form.json`: the HTML form workflow for operator-driven dashboard PDF generation. It serves the dashboard selector, tab checklist, report mode selector, and redaction inputs from `global_settings`.
- `metabase-report-generate.json`: the PDF generation workflow. It validates the submitted form, calls the local `clubspark-exporter` Playwright service, then post-processes the merged PDF with Stirling PDF.

Notes:

- These files are import-ready repository artifacts.
- The Docker build files for the supporting `clubspark-exporter` service live in `clubspark-exporter/`.
- The local server is now the active signup-processing path. The old host cron that called the cloud parser webhook has been removed.
- The cloud `New Member Email Parser` and cloud `Create Signup Batch` workflows are left in place as inactive historical copies.
- `sync-raw-tables-to-cloud.json` accepts an optional `force_full` input. When `false` or omitted, `member_signups`, `signup_batches`, and the synced `n8n` reporting tables are updated incrementally. When `true`, the workflow does a destructive full replace for `member_signups` and `signup_batches` before reloading them from local.
- `member_signups.source` is now part of the local source-of-truth model and is synced to cloud. Normal parser-created rows use `email_capture`; manually backfilled rows use `missing_signup_capture`.
- The Metabase missing-signup detector uses a `1 hour` grace period and links each row to `create-missing-signup-capture`, which can create or refresh the missing signup row and then call the local batch workflow. Future-dated memberships are treated as eligible immediately rather than being held back by the ClubSpark effective date.
- Manual batch additions are stored in `public.signup_batch_manual_items`, not `public.member_signups`. The combined batch views `vw_signup_batch_items`, `vw_signup_batch_consolidated`, and `vw_signup_batches_summary` are the reporting surface for labels, exports, and dashboard counts.
- The cloud `n8n.workflow_entity` sync deliberately writes `activeVersionId = NULL` because the cloud database is only used as a reporting copy for Metabase, not as a runnable replica of local workflow history.
- `complete-signup-batch.json` expects the operator to edit the `Set Batch Id` code node before manual execution.
- The no-address batch email mechanism is documented in [NO_ADDRESS_BATCH_EMAILS.md](/mnt/c/dev/avondale-n8n/docs/NO_ADDRESS_BATCH_EMAILS.md).
- The manual batch item mechanism is documented in [MANUAL_BATCH_ITEMS.md](/mnt/c/dev/avondale-n8n/docs/MANUAL_BATCH_ITEMS.md).
- The Metabase report PDF workflow is documented in [METABASE_REPORT_PDF_WORKFLOW_SPEC.md](/mnt/c/dev/avondale-n8n/docs/METABASE_REPORT_PDF_WORKFLOW_SPEC.md).
- Non-secret runtime values are now centralized in `public.global_settings`, seeded by [009_global_settings.sql](/mnt/c/dev/avondale-n8n/sql/009_global_settings.sql). Current keys include:
  - `clubspark_exporter_base_url`
  - `gotenberg_base_url`
  - `metabase_base_url`
  - `stirling_base_url`
  - `metabase_report_dashboards_json`
  - `metabase_report_redaction_profiles_json`
  - `clubspark_venue_slug`
  - `email_sender_name`
  - `email_reply_to`
  - `email_test_recipient`
  - `email_delivery_mode`
  - `no_address_email_template_key`
  - `gmail_test_email_template_key`
  - `signup_imap_mailbox`
- `metabase_report_dashboards_json` can also carry per-dashboard export overrides such as `snapshotDashcards`, which identifies dashcards by stable keys like `dashcardKey` or `cardKey` when a chart needs to be appended as a standalone PDF page.
- Secrets remain in n8n credentials or environment variables. The settings table is only for non-secret values such as service endpoints, reply-to addresses, template keys, and venue slugs.
