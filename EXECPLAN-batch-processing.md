# Implement n8n batch processing for ClubSpark member signups

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `/mnt/c/dev/PLAN.md`.

## Purpose / Big Picture

After this change, new ClubSpark signups will be stored with a workflow processing status of `New`, separate from the membership status parsed from the ClubSpark email. A manual batch-creation workflow will claim all `New` signups into one batch, return the enriched address dataset needed for downstream manual work, and a manual batch-completion workflow will close the batch and mark its signups as `Complete`.

The observable result is three importable n8n workflow exports plus a live PostgreSQL schema that supports batching. Because the live n8n API is currently broken, the workflows will be delivered as verified importable JSON files in this repository instead of being injected directly into the running n8n instance.

## Progress

- [x] (2026-03-11 10:22Z) Read the project plan in `/mnt/c/dev/avondale-n8n/PLAN.md`, the design doc in `/mnt/c/dev/avondale-n8n/DESIGN.md`, and the ExecPlan rules in `/mnt/c/dev/PLAN.md`.
- [x] (2026-03-11 10:22Z) Confirmed the live n8n public API is server-broken: `GET /api/v1/workflows` returns `relation "public.user" does not exist`.
- [x] (2026-03-11 10:23Z) Confirmed the live database does not yet contain `signup_batches`, `member_signups.id`, `member_signups.batch_id`, or `member_signups.clubspark_status`.
- [x] (2026-03-11 10:24Z) Confirmed the live `member_signups.status` column still stores ClubSpark membership values (`Active`, `Pending`, `Inactive`) rather than workflow processing values.
- [x] (2026-03-11 10:32Z) Created repository artifacts for the implementation: `/mnt/c/dev/avondale-n8n/sql/001_batch_processing_schema.sql`, three workflow JSON files, a preserved live export, and notes about the blocked live n8n deployment path.
- [x] (2026-03-11 10:33Z) Applied the live PostgreSQL migration for `member_signups` and `signup_batches`.
- [x] (2026-03-11 10:34Z) Verified the migrated live schema and historical backfill.
- [x] (2026-03-11 10:35Z) Confirmed that live workflow deployment still has no safe path and documented the blocker in `/mnt/c/dev/avondale-n8n/workflows/README.md`.

## Surprises & Discoveries

- Observation: The live n8n public API is not usable for workflow export or import.
  Evidence: `curl -H 'X-N8N-API-KEY: ...' https://n8n-150285098361.europe-west2.run.app/api/v1/workflows?limit=1` returns `{"message":"relation \"public.user\" does not exist"}`.

- Observation: The live database connected in `/home/steve/.codex/mcp_config.json` has only a partial set of n8n tables. It contains `dynamic_credential_*` tables but no `workflow_entity`, `shared_workflow`, or `user` tables.
  Evidence: read-only `information_schema.tables` queries returned no rows for those table names.

- Observation: The live `member_signups` table has already had legacy enrichment columns removed, so older workflow exports that still insert `"First name"`, `"Last name"`, `email_address`, and address fields are now invalid against production.
  Evidence: the live column list now contains only `signup_date`, `member`, `product`, `payer`, `cost`, `quantity`, `method`, `status`, and `"Tags provided"`.

- Observation: Historical `member_signups.status` values are ClubSpark membership states, not workflow processing states.
  Evidence: `select status, count(*) from public.member_signups group by status` returned `Active=403`, `Pending=38`, `Inactive=2`, and no rows for `New`, `Processing`, `Complete`, or `Error`.

## Decision Log

- Decision: Treat the checked-in/local workflow exports as the export source of truth for implementation artifacts.
  Rationale: the live n8n API cannot currently export workflows, and the live database lacks the normal n8n workflow metadata tables.
  Date/Author: 2026-03-11 / Codex

- Decision: Migrate existing `member_signups.status` values into a new `clubspark_status` column and convert existing processing `status` values to `Complete`.
  Rationale: existing rows should not all become `New`, because that would cause the first batch-creation run to claim all historical signups. `Complete` is the safest processing status for historical rows that predate batching.
  Date/Author: 2026-03-11 / Codex

