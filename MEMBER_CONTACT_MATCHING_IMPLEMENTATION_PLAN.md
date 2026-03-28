# Member / Contact Matching Implementation Plan

This turns [MEMBER_CONTACT_MATCHING_POLICY.md](/mnt/c/dev/avondale-n8n/MEMBER_CONTACT_MATCHING_POLICY.md)
into concrete work.

## Current Status

First implementation slice is now in the repo in
[021_member_contact_matching_first_slice.sql](/mnt/c/dev/avondale-n8n/sql/021_member_contact_matching_first_slice.sql).

Done in that slice:

- normalization helpers for postcode, phone, email, address line 1, and DOB
- corroborated reconcile rules for both `raw_contacts` and `raw_members`
- explicit audit outcomes including:
  - `matched_by_*`
  - `ambiguous_same_name`
  - `ambiguous_multiple_candidates`
  - `new_record`
- review views for ambiguous and weak `name_only` matches
- local Metabase audit cards and dashboard placement on the `Database` tab:
  - `Latest Raw Match Outcomes`
  - `Weak Name-Only Raw Matches`
  - `Ambiguous Raw Matches`
  - `Latest Raw Match Audit`

Still pending after that slice:

- regression checks for known duplicate-name and family cases

Done in the downstream resolver slice:

- shared resolver view/function:
  - [sql/022_best_contact_resolver.sql](/mnt/c/dev/avondale-n8n/sql/022_best_contact_resolver.sql)
  - `public.vw_best_current_contacts`
  - `public.resolve_best_contact_row(...)`
- batch/address resolution now uses the shared resolver through:
  - `public.vw_signup_batch_items`
