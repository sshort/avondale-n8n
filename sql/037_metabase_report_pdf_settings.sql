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
    'http://192.168.1.204:8080',
    'Base URL for the Stirling PDF instance used for sanitize and redaction operations'
  ),
  (
    'metabase_report_dashboards_json',
    $$[
      {
        "id": 11,
        "name": "Avondale Membership",
        "slug": "avondale-membership",
        "defaultTabs": [135, 136, 140, 133, 143, 144, 145, 138],
        "tabs": [
          { "id": 134, "name": "Search" },
          { "id": 133, "name": "Memberships" },
          { "id": 143, "name": "Membership History" },
          { "id": 144, "name": "Category Comparison" },
          { "id": 145, "name": "Map" },
          { "id": 135, "name": "Signup Statistics" },
          { "id": 136, "name": "Signup Batches" },
          { "id": 137, "name": "Batch Executions" },
          { "id": 138, "name": "Keys" },
          { "id": 139, "name": "Database" },
          { "id": 140, "name": "Refunds" },
          { "id": 141, "name": "History" },
          { "id": 142, "name": "Webhooks" }
        ],
        "filterMap": {
          "year": "year",
          "search": "search"
        },
        "snapshotDashcards": [
          { "dashcardKey": 1499, "placement": "append" },
          {
            "dashcardKey": 1380,
            "placement": "inline",
            "waitForText": [
              "How many people currently hold keys?",
              "How many key-related cases are we dealing with?"
            ]
          },
          {
            "title": "Summary of Keys",
            "dashcardKey": 1557,
            "placement": "inline",
            "waitForText": [
              "Question",
              "Count"
            ]
          }
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
        "columnHeaders": [
          "Member",
          "Payer",
          "British Tennis Number",
          "Venue ID",
          "Email address",
          "Name",
          "Member Name",
          "Payer Name",
          "Refund For",
          "Reason",
          "Address 1",
          "Address 2"
        ],
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
