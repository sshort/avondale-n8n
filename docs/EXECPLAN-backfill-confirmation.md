# Project: Confirm Missing Signup Backfill
**Objective:** Add a confirmation step before creating a missing signup backfill so the operator can review the resolved member, contact details, and valid current memberships. If multiple current paid memberships are possible, require explicit category selection before running the backfill.

## Scope
- Add a new HTML webhook page for backfill confirmation.
- Keep `create-missing-signup-capture` as the backend writer.
- Update member detail to route `Create Signup` through the confirmation page.
- Preserve local-first behavior; cloud can be synced later.

## Design
- Resolve the member from `member_id` or fallback identity fields.
- Load current `raw_members` rows for that resolved person.
- Restrict selectable memberships to current, active, paid or part-paid, and non-`Pavilion Key`.
- Show existing signup capture status per eligible membership.
- If only one eligible membership exists, preselect it.
- If multiple exist, require a radio-button selection.
- Submit the confirmed choice to `create-missing-signup-capture`.

## Steps
- [ ] Add `confirm-missing-signup-capture.json`
- [ ] Update `member-search-detail.json` create-signup link
- [ ] Deploy both workflows to local n8n
- [ ] Verify unique-option and multi-option flows
- [ ] Verify John Robbie style case does not default to older season
