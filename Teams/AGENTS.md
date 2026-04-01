# Agent Instructions for `/mnt/c/dev/avondale-n8n/Teams`

This directory contains the league and squad source documents used to build team contact lists.

## Source Files

- Use the `*.docx` files in this directory as the source of team membership.
- Treat the first table row as squad/team headers.
- Treat the first column as positional numbering, not the team name.
- Each output workbook should contain one squad per sheet.
- Each output PDF should contain one team per file, including `Reserves`.

## Matching Rules

- Match players by **exact full name only** against the club data.
- Use current club data from:
  - `public.raw_members`
  - `public.vw_best_current_contacts`
  - `public.member_signups`
  - `public.vw_junior_main_contacts`
- If there is a unique current paid membership match for the configured season, use that membership category.
- If the player is a junior and `public.vw_junior_main_contacts` provides a unique high-confidence main contact, prefer that adult/main-contact email and phone over the junior's own raw member/contact details.
- If a junior has their own contact row with consent to share and they also have a unique high-confidence main contact whose consent also allows sharing, output one row with two-line `Phone` and `Email` cells:
  - `Self: ...`
  - `Parent: ...`
- Use `public.raw_contacts."Share Contact Detail"` to decide whether a player's own phone/email can be shown.
  - `Yes` and similar true values mean the contact details may be shown.
  - blank or non-true values mean the generator must output `No Consent` in both `Phone` and `Email`.
- Treat junior and parent consent independently.
  - If the junior cannot share but the resolved parent contact can, show the parent details.
  - If the parent cannot share but the junior can, show the junior details.
  - Only show `No Consent` when no permitted line can be shown.
- Also include `No Consent` rows in the generated review report every run.
- If there is no current paid membership match but there is a unique exact contact match, set category to `Not Signed Up`.
- If there is no unique exact-name match, set category to `No Match`.
- `No Match` also covers ambiguous exact-name collisions, such as duplicate people with the same first and last name.
- For duplicate exact-name contact rows, prefer one unique contact whose email local-part clearly contains the player's first and last name, for example `harrymcintyre68@...` for `Harry McIntyre`.
- If duplicate exact-name active contacts remain after that, prefer one unique row with clearly more complete contact details, for example an email-populated row over a blank duplicate.
- When one row is chosen from several exact-name contact candidates, mark the output `Match` column as `Best Fit`.
- After exact full-name matching fails, allow a cautious second-pass first-name fallback:
  - same surname required
  - one unique candidate only
  - nickname/short-name expansion is allowed, for example `Jacquie` -> `Jacqueline`
- Apply manual overrides from [name_overrides.csv](./name_overrides.csv) before leaving a row as `No Match`.
- The override file may contain multiple target rows for the same source short name, for example `Sam -> Samuel` and `Sam -> Samantha`.
- If the override expansion produces more than one candidate for the same surname, leave the row as `No Match`.
- After exact and override-based nickname matching both fail, allow a cautious fuzzy final pass:
  - same first initial and surname initial required
  - one unique clear candidate only
  - intended for small spelling drift such as `Maeuw Tatum` -> `Maew Tatam`
  - if the top two fuzzy candidates are close, leave the row as `No Match`

## Output Requirements

- Keep captains first, marked with `C`, and bold them.
- Sort all non-captains by first name alphabetically.
- Use Avondale Tennis Club theming:
  - navy `#2F5496`
  - light blue `#D9E2F3`
  - gold `#C9A227`
- Keep all three output forms:
  - `.xlsx`
  - per-sheet `.csv`
  - per-team `.pdf`
- Also generate the captain email distribution list on every run:
  - `generated/team-captains-email-list.txt`
- The `Match` column should show non-exact resolution types explicitly:
  - `Best Fit`
  - `Override`
  - `Nickname`
  - `Fuzzy`
- Also regenerate the match review outputs on every run:
  - root markdown review: [NO_MATCH_NAMES.md](./NO_MATCH_NAMES.md)
  - generated markdown copy: `generated/NO_MATCH_NAMES.md`
  - generated PDF copy: `generated/NO_MATCH_NAMES.pdf`
- The generated sheets and PDFs must include a `No Consent` footnote explaining why phone/email may be withheld.

## Generator

- Main script: [generate_team_contact_lists.py](./generate_team_contact_lists.py)
- Output folder: `generated/`
- Per-team PDFs are written directly into `generated/`

Run with:

```bash
/mnt/c/dev/postgres-mcp-venv-linux/bin/python /mnt/c/dev/avondale-n8n/Teams/generate_team_contact_lists.py
```

Optional environment overrides:

```bash
TEAM_CONTACTS_DSN=postgresql://postgres:6523Tike@192.168.1.248:5432/postgres
TEAM_CONTACTS_SEASON=2026
```
