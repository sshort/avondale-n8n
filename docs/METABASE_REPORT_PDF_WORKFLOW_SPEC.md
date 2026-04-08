# Metabase Report PDF Workflow Spec

## Goal

Provide an operator-facing HTML form behind an n8n webhook that:

- lets the operator pick a Metabase dashboard
- lets the operator choose which dashboard tabs to include
- lets the operator choose `redact` or `anonymise`
- renders the selected dashboard tabs to PDF using the existing Playwright container
- post-processes the PDF in Stirling PDF
- returns the final PDF to the browser and optionally stores or emails it

This spec assumes:

- n8n is the orchestration layer
- the existing Playwright service in `clubspark-exporter` is extended instead of replaced
- Metabase is available at `http://192.168.1.138:3000`
- Stirling PDF is available at `http://192.168.1.197:8080`

## Design Summary

Use three building blocks:

1. `n8n` for form rendering, request validation, orchestration, and binary response handling
2. `clubspark-exporter` Playwright service for dashboard login, tab navigation, and per-tab PDF capture
3. `Stirling PDF` for merge, redact, sanitize, compress, and watermark operations

Important distinction:

- `redact` is a PDF-stage workflow
- `anonymise` is a data-stage workflow

`redact` means:

- render the live dashboard as-is
- pass the merged PDF through Stirling redaction

`anonymise` means:

- render a dedicated anonymised dashboard or anonymised dashboard variant
- optionally sanitize or compress with Stirling afterwards

Do not treat PDF-stage text redaction as true anonymisation. It is not reliable enough for stable replacement of names and member identities.

## Workflow Artifacts

Create these new artifacts:

- `docs/METABASE_REPORT_PDF_WORKFLOW_SPEC.md`
- `workflows/metabase-report-form.json`
- `workflows/metabase-report-generate.json`
- `scripts/export-metabase-dashboard-pdf.mjs`

Update these existing artifacts:

- `clubspark-exporter/Dockerfile`
- `clubspark-exporter/README.md`
- `scripts/clubspark-export-server.mjs`
- `docker-compose.yml`
- `docs/SERVICES.md`
- `workflows/README.md`

## Runtime Endpoints

### n8n webhook endpoints

Expose two webhook workflows:

- `GET /webhook/report-form`
- `POST /webhook/report-generate`

### Playwright service endpoints

Extend the existing exporter HTTP server with:

- `GET /health`
- `POST /metabase-dashboard-pdf`

Keep the existing ClubSpark endpoints unchanged.

### Stirling endpoints used

Use these Stirling API capabilities:

- status check: `GET /api/v1/info/status`
- merge
- auto-redact or manual redaction flow
- sanitize metadata
- optional compress

Exact endpoint names should be confirmed against the live Stirling swagger on the deployed instance before wiring the n8n HTTP Request nodes.

## HTML Form Contract

The HTML form should be generated dynamically from live Metabase dashboard metadata.

### Fields

- `dashboard_id`
- `dashboard_name`
- `report_mode`
- `season`
- `date_from`
- `date_to`
- `tabs[]`
- `output_name`
- `email_to`
- `store_copy`

### `report_mode`

Allowed values:

- `redact`
- `anonymise`

### `tabs[]`

Each checkbox should use the Metabase tab id as the submitted value and show the tab name as the visible label.

Example:

```html
<fieldset>
  <legend>Tabs to include</legend>
  <label><input type="checkbox" name="tabs[]" value="tab-overview" checked> Overview</label>
  <label><input type="checkbox" name="tabs[]" value="tab-renewals"> Renewals</label>
  <label><input type="checkbox" name="tabs[]" value="tab-history"> History</label>
</fieldset>
```

### Form rendering rules

- preselect a safe default dashboard
- preselect the most common tabs, for example `Overview`
- require at least one selected tab
- make `report_mode` mandatory
- set `output_name` automatically when blank
- show a warning that `anonymise` uses anonymised source dashboards rather than PDF-only masking

## Dashboard Metadata Source

The form workflow needs a reliable source of dashboard tab metadata.

Preferred order:

1. Metabase API dashboard metadata for the selected dashboard
2. fallback local JSON artifact from `backups/` if live metadata fetch fails

The expected metadata needed by the form is:

- dashboard id
- dashboard name
- tab ids
- tab names
- filter parameter names

Store a small n8n-side mapping for supported dashboards:

```json
{
  "11": {
    "name": "Avondale Membership",
    "publicBasePath": "/dashboard/11-avondale-membership",
    "anonymisedDashboardId": 21
  }
}
```

The anonymised dashboard id is required only for `report_mode=anonymise`.

## n8n Workflow 1: `metabase-report-form`

### Purpose

Render the HTML form.

### Node plan

1. `Webhook`
   - method: `GET`
   - path: `report-form`

2. `Set Supported Dashboards`
   - hardcode or load a small JSON allowlist of supported dashboard ids

