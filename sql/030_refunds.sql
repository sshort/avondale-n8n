BEGIN;

CREATE TABLE IF NOT EXISTS public.refunds (
    id bigserial PRIMARY KEY,
    name text NOT NULL,
    refund_for text NOT NULL,
    reason text NOT NULL,
    membership text NOT NULL,
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    from_date date NOT NULL,
    to_date date NOT NULL CHECK (to_date >= from_date),
    months integer NOT NULL CHECK (months >= 0),
    refund numeric(12,2) NOT NULL CHECK (refund >= 0),
    status text NOT NULL DEFAULT 'Request Bank Details',
    explanation text NOT NULL,
    created_by text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refunds_refund_for
    ON public.refunds (refund_for);

CREATE INDEX IF NOT EXISTS idx_refunds_status
    ON public.refunds (status);

CREATE INDEX IF NOT EXISTS idx_refunds_membership
    ON public.refunds (membership);

CREATE INDEX IF NOT EXISTS idx_refunds_from_date
    ON public.refunds (from_date);

COMMIT;
