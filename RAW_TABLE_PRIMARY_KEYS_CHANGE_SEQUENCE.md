# Raw Table Primary Keys: Concrete Change Sequence

## Status

- `Stage 0: Freeze Point and Backups` is complete.
- `Stage 1: Remove Schema-Shape Risks Before Adding Columns` is complete.
- `Stage 2: Add Non-Breaking Local Schema` is complete locally.
- `Stage 3: Backfill Local IDs and Lifecycle Fields` is complete locally.
- `Stage 4: Make Local-to-Cloud Sync ID-Aware` is complete.
- `Stage 5: Introduce Staging Tables` is complete locally.
- `Stage 6: Build Reconcile Functions` is complete locally.
- `Stage 7: Switch Import Workflows to Staging + Reconcile` is complete locally.
- `Stage 8: Update Downstream Views and Queries for Current-Row Semantics` is complete.
- `Stage 9: Metabase Metadata Refresh and Card Review` is complete.
- `Stage 10: Enforce Primary Keys` is complete.
- `Stage 11: Retire Old Snapshot/Truncate Path` is complete.
- Current next step: rollout complete, with only optional cleanup/monitoring remaining.

Completed work:

- backups taken before this phase
- dependency inventory written in
  [RAW_TABLE_DEPENDENCY_INVENTORY.md](/mnt/c/dev/avondale-n8n/RAW_TABLE_DEPENDENCY_INVENTORY.md)
