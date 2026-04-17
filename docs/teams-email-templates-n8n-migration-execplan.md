# Migrate Appsmith Teams Management And Email Templates To n8n HTML Apps

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document is maintained in accordance with [/mnt/c/dev/PLAN.md](/mnt/c/dev/PLAN.md).

## Purpose / Big Picture

After this work completes, the operational screens that currently live in Appsmith for team management, team players, nicknames, overrides, and email template editing will exist as native n8n HTML apps built in the same style as the new case-tracking flows. An operator will be able to open n8n webhook pages, browse and edit teams and their players, maintain team nicknames and overrides, and create, edit, or delete email templates using DaisyUI-based pages instead of the older Appsmith pages. The visible proof will be that the new n8n webhook pages render the same core data and complete the same CRUD actions against `public.teams`, `public.team_players`, `public.team_nicknames`, `public.team_name_overrides`, and `public.email_templates`.

## Progress

- [x] (2026-04-16 09:56Z) Inspected the existing n8n case-tracking app/action workflows and confirmed the renderer pattern is `Webhook GET -> settings/data load -> Code HTML builder -> Respond`, with POST actions handled by a companion workflow.
- [x] (2026-04-16 10:02Z) Inspected the Appsmith `TeamManagement`, `TeamPlayers`, and `EmailTemplates` page exports and their query files to capture the current CRUD surface and navigation.
- [x] (2026-04-16 10:11Z) Confirmed the underlying schema for `public.teams`, `public.team_players`, and `public.email_templates`, and confirmed there is no existing n8n teams UI to extend.
- [x] (2026-04-16 10:19Z) Added `Nicknames` and `Overrides` to scope after confirming they are thin Appsmith pages over `public.team_nicknames` and `public.team_name_overrides`.
- [ ] Draft the new workflow exports for the teams app/actions and email template app/actions.
- [ ] Validate the workflow JSON artifacts and, if possible in this session, publish them to the live n8n instance.

## Surprises & Discoveries

- Observation: The Appsmith page JSON files are mostly shells. The real behavior is in query files and per-widget action bindings.
  Evidence: `TeamManagement.json` and `TeamPlayers.json` only define layout-on-load actions, while CRUD behavior appears in `pages/.../queries/*.txt` and widget `onClick` bindings.

- Observation: The case-tracking app already contains a working rich HTML editor pattern based on TinyMCE, raw HTML, and plain-text modes.
  Evidence: `workflows/case-tracking-app.json` view `signatures` includes TinyMCE CDN loading, mode switching, HTML/text textareas, and a `save_signature` POST action.

- Observation: The Appsmith nickname and override pages are effectively just table views over two small tables, but they are misnamed in their exported page shells.
  Evidence: `pages/Nicknames/Nicknames.json` reports page name `Overrides` and loads `GetOverrides`, while `pages/Overrides/Overrides.json` reports page name `Nicknames` and loads `GetNicknames`.

- Observation: There is no checked-in `.agent/PLANS.md` in `/mnt/c/dev`, but prior work keeps ExecPlans under the repo `docs/` folder and references `/mnt/c/dev/PLAN.md`.
  Evidence: `docs/uninbox-proxmox-execplan.md` exists and explicitly cites `/mnt/c/dev/PLAN.md`.

## Decision Log

- Decision: Build two new n8n app surfaces instead of merging this into the existing case-tracking app.
  Rationale: Teams management and email template editing are separate operational domains with different data models and action sets. Separate workflows keep the routes, HTML builders, and SQL simpler and avoid turning the case-tracking app into a catch-all admin shell.
  Date/Author: 2026-04-16 / Codex

- Decision: Collapse Appsmith `TeamManagement` and `TeamPlayers` into a single n8n teams app with `teams` and `players` views.
  Rationale: Appsmith used separate pages largely because of its page model. In n8n, a single GET workflow with a `view` query parameter is simpler, keeps navigation local, and matches the case-tracking pattern already in use.
  Date/Author: 2026-04-16 / Codex

- Decision: Extend the teams app to also own `nicknames` and `overrides` views.
  Rationale: The user clarified that those pages are part of the migration target. They are small enough to fit naturally into the same admin app, and keeping them in the same surface avoids broken or Appsmith-only navigation from the teams page.
  Date/Author: 2026-04-16 / Codex

- Decision: Reuse the case-tracking signature editor pattern as the base for the email template editor rather than reproducing Appsmith modal behavior.
  Rationale: The important user behavior is editing HTML and text safely, not preserving the exact Appsmith modal interaction. The n8n pattern already has a tested inline editor model and is easier to maintain than modal-heavy HTML in a large string.
  Date/Author: 2026-04-16 / Codex

## Outcomes & Retrospective

This plan is in progress. The repository research is complete and the migration target is clear: one n8n teams app plus one n8n email template editor app, each with a companion POST actions workflow. The remaining work is implementation and validation.

## Context and Orientation

The main target repository is `/mnt/c/dev/avondale-n8n`. Workflow export artifacts live in `/mnt/c/dev/avondale-n8n/workflows`. These JSON files are import-ready n8n workflow definitions. SQL schema files live in `/mnt/c/dev/avondale-n8n/sql`.

