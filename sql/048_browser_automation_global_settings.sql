BEGIN;

INSERT INTO public.global_settings (key, value, description)
VALUES
  ('browser_automation_base_url', 'http://browser-automation:3000', 'Base URL for the local browser-automation Playwright service'),
  ('clubspark_email', 'steve@shortcentral.com', 'ClubSpark login email used by browser-automation workflows'),
  ('clubspark_password', 'HQ#zo7P8C$', 'ClubSpark login password used by browser-automation workflows'),
  ('lta_username', 'sshort', 'LTA username used by browser-automation workflows'),
  ('lta_password', 'fH8Urv2XrtZwXra!', 'LTA password used by browser-automation workflows')
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

UPDATE public.global_settings
SET setting_type = 'url'
WHERE key = 'browser_automation_base_url'
  AND setting_type = 'text';

UPDATE public.global_settings
SET setting_type = 'email'
WHERE key = 'clubspark_email'
  AND setting_type = 'text';

UPDATE public.global_settings
SET setting_type = 'text'
WHERE key IN ('clubspark_password', 'lta_username', 'lta_password')
  AND setting_type = 'text';

COMMIT;
