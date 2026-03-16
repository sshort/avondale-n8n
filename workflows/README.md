# n8n Workflow Artifacts

This folder contains the workflow JSON files for the batch-processing implementation.

Files:

- `process-clubspark-member-signups.live-export.json`: the older workflow export preserved from the local live-export artifact.
- `new-member-email-parser.json`: the updated parser workflow that writes to `member_signups` with `status = 'New'`, `clubspark_status`, and `batch_id = NULL`.
- `create-signup-batch.json`: the manual batch-creation workflow.
- `complete-signup-batch.json`: the manual batch-completion workflow.
- `clubspark-contacts-export.json`: the preferred local ClubSpark contacts export workflow. It calls the `clubspark-exporter` Playwright service on the `n8n` host, then imports the CSV into `raw_contacts`.
- `clubspark-members-export.json`: the preferred local ClubSpark members export workflow. It calls the `clubspark-exporter` Playwright service on the `n8n` host, then imports the CSV into `raw_members`.
- `sync-raw-tables-to-cloud.json`: a manual local-n8n workflow that copies `raw_contacts` and `raw_members` from the local Postgres database to the cloud Postgres database.
- `clubspark-full-refresh.json`: the parent orchestration workflow for local n8n. It runs the contacts export, members export, and cloud sync workflows in sequence while keeping them independent, and ends in explicit success or error summary nodes.

Notes:

- These files are import-ready repository artifacts.
- The Docker build files for the supporting `clubspark-exporter` service live in `clubspark-exporter/`.
- Live n8n deployment was not completed because the running n8n service returns `relation "public.user" does not exist` on authenticated workflow API calls and the connected Postgres database has no `workflow_entity`, `shared_workflow`, or `user` tables to update directly.
- `complete-signup-batch.json` expects the operator to edit the `Set Batch Id` code node before manual execution.