The source system being migrated is the Appsmith repository at `/mnt/c/dev/avondale-appsmith`. The relevant Appsmith pages are:

- `/mnt/c/dev/avondale-appsmith/pages/TeamManagement`
- `/mnt/c/dev/avondale-appsmith/pages/TeamPlayers`
- `/mnt/c/dev/avondale-appsmith/pages/EmailTemplates`

The current team schema is defined in `/mnt/c/dev/avondale-n8n/sql/026_team_management_schema.sql`. It creates:

- `public.teams`: the top-level team records with `section`, `team_name`, `season`, and `sort_order`
- `public.team_players`: the player rows linked to a team by `team_id`, storing `source_name`, `is_captain`, and `sort_order`
- `public.team_name_overrides`: a separate override table already used elsewhere

There is also a live `public.team_nicknames` table in the database with columns `id`, `source`, `target`, `notes`, `created_at`, and `updated_at`. The Appsmith `Nicknames` page reads directly from this table even though there is no checked-in schema file for it in the n8n repository.

The current email template table is defined in `/mnt/c/dev/avondale-n8n/sql/004_email_templates.sql`. It stores `template_key`, `template_name`, `template_type`, `subject_template`, `text_template`, `html_template`, and `is_active`. A `template_type` of `0` means a normal email template, `1` means a header template, and `2` means a signature template.

The existing n8n reference implementation is:

- `/mnt/c/dev/avondale-n8n/workflows/case-tracking-app.json`
- `/mnt/c/dev/avondale-n8n/workflows/case-tracking-actions.json`

Those workflows establish the pattern to follow: a GET webhook renders a DaisyUI page built in a Code node, and a POST webhook validates form input, executes SQL through a Postgres node, then responds with a redirect page containing a success or error flash message.

## Plan of Work

Create a new workflow export `/mnt/c/dev/avondale-n8n/workflows/team-management-app.json`. This workflow will follow the case-tracking app structure and serve a GET webhook such as `team-management`. It will load global settings only as needed for base URL derivation, resolve query parameters such as `view`, `team_id`, `season`, and `message`, build a SQL query for the `teams`, `players`, `nicknames`, or `overrides` view, load that data through the shared Postgres credential, and render an HTML page with DaisyUI.

In the `teams` view, the page will show the existing teams table with inline actions to edit, delete, and navigate to `players` for the selected team. The add and edit forms will be normal HTML forms on the page rather than modal dialogs. The page will also expose links out to any existing team-related routes that are already present in n8n, such as team mailout generation, rather than copying that functionality into this workflow.

In the `players` view, the page will show the selected team header, the list of players in `public.team_players`, and a form to add a player. The add form will use the same underlying lookup logic as the Appsmith `LookupPlayers` query by searching current rows in `raw_members` and `raw_contacts`. Edit and delete actions for existing players will be done with form posts back to the actions workflow.

In the `nicknames` view, the page will list and edit rows from `public.team_nicknames`. In the `overrides` view, the page will list and edit rows from `public.team_name_overrides`. These are small CRUD screens, so they can be inline forms on the same page rather than modal dialogs.

Create a companion workflow export `/mnt/c/dev/avondale-n8n/workflows/team-management-actions.json`. This workflow will accept POSTs from the teams app and implement the following actions: `create_team`, `update_team`, `delete_team`, `create_player`, `update_player`, `delete_player`, `create_nickname`, `update_nickname`, `delete_nickname`, `create_override`, `update_override`, and `delete_override`. It will validate required fields, build SQL in a Code node, execute that SQL via Postgres, and then redirect back to the relevant GET view with either `message=` or `error=` in the query string.

Create a new workflow export `/mnt/c/dev/avondale-n8n/workflows/email-template-editor-app.json`. This workflow will render a GET page showing the list of `public.email_templates`, filters for template type and active state, and an editor panel for the selected or newly created template. The editor panel will reuse the case-tracking signature editor approach: TinyMCE-backed rich editing, raw HTML editing, plain-text editing, and a live preview area. Unlike the case-tracking signatures page, this editor must expose all of the fields needed by the Appsmith editor: `template_key`, `template_name`, `template_type`, `subject_template`, `text_template`, `html_template`, and `is_active`.

Create a companion workflow export `/mnt/c/dev/avondale-n8n/workflows/email-template-editor-actions.json`. This workflow will implement `create_template`, `update_template`, and `delete_template`. It will validate `template_key` and `template_name`, write the correct row in `public.email_templates`, and redirect back to the selected template in the GET editor.

Keep the workflows repository-native. That means the exports should use the same `Postgres account` credential id/name as the existing local workflows, match the same `responseNode` webhook pattern, and include no-cache headers on HTML responses.

## Concrete Steps

Work from `/mnt/c/dev`.

