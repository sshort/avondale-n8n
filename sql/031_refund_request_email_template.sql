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
  'Refund request: {{$json.refund_for}} ({{$json.membership}})',
  E'Hi Treasury,\n\nPlease process the following membership refund request.\n\nRequested by: {{$json.requested_by}}\nRefund for: {{$json.refund_for}}\nReason: {{$json.reason}}\nMembership: {{$json.membership}}\nAmount paid: {{$json.amount}}\nFrom date: {{$json.from_date}}\nTo date: {{$json.to_date}}\nMonths: {{$json.months}}\nRefund due: {{$json.refund}}\nStatus: {{$json.status}}\n\n{{$json.explanation}}',
  '<p>Hi Treasury,</p><p>Please process the following membership refund request.</p><p><strong>Requested by:</strong> {{$json.requested_by}}<br><strong>Refund for:</strong> {{$json.refund_for}}<br><strong>Reason:</strong> {{$json.reason}}<br><strong>Membership:</strong> {{$json.membership}}<br><strong>Amount paid:</strong> {{$json.amount}}<br><strong>From date:</strong> {{$json.from_date}}<br><strong>To date:</strong> {{$json.to_date}}<br><strong>Months:</strong> {{$json.months}}<br><strong>Refund due:</strong> {{$json.refund}}<br><strong>Status:</strong> {{$json.status}}</p><p>{{$json.explanation}}</p>',
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
