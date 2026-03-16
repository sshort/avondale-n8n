# ClubSpark Web Navigation Notes

## Current Status

- Playwright is installed and running on the `n8n` host inside the `clubspark-exporter` Docker service.
- Browser launch is working.
- LTA authentication is working.
- Direct contacts export is working.
- Direct members export is working.
- The local `ClubSpark Contacts Export` workflow on `n8n` has been executed successfully end to end.
- The local `ClubSpark Members Export` workflow on `n8n` has been executed successfully end to end.

## Remote Runtime

- Host: `n8n`
- Compose file: `/root/docker-compose.yml`
- Exporter service: `clubspark-exporter`
- Base image: `mcr.microsoft.com/playwright:v1.52.0-jammy`
- Playwright package version pinned to `1.52.0`
- Exporter endpoint from the `n8n` container: `http://clubspark-exporter:3001/clubspark-export`
- Members endpoint from the `n8n` container: `http://clubspark-exporter:3001/clubspark-members-export`

## Credentials In Use

- ClubSpark email: `steve@shortcentral.com`
- ClubSpark password: `HQ#zo7P8C$`
- LTA username: `sshort`
- LTA password: `fH8Urv2XrtZwXra!`

## Working Navigation Sequence

1. Open:
   `https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts`
2. ClubSpark redirects to:
   `https://auth.clubspark.uk/account/signin?...`
3. On the initial ClubSpark sign-in page:
   - do **not** open `Login with another method` first
   - use the main LTA `Login` button / `button[name="idp"][value="LTA2"]`
4. That redirects to LTA:
   `https://mylta.my.site.com/s/login/...`
5. Fill LTA login:
   - username field: `input[placeholder="Username"]` or equivalent username selector
   - password field: password input on the same page
6. Submit `Log in`
7. Successful login returns to:
   `https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts`

## Important Findings

- The old failure was caused by opening `Login with another method` before taking the LTA path.
- That opens the ClubSpark email/password modal and leaves the LTA button underneath it, which confused the automation.
- Direct LTA login from the first page works on the `n8n` host.
- Cookie consent appears on the contacts page and must be dismissed before interacting with the page.
- `button.osano-cm-denyAll` is a reliable cookie-banner dismissal target.
- The visible `Export CSV` dropdown action is not the most reliable automation path.
- The stable path is to read the live contacts DataTables params from the page and post directly to:
  `contactsTableEndPoint.replace("Lookup", "Export")`
  with `SelectAll=True`.

## Contacts Page Findings

- After successful auth, the page reaches `/Admin/Contacts`.
- `clubHouseApp.AppSettings.contactsTableEndPoint` resolves to:
  `/AvondaleTennisClub/Admin/Contacts/Lookup?status=Active`
- The direct export URL is therefore:
  `https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts/Export?status=Active`
- `window.jQuery("#contacts-table").DataTable().ajax.params()` exposes the exact form parameters needed for export.
- Posting those parameters with `SelectAll=True` returns the CSV reliably.

## Members Page Findings

- After successful auth, the page reaches `/Admin/Membership/Members`.
- The direct export URL resolves to:
  `https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Membership/MemberExport?mode=members`
- `window.jQuery("#members-table").DataTable().ajax.params()` exposes the form parameters needed for export.
- Resetting filters before reading those params is safe.
- Posting those parameters with `SelectAll=True` returns the CSV reliably.

## Script State

File:
- `scripts/export-clubspark-contacts-local.mjs`

Current improvements already added:
- direct LTA-first login path
- cookie-banner dismissal
- stage logging to stderr
- Docker/container-safe browser launch options
- direct authenticated POST to the ClubSpark export endpoint using live page DataTables params
- no dependency on the fragile dropdown click path

Members file:
- `scripts/export-clubspark-members-local.mjs`

## Last Confirmed Good Logs

These stages were confirmed on the `n8n` host:

- `Opening https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts`
- `Initial page loaded: https://auth.clubspark.uk/account/signin?...`
- `Submitted LTA chooser`
- `LTA login page reached: https://mylta.my.site.com/s/login/...`
- `Submitting LTA username/password form via input[placeholder="Username"]`
- `Post-login page: https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts`
- `Dismissed cookie banner via button.osano-cm-denyAll`
- `On contacts page, preparing direct export request`
- `Submitting direct CSV export to https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts/Export?status=Active`

## Verified Outcome

- The exporter service returns a real CSV from the `n8n` host.
- The installed local workflow now calls:
  `http://clubspark-exporter:3001/clubspark-export`
- The installed local members workflow now calls:
  `http://clubspark-exporter:3001/clubspark-members-export`
- The local workflow run succeeded and loaded `1221` current rows into `raw_contacts`, archiving the prior snapshot first.
- The local members workflow run succeeded and loaded `817` current rows into `raw_members`.
