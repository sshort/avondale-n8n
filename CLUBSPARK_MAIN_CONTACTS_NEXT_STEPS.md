# ClubSpark Main Contacts Next Steps

## What Exists Now

- `raw_members` remains the source-of-truth import for the normal ClubSpark `Members` export.
- `ClubSpark Main Contacts Export` now provides a separate export path from the same ClubSpark members page after switching the member view to `Main Contacts`.
- The export shape matches the normal members CSV headers, but many junior rows are projected onto the adult main contact rather than the junior member.

## Recommended Database Tables

### 1. Keep `raw_members` unchanged

This should continue to hold the normal `Members` export.

### 2. Add a new raw import table

Recommended name:

- `public.raw_members_main_contacts`

Recommended first version:

- same column layout as `public.raw_members`
- same lifecycle columns:
  - `id`
  - `first_seen_at`
  - `last_seen_at`
  - `is_current`

Reason:

- the export is row-compatible with `raw_members`
- keeping the same shape makes sync/import tooling simpler
- it avoids polluting `raw_members` with a second semantic view of the same ClubSpark page

### 3. Add staging and reconcile objects to match the existing rollout

Recommended:

- `public.raw_members_main_contacts_import_staging`
- `public.prepare_raw_members_main_contacts_import_staging()`
- `public.reconcile_raw_members_main_contacts_from_staging()`

Reason:

- this should use the same stable-id import pattern already used for `raw_members` and `raw_contacts`

## Recommended Derived Views

### 1. A current-view helper

Recommended:

- `public.vw_raw_members_main_contacts_current`

Definition:

- current rows only from `raw_members_main_contacts`

### 2. A paired export view

Recommended:

- `public.vw_members_with_main_contacts`

Purpose:

- align `raw_members` rows with `raw_members_main_contacts` rows using same membership-row semantics
- expose:
  - `member_name`
  - `member_membership`
  - `member_email`
  - `main_contact_name`
  - `main_contact_email`
  - `main_contact_phone`
  - `relationship_inference`
  - `match_rule`

### 3. A junior-focused resolver view

Recommended:

- `public.vw_junior_main_contacts`

Purpose:

- only junior member rows
- expose the best deduced guardian / payer / main contact

Suggested columns:

- `member_raw_id`
- `member_name`
- `membership`
- `season`
- `member_email`
- `main_contact_name`
- `main_contact_email`
- `main_contact_phone`
- `main_contact_address_1`
- `main_contact_postcode`
- `match_confidence`
- `match_rule`

## Recommended Query Strategy

### Phase 1

Do not infer parenthood yet.

Treat the new export as:

- `main_contact`
- or `guardian_or_payer`

That is safer than calling it `parent`, because the ClubSpark export is clearly projecting the account/main contact, not necessarily a biological parent.

### Phase 2

Build matching from paired export semantics first, heuristics second.

Priority order:

1. exact row pairing from the same ClubSpark membership export semantics
2. same membership + same dates + same venue/BTN where available
3. same membership + same junior row projected onto a different contact name in the main-contacts export
4. only then fallback heuristics such as:
   - emergency contact name
   - emergency phone
   - shared surname
   - shared address/postcode

### Phase 3

Keep match provenance explicit.

Recommended `match_rule` values:

- `direct_main_contacts_export`
- `venue_id_pair`
- `btn_pair`
- `membership_date_pair`
- `emergency_contact_match`
- `household_match`
- `ambiguous`
- `unresolved`

## Recommended Workflow Sequence

1. Keep the new `ClubSpark Main Contacts Export` workflow as export-only for now.
2. After approval, add:
   - SQL migration for `raw_members_main_contacts`
   - a new import workflow that loads this export into staging and reconciles it
3. Then add the derived views.
4. Then update downstream junior/team logic to use those views instead of historical CSV heuristics.

## Recommended First Follow-on Change

If the next step is approved, the best next implementation slice is:

1. add `raw_members_main_contacts`
2. add staging + reconcile
3. add `vw_junior_main_contacts`
4. run one real import and inspect junior mappings before changing any downstream workflow logic