3. `HTTP Request - Metabase Dashboard Metadata`
   - fetch selected dashboard metadata
   - authenticate with Metabase service credentials

4. `Code - Build Form Model`
   - flatten dashboard tabs into checkbox rows
   - include default filters and help text

5. `Respond to Webhook`
   - content type: `text/html`
   - return the rendered HTML

### HTML generation notes

- use absolute form action URLs
- keep styling simple
- include hidden fields for dashboard id and dashboard name
- include a summary note:
  - `Redact` renders the live dashboard and redacts the PDF
  - `Anonymise` renders the anonymised dashboard and optionally sanitizes the PDF

## n8n Workflow 2: `metabase-report-generate`

### Purpose

Accept the submitted form, render tab PDFs through Playwright, merge and post-process in Stirling, and return the final file.

### Node plan

1. `Webhook`
   - method: `POST`
   - path: `report-generate`

2. `Code - Validate Input`
   - assert dashboard is in allowlist
   - assert at least one tab was selected
   - normalize single vs array values for `tabs[]`
   - normalize `report_mode`
   - derive output filename

3. `If - Mode Branch`
   - if `report_mode` is `anonymise`, swap the requested dashboard id for the configured anonymised dashboard id

4. `HTTP Request - Playwright Export`
   - call `http://clubspark-exporter:3001/metabase-dashboard-pdf`
   - send JSON payload
   - receive a zip or JSON manifest of per-tab PDFs

5. `Code - Extract Binary Inputs`
   - map per-tab PDF binaries into the format expected by downstream HTTP Request nodes

6. `HTTP Request - Stirling Merge`
   - merge the per-tab PDFs into a single report

7. `If - Post Process`
   - `redact`:
     - run Stirling redaction using a profile
   - `anonymise`:
     - run Stirling sanitize
     - optional compress

8. `If - Store Copy`
   - optional:
     - store to Nextcloud
     - store to filesystem
     - email as attachment

9. `Respond to Webhook`
   - return binary PDF to the browser
   - filename should match `output_name`

## Payload From n8n To Playwright

Call the Playwright service with JSON like this:

```json
{
  "metabaseBaseUrl": "http://192.168.1.138:3000",
  "dashboardId": 11,
  "dashboardName": "Avondale Membership",
  "reportMode": "redact",
  "tabs": [
    { "id": "overview", "name": "Overview" },
    { "id": "history", "name": "History" }
  ],
  "filters": {
    "season": "2026",
    "date_from": "",
    "date_to": ""
  },
  "login": {
    "username": "{{METABASE_SERVICE_USERNAME}}",
    "password": "{{METABASE_SERVICE_PASSWORD}}"
  },
  "pdf": {
    "format": "A4",
    "landscape": false,
    "printBackground": true,
    "margin": {
      "top": "10mm",
      "right": "10mm",
      "bottom": "12mm",
      "left": "10mm"
    }
  }
}
```

## Playwright Service Changes

### Server update

Extend `scripts/clubspark-export-server.mjs` with a new route:

```js
['/metabase-dashboard-pdf', {
  scriptPath: path.join(scriptDir, 'export-metabase-dashboard-pdf.mjs'),
  contentType: 'application/zip',
}]
```

This route should:

- require bearer auth via the existing `EXPORTER_TOKEN`
- accept a JSON payload
- write output to a temp directory
- return either:
  - a zip file containing one PDF per selected tab plus a manifest JSON
  - or a single merged PDF if you decide to merge in the Playwright step

Prefer returning a zip of per-tab PDFs and leave merge/post-process responsibility in n8n.

### Dockerfile update

Update `clubspark-exporter/Dockerfile` to copy the new script:

```dockerfile
COPY scripts/export-metabase-dashboard-pdf.mjs ./
```

No new npm dependency should be needed if the script stays on Playwright plus Node built-ins.

### New script: `scripts/export-metabase-dashboard-pdf.mjs`

Responsibilities:

1. launch Chromium using the same runtime flags as the ClubSpark scripts
2. log into Metabase with service account credentials
3. open the dashboard
4. apply requested filters
5. iterate selected tabs
6. click each tab
7. wait for charts to finish rendering
8. print the current tab to a PDF file
9. write all outputs to a temp directory
10. emit a zip file path to stdout or write directly to the target output path

### Browser automation details

The script should:

- wait for the dashboard shell to render
- use the visible tab name to click the tab
- verify that the selected tab matches the requested tab id or label
- wait for loading spinners to disappear before printing
- use `page.pdf()` for each tab
- use a dedicated browser context per request

### Render completion heuristics

Before printing:

- wait for `networkidle`
- wait for known Metabase loading indicators to disappear
- wait an additional short settle period, for example `1500ms`

If a tab fails to render after retries:

- include that in the manifest
- fail the whole request unless the payload explicitly allows partial output

## PDF Processing In Stirling

### Redact branch

