BEGIN;

-- Add stirling_api_key to global_settings.
-- Uses ON CONFLICT DO NOTHING so an existing key value is never overwritten.

INSERT INTO public.global_settings (key, value, setting_type, description)
VALUES (
  'stirling_api_key',
  '',
  'password',
  'API key for Stirling PDF service (sent as X-API-KEY header)'
)
ON CONFLICT (key) DO NOTHING;

COMMIT;
