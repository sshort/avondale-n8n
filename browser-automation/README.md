# Browser Automation Container

This directory contains the build files for the `browser-automation` service
that supersedes the older `clubspark-exporter` container on the local `n8n`
host.

Build from the repository root:

```bash
docker build -f browser-automation/Dockerfile -t local/browser-automation:latest .
```

The image contains a baked-in fallback copy of the runtime scripts from the
repository `scripts/` directory. When the container is started from this
repository checkout, it can also use a portable repo-relative bind mount such
as `./scripts:/app/runtime-scripts:ro` so that job-script changes do not
require an image rebuild.

The running service exposes:

- `GET /health`
- `GET /jobs`
- `POST /jobs/clubspark/contacts/export`
- `POST /jobs/clubspark/members/export`
- `POST /jobs/clubspark/members/main-contacts/export`
- `POST /jobs/clubspark/auth-session`
- `POST /jobs/metabase/dashboard-pdf`

Legacy aliases are also retained:

- `POST /clubspark-export`
- `POST /clubspark-members-export`
- `POST /clubspark-members-main-contacts-export`
- `POST /clubspark-auth-session`
- `POST /metabase-dashboard-pdf`

ClubSpark jobs accept credentials in the request JSON body under
`credentials.clubspark` and `credentials.lta`. The local Metabase PDF renderer
remains the checked-in script at `scripts/export-metabase-dashboard-pdf.mjs`.