- Decision: Add a surrogate `id` column to `member_signups` as a unique row identifier without replacing the existing composite primary key.
  Rationale: the batch-assignment SQL in the design is simpler and safer with a single row identifier, but changing the primary key is unnecessary risk for this iteration.
  Date/Author: 2026-03-11 / Codex

- Decision: Deliver new workflows as importable JSON files under `/mnt/c/dev/avondale-n8n/workflows/`.
  Rationale: this keeps the implementation usable immediately once the n8n instance is repaired, even if live deployment remains blocked today.
  Date/Author: 2026-03-11 / Codex

## Outcomes & Retrospective

The database side of the feature is implemented and verified. The repository now contains the migration SQL, an updated parser workflow export, batch-creation and batch-completion workflow exports, and a preserved copy of the old live-exported workflow for reference.

The remaining gap is live n8n deployment. That is blocked by the running n8n service returning `relation "public.user" does not exist` on authenticated API requests while the connected Postgres database has no `workflow_entity`, `shared_workflow`, or `user` tables. Until that service issue is repaired, the workflow JSON files in this repository are the deployment artifacts.

## Context and Orientation

The relevant repository files are:

- `/mnt/c/dev/avondale-n8n/PLAN.md`: the original batch-processing goal.
- `/mnt/c/dev/avondale-n8n/DESIGN.md`: the design that refines the plan into concrete database and workflow behavior.
- `/mnt/c/dev/avondale-nifi/nififlow/default/New_Member_Email_n8n_Workflow.json`: a more capable local export of a parser workflow that already separates HTML normalization, subject filtering, SQL generation, and database insertion.
- `/mnt/c/dev/raw_wf.json` and `/mnt/c/dev/troubleshoot_wf.json`: local exports of the currently active older workflow named `Process ClubSpark Member Signups`, which still writes to `member_signups_dev` and still inserts columns that no longer exist on the live tables.
- `/home/steve/.codex/mcp_config.json`: the local configuration that points both Postgres and n8n access at the live systems.

In this repository, “workflow processing status” means the operational state used by batching (`New`, `Processing`, `Complete`, `Error`). “ClubSpark status” means the membership/payment state parsed from the email body (`Active`, `Pending`, `Inactive`, and similar values from ClubSpark). The implementation must keep those two meanings in separate columns.

The live database currently has:

- `public.member_signups` with the columns `signup_date`, `member`, `product`, `payer`, `cost`, `quantity`, `method`, `status`, and `"Tags provided"`.
- no `signup_batches` table.
- no `member_signups.id`, `member_signups.batch_id`, or `member_signups.clubspark_status`.

The live n8n service at `https://n8n-150285098361.europe-west2.run.app/` serves the editor static assets but fails on authenticated workflow API requests because its backing schema is incomplete. That means workflow delivery must currently happen through repository artifacts, not direct injection.

## Plan of Work

First create the implementation artifacts in the repository so there is a clear, reviewable representation of the target state. Add a SQL migration file under `/mnt/c/dev/avondale-n8n/sql/` that adds `member_signups.id`, `member_signups.clubspark_status`, `member_signups.batch_id`, and the new `signup_batches` table, backfills historical data safely, and adds the supporting indexes and foreign key.

Next create workflow export files under `/mnt/c/dev/avondale-n8n/workflows/`. One file updates the parser workflow so it inserts into `member_signups`, stores `status='New'`, stores the parsed membership state in `clubspark_status`, and no longer refers to removed legacy columns. A second file creates the manual batch-creation workflow using one PostgreSQL node for the atomic claim step and one PostgreSQL node for the enriched batch dataset query. A third file creates the manual batch-completion workflow using a manual trigger, a `Set` node for `batch_id`, a PostgreSQL node for completion, and explicit success/failure branches.

Then apply the SQL migration against the live Postgres database. After the migration, verify that the schema matches the workflow expectations and that historical rows now have `clubspark_status` populated and processing `status='Complete'`.

Finally, attempt live workflow deployment only if a safe write path exists. If not, stop after verifying the JSON workflow exports and record clearly that live deployment is blocked by the n8n service’s missing metadata tables.

## Concrete Steps

Work from `/mnt/c/dev`.

