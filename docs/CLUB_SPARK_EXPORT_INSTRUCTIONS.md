## ClubSpark Contacts, Members, And Main Contacts Export

The supported local `ClubSpark Contacts Export`, `ClubSpark Members Export`, and `ClubSpark Main Contacts Export` workflows now run on the `n8n` host through the `browser-automation` Docker service. The checked-in workflow JSON files are self-contained, so importing an individual export workflow no longer depends on pre-creating the shared `ClubSpark Auth Session` workflow.

### How it works
1. The local `ClubSpark Contacts Export` workflow calls `POST http://browser-automation:3000/jobs/clubspark/contacts/export`.
2. The local `ClubSpark Members Export` workflow calls `POST http://browser-automation:3000/jobs/clubspark/members/export`.
3. The local `ClubSpark Main Contacts Export` workflow calls `POST http://browser-automation:3000/jobs/clubspark/members/main-contacts/export`.
4. The browser-automation service runs the matching Playwright script inside its container:
   - `scripts/export-clubspark-contacts-local.mjs`
   - `scripts/export-clubspark-members-local.mjs`
5. The workflows load `clubspark_email`, `clubspark_password`, `lta_username`, and `lta_password` from `public.global_settings` and send them in the request JSON body.
6. Each script logs into ClubSpark through the working LTA browser flow.
7. After login, each script reads the live DataTables request state from the relevant page and posts directly to the authenticated ClubSpark export endpoint.
8. The export workflows cache or forward the reusable session context so the full refresh can log in once and reuse that session across contacts, members, and main contacts.
9. n8n parses the returned CSV and imports it into:
   - `raw_contacts` for contacts
   - `raw_members` for members
   - `raw_members_main_contacts` for main contacts

### Required environment
- The `n8n` host must be running the `browser-automation` service.
- The service must have Playwright and the bundled Chromium available in the container.
- The `n8n` container must be able to reach:
  `http://browser-automation:3000/jobs/clubspark/contacts/export`
  `http://browser-automation:3000/jobs/clubspark/members/export`
  `http://browser-automation:3000/jobs/clubspark/members/main-contacts/export`

### Credentials
- The working browser path is the LTA login button.
- The workflows expect these `public.global_settings` keys to exist:
  - `clubspark_email`
  - `clubspark_password`
  - `lta_username`
  - `lta_password`
- The service and scripts still tolerate environment-variable fallback for direct local script runs, but the workflow path is now payload-driven.
- The legacy ClubSpark alternate-login form is not the supported route for this workflow anymore.

### Local script usage
Run the exporter directly if you want to test outside n8n on a machine that has Playwright installed:

`bash scripts/run-clubspark-export-local.sh`

Run the HTTP service locally if you want the same interface that the `n8n` workflow uses:

`node scripts/clubspark-export-server.mjs`

Useful environment variables:
- `CLUBSPARK_OUTPUT=-` to print CSV to stdout
- `HEADLESS=true` to run without a visible browser
- `SLOW_MO=0` to remove the default delay
- `PLAYWRIGHT_CHANNEL=chrome` to force a browser channel

### Current verified state
- The local workflows in this repository are wired to `browser-automation`.
- The exporter returns real contacts, members, and main contacts CSVs from the `n8n` host.
- The full local contacts workflow has been executed successfully end to end and loaded `1221` rows into `raw_contacts`.
- The full local members workflow has been executed successfully end to end and loaded `817` rows into `raw_members`.
