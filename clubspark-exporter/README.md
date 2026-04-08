# ClubSpark Exporter Container

This directory contains the build files for the `clubspark-exporter` service that runs on the local `n8n` host.

Build from the repository root:

```bash
docker build -f clubspark-exporter/Dockerfile -t local/clubspark-exporter:latest .
```

The image copies its runtime scripts from:

- `scripts/clubspark-export-server.mjs`
- `scripts/export-clubspark-contacts-local.mjs`
- `scripts/export-clubspark-members-local.mjs`
- `scripts/export-metabase-dashboard-pdf.mjs`

The running service exposes:

`GET /health`
- `POST /clubspark-export`
- `POST /clubspark-members-export`
- `POST /clubspark-members-main-contacts-export`
- `POST /clubspark-auth-session`
- `POST /metabase-dashboard-pdf`

## Metabase Dashboard PDF Export

`POST /metabase-dashboard-pdf` accepts a JSON body and returns a merged PDF binary.

The exporter:

- opens the selected Metabase dashboard in Playwright
- signs in if Metabase presents a login form
- clicks each selected dashboard tab in order
- prints each selected tab to PDF
- merges the tab PDFs into a single output document

Expected payload shape:

```json
{
  "metabaseBaseUrl": "http://metabase:3000",
  "dashboardId": 11,
  "dashboardName": "Avondale Membership",
  "tabs": [
    { "id": 112, "name": "Memberships" },
    { "id": 114, "name": "Signup Statistics" }
  ],
  "filters": {
    "year": "2026"
  },
  "pdf": {
    "format": "A4",
    "landscape": false
  }
}
```

Credential resolution order:

- `payload.login.username` / `payload.login.password`
- exporter environment variables:
  - `METABASE_EMAIL` or `METABASE_USERNAME`
  - `METABASE_PASSWORD`

Optional exporter environment variables:

- `METABASE_BASE_URL`
- `PLAYWRIGHT_CHANNEL`
- `PLAYWRIGHT_EXECUTABLE_PATH`
- `HEADLESS`
- `SLOW_MO`