1. Create `/mnt/c/dev/avondale-n8n/sql/001_batch_processing_schema.sql` with the additive migration and historical backfill.
2. Create `/mnt/c/dev/avondale-n8n/workflows/new-member-email-parser.json`.
3. Create `/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json`.
4. Create `/mnt/c/dev/avondale-n8n/workflows/complete-signup-batch.json`.
5. Apply the migration to the live database with the Postgres MCP Python driver.
6. Verify the live schema with read-only `information_schema` queries.
7. Verify each workflow JSON file parses cleanly with `jq . <file>`.

Expected terminal evidence after the migration step:

    [
      {
        "table_name": "member_signups",
        "column_name": "clubspark_status"
      },
      {
        "table_name": "member_signups",
        "column_name": "batch_id"
      },
      {
        "table_name": "member_signups",
        "column_name": "id"
      },
      {
        "table_name": "signup_batches",
        "column_name": "id"
      }
    ]

## Validation and Acceptance

Acceptance is met when all of the following are true:

1. The live Postgres schema contains `member_signups.id`, `member_signups.clubspark_status`, `member_signups.batch_id`, and the new `signup_batches` table.
2. Historical `member_signups` rows now preserve their old values in `clubspark_status`, and their workflow `status` is no longer `Active`, `Pending`, or `Inactive`.
3. The repository contains three importable n8n workflow JSON files that reflect the intended production behavior.
4. Each workflow JSON file parses successfully with `jq`.
5. If live deployment remains impossible, the blocker is explicitly documented as an n8n service issue rather than left ambiguous.

## Idempotence and Recovery

The SQL migration must be written so it can be re-run safely. Every `ALTER TABLE` and `CREATE` should use `if not exists` where PostgreSQL supports it, and backfill statements should only modify rows that still need migration.

If the migration fails partway through, rerun the same file after correcting the cause; the file is intended to be additive and re-entrant. Do not drop the existing composite `member_signups_pk` primary key during this work. That avoids turning a partial failure into a more invasive recovery problem.

Because live n8n workflow deployment is currently blocked, repository workflow JSON files are the recovery artifact for the n8n side. They can be imported later once the live n8n service is repaired.

## Artifacts and Notes

Important current evidence:

    GET /api/v1/workflows?limit=1
    -> {"message":"relation \"public.user\" does not exist"}

    select status, count(*) from public.member_signups group by status;
    -> Active 403
    -> Pending 38
    -> Inactive 2

Important artifact paths to maintain:

- `/mnt/c/dev/avondale-n8n/sql/001_batch_processing_schema.sql`
- `/mnt/c/dev/avondale-n8n/workflows/new-member-email-parser.json`
- `/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json`
- `/mnt/c/dev/avondale-n8n/workflows/complete-signup-batch.json`

## Interfaces and Dependencies

Use the live Postgres database defined in `/home/steve/.codex/mcp_config.json`:

    postgresql://postgres:gk^nL3cLUvtGxr@8.228.33.111:5432/postgres?sslmode=require

Use the local Python interpreter and Postgres MCP library already installed in:

    /mnt/c/dev/postgres-mcp-venv-linux/bin/python

At the end of the migration, the live database must expose at least these interfaces:

- Table `public.member_signups` with:
  `id bigint`, `signup_date timestamptz`, `member varchar`, `product varchar`, `payer varchar`, `cost numeric`, `quantity integer`, `method varchar`, `status varchar`, `clubspark_status varchar`, `batch_id bigint`, `"Tags provided" text`
- Table `public.signup_batches` with:
  `id bigint`, `status text`, `created_at timestamptz`, `completed_at timestamptz`

At the end of the workflow work, the repository must contain importable n8n exports implementing:

- `new-member-email-parser.json`: IMAP-triggered parser to `member_signups`
- `create-signup-batch.json`: manual batch claim and enriched export query
- `complete-signup-batch.json`: manual batch completion by `batch_id`

Revision note: created this ExecPlan after live inspection showed that the n8n API is broken and the live database is behind the design; the plan therefore includes both the intended feature work and the current deployment blocker.

Revision note: updated after implementation to record the completed live schema migration, the generated workflow artifacts, and the final blocker on live n8n deployment.
