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
  'request_bank_details',
  'Request Bank Details',
  0,
  'Membership refund: bank details required',
  E'Dear {{$json.refund_for}},\n\nWe are processing your membership refund request for {{$json.membership}}.\n\nTo complete the refund, please reply with your bank details:\n- Bank name\n- Account holder name\n- Sort code\n- Account number\n\nOnce we receive your bank details, we will submit the refund for payment.',
  '<p>Dear {{$json.refund_for}},</p><p>We are processing your membership refund request for {{$json.membership}}.</p><p>To complete the refund, please reply with your bank details:</p><ul><li>Bank name</li><li>Account holder name</li><li>Sort code</li><li>Account number</li></ul><p>Once we receive your bank details, we will submit the refund for payment.</p>',
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
