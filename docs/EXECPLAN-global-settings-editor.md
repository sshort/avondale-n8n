# Global Settings Editor

This ExecPlan is a living document. `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Add a type-aware web UI for viewing and editing the `public.global_settings` table, served as an n8n webhook app.

Before this change, settings can only be edited by running SQL directly. After this change, an operator can open `/webhook/global-settings` in a browser, see every setting with its type and current value, click Edit, change the value in a type-appropriate input, and save — with validation enforced before the write.

The visible proof is:
- a settings list page showing all rows with key, type badge, value preview, and description
- an edit page that renders the correct input for each type (text input, number input, URL input, JSON textarea, or template-key dropdown)
- a type-switcher that lets the operator change a setting's stored type without losing the workflow
- validation that prevents saving a non-numeric value for a `number` setting, an invalid URL for a `url` setting, or malformed JSON for a `json` setting
- a `type` column in `public.global_settings` so the type is stored durably alongside the value

## Progress

- [x] Write `sql/046_global_settings_type.sql` and apply it to homedb
- [x] Write `workflows/global-settings-app.json`
- [x] Write `workflows/global-settings-actions.json`
- [x] Sync both workflows to live n8n (app: `PAOrkro0ePJ4Bekj`, actions: `4Rf27cRk7JHG0sjq`)
- [ ] Verify list view and edit/save round-trip for each type
- [ ] Update this ExecPlan with outcomes

## Surprises & Discoveries

_To be filled in during implementation._

## Decision Log

- Decision: model this as an n8n webhook app (like email-template-editor) rather than a Metabase card.
  Rationale: the Metabase card 1610 is read-only; a webhook app can serve an interactive editor with type-aware inputs and server-side validation in the same way that the email template editor works today.
  Date/Author: 2026-04-28 / Claude

- Decision: support five types — `text`, `number`, `url`, `json`, `email_template_key`.
  Rationale: covers every current and anticipated setting. `email_template_key` renders a dropdown loaded from `public.email_templates` so the operator cannot mistype a key.
  Date/Author: 2026-04-28 / Claude

- Decision: type switching navigates via a query-string parameter (`?key=xxx&type=yyy`) rather than submitting a POST.
  Rationale: keeps the type switch idempotent and reversible without touching the database until the operator explicitly clicks Save.
  Date/Author: 2026-04-28 / Claude

- Decision: use `ADD COLUMN IF NOT EXISTS` with a `CHECK` constraint and backfill existing rows in the same migration.
  Rationale: the migration must be safe to rerun and must not leave any existing rows with a NULL or default type when a more specific type is known.
  Date/Author: 2026-04-28 / Claude

## Outcomes & Retrospective

_To be filled in after implementation._

## Context and Orientation

`public.global_settings` is defined in `sql/009_global_settings.sql`. Its current columns are `key`, `value`, `description`, `created_at`, `updated_at`. There is no `type` column.

Current settings and their intended types:

| key | type |
|-----|------|
| clubspark_exporter_base_url | url |
| gotenberg_base_url | url |
| n8n_base_url | url |
| metabase_base_url | url |
| stirling_base_url | url |
| metabase_report_dashboards_json | json |
| metabase_report_redaction_profiles_json | json |
| no_address_email_template_key | email_template_key |
| gmail_test_email_template_key | email_template_key |
| keys_stock_baseline_completed_batch_id | number |
| keys_stock_opening | number |
| clubspark_venue_slug | text |
| email_sender_name | text |
| email_reply_to | text |
| email_test_recipient | text |
| email_delivery_mode | text |
| signup_imap_mailbox | text |

The email-template-editor pattern (`workflows/email-template-editor-app.json` + `workflows/email-template-editor-actions.json`) is the direct implementation model. The global-settings editor uses the same node pipeline and HTML rendering approach.

## Plan of Work

### 1. Schema — add `type` column

Create `sql/046_global_settings_type.sql`. It must:

- `ALTER TABLE public.global_settings ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'text' CHECK (type IN ('text','number','url','json','email_template_key'))`
- Backfill URL settings: `UPDATE … SET type = 'url' WHERE key IN (…)`
- Backfill JSON settings: `UPDATE … SET type = 'json' WHERE key IN (…)`
- Backfill template-key settings: `UPDATE … SET type = 'email_template_key' WHERE key IN (…)`
- Be safe to rerun (use `IF NOT EXISTS`, update only where `type = 'text'`)

### 2. App workflow — `workflows/global-settings-app.json`

Node pipeline (same shape as email-template-editor-app):

```
Webhook (GET) → Load App Settings → Resolve App Request
  → Build Page SQL → Load Page Data → Build Page HTML → Respond App
