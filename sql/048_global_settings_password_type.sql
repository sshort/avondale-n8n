BEGIN;

-- Extend setting_type to support 'password'.
-- Safe to rerun: constraint replace is idempotent, backfills only rows still at 'text'.

ALTER TABLE public.global_settings
  DROP CONSTRAINT IF EXISTS global_settings_setting_type_check;

ALTER TABLE public.global_settings
  ADD CONSTRAINT global_settings_setting_type_check
    CHECK (setting_type IN ('text', 'number', 'url', 'json', 'email_template_key', 'email', 'password'));

-- Backfill password settings
UPDATE public.global_settings
SET setting_type = 'password'
WHERE setting_type = 'text'
  AND key IN (
    'clubspark_password',
    'lta_password'
  );

COMMIT;
