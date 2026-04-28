BEGIN;

-- Extend setting_type to support 'email'.
-- Safe to rerun: constraint replace is idempotent, backfills only rows still at 'text'.

ALTER TABLE public.global_settings
  DROP CONSTRAINT IF EXISTS global_settings_setting_type_check;

ALTER TABLE public.global_settings
  ADD CONSTRAINT global_settings_setting_type_check
    CHECK (setting_type IN ('text', 'number', 'url', 'json', 'email_template_key', 'email'));

-- Backfill email address settings
UPDATE public.global_settings
SET setting_type = 'email'
WHERE setting_type = 'text'
  AND key IN (
    'email_reply_to',
    'email_test_recipient'
  );

-- Backfill email_signature_template_key (was missed in 046)
UPDATE public.global_settings
SET setting_type = 'email_template_key'
WHERE setting_type = 'text'
  AND key IN (
    'email_signature_template_key'
  );

COMMIT;
