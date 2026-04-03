# Retrieve and Store ClubSpark Contacts and Members Exports

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `/mnt/c/dev/PLAN.md`.

## Purpose / Big Picture

The n8n batch processing workflow depends on two external datasets from ClubSpark—Contacts and Members—to enrich new signups with address and age details. Currently, these datasets represent manual exports. After this change, an n8n workflow will automatically log into ClubSpark, fetch both CSV exports, parse them, and replace the contents of the `raw_contacts` and `raw_members` tables in PostgreSQL. 

The observable result will be a new n8n workflow export (`clubspark-export-sync.json`) that the user can import, configure with real ClubSpark credentials, and run. It will visibly update the database tables so that subsequent batch creations succeed with up-to-date address information.

## Progress

- [ ] (YYYY-MM-DD HH:MMZ) Drafted initial ExecPlan for ClubSpark synchronization.
- [ ] Implement SQL schema script for `raw_contacts` and `raw_members` if needed.
- [ ] Create the n8n workflow JSON with HTTP login, fetch, and Postgres insert nodes.
- [ ] Apply SQL schema to the database.
- [ ] Verify the workflow JSON parses.

## Surprises & Discoveries

*(To be populated as work progresses)*

## Decision Log

- Decision: Use the workflow to `TRUNCATE` and `INSERT` rather than complicated `UPSERT` logic, unless a primary key is rigidly defined in the ClubSpark export.
  Rationale: These are full dataset exports "raw_contacts" and "raw_members". Truncate-and-load is often the most robust way to sync small-to-medium datasets without dealing with deletions or complex composite keys.
  Date/Author: (Today) / Codex

- Decision: Deliver workflow as an importable JSON file under `/mnt/c/dev/avondale-n8n/workflows/`.
  Rationale: Live deployment via API is currently blocked (as noted in prior batch-processing iterations), so manual import is required.
  Date/Author: (Today) / Codex

## Outcomes & Retrospective

*(To be populated upon completion)*

## Context and Orientation

This feature is the prequel to the batch-assignment feature implemented previously (see `EXECPLAN-batch-processing.md`). In the batch creation workflow, n8n queries the database joining `member_signups` with `raw_contacts` and `raw_members`.

The relevant files for this feature:
- `/mnt/c/dev/avondale-n8n/workflows/clubspark-export-sync.json` (to be created): The workflow to fetch exports and update the tables.
- `/mnt/c/dev/avondale-n8n/sql/002_raw_tables.sql` (to be created if necessary): The migration for the target tables.
- `/home/steve/.codex/mcp_config.json`: Contains the DB connection detail `postgresql://postgres:gk^nL3cLUvtGxr@8.228.33.111:5432/postgres?sslmode=require`.

The `raw_contacts` table is expected to have fields like `"First name"`, `"Last name"`, `"Address 1"`, `"Address 2"`, `"Address 3"`, `"town"`, `"postcode"`.
The `raw_members` table is expected to have `"First name"`, `"Last name"`, `"Membership"`, `"Age"`, `"Email address"`.

## Plan of Work

1. Ensure the PostgreSQL schema cleanly supports `raw_contacts` and `raw_members`. If the tables don't exist or lack standard definition, write `002_raw_tables_schema.sql` to formally create them.
2. Build `clubspark-export-sync.json`.
    - It triggers manually.
    - It uses an HTTP Request node to authenticate with ClubSpark (likely POST to `/users/sign_in` or similar, capturing the `Set-Cookie` header).
    - It uses an HTTP Request node to GET the contacts CSV.
    - It uses the Spreadsheet File node to parse the CSV.
    - It uses a Postgres node to clear `raw_contacts` and insert the new rows.
    - It repeats the fetch/parse/insert for the members CSV.
3. Apply any SQL migration to the live DB.
4. Verify the JSON workflow artifact.

## Concrete Steps

Work from `/mnt/c/dev`.

1. Check existing tables. Connect via Python Postgres driver or MCP.
2. Create `/mnt/c/dev/avondale-n8n/sql/002_raw_tables_schema.sql` if required.
3. Apply SQL migration.
4. Create `/mnt/c/dev/avondale-n8n/workflows/clubspark-export-sync.json`.
5. Verify JSON parsing with `jq . <file>`.

Expected terminal evidence after migration:
- `raw_contacts` and `raw_members` exist in `information_schema.tables`.

## Validation and Acceptance

Acceptance is met when:
1. The Postgres schema definitions for `raw_contacts` and `raw_members` are verified or properly created.
2. The repository contains the `clubspark-export-sync.json` workflow.
3. The workflow successfully parses with `jq`.
4. The workflow contains the structural steps to authenticate, download CSVs, parse them, and insert into the database. (Real URLs and credentials will be supplied by the user upon import).

## Idempotence and Recovery

The SQL migration can be applied safely if using `CREATE TABLE IF NOT EXISTS` and simple `TRUNCATE`. 
The workflow itself is designed to do a full replace (Truncate and Load), making it naturally idempotent upon each execution.

## Interfaces and Dependencies

- Target Database: `postgresql://postgres:gk^nL3cLUvtGxr@8.228.33.111:5432/postgres?sslmode=require`
- n8n Nodes required: `n8n-nodes-base.httpRequest`, `n8n-nodes-base.spreadsheetFile`, `n8n-nodes-base.postgres`.
