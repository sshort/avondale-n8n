-- Create html_templates table for n8n webhook HTML templates
CREATE TABLE IF NOT EXISTS public.html_templates (
  id bigserial PRIMARY KEY,
  template_name text NOT NULL,
  webhook_path text NOT NULL,
  html_template text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS html_templates_webhook_path_idx
  ON public.html_templates (webhook_path);

CREATE INDEX IF NOT EXISTS html_templates_is_active_idx
  ON public.html_templates (is_active);

-- Insert HTML templates from n8n webhooks
INSERT INTO public.html_templates (template_name, webhook_path, is_active) VALUES
-- Form-based webhooks with HTML responses
('Refund Form', 'refund-form', true),
('Refund Status Form', 'refunds', true),
('Case Tracking App', 'case-tracking', true),
('Team Management App', 'team-management', true),
('Team Management Actions', 'team-management-actions', true),
('Signup Batch Review', 'signup-batch-review', true),
('Signup Batch Actions', 'signup-batch-actions', true),
('Manual Batch Item Form', 'manual-batch-item-form', true),
('Delete Manual Batch Item', 'delete-manual-batch-item', true),
('Create Missing Signup Capture', 'create-missing-signup-capture', true),
('Confirm Missing Signup Capture', 'confirm-missing-signup-capture', true),
('Member Search Detail', 'member-search-detail', true),
('Metabase Report Form', 'report-form', true),
('Email Template Editor', 'email-template-editor', true),
('Email Template Editor Actions', 'email-template-editor-actions', true),
('ClubSpark Package Members Import', 'clubspark-package-members-import-form', true),

-- Email action webhooks
('Send Case Tracking Email', 'send-case-tracking-email', true),
('Preview Case Tracking Email', 'preview-case-tracking-email', true),
('Send Refund Request Email', 'send-refund-request-email', true),
('Preview Refund Request Email', 'preview-refund-request-email', true),
('Send Treasury Refund Request', 'send-treasury-refund-request', true),
('Send Member Template Email', 'send-member-template-email', true),
('Preview Member Template Email', 'preview-member-template-email', true),
('Send Member Calculation Email', 'send-member-calculation-email', true),
('Send No Address Batch Emails', 'send-no-address-batch-emails', true),

-- Refund webhooks
('Add Refund', 'add-refund', true),
('Update Refund Status', 'update-refund-status', true)
ON CONFLICT (webhook_path) DO NOTHING;