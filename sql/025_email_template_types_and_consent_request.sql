ALTER TABLE public.email_templates
  ADD COLUMN IF NOT EXISTS template_type integer NOT NULL DEFAULT 0;

ALTER TABLE public.email_templates
  DROP CONSTRAINT IF EXISTS email_templates_template_type_check;

ALTER TABLE public.email_templates
  ADD CONSTRAINT email_templates_template_type_check
  CHECK (template_type IN (0, 1, 2));

UPDATE public.email_templates
SET template_type = CASE
  WHEN template_key IN ('avondale_header') THEN 1
  WHEN template_key IN ('avondale_footer', 'signature', 'signature_html') THEN 2
  ELSE 0
END
WHERE template_type IS DISTINCT FROM CASE
  WHEN template_key IN ('avondale_header') THEN 1
  WHEN template_key IN ('avondale_footer', 'signature', 'signature_html') THEN 2
  ELSE 0
END;

INSERT INTO public.email_templates (
  template_key,
  template_name,
  template_type,
  subject_template,
  text_template,
  html_template,
  source_group,
  source_txt_path,
  source_html_path,
  is_active
)
VALUES (
  'request_contact_consent',
  'Request Contact Consent',
  0,
  'Please confirm whether we may share your contact details',
  E'Dear {{$json.first_name}} {{$json.last_name}},\n\nWe are preparing team contact sheets for Avondale Tennis Club and want to make sure we only share contact details with your permission.\n\nPlease reply to this email to confirm whether you are happy for us to share your phone number and email address with your team captain and team-mates for team administration.\n\nIf you do not consent, we will continue to withhold those details from the team contact sheets.',
  NULL,
  'system',
  NULL,
  NULL,
  TRUE
)
ON CONFLICT (template_key) DO UPDATE SET
  template_name = EXCLUDED.template_name,
  template_type = EXCLUDED.template_type,
  subject_template = EXCLUDED.subject_template,
  text_template = EXCLUDED.text_template,
  html_template = EXCLUDED.html_template,
  source_group = EXCLUDED.source_group,
  is_active = EXCLUDED.is_active,
  updated_at = now();
