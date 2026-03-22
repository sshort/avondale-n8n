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
- `capture-membership-history-season-snapshot.json`: the local workflow that captures the current season membership counts into `membership_history_snapshots` and refreshes the matching wide-year column in `membership_history`. It is scheduled for `:30` every hour.

Notes:

- These files are import-ready repository artifacts.
- The Docker build files for the supporting `clubspark-exporter` service live in `clubspark-exporter/`.
- The local server is now the active signup-processing path. The old host cron that called the cloud parser webhook has been removed.
- The cloud `New Member Email Parser` and cloud `Create Signup Batch` workflows are left in place as inactive historical copies.
- `sync-raw-tables-to-cloud.json` accepts an optional `force_full` input. When `false` or omitted, `member_signups`, `signup_batches`, and the synced `n8n` reporting tables are updated incrementally. When `true`, the workflow does a destructive full replace for `member_signups` and `signup_batches` before reloading them from local.
- `member_signups.source` is now part of the local source-of-truth model and is synced to cloud. Normal parser-created rows use `email_capture`; manually backfilled rows use `missing_signup_capture`.
- The Metabase missing-signup detector uses a `1 hour` grace period and links each row to `create-missing-signup-capture`, which can create or refresh the missing signup row and then call the local batch workflow. Future-dated memberships are treated as eligible immediately rather than being held back by the ClubSpark effective date.
- The cloud `n8n.workflow_entity` sync deliberately writes `activeVersionId = NULL` because the cloud database is only used as a reporting copy for Metabase, not as a runnable replica of local workflow history.
- `complete-signup-batch.json` expects the operator to edit the `Set Batch Id` code node before manual execution.
- The no-address batch email mechanism is documented in [NO_ADDRESS_BATCH_EMAILS.md](/mnt/c/dev/avondale-n8n/NO_ADDRESS_BATCH_EMAILS.md).
