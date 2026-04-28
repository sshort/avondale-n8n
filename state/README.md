# State

`state/` is the git-tracked working mirror for platform configuration. It is separate from `backups/`, which stays timestamped and recovery-oriented.

Current layout:

- `state/n8n/`
  - `manifest.json`: stable key to environment ID mapping for repository workflow files
- `state/metabase/`
  - `export/`: git-tracked Metabase export package used for promotion
  - `db-map.local-to-live.json`: source database mapping for local -> live imports
  - `db-map.live-to-local.json`: source database mapping for live -> local imports
  - `db-map.template.json`: minimal sample template for a new target

Entry points:

- `bash scripts/sync-platform-state.sh pull local`
- `bash scripts/sync-platform-state.sh push live`
- `bash scripts/sync-platform-state.sh mirror local live`

Service-specific entry points:

- `node scripts/sync-n8n-state.mjs ...`
- `bash scripts/sync-metabase-state.sh ...`
- `node scripts/generate-metabase-db-map.mjs ...`

Notes:

- `workflows/` remains the hand-maintained repository artifact folder for n8n development work.
- `state/n8n/manifest.json` only tracks the environment IDs that correspond to those workflow files.
- `state/metabase/export/` is designed around `metabase-migration-toolkit`, because Metabase promotion needs database, field, dashcard, and tab remapping.
- The Metabase db map files can be generated from live metadata; use `METABASE_DB_NAME_MAP` when the source and target database names differ.
- The Metabase export wrapper excludes top-level `Examples` and `Trash` by default unless you override `METABASE_EXCLUDE_ROOT_COLLECTION_NAMES` or set `METABASE_ROOT_COLLECTIONS` explicitly.
