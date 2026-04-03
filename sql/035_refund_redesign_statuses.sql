BEGIN;

ALTER TABLE public.refunds
  ALTER COLUMN status SET DEFAULT 'New Request';

UPDATE public.refunds
SET status = CASE status
  WHEN 'Requested' THEN 'Request Bank Details'
  WHEN 'Awaiting Bank Details' THEN 'Request Bank Details'
  WHEN 'Request Bank Details' THEN 'Request Bank Details'
  WHEN 'Bank Details Received' THEN 'Bank Details Obtained'
  WHEN 'Ready For Treasury' THEN 'Bank Details Obtained'
  WHEN 'Sent To Treasury' THEN 'Submitted for Refund'
  WHEN 'Paid' THEN 'Refund Processed'
  WHEN 'Rejected' THEN 'Refund Rejected'
  WHEN 'Cancelled' THEN 'Refund Rejected'
  ELSE status
END
WHERE status IN (
  'Requested',
  'Awaiting Bank Details',
  'Request Bank Details',
  'Bank Details Received',
  'Ready For Treasury',
  'Sent To Treasury',
  'Paid',
  'Rejected',
  'Cancelled'
);

COMMENT ON COLUMN public.refunds.status IS 'New Request | Request Bank Details | Bank Details Obtained | Submitted for Refund | Refund Processed | Refund Rejected';

COMMIT;
