BEGIN;

-- Add setting_type column to global_settings.
-- Safe to rerun: ADD COLUMN IF NOT EXISTS, backfills only rows still at the text default.

ALTER TABLE public.global_settings
  ADD COLUMN IF NOT EXISTS setting_type text NOT NULL DEFAULT 'text'
    CHECK (setting_type IN ('text', 'number', 'url', 'json', 'email_template_key'));

-- Backfill URL settings (only where setting_type is still the default)
UPDATE public.global_settings
SET setting_type = 'url'
WHERE setting_type = 'text'
  AND key IN (
    'clubspark_exporter_base_url',
    'gotenberg_base_url',
    'n8n_base_url',
    'metabase_base_url',
    'stirling_base_url'
  );

-- Backfill JSON settings
UPDATE public.global_settings
SET setting_type = 'json'
WHERE setting_type = 'text'
  AND key IN (
    'metabase_report_dashboards_json',
    'metabase_report_redaction_profiles_json'
  );

-- Backfill email template key settings
UPDATE public.global_settings
SET setting_type = 'email_template_key'
WHERE setting_type = 'text'
  AND key IN (
    'no_address_email_template_key',
    'gmail_test_email_template_key'
  );

-- Backfill number settings
UPDATE public.global_settings
SET setting_type = 'number'
WHERE setting_type = 'text'
  AND key IN (
    'keys_stock_baseline_completed_batch_id',
    'keys_stock_opening'
  );

COMMIT;
