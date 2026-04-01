CREATE TABLE IF NOT EXISTS public.email_templates (
  id bigserial PRIMARY KEY,
  template_key text NOT NULL UNIQUE,
  template_name text NOT NULL,
  template_type integer NOT NULL DEFAULT 0,
  subject_template text,
  text_template text,
  html_template text,
  source_group text,
  source_txt_path text,
  source_html_path text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS email_templates_is_active_idx
  ON public.email_templates (is_active);

ALTER TABLE public.email_templates
  DROP CONSTRAINT IF EXISTS email_templates_template_type_check;

ALTER TABLE public.email_templates
  ADD CONSTRAINT email_templates_template_type_check
  CHECK (template_type IN (0, 1, 2));
