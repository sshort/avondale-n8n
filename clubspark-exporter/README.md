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

The running service exposes:

 `GET /health`
- `POST /clubspark-export`
- `POST /clubspark-members-export`