1. `merge`
2. `auto-redact` or equivalent API using a selected profile
3. `sanitize`
4. optional `compress`

Redaction profiles should be maintained in n8n, for example:

- `membership`
- `finance`
- `safeguarding`

Example `membership` profile contents:

- member email addresses
- phone number patterns
- postcode patterns
- known address labels
- optional specific person names

### Anonymise branch

1. swap to an anonymised dashboard id before rendering
2. `merge`
3. `sanitize`
4. optional `compress`
5. optional watermark such as `Anonymised`

Do not rely on Stirling to transform named individuals into stable aliases. That belongs in the source dashboard.

## Recommended Dashboard Strategy

Maintain dashboard pairs:

- live dashboard
- anonymised dashboard

Example:

- live: `Avondale Membership`
- anonymised: `Avondale Membership - Anonymised`

The anonymised dashboard should:

- remove direct identifiers
- replace person detail cards where necessary
- use grouped or aggregated cards where possible

This keeps `anonymise` deterministic and auditable.

## Authentication And Secrets

### n8n

Store these in credentials or environment variables:

- `METABASE_SERVICE_USERNAME`
- `METABASE_SERVICE_PASSWORD`
- `PLAYWRIGHT_EXPORTER_TOKEN`
- `STIRLING_API_KEY`

### Playwright container

Keep the existing `EXPORTER_TOKEN` model.

Add environment support for:

- `METABASE_USERNAME`
- `METABASE_PASSWORD`

Or pass login credentials in the request body from n8n. Prefer n8n-managed credentials and pass them per request so the exporter remains a generic rendering service.

### Stirling

Use API key auth from n8n and verify the exact header shape against the live container.

## n8n Response Behavior

Default response:

- return the final merged PDF as a downloadable file

Optional behavior:

- email a copy if `email_to` is present
- store a copy in Nextcloud or a filesystem archive if `store_copy` is checked

Suggested filename format:

`<dashboard-name>-<mode>-<yyyymmdd>-<hhmm>.pdf`

## Audit And Safety

Log these fields in n8n execution data or a dedicated table:

- requester IP
- dashboard id
- selected tabs
- mode
- output filename
- whether a stored copy was created
- timestamp

Guardrails:

- only allow dashboards from an explicit allowlist
- only allow anonymise if an anonymised dashboard mapping exists
- reject requests with zero tabs
- use request timeouts on Playwright and Stirling calls

## Proposed Workflow JSON Names

- `metabase-report-form.json`
- `metabase-report-generate.json`

## Proposed Exporter Endpoint Contract

### `POST /metabase-dashboard-pdf`

#### Request body

```json
{
  "metabaseBaseUrl": "http://192.168.1.138:3000",
  "dashboardId": 11,
  "dashboardName": "Avondale Membership",
  "reportMode": "redact",
  "tabs": [
    { "id": "overview", "name": "Overview" },
    { "id": "history", "name": "History" }
  ],
  "filters": {
    "season": "2026"
  },
  "login": {
    "username": "service-account",
    "password": "secret"
  }
}
```

#### Response

Recommended:

- content type: `application/zip`
- archive contents:
  - `manifest.json`
  - `01-overview.pdf`
  - `02-history.pdf`

Manifest example:

```json
{
  "dashboardId": 11,
  "dashboardName": "Avondale Membership",
  "tabs": [
    {
      "id": "overview",
      "name": "Overview",
      "filename": "01-overview.pdf",
      "status": "ok"
    },
    {
      "id": "history",
      "name": "History",
      "filename": "02-history.pdf",
      "status": "ok"
    }
  ]
}
```

## Implementation Sequence

1. Add `export-metabase-dashboard-pdf.mjs`
2. Extend `clubspark-export-server.mjs` with `/metabase-dashboard-pdf`
3. Update Dockerfile and rebuild the exporter image
4. Create `metabase-report-form` workflow
5. Create `metabase-report-generate` workflow
6. Create the dashboard allowlist and anonymised dashboard map
7. Add Stirling API key to n8n credentials
8. Test:
   - one-tab live redaction
   - multi-tab live redaction
   - multi-tab anonymised output
9. Add operator docs and service inventory updates

## Acceptance Criteria

- operator can open a webhook-served HTML form
- form shows live dashboard tab names as checkbox options
- user can choose one or more tabs
- `redact` mode returns a merged PDF for the selected tabs
- `anonymise` mode uses the configured anonymised dashboard and returns a merged PDF
- Playwright rendering uses the existing exporter container, not a new service
- Stirling handles merge and post-processing
- workflow rejects unsupported dashboard ids and empty tab selection
- generated PDFs are downloadable from the webhook response

## Open Questions

1. Which exact Metabase dashboard ids should be allowed initially
2. Whether anonymised dashboard variants already exist for the first dashboard
3. Whether the final PDF should also be archived automatically in Nextcloud or filesystem storage