Read the current reference workflows and Appsmith sources:

    jq -r '.nodes[] | [.name,.type] | @tsv' /mnt/c/dev/avondale-n8n/workflows/case-tracking-app.json
    sed -n '1,220p' /mnt/c/dev/avondale-appsmith/pages/TeamManagement/queries/GetTeams/GetTeams.txt
    sed -n '1,220p' /mnt/c/dev/avondale-appsmith/pages/TeamPlayers/queries/LookupPlayers/LookupPlayers.txt
    sed -n '1,220p' /mnt/c/dev/avondale-appsmith/pages/EmailTemplates/queries/SaveTemplate/SaveTemplate.txt

Implement the new workflow export files under `/mnt/c/dev/avondale-n8n/workflows` and keep this plan updated as each file is added. Validate the exports locally with `jq empty`:

    jq empty /mnt/c/dev/avondale-n8n/workflows/team-management-app.json
    jq empty /mnt/c/dev/avondale-n8n/workflows/team-management-actions.json
    jq empty /mnt/c/dev/avondale-n8n/workflows/email-template-editor-app.json
    jq empty /mnt/c/dev/avondale-n8n/workflows/email-template-editor-actions.json

If live publication is possible in this session, publish the workflow JSON through the existing n8n update path and then verify the GET webhooks return HTML:

    curl -I -sS https://n8n.proxy.shortcentral.com/webhook/team-management
    curl -I -sS https://n8n.proxy.shortcentral.com/webhook/email-template-editor

The expected successful result is an HTTP `200` with `Content-Type: text/html; charset=utf-8`.

## Validation and Acceptance

The migration is complete when a human can do all of the following through the new n8n pages without using Appsmith:

1. Open the teams page, see current team rows from `public.teams`, add a new team, edit it, and delete it.
2. Open the players view for a specific team, see rows from `public.team_players`, add a player from the current contact/member lookup, toggle captain state, edit sort order, and delete a player.
3. Open the nicknames view, browse rows from `public.team_nicknames`, create one, edit it, and delete it.
4. Open the overrides view, browse rows from `public.team_name_overrides`, create one, edit it, and delete it.
5. Open the email template editor, browse template rows from `public.email_templates`, create a new template, edit subject/text/HTML/type/active state, and delete a template.
6. Observe that each successful action redirects back to the relevant page with a visible success message, and each validation failure redirects back with an error message.

Repository acceptance is `jq empty` passing for all new workflow JSON exports. Live acceptance, if deployment is done, is the GET pages returning HTML and the POST actions mutating the correct database tables.

## Idempotence and Recovery

The workflow export files are additive. Re-running `jq empty` is safe. Importing or publishing a later version of the same workflow should replace the prior live definition rather than create schema drift, provided the same workflow identity is used during deployment.

The risky operations are deletes in the actions workflows. For teams, deleting a `public.teams` row will also delete linked `public.team_players` rows because the schema uses `ON DELETE CASCADE`. The delete UI should therefore present that consequence clearly in the button text or surrounding copy. If a mistaken delete occurs, recovery requires re-inserting the deleted rows from backups or reconstructed data; there is no soft-delete column in the current schema.

## Artifacts and Notes

Important source behavior captured during research:

    TeamManagement GetTeams:
    SELECT id, section, team_name, season, sort_order, created_at, updated_at
    FROM public.teams
    ORDER BY sort_order ASC, team_name ASC;

    TeamPlayers LookupPlayers:
    searches current rows from raw_members and raw_contacts
    and returns label, value, player_name, email_address, source_tables

    EmailTemplates SaveTemplate:
    updates template_key, template_name, template_type, subject_template,
    text_template, html_template, is_active, updated_at

Reference implementation pattern:

    case-tracking-app.json:
    Webhook GET -> Postgres settings -> Code request parser -> Code SQL builder
    -> Postgres data load -> Code HTML builder -> RespondToWebhook

    case-tracking-actions.json:
    Webhook POST -> Postgres settings -> Code validator -> If error
    -> Code SQL builder -> Postgres execute -> Code redirect HTML -> RespondToWebhook

## Interfaces and Dependencies

The new workflows should continue using the existing n8n Postgres credential:

    credentials.postgres.id = "PjTUDAMk0dZ7g1iO"
    credentials.postgres.name = "Postgres account"

The new routes should be stable and human-readable. Use:

- `team-management` for the GET teams app
- `team-management-actions` for the POST teams actions
- `email-template-editor` for the GET email template app
- `email-template-editor-actions` for the POST email template actions

The teams app depends on:

- `public.teams`
- `public.team_players`
- `public.team_nicknames`
- `public.team_name_overrides`
- `public.raw_members`
- `public.raw_contacts`

The email template editor depends on:

- `public.email_templates`

The HTML pages depend on the same browser-side assets already accepted in the case-tracking app:

- DaisyUI via `https://cdn.jsdelivr.net/npm/daisyui@5`
- Tailwind browser bundle via `https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4`
- TinyMCE via `https://cdn.jsdelivr.net/npm/tinymce@7/tinymce.min.js` for the rich template editor

Revision note: created this plan after inspecting the current Appsmith pages, the case-tracking n8n workflows, and the relevant schema files so the implementation can proceed from checked-in repository context alone.
Revision note: updated the plan after the scope expanded to include the Appsmith nickname and override pages, and after confirming `public.team_nicknames` exists live even though its schema file is not checked into the n8n repository.
