# Member / Contact Matching Policy

This defines how `raw_members`, `raw_contacts`, and downstream workflows should
decide whether two records represent the same person.

The goal is:

- auto-match only when there is a clear best candidate
- avoid silently merging different people who share a name
- make ambiguous cases explicit

## Principles

1. Do not match on `First name + Last name` alone.
2. Treat `Venue ID` and `British Tennis Number` as the strongest person keys when present.
3. Treat package or membership name as an attribute, not identity.
4. Prefer address, DOB, phone, and email as corroborators, not primary identity.
5. If multiple candidates remain plausible, mark the result as ambiguous and do not auto-link.

## Record Normalization

All matching should use normalized values where possible:

- trim leading/trailing whitespace
- collapse repeated spaces
- compare names case-insensitively
- normalize postcodes to uppercase with internal spacing removed if needed
- normalize phone numbers to digits-only form for comparison
- treat empty strings as `NULL`

## Identity Strength Order

Use this precedence order.

### 1. Strong identity keys

These allow auto-match on their own if unique.

- `Venue ID`
- `British Tennis Number`

Rules:

- If exactly one current candidate matches `Venue ID`, use it.
- Else if exactly one current candidate matches `British Tennis Number`, use it.
- If either key matches multiple current candidates, treat as ambiguous and review.

### 2. Medium-confidence person match

Only use these when strong keys are absent.

Require normalized full name plus at least one strong corroborator:

- same DOB
- same postcode and same address line 1
- same normalized mobile or phone number
- same email address

Rules:

- If one candidate clearly satisfies the name + corroborator rule, use it.
- If more than one candidate satisfies it, treat as ambiguous.

### 3. Weak name-only match

This is not safe for auto-linking when there are multiple people with the same
name.

Rules:

- If normalized full name matches exactly one current row and there are no
  competing candidates, name-only matching is acceptable as a last resort.
- If the same normalized full name exists more than once, do not auto-link on
  name alone.

## Member Matching

Use this when reconciling `raw_members` imports or linking a member row to an
existing member identity.

Priority:

1. `Venue ID`
2. `British Tennis Number`
3. normalized full name + DOB
4. normalized full name + postcode + address line 1
5. normalized full name + phone
6. normalized full name + email
7. exact normalized full name only, but only if there is exactly one candidate

Important:

- membership/package text must not be treated as person identity
- category can be used to distinguish multiple memberships for the same person,
  but not to decide whether two people are the same

## Contact Matching

Use this when reconciling `raw_contacts` imports or choosing the best contact
row for a person or household.

Priority:

1. `Venue ID`
2. normalized full name + DOB
3. normalized full name + postcode + address line 1
4. normalized full name + phone
5. normalized full name + email
6. exact normalized full name only, but only if there is exactly one candidate

When multiple contact rows match the same person, choose the best row by
quality:

1. has `Address 1`
2. has `postcode`
3. has email
4. has mobile or phone
5. has the most populated address/contact fields
6. current row beats non-current row

This is the rule that should prevent a blank duplicate contact row from beating
an addressed row for the same person.

## Same-Name Ambiguity Rule

Example: two `David Smith` rows.

Never auto-match these solely because:

- first name matches
- last name matches

Auto-match is only allowed if one of these separates them:

- different `Venue ID`
- different `BTN`
- DOB
- postcode + address line 1
- phone
- email

If none of those resolve to a single winner:

- mark as `ambiguous_same_name`
- require review or manual selection

## Household / Family Cases

Family records often share:

- payer
- postal address
- email address

Therefore:

- email must not outrank DOB, phone, or address for person identity
- household contact selection is separate from person identity

Recommended household rule:

- resolve the person first
- resolve the best household contact second
- for family products, prefer the best active household contact with usable
  address data when generating labels, emails, or manual batch items

## Downstream Usage

Apply the policy differently depending on the task.

### Raw import reconciliation

Use the strongest safe auto-match possible.

- auto-update in place when there is one clear winner
- insert a new row when there is no safe match
- flag for review when multiple candidates remain plausible

### Member-to-contact enrichment

Use person match first, then choose best contact row by quality.

### Missing-signup backfill

Prefer:

1. resolved member identity
2. best household contact row

Do not pick a blank duplicate contact row if an addressed row exists for the
same resolved identity.

## Decision Outcomes

Every matching process should produce one of these outcomes:

- `matched_by_venue_id`
- `matched_by_btn`
- `matched_by_name_dob`
- `matched_by_name_address`
- `matched_by_name_phone`
- `matched_by_name_email`
- `matched_by_name_only`
- `new_record`
- `ambiguous_same_name`
- `ambiguous_multiple_candidates`

These outcome labels are useful for logging and later auditing.

## What To Avoid

- matching on name alone when duplicates exist
- matching on email alone as a universal person key
- treating package name with year suffix as identity
- assuming one contact row per person
- assuming one email address per person

## Recommended Next Implementation Step

When this policy is implemented in code or SQL:

1. add explicit match outcome logging
2. add an `ambiguous` bucket instead of forcing a bad match
3. keep the current reconcile functions conservative
4. only widen auto-match rules when there is evidence they are safe
