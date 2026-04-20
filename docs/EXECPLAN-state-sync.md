# ExecPlan: State Sync

## Goal

Add a git-friendly `state/` area and sync tooling for:

- n8n local <-> repo workflows <-> live
- Metabase local <-> state export package <-> live

This is separate from `scripts/backup-state.sh`, which remains restore-oriented.

## Decisions

1. Keep `backups/` as timestamped recovery data.
2. Add `state/` as the latest tracked platform mirror.
3. Keep the existing `workflows/` folder as the canonical n8n JSON store.
4. Add only a small n8n ID manifest under `state/n8n/`.
5. Wrap `metabase-migration-toolkit` for Metabase promotion instead of rebuilding collection, database, table, field, tab, and dashcard remapping locally.

## Deliverables

- `state/n8n/manifest.json`
- `state/metabase/export/`
- `state/metabase/db-map.local-to-live.json`
- `state/metabase/db-map.live-to-local.json`
- `scripts/sync-n8n-state.mjs`
- `scripts/sync-metabase-state.sh`
- `scripts/sync-platform-state.sh`
- `docs/STATE_SYNC.md`

## Status

- [x] Added the git-friendly `state/` layout.
- [x] Added native n8n pull/push/mirror tooling against the existing `workflows/` directory.
- [x] Added Metabase pull/push/mirror wrapper tooling around `metabase-migration-toolkit`.
- [x] Documented the commands and environment model.
