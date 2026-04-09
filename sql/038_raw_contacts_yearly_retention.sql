BEGIN;

CREATE OR REPLACE FUNCTION public.raw_contacts_history_identity_key(
    p_venue_id text,
    p_unique_id text,
    p_british_tennis_number integer,
    p_email_address text,
    p_first_name text,
    p_last_name text,
    p_postcode text,
    p_address_1 text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(
        public.normalize_match_text(p_venue_id),
        public.normalize_match_text(p_unique_id),
        public.normalize_match_text(p_british_tennis_number::text),
        public.normalize_match_text(p_email_address),
        NULLIF(
            CONCAT_WS(
                ' | ',
                public.normalize_match_text(CONCAT_WS(' ', p_first_name, p_last_name)),
                public.normalize_match_text(p_postcode)
            ),
            ''
        ),
        md5(
            CONCAT_WS(
                ' | ',
                COALESCE(p_first_name, ''),
                COALESCE(p_last_name, ''),
                COALESCE(p_email_address, ''),
                COALESCE(p_postcode, ''),
                COALESCE(p_address_1, '')
            )
        )
    );
$$;

WITH ranked_history AS (
    SELECT
        ctid,
        row_number() OVER (
            PARTITION BY
                snapshot_year,
                public.raw_contacts_history_identity_key(
                    "Venue ID",
                    "Unique ID",
                    "British Tennis Number",
                    "Email address",
                    "First name",
                    "Last name",
                    postcode,
                    "Address 1"
                )
            ORDER BY
                archived_at DESC,
                (
                    CASE WHEN NULLIF(trim(COALESCE("Email address", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
                    CASE WHEN NULLIF(trim(COALESCE(postcode, '')), '') IS NOT NULL THEN 1 ELSE 0 END +
                    CASE WHEN NULLIF(trim(COALESCE("Address 1", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
                    CASE WHEN NULLIF(trim(COALESCE("Mobile number", '')), '') IS NOT NULL THEN 1 ELSE 0 END
                ) DESC,
                ctid DESC
        ) AS row_rank
    FROM public.raw_contacts_historical
)
DELETE FROM public.raw_contacts_historical history
USING ranked_history ranked
WHERE history.ctid = ranked.ctid
  AND ranked.row_rank > 1;

DROP INDEX IF EXISTS raw_contacts_historical_yearly_identity_idx;

CREATE UNIQUE INDEX IF NOT EXISTS raw_contacts_historical_yearly_identity_idx
    ON public.raw_contacts_historical (
        snapshot_year,
        public.raw_contacts_history_identity_key(
            "Venue ID",
            "Unique ID",
            "British Tennis Number",
            "Email address",
            "First name",
            "Last name",
            postcode,
            "Address 1"
        )
    );

CREATE OR REPLACE FUNCTION public.archive_raw_contacts_yearly_snapshot(
    p_snapshot_year integer DEFAULT extract(year FROM current_date)::integer
)
RETURNS TABLE (
    snapshot_year integer,
    archived_row_count integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_archived_row_count integer := 0;
BEGIN
    DELETE FROM public.raw_contacts_historical
    WHERE raw_contacts_historical.snapshot_year = p_snapshot_year;

    WITH ranked_current_contacts AS (
        SELECT
            rc.*,
            row_number() OVER (
                PARTITION BY public.raw_contacts_history_identity_key(
                    rc."Venue ID",
                    rc."Unique ID",
                    rc."British Tennis Number",
                    rc."Email address",
                    rc."First name",
                    rc."Last name",
                    rc.postcode,
                    rc."Address 1"
                )
                ORDER BY
                    rc.last_seen_at DESC,
                    (
                        CASE WHEN NULLIF(trim(COALESCE(rc."Email address", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
                        CASE WHEN NULLIF(trim(COALESCE(rc.postcode, '')), '') IS NOT NULL THEN 1 ELSE 0 END +
                        CASE WHEN NULLIF(trim(COALESCE(rc."Address 1", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
                        CASE WHEN NULLIF(trim(COALESCE(rc."Mobile number", '')), '') IS NOT NULL THEN 1 ELSE 0 END
                    ) DESC,
                    rc.id DESC
            ) AS row_rank
        FROM public.raw_contacts rc
        WHERE COALESCE(rc.is_current, true) = true
    )
    INSERT INTO public.raw_contacts_historical (
        "Venue ID",
        "Unique ID",
        "First name",
        "Last name",
        gender,
        age,
        junior,
        "Date of birth",
        "Email address",
        "Phone number",
        "Work number",
        "Mobile number",
        "Emergency contact name",
        "Emergency phone number",
        "Address 1",
        "Address 2",
        "Address 3",
        town,
        county,
        country,
        postcode,
        "British Tennis Number",
        "Date joined venue",
        "Medical history",
        occupation,
        registered,
        unsubscribed,
        "Member status",
        "Last active",
        created,
        "Receipt of Emails",
        "Share Contact Detail",
        "Member's Directory",
        photography,
        snapshot_year,
        archived_at,
        snapshot_source
    )
    SELECT
        rc."Venue ID",
        rc."Unique ID",
        rc."First name",
        rc."Last name",
        rc.gender,
        rc.age,
        rc.junior,
        rc."Date of birth",
        rc."Email address",
        rc."Phone number",
        rc."Work number",
        rc."Mobile number",
        rc."Emergency contact name",
        rc."Emergency phone number",
        rc."Address 1",
        rc."Address 2",
        rc."Address 3",
        rc.town,
        rc.county,
        rc.country,
        rc.postcode,
        rc."British Tennis Number",
        rc."Date joined venue",
        rc."Medical history",
        rc.occupation,
        rc.registered,
        rc.unsubscribed,
        rc."Member status",
        rc."Last active",
        rc.created,
        rc."Receipt of Emails",
        rc."Share Contact Detail",
        rc."Member's Directory",
        rc.photography,
        p_snapshot_year,
        now(),
        'raw_contacts_yearly'
    FROM ranked_current_contacts rc
    WHERE rc.row_rank = 1;

    GET DIAGNOSTICS v_archived_row_count = ROW_COUNT;

    RETURN QUERY
    SELECT
        p_snapshot_year,
        v_archived_row_count;
END;
$$;

COMMIT;
