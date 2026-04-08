BEGIN;

INSERT INTO public.global_settings (key, value, description)
VALUES
  (
    'metabase_base_url',
    'http://192.168.1.138:3000',
    'Base URL for the Metabase instance used by dashboard PDF exports'
  ),
  (
    'stirling_base_url',
    'http://192.168.1.197:8080',
    'Base URL for the Stirling PDF instance used for sanitize and redaction operations'
  ),
  (
    'metabase_report_dashboards_json',
    $$[
      {
        "id": 11,
        "name": "Avondale Membership",
        "slug": "avondale-membership",
        "defaultTabs": [112, 114],
        "tabs": [
          { "id": 112, "name": "Memberships" },
          { "id": 113, "name": "Search" },
          { "id": 114, "name": "Signup Statistics" },
          { "id": 115, "name": "Signup Batches" },
          { "id": 116, "name": "Batch Executions" },
          { "id": 117, "name": "Keys" },
          { "id": 118, "name": "Database" },
          { "id": 119, "name": "Refunds" }
        ],
        "filterMap": {
          "year": "year",
          "search": "search"
        },
        "snapshotDashcards": [
          { "dashcardKey": 1499 }
        ],
        "anonymisedDashboardId": null
      }
    ]$$,
    'Allowlisted Metabase dashboards and tab metadata exposed by the report form workflow'
  ),
  (
    'metabase_report_redaction_profiles_json',
    $$[
      {
        "id": "member-pii",
        "name": "Member PII",
        "useRegex": true,
        "wholeWordSearch": false,
        "convertPdfToImage": true,
        "customPadding": 2,
        "redactColor": "#000000",
        "terms": [
          "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\\\.[A-Z]{2,}",
          "\\\\b(?:[A-Z]{1,2}\\\\d[A-Z\\\\d]? ?\\\\d[A-Z]{2})\\\\b",
          "\\\\b\\\\d{8,10}\\\\b"
        ]
      }
    ]$$,
    'Redaction profiles offered by the Metabase report PDF workflow'
  )
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

COMMIT;
