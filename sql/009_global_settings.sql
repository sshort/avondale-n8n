BEGIN;

CREATE TABLE IF NOT EXISTS public.global_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.global_settings (key, value, description)
VALUES
  ('clubspark_exporter_base_url', 'http://clubspark-exporter:3001', 'Base URL for the local ClubSpark exporter service'),
  ('gotenberg_base_url', 'http://gotenberg:3000', 'Base URL for the local Gotenberg PDF service'),
  ('clubspark_venue_slug', 'AvondaleTennisClub', 'ClubSpark venue slug used to build venue admin URLs'),
  ('email_sender_name', 'Steve Short', 'Default display name for outgoing membership emails'),
  ('email_reply_to', 'members.avondaleltc@gmail.com', 'Reply-to address for outgoing membership emails'),
  ('email_test_recipient', 'steve.short@gmail.com', 'Default recipient used when batch-email workflows run in test mode'),
  ('email_delivery_mode', 'production', 'Default delivery mode for batch-email workflows: production or test'),
  ('no_address_email_template_key', 'shoe_tag_pigeon_hole', 'Template key for the no-address batch-email workflow'),
  ('gmail_test_email_template_key', 'shoe_tag_pigeon_hole', 'Template key for the manual Gmail test-send workflow'),
  ('signup_imap_mailbox', 'NewMemberships', 'Mailbox/folder name for the disabled IMAP signup reader path')
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

COMMIT;
