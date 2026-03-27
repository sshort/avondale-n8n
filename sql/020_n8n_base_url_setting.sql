BEGIN;

INSERT INTO public.global_settings (key, value, description)
VALUES (
  'n8n_base_url',
  'http://n8n:5678',
  'Base URL used when generating links to n8n webhooks'
)
ON CONFLICT (key) DO UPDATE
SET
  description = EXCLUDED.description,
  updated_at = now();

COMMIT;
