BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS uq_case_emails_gmail_message_id
    ON public.case_emails (gmail_message_id)
    WHERE gmail_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_case_emails_gmail_thread_id
    ON public.case_emails (gmail_thread_id)
    WHERE gmail_thread_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cases_metadata_gmail_thread_id
    ON public.cases ((metadata ->> 'gmail_thread_id'))
    WHERE COALESCE(metadata ->> 'gmail_thread_id', '') <> '';

COMMIT;
