## ClubSpark Contacts Export

The supported local `ClubSpark Contacts Export` workflow now runs on the `n8n` host through the `clubspark-exporter` Docker service.

### How it works
1. The local `ClubSpark Contacts Export` workflow calls `POST http://clubspark-exporter:3001/clubspark-export`.
2. The exporter service runs `scripts/export-clubspark-contacts-local.mjs` inside its Playwright container.
3. The script logs into ClubSpark through the working LTA browser flow.
4. After login, the script reads the live DataTables request state from the contacts page and posts directly to the authenticated ClubSpark `.../Admin/Contacts/Export` endpoint.
5. n8n parses the returned CSV and imports it into `raw_contacts` after archiving the previous snapshot.

### Required environment
- The `n8n` host must be running the `clubspark-exporter` service.
- The service must have Playwright `1.52.0` and the bundled Chromium available in the container.
- The `n8n` container must be able to reach:
  `http://clubspark-exporter:3001/clubspark-export`

### Credentials
- The working browser path is the LTA login button with:
  - username: `sshort`
  - password: stored in `scripts/run-clubspark-export-local.sh`
- The legacy ClubSpark alternate-login form is not the supported route for this workflow anymore.

### Local script usage
Run the exporter directly if you want to test outside n8n on a machine that has Playwright installed:

`bash scripts/run-clubspark-export-local.sh`

Run the HTTP exporter service locally if you want the same interface that the `n8n` workflow uses:

`node scripts/clubspark-export-server.mjs`

Useful environment variables:
- `CLUBSPARK_OUTPUT=-` to print CSV to stdout
- `HEADLESS=true` to run without a visible browser
- `SLOW_MO=0` to remove the default delay
- `PLAYWRIGHT_CHANNEL=chrome` to force a browser channel

### Current verified state
- The local workflow on `n8n` is wired to `clubspark-exporter`.
- The exporter returns a real contacts CSV from the `n8n` host.
- The full local workflow has been executed successfully end to end and loaded `1221` rows into `raw_contacts`.
