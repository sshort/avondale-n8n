# Metabase Report PDF Workflow Spec

## Goal

Provide an operator-facing HTML form behind n8n that:

- lists the supported Metabase dashboards
- lists the available tab names for the chosen dashboard
- lets the operator choose `redact` or `anonymise`
- renders the selected tabs to PDF through the existing Playwright exporter
- post-processes the merged PDF in Stirling PDF
- returns the final PDF directly to the browser

## Runtime Shape

The implementation uses three moving parts:

1. `n8n` for the HTML form, request validation, and binary response handling
2. `clubspark-exporter` for Playwright-based Metabase rendering
3. `Stirling PDF` for sanitize and auto-redact post-processing

The exporter now returns one merged PDF, not a zip of per-tab files.

## Workflows

Two new workflow artifacts are part of this implementation:

- `workflows/metabase-report-form.json`
- `workflows/metabase-report-generate.json`

The form workflow serves:

- dashboard selector
- tab checklist
- report mode selector
- optional year and search filters
- optional redaction profile and extra redact terms

The generation workflow:

- validates the submitted form against an allowlist
- calls `POST /metabase-dashboard-pdf` on the local exporter
- sanitizes the result in Stirling for all modes
- applies Stirling auto-redact when the operator chooses `redact`

## Settings-Driven Dashboard Catalog

The form does not scrape live Metabase metadata from n8n.

It reads a non-secret dashboard catalog from `public.global_settings`:

- `metabase_report_dashboards_json`
- `metabase_report_redaction_profiles_json`
- `metabase_base_url`
- `clubspark_exporter_base_url`
- `stirling_base_url`
- `n8n_base_url`

This keeps the workflow importable and lets operators update dashboard/tab metadata without editing workflow JSON.

The dashboard catalog can also carry PDF-export overrides. Current supported override:

- `snapshotDashcards`
  - array of selector objects such as `{ "dashcardKey": 1499 }` or `{ "cardKey": 1626 }`
  - matching dashcards are hidden in the browser render and appended back as standalone image pages in the final PDF
  - use this for charts that Chromium otherwise splits across a page break

## Modes

### `redact`

- render the selected live dashboard tabs
- sanitize the PDF
- apply Stirling `auto-redact` using the selected profile plus any extra terms entered in the form

### `anonymise`

- if the dashboard catalog defines `anonymisedDashboardId`, render that dashboard instead
- sanitize the PDF
- do not rely on PDF-only masking as a substitute for a true anonymised source dashboard

If no anonymised dashboard id is configured, the generation workflow fails fast with a clear error.

## Exporter Contract

The Playwright exporter endpoint is:

- `POST /metabase-dashboard-pdf`

Expected JSON payload:

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
    "year": "2026",
    "search": "Steve"
  },
  "snapshotDashcards": [
    { "dashcardKey": 1499 }
  ],
  "pdf": {
    "format": "A4",
    "landscape": false,
    "printBackground": true
  }
}
```

Credential resolution order inside the exporter:

1. `payload.login.username` / `payload.login.password`
2. `METABASE_EMAIL` or `METABASE_USERNAME`
3. `METABASE_PASSWORD`

## Stirling API Usage

The generation workflow uses:

- `GET /api/v1/info/status` for health checks outside the workflow
- `POST /api/v1/security/sanitize-pdf`
- `POST /api/v1/security/auto-redact`

The workflow assumes the current Stirling install accepts `fileInput` multipart uploads and the redaction options already used by the UI:

- `listOfText`
- `useRegex`
- `wholeWordSearch`
- `customPadding`
- `redactColor`
- `convertPDFToImage`

## Supported Inputs

The form currently supports:

- `dashboard_id`
- `report_mode`
- `tabs[]`
- `year`
- `search`
- `output_name`
- `redaction_profile`
- `extra_redaction_terms`

`year` and `search` map to the `Avondale Membership` dashboard filters already in use in Metabase.

## Deployment Notes

- Set `METABASE_BASE_URL` on the `clubspark-exporter` service.
- Set `METABASE_EMAIL` and `METABASE_PASSWORD` on the host before using the workflow.
- Apply `sql/037_metabase_report_pdf_settings.sql` so the dashboard catalog and redaction profiles exist in `global_settings`.
- Import both workflow JSON files into n8n.

## Known Limits

- The allowlisted dashboard tabs are seeded from the repository backup. If dashboard tabs change in Metabase, update `metabase_report_dashboards_json`.
- `anonymise` is only safe when an anonymised dashboard exists. The workflow deliberately refuses to fake anonymisation by pretending redaction is equivalent.
- The tab click logic in Playwright is selector-based and should be validated against the live dashboard after deployment.