- main downstream workflows now use the shared resolver:
  - [workflows/create-missing-signup-capture.json](/mnt/c/dev/avondale-n8n/workflows/create-missing-signup-capture.json)
  - [workflows/add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
  - [workflows/send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
  - [workflows/member-search-detail.json](/mnt/c/dev/avondale-n8n/workflows/member-search-detail.json)

## Verification Status

Current state after applying the migration in local and cloud:

- local and cloud DBs both have the new helpers, reconcile functions, audit table,
  and review views
- local reconcile now verifies cleanly for both `raw_members` and `raw_contacts`
- the duplicate same-person contact edge cases have been stabilized with
  deterministic ranked matching and strong-key name-conflict protection
- local Metabase now exposes the review views on dashboard `11`, tab `Database`
- local and cloud DBs both now have the shared best-contact resolver
- the local downstream address/email workflows now call the shared resolver

Current local verification:

- `raw_members`: `892 updated, 0 inserted, 0 deactivated`
- `raw_contacts`: `1233 updated, 0 inserted, 0 deactivated`

Representative latest audit outcomes after the final local reconcile run:

- `raw_contacts`
  - `matched_by_name_address` `3`
  - `matched_by_name_dob` `834`
  - `matched_by_name_email` `4`
  - `matched_by_name_only` `1`
  - `matched_by_name_phone` `20`
  - `matched_by_venue_id` `371`
- `raw_members`
  - `matched_by_btn` `197`
  - `matched_by_name_address` `10`
  - `matched_by_name_dob` `378`
  - `matched_by_name_email` `1`
  - `matched_by_name_only` `2`
  - `matched_by_name_phone` `2`
  - `matched_by_venue_id` `302`

## Original Gap

The following was the gap before the first implementation slice was added.
It remains useful as the rationale for the new migration.

The current raw-table reconcile logic is still too weak for same-name cases.

### Current `raw_contacts` reconcile

It currently matches by:

1. `Venue ID`
2. normalized full name only

That is not sufficient for cases like two `David Smith` records.

### Current `raw_members` reconcile

It currently matches by:

1. `Venue ID`
2. `British Tennis Number`
3. normalized full name + normalized membership category

That is better, but it still does not use corroborators like DOB, postcode,
address, or phone before falling back to weak identity.

### Current downstream behavior

Some downstream flows already try to choose the "best" contact row, but the
logic is local to each use case and not a single shared identity resolver.

That means:

- duplicate-name handling is inconsistent
- ambiguous same-name cases are not surfaced explicitly
- different workflows can make different choices for the same person

## Actual Work Needed

## 1. Strengthen normalization helpers

Add or extend helper functions so matching uses consistent normalized values for:

- full name
- postcode
- phone / mobile
- DOB
- email
- address line 1

Deliverables:

- SQL normalization helpers for postcode and phone
- standardized normalized field expressions inside reconcile functions/views
- documented null/empty handling

## 2. Build candidate-match scoring for contacts

Replace the current `Venue ID` then `name` ranking logic with explicit candidate
selection.

Contacts should be matched in this order:

1. `Venue ID`
2. normalized full name + DOB
3. normalized full name + postcode + address line 1
4. normalized full name + phone
5. normalized full name + email
6. full name only, but only when there is exactly one candidate

Deliverables:

- new candidate-selection SQL for contacts
- explicit match rule labels
- no auto-match when multiple candidates remain plausible

## 3. Build candidate-match scoring for members

Replace the current `Venue ID` / `BTN` / `name + category` logic with the full
priority order from the policy.

Members should be matched in this order:

1. `Venue ID`
2. `British Tennis Number`
3. normalized full name + DOB
4. normalized full name + postcode + address line 1
5. normalized full name + phone
6. normalized full name + email
7. full name only, only if there is exactly one candidate

Category remains useful for distinguishing memberships, but not for deciding
person identity.

Deliverables:

- new candidate-selection SQL for members
- conservative fallback behavior
- explicit separation of identity vs package/category

## 4. Add ambiguity outcomes instead of forced matches

The system needs a real `ambiguous` outcome, not just a best-effort guess.

Deliverables:

- match outcome labels such as:
  - `matched_by_venue_id`
  - `matched_by_btn`
  - `matched_by_name_dob`
  - `matched_by_name_address`
  - `matched_by_name_phone`
  - `matched_by_name_email`
  - `matched_by_name_only`
  - `ambiguous_same_name`
  - `ambiguous_multiple_candidates`
  - `new_record`
- storage or logging of the chosen outcome during reconcile
- refusal to auto-link where ambiguity remains

## 5. Add audit visibility for ambiguous and weak matches

The policy is only useful if ambiguous cases are visible.

Deliverables:

- a review query/view for ambiguous member matches
- a review query/view for ambiguous contact matches
- a review query/view for weak `name_only` matches
- counts/cards in Metabase for operational monitoring

## 6. Centralize "best contact row" selection

Downstream flows should not each invent their own contact-choice rules.

Create one shared resolver for "best contact row for resolved identity", using:

1. `Address 1`
2. `postcode`
3. email
4. mobile/phone
5. most populated contact fields
6. `is_current = true`

Deliverables:

- shared SQL view/function for best contact resolution
- update downstream flows to use it

## 7. Update downstream workflows and queries

Once the resolver exists, update the workflows and cards that currently depend on
name-only or ad hoc contact matching.

Main candidates:

- missing-signup backfill
- manual batch item creation
- no-address email recipient resolution
- label/envelope address resolution
- search/detail views that show contact/member linkage

Deliverables:

- one consistent resolver path
- no blank duplicate contact rows winning over complete rows
- explicit handling when person identity is ambiguous

## 8. Create regression tests with known bad cases

The policy should be proven against real examples.

Seed or record test cases like:

- same-name duplicates such as `David Smith`
- duplicate contact rows where one is blank and one has full address
- family members sharing email address
- year rollover package changes that should not create new identities

Deliverables:

- SQL verification queries
- sample expected outcomes by case
- rerun checks after reconcile changes

Implemented artifacts:

- [023_member_contact_matching_regression_checks.sql](/mnt/c/dev/avondale-n8n/sql/023_member_contact_matching_regression_checks.sql)
- [run-member-contact-regression-checks.sh](/mnt/c/dev/avondale-n8n/scripts/run-member-contact-regression-checks.sh)

Current pinned cases:

- `Louise Graham` family resolution should prefer `Hamish Graham`
- `Roni Asp` should resolve to her exact contact row
- duplicate `David Smith` rows must disambiguate by email
- current `David Smith` 2026 member rows must remain two distinct identities

Current verification status:

- local regression runner passes with all checks green
- cloud apply is still blocked by ownership on `vw_best_current_contacts`

## Recommended Delivery Order

1. normalization helpers
2. contact candidate scoring
3. member candidate scoring
4. ambiguity outcomes and logging
5. audit/review cards
6. shared best-contact resolver
7. downstream workflow updates
8. regression checks

## Suggested First Implementation Slice

The highest-value first slice is:

1. strengthen contact matching
2. add ambiguity outcomes
3. add a review card for ambiguous same-name matches

That addresses the riskiest silent failure mode first:

- auto-linking the wrong `David Smith`
