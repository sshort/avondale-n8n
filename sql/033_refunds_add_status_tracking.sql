BEGIN;

ALTER TABLE public.refunds
  ADD COLUMN IF NOT EXISTS request_email_message_id text,
  ADD COLUMN IF NOT EXISTS bank_details_message_id text,
  ADD COLUMN IF NOT EXISTS treasury_email_message_id text,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejected_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.refunds
  ALTER COLUMN status TYPE text,
  ALTER COLUMN status SET DEFAULT 'Requested';

UPDATE public.refunds
SET status = 'Requested'
WHERE status = 'Request Bank Details';

COMMENT ON COLUMN public.refunds.status IS 'Requested | Awaiting Bank Details | Bank Details Received | Ready For Treasury | Sent To Treasury | Paid | Rejected | Cancelled';

COMMENT ON COLUMN public.refunds.request_email_message_id IS 'Gmail message ID of the email sent to member requesting bank details';
COMMENT ON COLUMN public.refunds.bank_details_message_id IS 'Gmail message ID of the reply containing bank details';
COMMENT ON COLUMN public.refunds.treasury_email_message_id IS 'Gmail message ID of the email sent to treasury';

COMMIT;
