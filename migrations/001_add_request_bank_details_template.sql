-- Migration: Add 'Request Bank Details' email template
-- Description: Creates the email template used when requesting bank details from refund applicants
-- Created: 2026-04-03

INSERT INTO public.email_templates (template_key, template_name, template_type, subject_template, text_template, html_template, is_active, created_at, updated_at)
VALUES (
  'request_bank_details',
  'Request Bank Details',
  0,
  'Membership Refund - Bank Details Required',
  'Dear {{name}},

We are processing your membership refund request for {{membership}}.

To complete the refund, please reply with your bank details:
- Bank name
- Account holder name
- Account number
- Sort code

Refund Amount: {{refund}}
Status: {{status}}

Kind regards,
Avondale Tennis Club',
  '<p>Dear {{name}},</p><p>We are processing your membership refund request for {{membership}}.</p><p>To complete the refund, please reply with your bank details:</p><ul><li>Bank name</li><li>Account holder name</li><li>Account number</li><li>Sort code</li></ul><p><strong>Refund Amount:</strong> {{refund}}</p><p><strong>Status:</strong> {{status}}</p><p>Kind regards,<br>Avondale Tennis Club</p>',
  true,
  now(),
  now()
)
ON CONFLICT (template_key) DO UPDATE SET
  template_name = EXCLUDED.template_name,
  subject_template = EXCLUDED.subject_template,
  text_template = EXCLUDED.text_template,
  html_template = EXCLUDED.html_template,
  is_active = EXCLUDED.is_active,
  updated_at = now();
