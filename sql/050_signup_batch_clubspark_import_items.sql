CREATE TABLE IF NOT EXISTS public.signup_batch_clubspark_import_items (
    id bigserial PRIMARY KEY,
    batch_id bigint NOT NULL REFERENCES public.signup_batches (id) ON DELETE CASCADE,
    raw_member_id bigint NOT NULL REFERENCES public.raw_members (id) ON DELETE RESTRICT,
    member text NOT NULL,
    email_address text,
    source_membership text,
    target_membership text NOT NULL,
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'exported', 'imported', 'cancelled')),
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text,
    exported_at timestamptz,
    imported_at timestamptz,
    export_file_name text,
    CONSTRAINT signup_batch_clubspark_import_items_exported_requires_timestamp
        CHECK (
            status <> 'exported'
            OR exported_at IS NOT NULL
        ),
    CONSTRAINT signup_batch_clubspark_import_items_imported_requires_timestamp
        CHECK (
            status <> 'imported'
            OR imported_at IS NOT NULL
        )
);

CREATE INDEX IF NOT EXISTS idx_signup_batch_clubspark_import_items_batch_id
    ON public.signup_batch_clubspark_import_items (batch_id);

CREATE INDEX IF NOT EXISTS idx_signup_batch_clubspark_import_items_raw_member_id
    ON public.signup_batch_clubspark_import_items (raw_member_id);

CREATE INDEX IF NOT EXISTS idx_signup_batch_clubspark_import_items_status
    ON public.signup_batch_clubspark_import_items (status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_signup_batch_clubspark_import_items_active
    ON public.signup_batch_clubspark_import_items (batch_id, raw_member_id, target_membership)
    WHERE status IN ('queued', 'exported', 'imported');

CREATE OR REPLACE VIEW public.vw_signup_batch_clubspark_import_items AS
SELECT
    q.id,
    q.batch_id,
    q.raw_member_id,
    q.member,
    q.email_address,
    q.source_membership,
    q.target_membership,
    q.status,
    q.notes,
    q.created_at,
    q.created_by,
    q.exported_at,
    q.imported_at,
    q.export_file_name,
    b.status AS batch_status,
    rm."Membership" AS current_membership,
    rm."Status" AS current_membership_status,
    rm."Payment" AS current_membership_payment,
    rm."Email address" AS raw_member_email,
    rm."Venue ID" AS venue_id,
    rm."British Tennis Number" AS british_tennis_number,
    target_pkg.category AS target_membership_category,
    target_pkg.season AS target_membership_season,
    target_pkg.display_order AS target_membership_display_order,
    source_pkg.category AS source_membership_category,
    source_pkg.season AS source_membership_season
FROM public.signup_batch_clubspark_import_items q
JOIN public.signup_batches b
    ON b.id = q.batch_id
LEFT JOIN public.raw_members rm
    ON rm.id = q.raw_member_id
LEFT JOIN public.membership_packages target_pkg
    ON target_pkg.name = q.target_membership
LEFT JOIN public.membership_packages source_pkg
    ON source_pkg.name = q.source_membership;
