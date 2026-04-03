BEGIN;

INSERT INTO public.email_templates (
  template_key,
  template_name,
  subject_template,
  text_template,
  is_active,
  template_type
) VALUES (
  'refund_calculation_member',
  'Refund Calculation - Request Bank Details',
  'Your refund calculation from Avondale LTC',
  E'Hi {{refund_for}},

Thank you for your refund request. We have calculated the refund amount as follows:

Refund for: {{membership}}
Amount paid: {{amount}}
From date: {{from_date}}
To date: {{to_date}}
Membership period: {{months}} month(s)
Refund amount: {{refund}}

{{explanation}}

To proceed with this refund, please reply to this email with your bank details:
- Bank name
- Account holder name
- Sort code
- Account number

Once we receive your bank details, we will process the refund and notify treasury.

If you have any questions, please reply to this email.

Best regards,
Avondale LTC',
  true,
  0
);

COMMIT;
