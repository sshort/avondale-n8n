## ClubSpark Contacts Export

The supported local `ClubSpark Contacts Export` workflow now uses a browser-driven export step instead of the old raw HTTP login path.

### How it works
1. n8n runs `scripts/run-clubspark-export-local.sh` with an `Execute Command` node.
2. That wrapper launches the local Playwright exporter in `scripts/export-clubspark-contacts-local.mjs`.
3. The script logs into ClubSpark through the working LTA browser flow and writes the CSV to stdout.
4. n8n parses the CSV and imports it into `raw_contacts` after archiving the previous snapshot.

### Required environment
- The n8n host must be able to run:
  `bash /mnt/c/dev/avondale-n8n/scripts/run-clubspark-export-local.sh`
- Playwright must already be installed on that host.
- The host must be able to launch Chromium for the local exporter.

### Credentials
- The working browser path is the LTA login button with:
  - username: `sshort`
  - password: stored in `scripts/run-clubspark-export-local.sh`
- The legacy ClubSpark alternate-login form is not the supported route for this workflow anymore.

### Local script usage
Run the exporter directly if you want to test outside n8n:

`bash scripts/run-clubspark-export-local.sh`

Useful environment variables:
- `CLUBSPARK_OUTPUT=-` to print CSV to stdout
- `HEADLESS=true` to run without a visible browser
- `SLOW_MO=0` to remove the default delay
- `PLAYWRIGHT_CHANNEL=chrome` to force a browser channel