```

**Resolve App Request** parses `?key`, `?type` (type override for the edit form), `?message`, `?error` from the query string and derives the n8n base URL from forwarded headers.

**Build Page SQL** generates:
- In list mode: `SELECT json_agg(to_jsonb(s) ORDER BY s.key) AS settings FROM public.global_settings s`
- In edit mode: fetches the specific setting row AND loads active email templates for the template-key dropdown

**Build Page HTML** renders:
- List view: table with key, type badge, value preview, description, Edit button
- Edit view: card with the setting info, type-switcher select (navigates via JS to `?key=&type=`), type-appropriate value input, Save and Cancel buttons

Type-to-input mapping:
- `text` → `<input type="text">` or `<textarea>` for long/multiline values
- `number` → `<input type="number" step="any">`
- `url` → `<input type="url">`
- `json` → `<textarea class="font-mono" rows="16">` with pretty-printed value
- `email_template_key` → `<select>` from active email templates

### 3. Actions workflow — `workflows/global-settings-actions.json`

Node pipeline (same shape as email-template-editor-actions):

```
Webhook (POST) → Load Action Settings → Resolve Action Request
  → Check Request Error
      true  → Build Error HTML → Respond Error
      false → Build Action SQL → Execute Action SQL → Build Success HTML → Respond Success
```

**Resolve Action Request** handles `action = update_setting`. It:
- Reads `key`, `value`, `type` from the POST body
- Validates `type` is one of the five valid values
- Validates `value` according to type:
  - `number`: `isFinite(Number(value.trim()))`
  - `url`: `new URL(value.trim())` does not throw
  - `json`: `JSON.parse(value.trim())` does not throw
  - `email_template_key`: value is non-empty
  - `text`: always valid
- Sets `error_message` if validation fails

**Build Action SQL** produces:
```sql
UPDATE public.global_settings SET value = '…', type = '…', updated_at = now() WHERE key = '…' RETURNING key
```

**Build Success HTML** redirects to `/webhook/global-settings?message=…`

**Build Error HTML** redirects to `return_url?error=…`

## Concrete Steps

From the repository root `/mnt/c/dev/avondale-n8n`:

1. Write and apply `sql/046_global_settings_type.sql`
2. Verify: `SELECT key, type FROM public.global_settings ORDER BY key;` — all rows must have a non-`text` type where applicable
3. Write `workflows/global-settings-app.json` and validate with `jq empty`
4. Write `workflows/global-settings-actions.json` and validate with `jq empty`
5. Sync both to live n8n (import via API or MCP)
6. Open `/webhook/global-settings` and verify the list renders
7. Click Edit on a URL setting, change the value to an invalid URL, click Save — expect error redirect
8. Save a valid value — expect success redirect and the list page shows the updated value

## Validation and Acceptance

Complete when all of the following are true:

1. `SELECT key, type FROM public.global_settings ORDER BY key` shows correct types for all rows (no `text` default where url/json/email_template_key apply)
2. `GET /webhook/global-settings` returns a 200 HTML page listing all settings
3. `GET /webhook/global-settings?key=n8n_base_url` returns a 200 HTML page with a URL input pre-filled
4. Submitting an invalid URL shows an error message without writing to the database
5. Submitting a valid URL updates the row and redirects to the list with a success message
6. `GET /webhook/global-settings?key=metabase_report_dashboards_json` shows a JSON textarea with pretty-printed value
7. Submitting malformed JSON shows an error without writing to the database
8. `GET /webhook/global-settings?key=no_address_email_template_key` shows a dropdown of active email templates

## Artifacts

- `sql/046_global_settings_type.sql`
- `workflows/global-settings-app.json`
- `workflows/global-settings-actions.json`
