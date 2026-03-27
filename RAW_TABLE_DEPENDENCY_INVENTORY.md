# Raw Table Dependency Inventory

Inventory date: `2026-03-24`

Scope:

- `public.raw_members`
- `public.raw_contacts`

Sources checked:

- repo workflows under [workflows](/mnt/c/dev/avondale-n8n/workflows)
- repo SQL under [sql](/mnt/c/dev/avondale-n8n/sql)
- repo scripts under [scripts](/mnt/c/dev/avondale-n8n/scripts)
- latest local backup set under [20260324-123703-local-state](/mnt/c/dev/avondale-n8n/backups/20260324-123703-local-state)
- latest local public schema dump:
  [local-public.dump](/mnt/c/dev/avondale-n8n/backups/20260324-123703-local-state/local-public.dump)

## Summary

Direct repo dependencies found:

- workflows: `10`
- scripts: `0`
- SQL files: `5`

Metabase:

- base table metadata entries:
  - `raw_members` table id `14`
  - `raw_contacts` table id `25`
- many saved-question dependencies exist, including legacy duplicates

## Workflows

These workflow files directly reference `raw_members` and/or `raw_contacts`.

### Import / sync

- [clubspark-members-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-members-export.json)
  - imports into `raw_members`
  - verifies `raw_members` row count

- [clubspark-contacts-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-contacts-export.json)
  - imports into `raw_contacts`
  - verifies `raw_contacts` row count

