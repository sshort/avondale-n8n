# Raw Table Primary Keys: Safe Staged Rollout

## Status

- `Stage 1: Preparation` is complete.
- `Stage 2: Add Non-Breaking Schema` is complete locally.
- `Stage 3: Backfill Local IDs` is complete locally.
- `Stage 4: Copy IDs to Cloud` is complete.
- `Stage 5: Make Sync Fully ID-Aware` is complete.
- `Stage 6: Introduce Staging Tables` is complete locally.
- `Stage 7: Reconcile Instead of Truncate` is complete locally.
- `Stage 8: Verification and Downstream Current-Row Semantics` is complete.
- `Stage 9: Metabase Metadata Refresh and Card Review` is complete.
- `Stage 10: Enforce Primary Keys` is complete.
- `Stage 11: Cleanup` is complete.
- Current next step: rollout complete, with only optional post-rollout housekeeping remaining.

Completed Stage 1 work:

- inventory completed in
  [RAW_TABLE_DEPENDENCY_INVENTORY.md](/mnt/c/dev/avondale-n8n/docs/RAW_TABLE_DEPENDENCY_INVENTORY.md)
- explicit-column cleanup completed in:
  - [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
  - [archive-raw-members-by-season.json](/mnt/c/dev/avondale-n8n/workflows/archive-raw-members-by-season.json)
  - [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
  - [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
- live local n8n workflows updated:
  - `GIMyaYVnTEQvLLVa`
  - `SyT9FvdjQuJOcRGM`
- live local Postgres function/view definitions updated from the Stage 1 SQL files above

Completed Stage 2 work:

- added migration
  [012_raw_table_ids_stage1.sql](/mnt/c/dev/avondale-n8n/sql/012_raw_table_ids_stage1.sql)
- applied nullable columns locally to:
  - `public.raw_members`
  - `public.raw_contacts`
- added columns:
  - `id bigint`
  - `first_seen_at timestamptz`
  - `last_seen_at timestamptz`
  - `is_current boolean`
- verified the new columns are present and nullable on both current raw tables
- historical tables were left unchanged in this stage

Completed Stage 3 work:

- added migration
  [013_raw_table_id_backfill.sql](/mnt/c/dev/avondale-n8n/sql/013_raw_table_id_backfill.sql)
- created local sequences:
  - `public.raw_members_id_seq`
  - `public.raw_contacts_id_seq`
- set local defaults:
  - `public.raw_members.id -> nextval('raw_members_id_seq')`
  - `public.raw_contacts.id -> nextval('raw_contacts_id_seq')`
- backfilled all existing current rows locally:
  - `raw_members.id`
  - `raw_contacts.id`
- populated lifecycle fields locally:
  - `first_seen_at`
  - `last_seen_at`
  - `is_current = true`
- verified locally:
  - no null `id` values remain
  - no duplicate `id` values exist
  - row counts are unchanged
- sequence values are aligned to the current max IDs

Completed Stage 4 work:

- added cloud prep migration
  [014_raw_table_ids_cloud_sync.sql](/mnt/c/dev/avondale-n8n/sql/014_raw_table_ids_cloud_sync.sql)
- updated
  [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
  so the raw-table sync now:
  - reads `id`, `first_seen_at`, `last_seen_at`, `is_current` locally
  - writes those fields to cloud
  - resets `raw_members_id_seq` / `raw_contacts_id_seq` on cloud after insert
  - runs a cloud schema-prep step before the raw-table sync using:
    - [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
    - [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
    - [014_raw_table_ids_cloud_sync.sql](/mnt/c/dev/avondale-n8n/sql/014_raw_table_ids_cloud_sync.sql)
- updated the live local n8n workflow definition in the local n8n database so the running workflow matches the repo copy
- added corrective migration
  [015_raw_table_lifecycle_defaults.sql](/mnt/c/dev/avondale-n8n/sql/015_raw_table_lifecycle_defaults.sql)
  so lifecycle defaults are now enforced on both local and cloud:
  - `first_seen_at default now()`
  - `last_seen_at default now()`
  - `is_current default true`
- applied the Stage 4 cloud schema prep directly on cloud and granted `n8n-user` access
- execution-verified the live sync workflow through local n8n:
  - execution `1278` succeeded after the cloud schema and sync fixes
  - execution `1281` succeeded after the lifecycle-default correction
- verified local and cloud raw-table lifecycle counts now match:
  - `raw_members`: `872/872` rows populated for `first_seen_at`, `last_seen_at`, and `is_current`
  - `raw_contacts`: `1228/1228` rows populated for `first_seen_at`, `last_seen_at`, and `is_current`

Completed Stage 8 work:

- updated downstream current-row SQL/view definitions in:
  - [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
  - [010_signup_batch_manual_items.sql](/mnt/c/dev/avondale-n8n/sql/010_signup_batch_manual_items.sql)
- updated downstream workflow queries in:
  - [create-signup-batch.json](/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json)
  - [create-missing-signup-capture.json](/mnt/c/dev/avondale-n8n/workflows/create-missing-signup-capture.json)
  - [add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
  - [member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json)
  - [send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
  - [send-gmail-test-message.json](/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json)
- updated the live local n8n workflows to the new Stage 8 versions:
  - `YYrFJbug2FOcujPmhhQ8T`
  - `3Pqx4wurJln7h1du`
  - `rnwJ9lr346JFHAa6`
  - `Xw19pdpgo49bKfJW`
  - `otOxMsooAQde1Erj`
  - `TPqbJ7Niw68B92T3`
- applied the Stage 8 SQL updates to both local and cloud Postgres
- verified current-row semantics in live views:
  - `public.vw_signup_batch_items`
  - `public.vw_raw_contacts_all`
  - `public.vw_raw_members_all`
- verified live workflow definitions now use either:
  - `coalesce(is_current, true) = true`
  - or `public.vw_signup_batch_items` where current-row filtering is centralized
- verified the live `member-search-detail` webhook still renders correctly after the Stage 8 updates

Completed Stage 9 work:

- refreshed local Metabase database `2` metadata
- updated local Metabase cards to use current-row semantics where required:
  - `1451` `Age Ranges`
  - `1597` `Contacts - Selected Year`
  - `1608` `Count of Members Missing Signup Capture - Selected Year`
  - `1472` `Current Members - Selected Year (Map)`
  - `1609` `List of Members Missing Signup Capture - Selected Year`
  - `1505` `Members - Previous Year`
  - `1506` `Members - Selected Year`
  - `1494` `Members by category`
  - `1540` `Processed Signups Base`
- updated local raw-table technical fields to `details-only`:
  - `raw_contacts`: `id`, `first_seen_at`, `last_seen_at`, `is_current`
  - `raw_members`: `id`, `first_seen_at`, `last_seen_at`, `is_current`
- synced the Stage 9 card changes to cloud Metabase:
  - `98` `Age Ranges`
  - `115` `Contacts - Selected Year`
  - `97` `Current Members - Selected Year (Map)`
  - `82` `Members by category`
  - `86` `Members - Previous Year`
  - `124` `Members - Selected Year`
  - `155` `Processed Signups Base`
- created cloud Metabase cards:
  - `164` `Count of Members Missing Signup Capture - Selected Year`
  - `165` `List of Members Missing Signup Capture - Selected Year`
- updated cloud raw-table technical fields to `details-only`:
  - `raw_contacts` field ids `4289`, `4290`, `4291`, `4292`
  - `raw_members` field ids `4293`, `4294`, `4295`, `4296`
- verified all synced cloud cards now include current-row logic with `is_current` where applicable

Completed Stage 10 work:

- added migration
  [018_raw_table_primary_keys.sql](/mnt/c/dev/avondale-n8n/sql/018_raw_table_primary_keys.sql)
- applied it to both local and cloud Postgres
- enforced `NOT NULL` on both current raw tables for:
  - `id`
  - `first_seen_at`
  - `last_seen_at`
  - `is_current`
- added primary keys:
  - `public.raw_members_pkey`
  - `public.raw_contacts_pkey`
- set sequence ownership:
  - `public.raw_members_id_seq -> public.raw_members.id`
  - `public.raw_contacts_id_seq -> public.raw_contacts.id`
- added supporting indexes:
  - `public.raw_members_is_current_idx`
  - `public.raw_contacts_is_current_idx`
- verified on both local and cloud:
  - no null `id` values remain
  - no duplicate `id` values exist
  - primary keys are enforced on `raw_members.id` and `raw_contacts.id`

Completed Stage 11 work:

- added retirement migration
  [019_retire_old_raw_import_path.sql](/mnt/c/dev/avondale-n8n/sql/019_retire_old_raw_import_path.sql)
- applied the Stage 11 retirement migration to both local and cloud Postgres
- retired the legacy current-table reset functions in both local and cloud:
  - `public.prepare_raw_contacts_import()`
  - `public.prepare_raw_members_import()`
- updated
  [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
  so the cloud raw-table replica step now:
  - truncates `public.raw_contacts` directly before inserting replica rows
  - truncates `public.raw_members` directly before inserting replica rows
  - no longer calls the retired `prepare_raw_*_import()` functions
- updated the live local sync workflow `GIMyaYVnTEQvLLVa` to the Stage 11 version through the local n8n API
- updated
  [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
  and
  [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
  so rerunning those files does not silently restore the retired legacy functions
- verified:
  - local legacy functions are present only as retirement stubs
  - cloud legacy functions are present only as retirement stubs
  - local staging prep functions remain available:
    - `public.prepare_raw_contacts_import_staging()`
    - `public.prepare_raw_members_import_staging()`
  - the live local sync workflow builders now use direct `TRUNCATE TABLE public.raw_contacts;` and `TRUNCATE TABLE public.raw_members;`

This plan describes a low-risk rollout for adding durable primary key IDs to:

- `public.raw_members`
- `public.raw_contacts`

The IDs must be:

- unique
- preserved across imports
- replicated unchanged to cloud

## Principle

Do not jump straight to `bigserial primary key` on truncate-and-reload tables.

The safe path is:

1. prepare code and schema
2. backfill durable IDs
3. make sync ID-aware
4. replace truncate/reload imports with staging + reconcile
5. only then enforce primary key constraints

## Stage 1: Preparation

- Take fresh local and cloud backups.
- Inventory every workflow, script, SQL function, and Metabase dependency touching `raw_members` and `raw_contacts`.
- Replace risky patterns first:
  - `SELECT *`
  - `rm.*`
  - `rc.*`
  - `INSERT ... SELECT *`
- Convert those to explicit column lists before introducing `id`.

### Goal

Remove schema-shape assumptions so adding a new column is non-breaking.

### Status

Completed.

## Stage 2: Add Non-Breaking Schema

Add these columns locally to both tables:

- `id bigint`
- `first_seen_at timestamptz`
- `last_seen_at timestamptz`
- `is_current boolean`

Initial rules:

- `id` stays nullable at first
- no primary key yet
- no import logic changes yet

### Goal

Introduce the new shape without changing live behavior.

### Status

Completed locally.

## Stage 3: Backfill Local IDs

- Create sequences or identity defaults for future local inserts.
- Backfill `id` for all existing local rows.
- Populate lifecycle fields:
  - `first_seen_at`
  - `last_seen_at`
  - `is_current`

Suggested initial values:

- `first_seen_at = now()`
- `last_seen_at = now()`
- `is_current = true`

### Goal

Every current local row gets a unique durable ID before any sync or import redesign.

### Status

Completed locally.

## Stage 4: Copy IDs to Cloud

- Add the same non-breaking columns in cloud.
- Update the sync flow so `id` is included explicitly for:
  - `raw_members`
  - `raw_contacts`
- Write to cloud using explicit `id` values from local.
- Reset cloud sequences after sync with `setval(...)`.

### Goal

Cloud mirrors local IDs exactly, while local remains the sole authority for new ID generation.

### Status

Completed.

## Stage 5: Make Sync Fully ID-Aware

Update sync logic so it:

- reads explicit column lists including `id`
- writes explicit column lists including `id`
- upserts by `id` where appropriate
- does not generate new cloud-side IDs independently

Verification:

- rerun sync twice
- confirm row counts and IDs stay stable
- confirm no duplicate rows are created

### Goal

Sync becomes safe before import behavior changes.

### Status

Completed.

## Stage 6: Introduce Staging Tables

Create staging tables for fresh imports:

- `raw_members_import_staging`
- `raw_contacts_import_staging`

These should match incoming file shape and not need durable primary keys.

Import flow changes:

- load CSV into staging
- normalize values in staging
- do not write imported rows straight into current tables

### Goal

Separate file ingestion from durable current-state tables.

### Status

Completed locally.

## Stage 7: Reconcile Instead of Truncate

Replace truncate/reload with reconcile logic:

- update matched current rows in place
- preserve existing `id`
- insert unmatched rows with new local IDs
- mark unseen rows as:
  - `is_current = false`
  - or archive them separately

Suggested matching order for `raw_members`:

1. `Venue ID`
2. `British Tennis Number`
3. exact normalized `First name + Last name + category`
4. exact normalized `First name + Last name + Membership`

Suggested matching order for `raw_contacts`:

1. `Venue ID`
2. exact normalized `First name + Last name`
3. prefer richer rows with real address/email/phone completeness

### Goal

Preserve IDs across repeated imports.

### Status

Completed locally.

## Stage 8: Verification Pass

Run controlled checks:

1. import the same contacts file twice
   - IDs must not change
2. import the same members file twice
   - IDs must not change
3. change one known source row
   - same ID, updated attributes
4. remove one known source row
   - row should not be recreated with a new ID
5. sync to cloud
   - local/cloud IDs must match
6. rerun sync
   - no churn

### Goal

Prove stability before enforcing hard constraints.

### Status

Completed.

## Stage 10: Enforce Primary Keys

Only after verification:

- make `id not null`
- add primary key on `id`
- add supporting indexes
- add uniqueness constraints on natural keys only where the data actually supports them

Do not assume `Venue ID` or tennis number is universally present or unique without checking.

### Goal

Promote `id` to the formal durable primary key after behavior is already stable.

## Stage 11: Cleanup

- retire old truncate/reload code paths
- refresh Metabase metadata
- hide `id` on user-facing raw table cards where appropriate
- keep `id` visible on admin/debug views if useful

### Goal

Finish the migration cleanly without exposing unnecessary technical columns to end users.

## Stage 12: Thin Contact History Retention

- prune `public.raw_contacts_historical` to one retained row per contact identity per `snapshot_year`
- keep operational contact history in `public.raw_contacts` via:
  - `id`
  - `first_seen_at`
  - `last_seen_at`
  - `is_current`
- add an explicit yearly snapshot function instead of restoring per-import contact archiving
  - `public.archive_raw_contacts_yearly_snapshot()`
- leave `public.vw_raw_contacts_all` in place for compatibility, but treat `raw_contacts_historical` as yearly-only history

### Goal

Keep historical contact storage bounded and useful without reintroducing the retired per-import snapshot pattern.

## Recommended Implementation Order

1. Preparation and explicit column cleanup
2. Add nullable schema columns
3. Backfill local IDs
4. Replicate IDs to cloud
5. Make sync fully ID-aware
6. Add staging tables
7. Switch imports to reconcile
8. Verify repeated imports and syncs
9. Enforce `NOT NULL` and primary keys
10. Clean up old paths
11. Thin historical contact retention to yearly snapshots only

## Rollback Strategy

- Take backups before each major stage.
- Keep old import workflows/functions until the reconcile path is verified.
- Do not drop legacy behavior until repeated import and sync tests pass.
- If needed, roll back one stage at a time rather than attempting a single all-or-nothing migration.

## Summary

The critical safety rule is:

Do not make `id` the true primary key until imports stop recreating rows.

The migration is safe if IDs are introduced first, synced second, and only then made durable through staging + reconcile imports.
