# Typed Query Contracts Implementation Plan

## Goal

Add typed query contracts around existing SQL without replacing the SQL itself.

This is an additive safety improvement, not an ORM rewrite.

## Non-Goals

- Do not replace working SQL with ORM-generated queries.
- Do not rename columns that Metabase or n8n workflows already depend on.
- Do not move mature Postgres business logic out of views/functions unless there is a clear operational benefit.
- Do not try to type every query in one pass.

## What "Typed Query Contracts" Means Here

For each important query used by scripts or service code:

- define the expected output columns
- define the expected type of each column
- validate the returned rows where code consumes them
- fail fast when a query shape drifts unexpectedly

The SQL remains the source of truth. The contract is a checked boundary around it.

## Scope Priority

Start with code that is easiest to validate and most likely to benefit:

1. standalone scripts in `scripts/*.mjs`
2. shared DB views/functions already used by multiple workflows
3. exporter/service code
4. only later, if needed, small reusable helpers for workflow-side SQL consumers

Do not begin with Metabase cards or raw n8n workflow JSON as the primary typing target.

## Candidate Objects For First Coverage

High-value shared DB objects:

- `public.resolve_best_contact_row(...)`
- `public.vw_best_current_contacts`
- `public.vw_signup_batch_items`
- `public.vw_signup_batch_consolidated`
- `public.vw_signup_batches_summary`
- `public.global_settings`
- `public.images`
- `public.email_templates`

High-value scripts:

- `scripts/import-images.mjs`
- `scripts/import-email-templates.mjs`
- `scripts/export-clubspark-auth-session-local.mjs`
- `scripts/export-clubspark-contacts-local.mjs`
- `scripts/export-clubspark-members-local.mjs`
- `scripts/clubspark-export-server.mjs`

## Safe Delivery Approach

### Phase 1: Inventory and Prioritization

Create a map of:

- which scripts execute SQL directly
- which SQL objects are shared dependencies
- which result sets are already treated as implicit contracts

Deliverable:

- a short inventory file listing target query contracts in priority order

### Phase 2: Contract Format

Choose one lightweight contract format for Node scripts.

Recommended options:

- plain JSDoc typedefs plus explicit runtime assertions
- or a small schema library already acceptable in the repo

Selection criteria:

- easy to read
- low dependency cost
- minimal runtime overhead
- works well with Node scripts already in this repo

Deliverable:

- one agreed contract pattern with one example

### Phase 3: Shared DB Object Contracts

For each high-value view/function:

- document expected columns and types
- add a small verification query/script that checks the shape
- avoid changing the SQL unless required for consistency

Deliverable:

- checked contracts for the shared DB objects listed above

### Phase 4: Script Boundary Contracts

At each script boundary:

- validate DB rows after query execution
- validate structured payloads before use
- surface actionable errors when a contract fails

Examples:

- `global_settings` row shape
- `images` row shape
- `email_templates` row shape
- ClubSpark session payload shape

Deliverable:

- typed, validated input/output boundaries for the target scripts

### Phase 5: Drift Detection

Add regression checks for contract drift.

This should catch:

- missing expected columns
- changed column names
- type changes that would break scripts
- nullability drift for required fields

Deliverable:

- one script or SQL-based check that can be rerun after DB/view changes

### Phase 6: Documentation and Adoption

Document:

- where contracts live
- how to add a new one
- what to do when a contract fails

Deliverable:

- short maintainer guidance in repo docs

## Sub-Tasks

### 1. Inventory current script/query boundaries

- identify scripts that depend on SQL result shapes
- identify shared views/functions used as de facto contracts
- rank by operational risk

### 2. Choose the contract mechanism

- decide between JSDoc + assertions vs schema library
- define one canonical pattern
- write one example contract

### 3. Add contracts for core shared DB objects

- `resolve_best_contact_row(...)`
- `vw_signup_batch_items`
- `vw_signup_batch_consolidated`
- `vw_signup_batches_summary`
- `global_settings`

### 4. Add contracts to import/support scripts

- `import-images.mjs`
- `import-email-templates.mjs`
- any helper reading `global_settings`

### 5. Add contracts to ClubSpark exporter scripts

- auth session payload
- contacts export payload
- members export payload

### 6. Add reusable query assertion helpers

- assert required columns exist
- assert row values have expected primitive types
- keep helper minimal and script-friendly

### 7. Add drift/regression checks

- verify critical views/functions still expose expected columns
- verify required fields remain present and typed
- make the checks rerunnable after SQL migrations

### 8. Document the pattern

- how to define a contract
- how to validate query output
- how to extend coverage safely

## Risks

Main risks if this is done badly:

- scope creep into ORM replacement
- renaming stable SQL columns
- applying the pattern to n8n workflow JSON too early
- creating too much ceremony for low-value queries

## Safety Rules

- keep SQL as the system contract
- add contracts only at code boundaries
- start with shared/high-value queries
- prefer additive validation over rewrites
- do not change query semantics just to fit a typing scheme

## Recommended First Slice

If this work is started later, the safest first slice is:

1. define the contract format
2. add contracts for `resolve_best_contact_row(...)`
3. add contracts for `vw_signup_batch_items`
4. add contracts for `global_settings`
5. add one rerunnable drift check

That gives useful safety without forcing broad refactoring.
