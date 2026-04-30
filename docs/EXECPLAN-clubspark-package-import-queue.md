# Queue ClubSpark Package Imports From Member Search And Batch Selection

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with [/mnt/c/dev/PLAN.md](/mnt/c/dev/PLAN.md).

## Purpose / Big Picture

After this change, an operator will be able to open the existing member search flow, queue an existing ClubSpark member for a new package import, review those queued rows by batch, and generate a ClubSpark external-file import workbook for one specific membership package at a time instead of typing free-text names into a separate form. The important constraint is that this feature is only for people who already exist in ClubSpark and need an additional package, such as adding a `2026` package to someone who previously had `2025`.

The visible proof is simple. From the member search detail page, the operator will click a new action such as `Queue ClubSpark Package`, choose a batch and the target package, and save the row. Later, the operator will open a batch-scoped import review page, filter to a single target package, download the XLSX workbook for that package, upload it into the matching ClubSpark `Import from an external file` page, and see those queue rows marked as exported or imported. Existing manual tag and key rows must continue to work exactly as they do today.

## Progress

- [x] (2026-04-29 17:39Z) Investigated the current ClubSpark import workflow and confirmed it only supports free-text member-name entry and assumes the member already has ClubSpark `Unique ID` values.
- [x] (2026-04-29 17:44Z) Investigated the current manual batch flow and confirmed `signup_batch_manual_items` is intentionally a physical tag/key queue rather than a general-purpose work queue.
- [x] (2026-04-29 17:50Z) Confirmed the real user requirement is narrower than “import brand-new people into ClubSpark”: it is specifically “existing member, add a new package”.
- [x] (2026-04-29 18:03Z) Confirmed GitHub issue `#94` is the correct existing tracker, moved its project item to `In Progress`, and treated it as the canonical issue for this work.
- [x] (2026-04-29 18:11Z) Drafted this ExecPlan for a separate ClubSpark import queue tied to member search and batch review.
- [x] (2026-04-29 18:36Z) Added `sql/050_signup_batch_clubspark_import_items.sql` defining the new queue table and read-friendly view for ClubSpark package import candidates.
- [x] (2026-04-29 18:42Z) Extended `workflows/sync-raw-tables-to-cloud.json` so the new queue table is mirrored to the cloud reporting database alongside the existing batch tables.
- [x] (2026-04-29 18:48Z) Added `workflows/clubspark-package-import-queue-form.json` and `workflows/add-clubspark-package-import-item.json` for the first operator-facing queue-entry path.
- [x] (2026-04-29 18:50Z) Updated `workflows/member-search-detail.json` to expose a new `Queue ClubSpark Package` action that launches the queue form from the existing member search page.
- [x] (2026-04-29 19:24Z) Added `workflows/clubspark-package-import-queue-review.json` so operators can review queued rows by batch, inspect target-package groupings, and filter the review by `target_membership`.
- [x] (2026-04-29 19:27Z) Added `workflows/cancel-clubspark-package-import-item.json` so queued rows can be cancelled safely without deleting history, and linked the new queue review from `workflows/signup-batch-actions.json`.
- [x] (2026-04-29 19:38Z) Confirmed the actual ClubSpark import path is package-specific under `Admin/Membership/Import?packageID=...` using the `Import from an external file` section, and confirmed the import headers differ from the earlier `PrimaryContactID`-based workbook assumption.
- [x] (2026-04-30 08:32Z) Added `sql/051_clubspark_membership_import_targets.sql` introducing `public.clubspark_membership_import_targets` and extended `public.vw_signup_batch_clubspark_import_items` with package mapping and import URL fields.
- [x] (2026-04-30 08:49Z) Added `workflows/clubspark-package-import-queued-xlsx.json` to generate package-specific external-file workbooks from selected queue rows, using `raw_members` as the export source and stamping selected rows as `exported`.
- [x] (2026-04-30 08:58Z) Reworked `workflows/clubspark-package-import-queue-review.json` so a target-package filter now exposes mapping state, the ClubSpark import destination link, and checkbox-based XLSX export submission for selected rows.
- [x] (2026-04-30 09:11Z) Added `workflows/mark-clubspark-package-import-items-imported.json` and wired the batch review page so selected exported rows can be marked as `imported` after a successful manual ClubSpark upload.
- [x] (2026-04-30 09:04Z) Applied `sql/050_signup_batch_clubspark_import_items.sql` and `sql/051_clubspark_membership_import_targets.sql` to the live database, synced the updated existing workflows into live n8n, imported the six new queue workflows into the live n8n project, published them, and restarted `n8n` so the public webhooks registered.
- [x] (2026-04-30 09:05Z) Fixed two live-runtime issues discovered during smoke testing: the review query now aggregates `clubspark_package_id::text` instead of `min(uuid)`, and the queued export now uses `raw_members."Venue ID"` as the first ClubSpark contact identifier source.
- [x] (2026-04-30 14:20Z) Scraped the live ClubSpark Membership admin table to recover the actual package-to-`packageID` mapping, refreshed the live mapping table, added `sql/052_clubspark_membership_import_targets_refresh_20260430.sql` so future environments get the same mapping, and updated the queued export to fall back to `raw_contacts."Unique ID"` via `resolve_best_contact_row(...)` when `raw_members."Venue ID"` is blank.
- [x] (2026-04-30 14:36Z) Fixed the remaining duplicate-row bug by redefining `public.vw_signup_batch_clubspark_import_items` to choose one `membership_packages` row per package name, stopped the export workflow depending on that duplicating join, and revalidated the live review page plus the live export webhook with a temporary Sally Maxfield row.
- [x] (2026-04-30 09:06Z) Smoke-tested the live public queue flow end to end with one reversible row in batch `12`: queue insert, filtered review, XLSX export, and cancellation all succeeded.
- [ ] Validate the queue flow end to end in n8n and by uploading a generated workbook into a real ClubSpark package.

