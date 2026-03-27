CREATE TABLE IF NOT EXISTS public.signup_batch_manual_items (
    id bigserial PRIMARY KEY,
    batch_id bigint NOT NULL REFERENCES public.signup_batches (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    source text NOT NULL DEFAULT 'manual' CHECK (source = 'manual'),
    member text NOT NULL,
    payer text NOT NULL,
    email_address text,
    address_1 text,
    address_2 text,
    address_3 text,
    town text,
    postcode text,
    regular_tags integer NOT NULL DEFAULT 0 CHECK (regular_tags >= 0),
    parent_tags integer NOT NULL DEFAULT 0 CHECK (parent_tags >= 0),
    key_tags integer NOT NULL DEFAULT 0 CHECK (key_tags >= 0),
    notes text,
    created_by text,
    CONSTRAINT signup_batch_manual_items_has_items
        CHECK (regular_tags + parent_tags + key_tags > 0)
);

CREATE INDEX IF NOT EXISTS idx_signup_batch_manual_items_batch_id
    ON public.signup_batch_manual_items (batch_id);

CREATE INDEX IF NOT EXISTS idx_signup_batch_manual_items_member
    ON public.signup_batch_manual_items (member);

CREATE INDEX IF NOT EXISTS idx_signup_batch_manual_items_payer
    ON public.signup_batch_manual_items (payer);

CREATE OR REPLACE VIEW public.vw_signup_batch_items AS
WITH best_contact AS (
    SELECT DISTINCT ON (concat(rc."First name", ' ', rc."Last name"))
        concat(rc."First name", ' ', rc."Last name") AS payer_name,
        rc."Address 1" AS address_1,
        rc."Address 2" AS address_2,
        rc."Address 3" AS address_3,
        rc.town,
        rc.postcode
    FROM public.raw_contacts rc
    WHERE COALESCE(rc.is_current, true) = true
    ORDER BY concat(rc."First name", ' ', rc."Last name"),
             CASE
                 WHEN COALESCE(NULLIF(trim(rc."Address 1"), ''), NULLIF(trim(rc.postcode), '')) IS NOT NULL
                 THEN 0 ELSE 1
             END,
             CASE WHEN NULLIF(trim(rc."Address 1"), '') IS NOT NULL THEN 0 ELSE 1 END,
             CASE WHEN NULLIF(trim(rc.postcode), '') IS NOT NULL THEN 0 ELSE 1 END
)
SELECT
    s.id AS source_id,
    s.batch_id,
    s.signup_date AS item_date,
    s.member,
    s.payer,
    s.product,
    m."Email address" AS email_address,
    bc.address_1,
    bc.address_2,
    bc.address_3,
    bc.town,
    bc.postcode,
    CASE
        WHEN s.product NOT IN ('6. Parent 2026', 'b. Pavilion Key', 'a. Social 2026')
        THEN 1 ELSE 0
    END AS regular_tags,
    CASE WHEN s.product = '6. Parent 2026' THEN 1 ELSE 0 END AS parent_tags,
    CASE WHEN s.product = 'b. Pavilion Key' THEN 1 ELSE 0 END AS key_tags,
    COALESCE(NULLIF(trim(s.source), ''), 'email_capture') AS source,
    NULL::text AS notes,
    'member_signups'::text AS source_table
FROM public.member_signups s
LEFT JOIN public.raw_members m
    ON s.member = concat(m."First name", ' ', m."Last name")
   AND m."Membership" = s.product
   AND COALESCE(m.is_current, true) = true
LEFT JOIN best_contact bc
    ON s.payer = bc.payer_name

UNION ALL

SELECT
    mi.id AS source_id,
    mi.batch_id,
    mi.created_at AS item_date,
    mi.member,
    mi.payer,
    NULL::text AS product,
    mi.email_address,
    mi.address_1,
    mi.address_2,
    mi.address_3,
    mi.town,
    mi.postcode,
    mi.regular_tags,
    mi.parent_tags,
    mi.key_tags,
    mi.source,
    mi.notes,
    'signup_batch_manual_items'::text AS source_table
FROM public.signup_batch_manual_items mi;

CREATE OR REPLACE VIEW public.vw_signup_batch_consolidated AS
SELECT
    batch_id,
    payer,
    address_1,
    address_2,
    address_3,
    town,
    postcode,
    SUM(regular_tags) AS regular_tags,
    SUM(parent_tags) AS parent_tags,
    SUM(key_tags) AS key_tags,
    SUM(regular_tags + parent_tags + key_tags) AS total_items,
    BOOL_OR(source = 'manual') AS has_manual_items
FROM public.vw_signup_batch_items
WHERE COALESCE(product, '') <> 'a. Social 2026'
GROUP BY
    batch_id,
    payer,
    address_1,
    address_2,
    address_3,
    town,
    postcode;

CREATE OR REPLACE VIEW public.vw_signup_batches_summary AS
SELECT
    b.id AS batch_id,
    b.status,
    b.created_at,
    b.completed_at,
    COUNT(*) FILTER (WHERE i.source_table = 'member_signups') AS signup_rows,
    COUNT(*) FILTER (WHERE i.source = 'manual') AS manual_rows,
    COALESCE(SUM(i.regular_tags), 0) AS regular_tags,
    COALESCE(SUM(i.parent_tags), 0) AS parent_tags,
    COALESCE(SUM(i.key_tags), 0) AS key_tags,
    COALESCE(SUM(i.regular_tags + i.parent_tags + i.key_tags), 0) AS total_items
FROM public.signup_batches b
LEFT JOIN public.vw_signup_batch_items i
    ON i.batch_id = b.id
GROUP BY
    b.id,
    b.status,
    b.created_at,
    b.completed_at;