- Stage 1 repo changes completed in:
  - [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
  - [archive-raw-members-by-season.json](/mnt/c/dev/avondale-n8n/workflows/archive-raw-members-by-season.json)
  - [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
  - [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
- Stage 1 live local updates applied to:
  - workflow `GIMyaYVnTEQvLLVa`
  - workflow `SyT9FvdjQuJOcRGM`
  - local Postgres function/view definitions from the SQL files above
- Stage 2 local schema migration added and applied:
  - [012_raw_table_ids_stage1.sql](/mnt/c/dev/avondale-n8n/sql/012_raw_table_ids_stage1.sql)
  - nullable columns added to `public.raw_members` and `public.raw_contacts`
  - verified present and nullable after apply
- Stage 3 local backfill migration added and applied:
  - [013_raw_table_id_backfill.sql](/mnt/c/dev/avondale-n8n/sql/013_raw_table_id_backfill.sql)
  - created `public.raw_members_id_seq` and `public.raw_contacts_id_seq`
  - backfilled all current local `id` values and lifecycle fields
  - verified:
    - no null `id` values remain
    - no duplicate `id` values exist
    - defaults are set for future inserts
    - sequence values match the current local maxima
- Stage 4 implementation completed:
  - added [014_raw_table_ids_cloud_sync.sql](/mnt/c/dev/avondale-n8n/sql/014_raw_table_ids_cloud_sync.sql)
  - updated [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json) so the raw-table sync now:
    - reads `id`, `first_seen_at`, `last_seen_at`, `is_current`
    - writes those fields to cloud
    - resets cloud `raw_members_id_seq` / `raw_contacts_id_seq` after insert
    - runs a cloud schema-prep step before the raw-table sync
  - updated the live local sync workflow definition in the local n8n database so it matches the repo copy
  - added [015_raw_table_lifecycle_defaults.sql](/mnt/c/dev/avondale-n8n/sql/015_raw_table_lifecycle_defaults.sql)
    to correct missing lifecycle defaults after the first live Stage 4 run
  - applied the cloud schema/grant changes directly where owner-level DDL was required
  - verified the live workflow through local n8n executions:
    - `1278` successful after the cloud schema/sync fixes
    - `1281` successful after the lifecycle-default correction
  - verified local/cloud lifecycle coverage:
    - `raw_members`: `872/872`
    - `raw_contacts`: `1228/1228`
- Stage 5 staging work completed locally:
  - added [016_raw_table_import_staging.sql](/mnt/c/dev/avondale-n8n/sql/016_raw_table_import_staging.sql)
  - created local tables:
    - `public.raw_members_import_staging`
    - `public.raw_contacts_import_staging`
  - created local staging prep functions:
    - `public.prepare_raw_members_import_staging()`
    - `public.prepare_raw_contacts_import_staging()`
  - verified rolled-back test loads succeeded:
    - `872` rows into `raw_members_import_staging`
    - `1228` rows into `raw_contacts_import_staging`
  - verified both staging tables were empty again after rollback
- Stage 6 reconcile work completed locally:
  - added [017_raw_table_reconcile.sql](/mnt/c/dev/avondale-n8n/sql/017_raw_table_reconcile.sql)
  - created helper functions:
    - `public.normalize_match_text(text)`
    - `public.normalize_membership_category(text)`
  - created reconcile functions:
    - `public.reconcile_raw_members_from_staging()`
    - `public.reconcile_raw_contacts_from_staging()`
  - verified rolled-back reconciliation against the current local dataset:
    - members result: `updated=872, inserted=0, deactivated=0`
    - contacts result: `updated=1228, inserted=0, deactivated=0`
  - verified row counts and distinct `id` counts were unchanged during the test
- Stage 7 import cutover completed locally:
  - updated [clubspark-members-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-members-export.json)
    to:
    - truncate `raw_members_import_staging`
    - load the CSV into `raw_members_import_staging`
    - call `public.reconcile_raw_members_from_staging()`
    - stop calling `prepare_raw_members_import()`
  - updated [clubspark-contacts-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-contacts-export.json)
    to:
    - truncate `raw_contacts_import_staging`
    - load the CSV into `raw_contacts_import_staging`
    - call `public.reconcile_raw_contacts_from_staging()`
    - stop calling `prepare_raw_contacts_import()`
  - updated the live local n8n workflows:
    - `0cLfjgMnyQeFcJ8T` `ClubSpark Members Export`
    - `6XC5aXJ8uS5DS553` `ClubSpark Contacts Export`
  - execution-verified repeated live imports:
    - members `1283`: `updated=872, inserted=0, deactivated=0`
    - members `1284`: `updated=872, inserted=0, deactivated=0`
    - contacts `1285`: `updated=1228, inserted=0, deactivated=0`
    - contacts `1286`: `updated=1228, inserted=0, deactivated=0`
  - verified repeated live imports produced no inserted or deactivated rows, confirming IDs were preserved across reruns for the current source data
- Stage 8 downstream current-row semantics completed:
  - updated SQL/view definitions in:
    - [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
    - [010_signup_batch_manual_items.sql](/mnt/c/dev/avondale-n8n/sql/010_signup_batch_manual_items.sql)
  - updated downstream workflow queries in:
    - [create-signup-batch.json](/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json)
    - [create-missing-signup-capture.json](/mnt/c/dev/avondale-n8n/workflows/create-missing-signup-capture.json)
    - [add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
    - [member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json)
    - [send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
    - [send-gmail-test-message.json](/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json)
  - updated live local n8n workflows:
    - `YYrFJbug2FOcujPmhhQ8T`
    - `3Pqx4wurJln7h1du`
    - `rnwJ9lr346JFHAa6`
    - `Xw19pdpgo49bKfJW`
    - `otOxMsooAQde1Erj`
    - `TPqbJ7Niw68B92T3`
  - applied the Stage 8 SQL updates to both local and cloud Postgres
  - verified current-row filtering in:
    - `public.vw_signup_batch_items`
    - `public.vw_raw_contacts_all`
    - `public.vw_raw_members_all`
  - verified live workflow definitions now either filter with `coalesce(is_current, true) = true` or route through `public.vw_signup_batch_items`
  - verified the live `member-search-detail` webhook still renders correctly after the Stage 8 changes
- Stage 9 Metabase cleanup completed locally and in cloud:
  - refreshed local Metabase metadata for database `2`
  - updated local cards:
    - `1451`, `1597`, `1608`, `1472`, `1609`, `1505`, `1506`, `1494`, `1540`
  - updated local raw-table technical fields to `details-only`:
    - `raw_contacts`: `id`, `first_seen_at`, `last_seen_at`, `is_current`
    - `raw_members`: `id`, `first_seen_at`, `last_seen_at`, `is_current`
  - synced Stage 9 card definitions to cloud:
    - `98`, `115`, `97`, `82`, `86`, `124`, `155`
  - created cloud cards:
    - `164` `Count of Members Missing Signup Capture - Selected Year`
    - `165` `List of Members Missing Signup Capture - Selected Year`
  - refreshed cloud Metabase metadata and updated cloud raw-table technical fields to `details-only`:
    - `raw_contacts` field ids `4289`, `4290`, `4291`, `4292`
    - `raw_members` field ids `4293`, `4294`, `4295`, `4296`
  - verified all Stage 9 cloud cards include current-row logic with `is_current` where applicable
- Stage 10 primary key enforcement completed locally and in cloud:
  - added [018_raw_table_primary_keys.sql](/mnt/c/dev/avondale-n8n/sql/018_raw_table_primary_keys.sql)
  - applied it to both local and cloud Postgres
  - enforced `NOT NULL` on:
    - `raw_members.id`
    - `raw_members.first_seen_at`
    - `raw_members.last_seen_at`
    - `raw_members.is_current`
    - `raw_contacts.id`
    - `raw_contacts.first_seen_at`
    - `raw_contacts.last_seen_at`
    - `raw_contacts.is_current`
  - added primary keys:
    - `raw_members_pkey`
    - `raw_contacts_pkey`
  - added supporting indexes:
    - `raw_members_is_current_idx`
    - `raw_contacts_is_current_idx`
  - verified local and cloud state after apply:
    - `raw_members`: `885` rows, `0` null `id`, `885` distinct `id`
    - `raw_contacts`: `1231` rows, `0` null `id`, `1231` distinct `id`
- Stage 11 old-path retirement completed locally and in cloud:
  - added [019_retire_old_raw_import_path.sql](/mnt/c/dev/avondale-n8n/sql/019_retire_old_raw_import_path.sql)
  - applied it to both local and cloud Postgres
  - retired the legacy functions:
    - `public.prepare_raw_contacts_import()`
    - `public.prepare_raw_members_import()`
  - updated [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
    so cloud raw-table replica loads now use direct:
    - `TRUNCATE TABLE public.raw_contacts;`
    - `TRUNCATE TABLE public.raw_members;`
  - updated the live local sync workflow `GIMyaYVnTEQvLLVa` through the local n8n API so it matches the repo copy
  - updated [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
    and [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
    so those files now preserve the retirement stubs instead of recreating the legacy functions
  - verified:
    - local legacy functions are retirement stubs
    - cloud legacy functions are retirement stubs
    - local staging prep functions remain in place
    - the live local sync workflow no longer references `prepare_raw_contacts_import()` or `prepare_raw_members_import()`

This is the execution sequence for adding durable primary keys to:

- `public.raw_members`
- `public.raw_contacts`

The aim is:

- unique IDs
- preserved across imports
- replicated unchanged to cloud
- minimal risk during rollout

This document builds on:

- [RAW_TABLE_PRIMARY_KEYS_PLAN.md](/mnt/c/dev/avondale-n8n/RAW_TABLE_PRIMARY_KEYS_PLAN.md)
- [RAW_TABLE_PRIMARY_KEYS_SAFE_STAGES_PLAN.md](/mnt/c/dev/avondale-n8n/RAW_TABLE_PRIMARY_KEYS_SAFE_STAGES_PLAN.md)
- [RAW_TABLE_DEPENDENCY_INVENTORY.md](/mnt/c/dev/avondale-n8n/RAW_TABLE_DEPENDENCY_INVENTORY.md)

## Stage 0: Freeze Point and Backups

Do this before any schema work.

### Actions

- Take fresh local DB backup.
- Take fresh cloud DB backup.
- Export current local n8n workflows.
- Export current local Metabase cards and dashboards.

### Files / systems

- local backup folder under [backups](/mnt/c/dev/avondale-n8n/backups)
- live local Postgres
- live cloud Postgres
- live local n8n
- live local Metabase

### Exit criteria

- verified local and cloud dumps exist
- verified current workflow exports exist
- verified current Metabase exports exist

### Status

Completed.

## Stage 1: Remove Schema-Shape Risks Before Adding Columns

This stage is about eliminating unsafe assumptions like `SELECT *`, `public.raw_members.*`, and full-row archive inserts.

### 1.1 Update raw-table cloud sync to explicit column reads

### File

- [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)

### Current risks

- `SELECT * FROM public.raw_contacts`
- `SELECT * FROM public.raw_members`

### Required change

- replace both `SELECT *` queries with explicit column lists
- keep the lists aligned with current import columns
- do not include future `id` yet in this stage

### Why now

Adding `id` later should not silently alter sync payload shape.

### 1.2 Update raw-table archive/import functions to stop whole-row inserts

### Files

- [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
- [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)

### Current risks

- `insert into public.raw_contacts_historical select public.raw_contacts.*, ...`
- `insert into public.raw_members_historical select public.raw_members.*, ...`

### Required change

- replace `public.raw_contacts.*` with explicit column lists
- replace `public.raw_members.*` with explicit column lists
- make current-to-historical mapping explicit

### Why now

If `id` is added to current tables before this is fixed, archive writes can break or copy the wrong shape.

### 1.3 Review archive workflow logic for row-shape assumptions

### File

- [archive-raw-members-by-season.json](/mnt/c/dev/avondale-n8n/workflows/archive-raw-members-by-season.json)

### Required change

- confirm there is no `SELECT *`, `rm.*`, or implicit archive column parity
- if present, replace with explicit columns

### Why now

This is the most likely workflow to break once new columns are introduced.

### 1.4 Keep enrichment workflows on named fields only

### Files

- [create-signup-batch.json](/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json)
- [create-missing-signup-capture.json](/mnt/c/dev/avondale-n8n/workflows/create-missing-signup-capture.json)
- [add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
- [member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json)
- [send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
- [send-gmail-test-message.json](/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json)

### Required change

- verify these flows use named business columns only
- no action unless hidden `SELECT *` assumptions are found

### Exit criteria for Stage 1

- all raw-table sync and archive logic uses explicit columns
- no live workflow depends on whole-row shape of `raw_members` / `raw_contacts`

### Status

Completed.

## Stage 2: Add Non-Breaking Local Schema

This stage introduces the new columns without changing behavior yet.

### New SQL file to create

- `sql/012_raw_table_ids_stage1.sql`

### Required schema changes

Add to `public.raw_members`:

- `id bigint`
- `first_seen_at timestamptz`
- `last_seen_at timestamptz`
- `is_current boolean`

Add to `public.raw_contacts`:

- `id bigint`
- `first_seen_at timestamptz`
- `last_seen_at timestamptz`
- `is_current boolean`

### Constraints in this stage

- `id` remains nullable
- no primary key yet
- no not-null yet
- no default/identity enforced yet if that would interfere with existing imports

### Historical table decision

At this stage, do not automatically add `id` to:

- `raw_members_historical`
- `raw_contacts_historical`

Decide explicitly later whether historical rows should:

- preserve current raw row IDs
- or have independent archive IDs

### Exit criteria for Stage 2

- local schema updated
- imports still run
- dashboards still work

### Status

Completed locally.

## Stage 3: Backfill Local IDs and Lifecycle Fields

This stage makes local rows identifiable without changing import logic yet.

### New SQL file to create

- `sql/013_raw_table_id_backfill.sql`

### Required work

- create sequences for both tables
- backfill every existing row in `raw_members.id`
- backfill every existing row in `raw_contacts.id`
- set:
  - `first_seen_at = now()`
  - `last_seen_at = now()`
  - `is_current = true`

### Recommended implementation

- one sequence for `raw_members.id`
- one sequence for `raw_contacts.id`
- assign IDs in deterministic batches
- advance sequences with `setval`

### Required verification

- row counts unchanged
- no null IDs remain in current tables
- no duplicate IDs

### Exit criteria for Stage 3

- every local current raw row has a unique ID
- sequences are ready for future inserts

### Status

Completed locally.

## Stage 4: Make Local-to-Cloud Sync ID-Aware

Now that local rows have IDs, cloud must start mirroring them.

### Files

- [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
- new cloud/local SQL migration file, e.g.:
  - `sql/014_raw_table_ids_cloud_sync.sql`

### Required cloud schema changes

Add to cloud:

- `raw_members.id bigint`
- `raw_contacts.id bigint`
- `first_seen_at timestamptz`
- `last_seen_at timestamptz`
- `is_current boolean`

Keep these nullable initially.

### Required workflow changes

In sync workflow:

- read explicit column lists including `id`
- write explicit column lists including `id`
- preserve local IDs exactly
- after cloud writes, advance cloud sequences with `setval(...)`

### Sync mode for this stage

Still allow current full-refresh sync behavior if needed, but now with explicit `id`.

### Required verification

- local and cloud row counts match
- local and cloud IDs match for sampled rows
- rerunning sync does not change IDs

### Exit criteria for Stage 4

- cloud mirrors local IDs exactly
- cloud no longer has independent ID generation for these tables

### Status

Completed locally.

## Stage 5: Introduce Staging Tables

Do not switch live imports yet. Create the new import landing zone first.

### New SQL file

- [016_raw_table_import_staging.sql](/mnt/c/dev/avondale-n8n/sql/016_raw_table_import_staging.sql)

### Tables to create

- `public.raw_members_import_staging`
- `public.raw_contacts_import_staging`

### Design rules

- match incoming CSV shapes closely
- no durable ID requirement
- allow truncation/reload inside staging

### Why this stage matters

Durable IDs only become meaningful once current tables stop being disposable snapshots.

### Exit criteria for Stage 5

- staging tables exist
- test loads into staging succeed

## Stage 6: Build Reconcile Functions

This is the core of preserving IDs across imports.

### New SQL file to create

- `sql/017_raw_table_reconcile.sql`

### Functions to create

- `public.reconcile_raw_contacts_from_staging()`
- `public.reconcile_raw_members_from_staging()`

### Required behavior

For `raw_members`:

- match current rows by:
  1. `Venue ID`
  2. `British Tennis Number`
  3. normalized `First name + Last name + membership package/category`
- update matched current row in place
- preserve `id`
- set `last_seen_at = now()`
- set `is_current = true`
- insert unmatched rows with new IDs
- mark unseen rows `is_current = false`

For `raw_contacts`:

- match current rows by:
  1. `Venue ID`
  2. normalized `First name + Last name`
- choose best-quality row behavior deliberately where duplicates exist
- preserve `id` for matched rows
- insert unmatched rows with new IDs
- mark unseen rows `is_current = false`

### Important rule

Do not use email as a primary identity key for member reconciliation.

### Exit criteria for Stage 6

- reconcile functions exist
- dry-run/test reconciliation logic is validated

### Status

Completed locally.

## Stage 7: Switch Import Workflows to Staging + Reconcile

Only after reconcile logic exists.

### Files

- [clubspark-members-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-members-export.json)
- [clubspark-contacts-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-contacts-export.json)

### Required changes

Members workflow:

- parse CSV
- load into `raw_members_import_staging`
- call `reconcile_raw_members_from_staging()`
- stop calling `prepare_raw_members_import(...)`

Contacts workflow:

- parse CSV
- load into `raw_contacts_import_staging`
- call `reconcile_raw_contacts_from_staging()`
- stop calling `prepare_raw_contacts_import(...)`

### Temporary compatibility

Do not remove old functions immediately.

Keep:

- `prepare_raw_contacts_import(...)`
- `prepare_raw_members_import(...)`

until repeated imports are verified stable.

### Required verification

- import the same file twice
- verify IDs do not change
- verify changed rows update in place
- verify missing rows are marked non-current instead of being recreated

### Exit criteria for Stage 7

- current import workflows preserve IDs across repeated imports

### Status

Completed locally.

## Stage 8: Update Downstream Views and Queries for Current-Row Semantics

Once rows can remain non-current, current-only consumers must be explicit.

### Files / objects

- [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
- [010_signup_batch_manual_items.sql](/mnt/c/dev/avondale-n8n/sql/010_signup_batch_manual_items.sql)
- [create-signup-batch.json](/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json)
- [create-missing-signup-capture.json](/mnt/c/dev/avondale-n8n/workflows/create-missing-signup-capture.json)
- [add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
- [member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json)
- [send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
- [send-gmail-test-message.json](/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json)

### Required changes

Where appropriate:

- filter current-table reads with `is_current = true`
- or update views so “current” means `is_current = true`

### Why this matters

After reconcile imports, old rows may remain in current tables with `is_current = false`.

### Exit criteria for Stage 8

- downstream business logic consistently reads only current rows where intended

### Status

Completed.

## Stage 9: Metabase Metadata Refresh and Card Review

### Systems

- local Metabase
- cloud Metabase

### Required actions

- refresh metadata for:
  - `raw_members`
  - `raw_contacts`
- review user-facing cards
- hide `id` by default where appropriate
- review whether cards should filter on `is_current = true`

### Cards to review first

- `Members - Selected Year`
- `Members - Previous Year`
- `Members by category`
- `Contacts - Selected Year`
- `Age Ranges`
- `Current Members - Selected Year (Map)`
- `List of Members Missing Signup Capture - Selected Year`
- `Count of Members Missing Signup Capture - Selected Year`
- `Processed Signups Base`

### Exit criteria for Stage 9

- no user-facing Metabase card is showing stale/non-current rows unintentionally

## Stage 10: Enforce Primary Keys

Only after repeated imports and syncs prove stable.

### SQL file used

- [018_raw_table_primary_keys.sql](/mnt/c/dev/avondale-n8n/sql/018_raw_table_primary_keys.sql)

### Required changes

On local:

- make `id not null` on `raw_members`
- make `id not null` on `raw_contacts`
- add primary key on `id`

On cloud:

- same changes after local is already proven stable

### Optional supporting indexes

- indexes on:
  - `is_current`
  - `Venue ID`
  - `British Tennis Number`
  - normalized name expressions if required for reconcile speed

### Exit criteria for Stage 10

- local and cloud current raw tables have enforced primary keys
- imports preserve IDs
- sync preserves IDs

## Stage 11: Retire Old Snapshot/Truncate Path

### Files / objects

- [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
- [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
- any remaining workflow references to:
  - `prepare_raw_contacts_import(...)`
  - `prepare_raw_members_import(...)`

### Required work

- remove or deprecate truncate/reload import path
- update documentation to reflect staging + reconcile as the live method

### Exit criteria for Stage 11

- old disposable-snapshot import logic is no longer on the active path

## Exact First Edits To Make

If starting implementation now, do these first in order:

1. [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
   - replace `SELECT * FROM public.raw_contacts`
   - replace `SELECT * FROM public.raw_members`
   - use explicit column lists

2. [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
   - replace `public.raw_contacts.*`
   - replace `public.raw_members.*`
   - make archive column lists explicit

3. [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
   - replace `public.raw_contacts.*`
   - make archive column list explicit

4. [archive-raw-members-by-season.json](/mnt/c/dev/avondale-n8n/workflows/archive-raw-members-by-season.json)
   - inspect for whole-row assumptions
   - convert to explicit columns if needed

Only after those four are clean should schema changes begin.

## Suggested File Sequence For New Migrations

Recommended new SQL files:

- `012_raw_table_ids_stage1.sql`
- `013_raw_table_id_backfill.sql`
- `014_raw_table_ids_cloud_sync.sql`
- `015_raw_table_lifecycle_defaults.sql`
- `016_raw_table_import_staging.sql`
- `017_raw_table_reconcile.sql`
- `018_raw_table_primary_keys.sql`

## Practical Stop Points

Good pause/checkpoint boundaries:

- after Stage 1
- after Stage 4
- after Stage 7
- before Stage 10

Those are the safest places to verify before continuing.