## Surprises & Discoveries

- Observation: the current ClubSpark package-import workflow is already close to the required data-shaping behavior, but its input model is wrong for the new operator workflow.
  Evidence: [workflows/clubspark-package-members-import-xlsx.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-package-members-import-xlsx.json) builds the workbook from existing `raw_members` and `raw_contacts` rows and resolves `ContactID` and `PrimaryContactID`, but it only accepts free-text member names from a form.

- Observation: `signup_batch_manual_items` must not be reused as the queue for ClubSpark package imports.
  Evidence: [sql/010_signup_batch_manual_items.sql](/mnt/c/dev/avondale-n8n/sql/010_signup_batch_manual_items.sql) enforces `regular_tags + parent_tags + key_tags > 0`, and the related views feed labels, envelopes, and batch item totals. Those semantics do not match “include this member in a ClubSpark package import workbook”.

- Observation: the member search detail page already has the right operator entry point for the new feature.
  Evidence: [workflows/member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json) already presents action buttons for missing-signup capture and manual batch entry, so adding a sibling queue action fits the existing operator UX.

- Observation: the target ClubSpark package must be captured in the local queue even though the current XLSX export rows do not contain a package-name column.
  Evidence: the existing XLSX column list in [workflows/clubspark-package-members-import-xlsx.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-package-members-import-xlsx.json) contains identity and contact fields but no package name. ClubSpark package selection happens when the operator uploads the workbook into a specific package, so the local queue still needs `target_membership` to prevent mixing different intended packages into one export.

