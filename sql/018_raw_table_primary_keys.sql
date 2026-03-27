BEGIN;

ALTER TABLE public.raw_members
  ALTER COLUMN id SET NOT NULL,
  ALTER COLUMN first_seen_at SET NOT NULL,
  ALTER COLUMN last_seen_at SET NOT NULL,
  ALTER COLUMN is_current SET NOT NULL;

ALTER TABLE public.raw_contacts
  ALTER COLUMN id SET NOT NULL,
  ALTER COLUMN first_seen_at SET NOT NULL,
  ALTER COLUMN last_seen_at SET NOT NULL,
  ALTER COLUMN is_current SET NOT NULL;

ALTER SEQUENCE public.raw_members_id_seq OWNED BY public.raw_members.id;
ALTER SEQUENCE public.raw_contacts_id_seq OWNED BY public.raw_contacts.id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.raw_members'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE public.raw_members
      ADD CONSTRAINT raw_members_pkey PRIMARY KEY (id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.raw_contacts'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE public.raw_contacts
      ADD CONSTRAINT raw_contacts_pkey PRIMARY KEY (id);
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS raw_members_is_current_idx
  ON public.raw_members (is_current);

CREATE INDEX IF NOT EXISTS raw_contacts_is_current_idx
  ON public.raw_contacts (is_current);

COMMIT;
