ALTER TABLE public.signup_batches
  ADD COLUMN IF NOT EXISTS no_address_email_sent boolean NOT NULL DEFAULT false;

UPDATE public.signup_batches
SET no_address_email_sent = true
WHERE id = 4;