- Observation: issue `#94` already existed and matched the original request, so a new issue was not needed.
  Evidence: the project board item list showed [issue #94](https://github.com/sshort/avondale-n8n/issues/94) with the original wording about allowing ClubSpark member CSV import for manually signed-up members.

- Observation: the review UI needs package-level grouping before export even though the export path is not built yet.
  Evidence: once queued rows are visible together, it is immediately obvious that mixing `target_membership` values in one future workbook would be an operator error, so the review page now exposes those groups explicitly before the export button exists.

- Observation: the real ClubSpark import contract is the package-specific `Import from an external file` flow, not the earlier `PrimaryContactID`-based workbook assumption.
  Evidence: the live package flow is `Admin/Membership` -> package page -> `Member Options` -> `Import members` -> `Admin/Membership/Import?packageID=...`, and the external-file header list is `ContactID`, `FirstName`, `LastName`, `EmailAddress`, `StartDate`, `ExpiryDate`, `Cost`, `Paid`, `GiftAid`, `Gender`, `BirthDate`, `HomeNumber`, `WorkNumber`, `MobileNumber`, `EmergencyPhoneNumber`, `PostCode`, `Address1`, `Address2`, `Address3`, `Town`, `County`, `Country`, `Occupation`, `BritishTennisNumber`, `DateJoinedVenue`, `MedicalHistory`, `Source`, `KeyPinNumber`, `TagsProvided`. That contract has no `PrimaryContactID` column and does include `BritishTennisNumber`.

- Observation: the external-file export can avoid the older main-contact expansion logic, but it still needs `raw_contacts` as a fallback contact-ID resolver.
  Evidence: the clarified header contract only requires `ContactID` plus flat member/contact fields and does not include `PrimaryContactID`, so the queue export does not need parent rows. However, some live members such as Sally Maxfield have blank `raw_members."Venue ID"` values and only resolve their ClubSpark identifier through `raw_contacts."Unique ID"`.

- Observation: on the live database, `raw_members` does not expose a `"Unique ID"` column; the member-side ClubSpark identifier is usually stored in `"Venue ID"` and otherwise must be resolved through `raw_contacts`.
  Evidence: a live smoke-test member row such as `David Pharo` has `raw_members."Venue ID" = 00692371`, while the resolved `raw_contacts` row has `"Unique ID" = [00692371]`. Another live row such as Sally Maxfield has blank `raw_members."Venue ID"` but still resolves through `resolve_best_contact_row(...)` to `raw_contacts."Unique ID" = [00313366]`.

## Decision Log

- Decision: implement a separate queue table for ClubSpark package imports instead of overloading `signup_batch_manual_items`.
  Rationale: manual batch items mean “physical extras for labels, envelopes, and counts”. A ClubSpark package-import candidate is a different kind of work item and would corrupt those downstream semantics if stored in the same table.
  Date/Author: 2026-04-29 / Codex

- Decision: scope this feature only to existing ClubSpark members receiving an additional package.
  Rationale: the user clarified that the real need is adding a new membership package to someone already known to ClubSpark, not creating a brand-new person in ClubSpark. That makes the existing `Unique ID`-based workbook approach appropriate.
  Date/Author: 2026-04-29 / Codex

- Decision: preserve the existing free-text import workflow during the rollout and add a new queued path alongside it.
  Rationale: the current free-text workflow may still be useful as a fallback while the queued operator flow is proven. Keeping it initially reduces risk and makes regression checking easier.
  Date/Author: 2026-04-29 / Codex

- Decision: capture `target_membership` on the queue row even though it is not emitted into the workbook.
  Rationale: the operator chooses the destination package in ClubSpark during upload, but the local queue still needs to know the intended package so the batch review page can group correctly and the operator does not accidentally export mixed-package rows together.
  Date/Author: 2026-04-29 / Codex

- Decision: resolve ClubSpark `Unique ID` values and main-contact data at workbook-generation time, not when the queue row is created.
  Rationale: `raw_members` and `raw_contacts` are the source of truth for current ClubSpark identity data. Deferring that resolution keeps the queue row lightweight and ensures the export uses the freshest synced ClubSpark data.
  Date/Author: 2026-04-29 / Codex

- Decision: use queue status fields instead of destructive deletion for normal operator actions.
  Rationale: marking rows as `queued`, `exported`, `imported`, or `cancelled` keeps an audit trail and makes retry logic safer than deleting history when an operator changes their mind.
  Date/Author: 2026-04-29 / Codex

- Decision: retarget the export to ClubSpark’s package-specific external-file import shape instead of extending the existing `PrimaryContactID` workbook.
  Rationale: the real operator flow imports into one specific package at `Admin/Membership/Import?packageID=...`, and the actual header contract differs from the current workbook generator. Continuing with the older shape would optimize the wrong interface.
  Date/Author: 2026-04-29 / Codex

- Decision: store ClubSpark import destinations in a dedicated local mapping table rather than overloading `membership_packages` immediately.
  Rationale: `membership_packages` is a small generic catalog used elsewhere by season/name/category. A separate `clubspark_membership_import_targets` table keeps the ClubSpark-specific `packageID` mapping explicit, seedable, and easy to extend without changing assumptions in unrelated membership logic.
  Date/Author: 2026-04-30 / Codex

- Decision: generate queued external-file exports from `raw_members`, with `raw_contacts` used only as a fallback `ContactID` resolver.
  Rationale: once the import contract was corrected, the older main-contact expansion path became unnecessary for this feature. The flat export shape can be satisfied from the selected member rows, but the exporter must still fall back to `raw_contacts."Unique ID"` when `raw_members."Venue ID"` is blank.
  Date/Author: 2026-04-30 / Codex

## Outcomes & Retrospective

_To be filled in after implementation._

## Context and Orientation

The repository to change is `/mnt/c/dev/avondale-n8n`. The current ClubSpark workbook generator is [workflows/clubspark-package-members-import-xlsx.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-package-members-import-xlsx.json). That workflow serves an HTML form, accepts names typed by the operator, looks up matching rows in `public.raw_members`, resolves the best contact rows from `public.raw_contacts`, and generates an `.xlsx` workbook containing `ContactID`, `PrimaryContactID`, and the other columns needed by the old assumption of ClubSpark package import. In plain language, it is a useful reference for member lookup and workbook generation, but it is no longer the target contract for the queued flow.

The clarified live ClubSpark flow is package-specific. The operator starts at `https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Membership`, opens one package, chooses `Import members` from `Member Options`, and lands on `https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Membership/Import?packageID=...`. The relevant section is `Import from an external file`. That means the local export path must be grouped by one package at a time and must eventually know the ClubSpark `packageID` for each target package.

The current manual batch feature is separate. It is documented in [docs/MANUAL_BATCH_ITEMS.md](/mnt/c/dev/avondale-n8n/docs/MANUAL_BATCH_ITEMS.md), implemented by [workflows/manual-batch-item-form.json](/mnt/c/dev/avondale-n8n/workflows/manual-batch-item-form.json) and [workflows/add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json), and stored in `public.signup_batch_manual_items` defined in [sql/010_signup_batch_manual_items.sql](/mnt/c/dev/avondale-n8n/sql/010_signup_batch_manual_items.sql). A “manual batch item” means a row for extra shoe tags, parent tags, or keys. It is not a general-purpose operator note or queue row. The views built on top of it, especially `public.vw_signup_batch_items` and `public.vw_signup_batch_consolidated`, are consumed by labels, envelopes, and batch totals.

The existing member-search detail page is [workflows/member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json). It already exposes the selected member’s current `raw_members`, `raw_contacts`, and `member_signups` rows and offers action buttons for missing-signup capture and manual batch work. This page is the correct place to launch the new ClubSpark package queue action because the operator is already looking at the exact member they want to act on.

This plan uses a few terms that matter:

- “Batch” means the operator-managed grouping already used elsewhere in this repository for signup processing. It lives in `public.signup_batches`.
- “Queue row” means one local instruction saying “include this existing member in a future ClubSpark package import workbook for this target package”.
- “Target membership” means the local package label chosen by the operator, such as `Junior 2026` or `Parent 2026`. It is used for grouping, operator clarity, and mapping to the correct ClubSpark `packageID`.
- “Existing ClubSpark member” means a person who already appears in `public.raw_members` and can therefore be resolved back to ClubSpark `Unique ID` values through the existing import workflow logic.

The canonical tracker for this work is [issue #94](https://github.com/sshort/avondale-n8n/issues/94), titled “Allow using ClubSpark member CSV import to add manuallly signed up members to be added to ClubSpark”. The user has clarified that the actual implementation should be an existing-member package queue, not a brand-new-person import.

## Target Design

The new design adds a separate persistence layer for ClubSpark package-import candidates. The table name should be `public.signup_batch_clubspark_import_items`. Each row represents one member that an operator wants to include in a ClubSpark external-file import for a given batch and target package. The row should store:

- `id`
- `batch_id`
- `raw_member_id`
- `member`
- `email_address`
- `source_membership`
- `target_membership`
- `status`
- `notes`
- `created_at`
- `created_by`
- `exported_at`
- `imported_at`
- `export_file_name`

The exact column list can be adjusted slightly during implementation, but the semantics must remain the same. `raw_member_id` is the key link back to the current ClubSpark-synced member row. `source_membership` records what package the member currently has in the local data, while `target_membership` records what package the operator intends to add next. `status` must support at least `queued`, `exported`, `imported`, and `cancelled`.

The export payload now needs to target the ClubSpark external-file headers exactly, in this order:

- `ContactID`
- `FirstName`
- `LastName`
- `EmailAddress`
- `StartDate`
- `ExpiryDate`
- `Cost`
- `Paid`
- `GiftAid`
- `Gender`
- `BirthDate`
- `HomeNumber`
- `WorkNumber`
- `MobileNumber`
- `EmergencyPhoneNumber`
- `PostCode`
- `Address1`
- `Address2`
- `Address3`
- `Town`
- `County`
- `Country`
- `Occupation`
- `BritishTennisNumber`
- `DateJoinedVenue`
- `MedicalHistory`
- `Source`
- `KeyPinNumber`
- `TagsProvided`

Notably, this shape does not include `PrimaryContactID`, and it does include `BritishTennisNumber`.

Add a partial uniqueness rule so the same member cannot be actively queued twice for the same batch and target package. In plain language, the system should reject “queue Alice for Junior 2026 in batch 12” if there is already a non-cancelled active row for Alice, batch `12`, and target package `Junior 2026`.

Add a read-friendly view, preferably `public.vw_signup_batch_clubspark_import_items`, that joins the queue rows back to `raw_members` and perhaps `membership_packages` so the batch review page can display:

- member name
- current membership
- target membership
- email
- batch
- status
- notes
- whether a current `raw_members` row still exists

The queue is deliberately separate from physical extras. Nothing in `vw_signup_batch_items`, label generation, or envelope generation should start reading from the new table.

The remaining design gap is package mapping. The system needs a reliable way to resolve a queued `target_membership` such as `1. Senior 2026` to the correct ClubSpark package import destination. The minimum viable approach is to store or derive a `packageID` per target package, either in local configuration or from a discovered export of the membership admin page.

## Plan of Work

### Milestone 1: Add queue storage without touching the current workbook generator

Create a new SQL migration after the latest numbered migration in `/mnt/c/dev/avondale-n8n/sql`. The migration should create `public.signup_batch_clubspark_import_items`, add the needed indexes, add the partial uniqueness rule for active queue rows, and create `public.vw_signup_batch_clubspark_import_items`. It should also extend any sync workflow that needs this table copied to the cloud reporting database, following the same pattern already used for `signup_batch_manual_items` in [workflows/sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json).

At the end of this milestone, the database can store the new kind of work item without changing labels, envelopes, or the existing import workbook logic. Proof is that the migration applies cleanly, the new table and view exist, and existing batch views still behave the same.

### Milestone 2: Add member-search queue insertion flow

Create a new form workflow to launch from member search. The likely new files are:

- `workflows/clubspark-package-import-queue-form.json`
- `workflows/add-clubspark-package-import-item.json`

Do not overload [workflows/manual-batch-item-form.json](/mnt/c/dev/avondale-n8n/workflows/manual-batch-item-form.json). That form is specifically for tags and keys and should stay that way.

The new form should receive the same member identity fields that the member detail page already knows how to supply, especially:

- `member_id` or `raw_member_id`
- `member`
- current membership
- email
- optional `batch_id`

The form should show the selected member clearly, allow the operator to choose a batch, choose a target membership, and optionally enter notes. The form should not ask for tag or key counts. The target membership option list should come from the local package catalog, ideally `public.membership_packages`, filtered to operator-meaningful choices. The implementation should exclude obvious non-membership utility products such as Pavilion Key if those are not valid ClubSpark package-import targets.

The insert workflow should validate:

- a resolvable `raw_member_id`
- an existing batch, or a default current `Processing` batch if none is supplied
- a non-empty `target_membership`
- no duplicate active queue row for the same member, batch, and target membership

At the end of this milestone, the member detail page shows a new action button such as `Queue ClubSpark Package`, the form writes a queue row, and the operator receives a clear success or duplicate warning page.

### Milestone 3: Add batch review and selection page for the queue

Create a new review workflow, likely something like `workflows/clubspark-package-import-queue-review.json`. This page should behave like an operator workbench for one batch. It must list the queued import rows for the selected batch and allow the operator to:

- filter or group by `target_membership`
- select the rows to include in the next workbook
- cancel queue rows that should no longer be used
- launch workbook generation from the selected row IDs

The review page must make it obvious that target package matters. If the batch contains queued rows for more than one target membership, the page should either require the operator to pick one target membership at a time or clearly separate the export actions by package group. The plan deliberately rejects a design that quietly mixes `Junior 2026` and `Parent 2026` candidates into one workbook with no operator warning.

At the end of this milestone, the queue can be managed without direct SQL. Proof is that a human can open the review page, see their queued members, and choose which rows to export.

### Milestone 4: Discover or store ClubSpark package import destinations

Before the queued export is completed, add a reliable mapping from local `target_membership` values to ClubSpark import destinations. The queued export now depends on one package at a time, and the operator flow is anchored on `Admin/Membership/Import?packageID=...`.

There are two acceptable implementation shapes:

- add local package metadata, for example a table or `global_settings` structure that maps `target_membership` to ClubSpark `packageID`
- or build a small discovery/export step from the ClubSpark membership admin page and persist the discovered mapping locally

At the end of this milestone, the system knows which ClubSpark import page each `target_membership` belongs to.

### Milestone 5: Add queued workbook generation using the external-file import contract

Build the new export path by reusing the useful parts of the existing existing-member lookup logic, but not the old workbook shape. There are two acceptable implementation shapes:

The first acceptable shape is to add a new workflow such as `workflows/clubspark-package-members-import-queued-xlsx.json` that takes selected queue item IDs plus one target package and generates the external-file workbook directly.

The second acceptable shape is to refactor [workflows/clubspark-package-members-import-xlsx.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-package-members-import-xlsx.json) so the current free-text path becomes a shared lookup engine while the queued path emits a different final spreadsheet shape. If this is chosen, keep the old free-text route working until the queued flow is validated.

Whichever shape is chosen, the queued workbook-generation logic must continue to:

- resolve the latest matching `raw_members` row
- resolve `member_unique_id` for `ContactID`
- populate `BritishTennisNumber` if it is present in local source data
- generate the exact external-file column order listed above
- reject mixed-package selections so one export always maps to one ClubSpark `packageID`

The new queue-based export input should be queue item IDs, not names. The SQL should first resolve the selected queue rows, then derive the unique member set to export, then feed the existing contact-resolution logic.

After a successful workbook generation, the selected queue rows should move from `queued` to `exported` and store `exported_at` plus the generated file name. If the operator needs to regenerate, the review page can expose an explicit reset or re-export action rather than silently duplicating queue rows.

At the end of this milestone, a human can select queued members from the batch review page, download the workbook, and see the selected queue rows marked as exported.

### Milestone 6: Add final operator confirmation and documentation

After workbook generation is working, add a lightweight way to mark rows as `imported` after the human has actually uploaded the file into ClubSpark. This can be a button on the review page such as `Mark Imported`, scoped to the exported rows that were just used. Do not try to automate ClubSpark package upload here; the scope is still workbook generation for manual upload.

Update the repository documentation so the next operator understands the difference between:

- manual batch items for tags and keys
- missing-signup capture
- ClubSpark package import queue rows for existing members

The main docs to update are:

- `docs/MANUAL_BATCH_ITEMS.md`
- `workflows/README.md`
- a new feature-specific note if needed, such as `docs/CLUBSPARK_PACKAGE_IMPORT_QUEUE.md`

At the end of this milestone, a novice can discover the feature from the docs and follow the queue-to-workbook flow without reading the workflow JSON first.

## Concrete Steps

Work from `/mnt/c/dev/avondale-n8n`.

Start by creating the SQL migration. Replace `0xx` with the next real migration number:

    cd /mnt/c/dev/avondale-n8n
    git checkout -b clubspark-package-import-queue
    ls sql

Create the new migration and then validate its basic syntax by reading it carefully and, if local database access is available, applying it in a non-production environment first. If homedb is the first target, keep the migration idempotent with `IF NOT EXISTS` where appropriate.

After adding the migration, update any sync workflow that must mirror the new table to the cloud database. Validate the changed workflow JSON:

    cd /mnt/c/dev/avondale-n8n
    jq empty workflows/sync-raw-tables-to-cloud.json

Create the new queue form and insert workflows, then validate each workflow file:

    cd /mnt/c/dev/avondale-n8n
    jq empty \
      workflows/clubspark-package-import-queue-form.json \
      workflows/add-clubspark-package-import-item.json \
      workflows/member-search-detail.json

Create the batch review workflow and the queued export workflow, then validate them too:

    cd /mnt/c/dev/avondale-n8n
    jq empty \
      workflows/clubspark-package-import-queue-review.json \
      workflows/clubspark-package-members-import-queued-xlsx.json \
      workflows/clubspark-package-members-import-xlsx.json

If the implementation reuses large code-node blocks from the existing import workflow, validate the final JSON again after the refactor to ensure no node or connection object was malformed.

If the workflows are being synced into live n8n from the repository, use the existing repository sync mechanism rather than hand-editing live workflows. The exact command depends on the current deployment pattern already used in this repository. After sync, open the new member-search action and the new batch review page from the live stack or local n8n and verify them in the browser.

For the end-to-end manual proof, use a real member who already appears in `raw_members` and choose a harmless test package. The operator flow should be:

    1. Open Member Search.
    2. Open the chosen member’s detail page.
    3. Click Queue ClubSpark Package.
    4. Choose the current Processing batch and a target package.
    5. Submit and observe a success page.
    6. Open the batch import review page.
    7. Filter to a single target package.
    8. Generate the external-file XLSX workbook for that package only.
    9. Open the matching ClubSpark `Admin/Membership/Import?packageID=...` page and verify it is the correct package import destination.
    7. Select the queued row and generate the workbook.
    8. Observe that the file downloads and the row status changes to exported.
    9. Upload the workbook into the correct ClubSpark package manually.
    10. Mark the row imported in the local review page.

## Validation and Acceptance

Acceptance is complete only when a human can verify all of the following.

First, existing manual batch behavior still works. Adding a manual tag or key row through [workflows/manual-batch-item-form.json](/mnt/c/dev/avondale-n8n/workflows/manual-batch-item-form.json) must continue to create rows in `signup_batch_manual_items`, and labels and envelopes must still read the same batch views as before. This proves the new ClubSpark queue has not polluted the old batch-item path.

Second, the member-search detail page must expose a clear new action for ClubSpark package queueing. Clicking it must open a form showing the selected member and allowing batch and target package selection. Submitting the form must create exactly one queue row and reject duplicate active rows cleanly.

Third, the batch review page must list the queued ClubSpark import rows for the chosen batch without requiring SQL. It must show enough context for a human to distinguish current membership from target membership and to select rows intentionally.

Fourth, workbook generation from selected queue rows must produce the same XLSX structure as the current existing-member import workflow. The workbook must still rely on resolved ClubSpark `Unique ID` values. If a selected row cannot resolve those IDs anymore, the operator must get a clear failure message naming the affected member rather than a silent partial export.

Fifth, successful export must update queue-row status from `queued` to `exported`, and successful post-upload confirmation must update rows to `imported`. A cancelled row must no longer appear as an active export candidate.

Sixth, the repository artifacts must validate mechanically. At minimum:

- `jq empty` must pass for all changed workflow JSON files
- the SQL migration must be syntactically valid
- any documentation links added in the docs must point at real files

The strongest behavioral proof is a real manual ClubSpark upload using the generated workbook for an existing member and a new package. After upload, the operator should be able to see that the person has the new package in ClubSpark without having typed the member name into the old free-text workflow.

## Idempotence and Recovery

The migration must be additive and safe to re-run. Use `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and `CREATE OR REPLACE VIEW` where possible so a partially applied dev/test run can be retried without manual cleanup.

The new queue rows should be status-driven rather than delete-driven. If an operator queues the wrong member or wrong target package, the safe recovery action is to mark that row `cancelled`, not to delete history. If a workbook is generated in error, the safe recovery action is either to cancel the exported rows or reset them back to `queued` with an explicit operator action. Do not silently create fresh duplicates for the same member/package combination.

Keep the old free-text workflow in place during rollout. If the new queued flow has a bug, the operator can still fall back temporarily to [workflows/clubspark-package-members-import-xlsx.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-package-members-import-xlsx.json) while the queued path is repaired. Only retire the old path after the new one is validated with real use.

If a queue row resolves successfully when created but later fails during export because `raw_members` or `raw_contacts` changed, the failure page must leave the row in a recoverable state. The operator should be able to fix the source data problem, rerun the export, and reuse the same queued row rather than rebuilding the queue from scratch.

## Artifacts and Notes

The current and target workflow shapes can be summarized concisely.

Current operator path:

    Member Search Detail
      -> Open Manual Batch Form
      -> creates signup_batch_manual_items for tags/keys

    Separate ClubSpark Import Form
      -> operator types free-text names
      -> workflow resolves raw_members/raw_contacts
      -> workbook download

Target operator path:

    Member Search Detail
      -> Queue ClubSpark Package
      -> creates signup_batch_clubspark_import_items

    Batch Import Review
      -> operator selects queued rows
      -> workflow resolves raw_members/raw_contacts
      -> workbook download
      -> rows marked exported/imported

The implementation should preserve the existing workbook column contract. The current export columns are:

    ContactID
    PrimaryContactID
    FirstName
    LastName
    EmailAddress
    StartDate
    ExpiryDate
    Cost
    Paid
    GiftAid
    Gender
    BirthDate
    HomeNumber
    WorkNumber
    MobileNumber
    EmergencyPhoneNumber
    PostCode
    Address1
    Address2
    Address3
    Town
    County
    Country
    Occupation
    DateJoinedVenue
    MedicalHistory
    Source
    KeyPinNumber
    TagsProvided

That column order comes from the existing workflow and must remain stable for ClubSpark workbook compatibility.

## Interfaces and Dependencies

The implementation depends on the following existing repository pieces:

- `public.raw_members` and `public.raw_contacts` as the current ClubSpark-synced source data
- `public.signup_batches` as the existing operator batch concept
- `public.membership_packages` as the likely source of target package choices
- [workflows/member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json) as the operator entry point
- [workflows/clubspark-package-members-import-xlsx.json](/mnt/c/dev/avondale-n8n/workflows/clubspark-package-members-import-xlsx.json) as the existing workbook-generation logic to reuse
- [workflows/sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json) if the new queue table must be mirrored to the cloud reporting database

Define these new repository-level artifacts by the end of implementation:

- one SQL migration that creates `public.signup_batch_clubspark_import_items` and `public.vw_signup_batch_clubspark_import_items`
- one queue-entry form workflow
- one queue-row insert workflow
- one batch review workflow
- one queue-based workbook-generation workflow, or a refactored existing workbook workflow with a queue-based entry path

Plan revision note: 2026-04-29 initial draft created after investigating issue `#94` and after the user clarified that the real requirement is adding a new package for existing ClubSpark members, not importing brand-new people into ClubSpark.
