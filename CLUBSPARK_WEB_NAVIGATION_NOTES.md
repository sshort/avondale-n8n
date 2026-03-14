# ClubSpark Web Navigation Notes

## Current Status

- Playwright is installed and running on the `n8n` host inside the `clubspark-exporter` Docker service.
- Browser launch is working.
- LTA authentication is working.
- The remaining failure is the final contacts export action, not auth.

## Remote Runtime

- Host: `n8n`
- Compose file: `/root/docker-compose.yml`
- Exporter service: `clubspark-exporter`
- Base image: `mcr.microsoft.com/playwright:v1.52.0-jammy`
- Playwright package version pinned to `1.52.0`
- Exporter endpoint from the `n8n` container: `http://clubspark-exporter:3001/clubspark-export`

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

## Contacts Page Findings

- After successful auth, the page reaches `/Admin/Contacts`.
- `Contact Options` is visible and opens a visible dropdown menu.
- A second dropdown menu exists in the DOM containing:
  - `Export PDF`
  - `Export CSV`
  - `Add Tags`
  - `Remove Tags`
  - `Merge contacts`
  - `Delete contacts`
- That export menu is present in the DOM even when not visibly open.

## Export Problem

- The previous script used a generic `.dropdown-toggle` selector and clicked the wrong menu.
- Then it tried `a.btn-more`, but that control remained disabled/inactive in the tested state.
- Selecting all contacts with `input[name='select_all']` did not make that `More options` button usable in headless mode.
- The export blocker is now specifically:
  - how to trigger the hidden `Export CSV` action reliably after login

## Script State

File:
- `scripts/export-clubspark-contacts-local.mjs`

Current improvements already added:
- direct LTA-first login path
- cookie-banner dismissal
- stage logging to stderr
- Docker/container-safe browser launch options
- fallback logic for export triggering

Latest intended direction in the script:
- do not depend on the disabled visible `More options` control
- instead locate the DOM action for `Export CSV`
- trigger that action directly after login
- capture either:
  - a Playwright download event, or
  - a network response to `/Admin/Contacts/Export`

## Last Confirmed Good Logs

These stages were confirmed on the `n8n` host:

- `Opening https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts`
- `Initial page loaded: https://auth.clubspark.uk/account/signin?...`
- `Submitted LTA chooser`
- `LTA login page reached: https://mylta.my.site.com/s/login/...`
- `Submitting LTA username/password form via input[placeholder="Username"]`
- `Post-login page: https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts`
- `Dismissed cookie banner via button.osano-cm-denyAll`
- `On contacts page, preparing export`

## Next Step

1. Finish the direct `Export CSV` DOM trigger in `scripts/export-clubspark-contacts-local.mjs`.
2. Verify the exporter returns real CSV from the `clubspark-exporter` container.
3. Only then update the installed n8n workflow to call:
   `http://clubspark-exporter:3001/clubspark-export`