- [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
  - reads local `raw_contacts`
  - writes cloud `raw_contacts`
  - reads local `raw_members`
  - writes cloud `raw_members`
  - currently uses full-table `SELECT *` plus explicit rebuild SQL

### Archiving / lifecycle

- [archive-raw-members-by-season.json](/mnt/c/dev/avondale-n8n/workflows/archive-raw-members-by-season.json)
  - archives from `raw_members`
  - high-risk candidate for primary-key rollout because archive flows often assume full-row column parity

### Batch / signup / backfill logic

- [create-signup-batch.json](/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json)
  - joins `member_signups` to `raw_members` and `raw_contacts`
  - uses them to enrich signup batch export rows

- [create-missing-signup-capture.json](/mnt/c/dev/avondale-n8n/workflows/create-missing-signup-capture.json)
  - reads `raw_members`
  - reads `raw_contacts`
  - backfills missing signup-capture data

- [add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
  - resolves member/payer/contact/address details from `raw_members` and `raw_contacts`

### Search / detail / email flows

- [member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json)
  - reads `raw_members`
  - reads `raw_contacts`
  - shows combined member/contact detail page

- [send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
  - reads `raw_members`
  - reads `raw_contacts`
  - identifies members with no usable postal address

- [send-gmail-test-message.json](/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json)
  - reads `raw_members`
  - reads `raw_contacts`
  - uses them to populate template fields for test sends

## Scripts

No direct references were found in repo scripts:

- [scripts](/mnt/c/dev/avondale-n8n/scripts)

That means the raw-table touch points are currently concentrated in workflows and SQL, not standalone scripts.

## SQL Files

### [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)

Touches both raw tables extensively:

- creates `raw_contacts_historical`
- creates `raw_members_historical`
- creates `prepare_raw_contacts_import(...)`
- creates `prepare_raw_members_import(...)`
- truncates current raw tables during import
- creates snapshot/current-history views

This is the highest-risk SQL file for the primary-key rollout.

### [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)

Replaces `prepare_raw_contacts_import(...)` with an every-import archive/truncate behavior for `raw_contacts`.

### [006_membership_history_2026_2027.sql](/mnt/c/dev/avondale-n8n/sql/006_membership_history_2026_2027.sql)

Reads `raw_members` to rebuild membership-history wide columns.

### [007_membership_history_snapshot_mechanism.sql](/mnt/c/dev/avondale-n8n/sql/007_membership_history_snapshot_mechanism.sql)

Reads `raw_members` through `capture_membership_history_snapshot(...)`.

### [010_signup_batch_manual_items.sql](/mnt/c/dev/avondale-n8n/sql/010_signup_batch_manual_items.sql)

Touches raw tables through views:

- `vw_signup_batch_items`
  - reads `raw_contacts`
  - reads `raw_members`
- `vw_signup_batch_consolidated`
  - depends on `vw_signup_batch_items`
- `vw_signup_batches_summary`
  - depends on `vw_signup_batch_items`

## Live Database Functions and Views

From the latest local public-schema dump:

- [local-public.dump](/mnt/c/dev/avondale-n8n/backups/20260324-123703-local-state/local-public.dump)

### Functions

- `public.prepare_raw_contacts_import(integer)`
  - archives current `raw_contacts`
  - truncates `raw_contacts`

- `public.prepare_raw_members_import(integer)`
  - archives current `raw_members`
  - truncates `raw_members`

- `public.capture_membership_history_snapshot(text, text)`
  - reads `raw_members`

### Views

- `public.vw_raw_contacts_all`
  - unions current `raw_contacts` with `raw_contacts_historical`

- `public.vw_contacts_current_and_historical`
  - depends on `vw_raw_contacts_all`

- `public.vw_raw_members_all`
  - unions current `raw_members` with `raw_members_historical`

- `public.vw_members_current_and_historical`
  - depends on `vw_raw_members_all`

- `public.vw_signup_batch_items`
  - reads `raw_contacts`
  - reads `raw_members`

- `public.vw_signup_batch_consolidated`
  - depends on `vw_signup_batch_items`

- `public.vw_signup_batches_summary`
  - depends on `vw_signup_batch_items`

### Tables closely tied to raw-table lifecycle

- `public.raw_contacts_historical`
- `public.raw_members_historical`
- `public.raw_snapshot_state`

These are not the current raw tables, but they are part of the import/archive mechanism and must be included in any safe primary-key rollout.

## Metabase Base Table Metadata

From:

- [local-metabase-tables.json](/mnt/c/dev/avondale-n8n/backups/20260324-123703-local-state/local-metabase-tables.json)

Relevant table metadata entries:

- `raw_members`
  - table id `14`
  - schema `public`

- `raw_contacts`
  - table id `25`
  - schema `public`

These table metadata objects will need a metadata refresh if an `id` column is added.

## Metabase Saved Questions and Dependencies

From:

- [local-metabase-cards.json](/mnt/c/dev/avondale-n8n/backups/20260324-123703-local-state/local-metabase-cards.json)

The local Metabase environment has many legacy duplicated cards. The list below collapses them to unique card names that reference `raw_members` or `raw_contacts`.

### Current/high-signal cards

- `Age Ranges`
  - ids: `1451`

- `Contacts - Selected Year`
  - ids: `1028`, `1597`

- `Count of Members - Selected Year`
  - ids: `1466`

- `Count of Members Missing Signup Capture - Selected Year`
  - ids: `1608`

- `Count of Members Not Renewed - Selected Year`
  - ids: `1464`

- `Current Members - Selected Year (Map)`
  - ids: `1472`

- `List of Members Missing Signup Capture - Selected Year`
  - ids: `1609`

- `List of Members Not Renewed - Selected Year`
  - ids: `1489`

- `List of Members Who Changed Package - Selected Year`
  - ids: `1607`

- `Members - Selected Year`
  - ids: `1506`

- `Members - Previous Year`
  - ids: `1505`, plus older duplicates

- `Members by category`
  - ids: `1494`, `51`

- `Members in Category - Selected Year`
  - ids: `1502`

- `Processed Signups Base`
  - ids: `1540`

- `Processed Signups base`
  - ids: `1541`

- `Processed Signups Base (Intermediate table)`
  - ids: `1542`

### Additional duplicated / legacy names still referencing raw tables

- `2024 Members Who Have Not Renewed`
- `Contacts Current and Historical`
- `Count of Members - Previous Year`
- `Count of New Members - Selected Year`
- `Count of New Members in 2025`
- `Count of Non-Active Members - Previous Year`
- `Count of Non-Active Members - Selected Year`
- `Labels`
- `Labels Report`
- `List of New Members`
- `List of New Members - Selected Year`
- `List of New Members - Selected Year (Model)`
- `Member signups with payment details`
- `Members Current and Historical`
- `New Members in 2025`
- `Non-Active Members - Previous Year (Records)`
- `Non-Active Members - Selected Year (Records)`
- `Summary of Keys`

These are not all necessarily current dashboard surfaces, but they do exist as saved-question dependencies and would be affected by schema changes or metadata refreshes.

## Dashboards

From:

- [local-metabase-dashboards.json](/mnt/c/dev/avondale-n8n/backups/20260324-123703-local-state/local-metabase-dashboards.json)

Relevant dashboards:

- dashboard `11`
  - `Avondale Membership - Selected Year`

- dashboard `9`
  - `Member Search`

- dashboard `16`
  - `Member Search`

These are the main user-facing dashboard surfaces where raw-table-backed cards currently appear.

## Highest-Risk Objects For Primary-Key Rollout

These are the first objects to inspect/change before adding durable primary keys:

1. [sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)
   - currently full-table sync logic
   - includes `SELECT *`
   - must become explicit-column and ID-aware

2. [clubspark-members-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-members-export.json)
   - currently imports into `raw_members`
   - tied to `prepare_raw_members_import(...)`

3. [clubspark-contacts-export.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-contacts-export.json)
   - currently imports into `raw_contacts`
   - tied to `prepare_raw_contacts_import(...)`

4. [002_raw_snapshot_history.sql](/mnt/c/dev/avondale-n8n/sql/002_raw_snapshot_history.sql)
   - current import/archive/truncate core

5. [003_archive_raw_contacts_every_import.sql](/mnt/c/dev/avondale-n8n/sql/003_archive_raw_contacts_every_import.sql)
   - overrides the contacts import function

6. [archive-raw-members-by-season.json](/mnt/c/dev/avondale-n8n/workflows/archive-raw-members-by-season.json)
   - likely sensitive to row-shape changes and archive assumptions

## Immediate Conclusions

- There are no direct repo script dependencies to update.
- The core migration surface is concentrated in:
  - raw import workflows
  - cloud sync workflow
  - archive/snapshot SQL functions and views
  - Metabase metadata and saved-question cards
- The most dangerous current assumption is still the truncate-and-reload import model in:
  - `prepare_raw_contacts_import(...)`
  - `prepare_raw_members_import(...)`

That import model must change before durable primary keys can be considered fully safe.
