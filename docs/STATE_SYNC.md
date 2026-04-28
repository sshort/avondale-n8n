# State Sync

This repo now has a git-friendly state path in [state](/mnt/c/dev/avondale-n8n/state) for n8n and Metabase. It is intentionally separate from [backups](/mnt/c/dev/avondale-n8n/backups):

- `backups/` is for timestamped restore snapshots.
- `state/` is for the latest tracked configuration that you want to diff and promote.

## Commands

Sync both services:

```bash
bash scripts/sync-platform-state.sh pull local
bash scripts/sync-platform-state.sh push live
bash scripts/sync-platform-state.sh mirror local live
```

Sync only one service:

```bash
bash scripts/sync-platform-state.sh --service n8n pull local
bash scripts/sync-platform-state.sh --service metabase mirror local live
```

## n8n

Use [scripts/sync-n8n-state.mjs](/mnt/c/dev/avondale-n8n/scripts/sync-n8n-state.mjs).

- `pull <env>` reads workflows from that n8n instance into the existing [workflows](/mnt/c/dev/avondale-n8n/workflows) directory and updates `state/n8n/manifest.json`.
- `push <env>` writes the tracked workflow JSON from `workflows/` back to that instance.
- `mirror <src> <dst>` pulls from the source into the repo workflow files, then pushes from those files to the target.

Expected environment variables:

- `N8N_LOCAL_BASE_URL`
- `N8N_LOCAL_API_KEY`
- `N8N_LIVE_BASE_URL`
- `N8N_LIVE_API_KEY`

`local` defaults are populated from the repo’s current docker-compose setup. `live` is intentionally env-driven.

## Metabase

Use [scripts/sync-metabase-state.sh](/mnt/c/dev/avondale-n8n/scripts/sync-metabase-state.sh).

This wrapper expects `metabase-migration-toolkit` to be installed and available as:

- `metabase-export`
- `metabase-import`
- `metabase-sync`

Recommended install:

```bash
pip install metabase-migration-toolkit
```

The wrapper uses:

- `state/metabase/export/` as the tracked export package
- `state/metabase/db-map.local-to-live.json`
- `state/metabase/db-map.live-to-local.json`
- `scripts/generate-metabase-db-map.mjs` to build those map files from instance metadata for new targets

Expected environment variables:

- `METABASE_LOCAL_URL`
- `METABASE_LOCAL_TOKEN` or `METABASE_LOCAL_USERNAME` + `METABASE_LOCAL_PASSWORD`
- `METABASE_LIVE_URL`
- `METABASE_LIVE_TOKEN` or `METABASE_LIVE_USERNAME` + `METABASE_LIVE_PASSWORD`
- `METABASE_VERSION`
- `METABASE_DB_NAME_MAP` for renamed databases in a fresh deployment, for example `avondale@homedb=avondale@prod`
- `METABASE_EXCLUDE_ROOT_COLLECTION_NAMES` to drop non-deployable top-level collections, default `Examples,Trash`
- `METABASE_INCLUDE_ARCHIVED` when you intentionally want archived content in the tracked package
- `METABASE_ROOT_COLLECTIONS`

The default local URL and token come from the existing repo backup tooling. Live values stay explicit.

For a fresh deployment, `push` and `mirror` will auto-generate the required `db-map.*.json` file when it is missing or empty. Exact name matches are mapped automatically, the sample database is mapped by `is_sample`, and `METABASE_DB_NAME_MAP` covers renamed non-sample databases.
The wrapper now exports non-archived content by default, which avoids stale archived cards blocking sync because of broken internal dependencies. Set `METABASE_INCLUDE_ARCHIVED=1` if you need the archived package as well.
If `METABASE_ROOT_COLLECTIONS` is not set, the wrapper auto-resolves top-level collections and excludes `Examples` and `Trash` by default so the tracked state stays deployable.

## Why The Split

Metabase promotion is not just files. It needs:

- database ID remapping
- table and field remapping
- collection hierarchy recreation
- dashboard tab and dashcard remapping

`metabase-migration-toolkit` already handles those pieces. n8n workflows are simpler, so the repo now has a smaller native sync utility for them.
