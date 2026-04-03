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
  'refund_request_treasury',
  'Refund Request To Treasury',
  0,
  'Refund request: {{refund_for}} ({{membership}})',
  E'Hi Treasury,\n\nPlease process the following membership refund request.\n\nRequested by: {{name}}\nRefund for: {{refund_for}}\nReason: {{reason}}\nMembership: {{membership}}\nAmount paid: {{amount}}\nFrom date: {{from_date}}\nTo date: {{to_date}}\nMonths: {{months}}\nRefund due: {{refund}}\nStatus: {{status}}\n\n{{explanation}}',
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
