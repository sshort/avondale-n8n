BEGIN;

INSERT INTO public.email_templates (
  template_key,
  template_name,
  subject_template,
  text_template,
  html_template,
  is_active,
  template_type
) VALUES (
  'refund_calculation_member',
  'Refund Calculation - Request Bank Details',
  'Your refund calculation from Avondale LTC',
  E'Hi {{$json.refund_for}},

Thank you for your refund request. We have calculated the refund amount as follows:

Refund for: {{$json.membership}}
Amount paid: {{$json.amount}}
From date: {{$json.from_date}}
To date: {{$json.to_date}}
Membership period: {{$json.months}} month(s)
Refund amount: {{$json.refund}}

{{$json.explanation}}

To proceed with this refund, please reply to this email with your bank details:
- Bank name
- Account holder name
- Sort code
- Account number

Once we receive your bank details, we will process the refund and notify treasury.

If you have any questions, please reply to this email.
',
  '<p>Hi {{$json.refund_for}},</p><p>Thank you for your refund request. We have calculated the refund amount as follows:</p><p><strong>Refund for:</strong> {{$json.membership}}<br><strong>Amount paid:</strong> {{$json.amount}}<br><strong>From date:</strong> {{$json.from_date}}<br><strong>To date:</strong> {{$json.to_date}}<br><strong>Membership period:</strong> {{$json.months}} month(s)<br><strong>Refund amount:</strong> {{$json.refund}}</p><p>{{$json.explanation}}</p><p>To proceed with this refund, please reply to this email with your bank details:</p><ul><li>Bank name</li><li>Account holder name</li><li>Sort code</li><li>Account number</li></ul><p>Once we receive your bank details, we will process the refund and notify treasury.</p><p>If you have any questions, please reply to this email.</p>',
  true,
  0
)
ON CONFLICT (template_key) DO UPDATE SET
  template_name = EXCLUDED.template_name,
  subject_template = EXCLUDED.subject_template,
  text_template = EXCLUDED.text_template,
  html_template = EXCLUDED.html_template,
  is_active = EXCLUDED.is_active,
  template_type = EXCLUDED.template_type,
  updated_at = now()
);

COMMIT;
