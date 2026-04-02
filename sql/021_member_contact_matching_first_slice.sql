-- First implementation slice for the member/contact matching policy.
-- Adds shared normalization helpers, safer corroborated reconcile logic,
-- and audit/review objects for ambiguous and weak matches.

BEGIN;

CREATE OR REPLACE FUNCTION public.normalize_match_postcode(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        regexp_replace(upper(trim(COALESCE(value, ''))), '\s+', '', 'g'),
        ''
    );
$$;

CREATE OR REPLACE FUNCTION public.normalize_match_phone(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        regexp_replace(COALESCE(value, ''), '[^0-9]+', '', 'g'),
        ''
    );
$$;

CREATE OR REPLACE FUNCTION public.clean_phone_display(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        trim(regexp_replace(COALESCE(value, ''), '[\[\]]+', '', 'g')),
        ''
    );
$$;

CREATE OR REPLACE FUNCTION public.normalize_match_email(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(lower(trim(COALESCE(value, ''))), '');
$$;

CREATE OR REPLACE FUNCTION public.normalize_match_address_line1(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        regexp_replace(lower(trim(COALESCE(value, ''))), '[^a-z0-9]+', '', 'g'),
        ''
    );
$$;

CREATE OR REPLACE FUNCTION public.normalize_match_date(value text)
RETURNS date
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v text := trim(COALESCE(value, ''));
BEGIN
    IF v = '' THEN
        RETURN NULL;
    END IF;

    IF v ~ '^\d{2}/\d{2}/\d{4}$' THEN
        RETURN to_date(v, 'DD/MM/YYYY');
    END IF;

    IF v ~ '^\d{4}-\d{2}-\d{2}$' THEN
        RETURN v::date;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TABLE IF NOT EXISTS public.raw_reconcile_match_audit (
    id bigserial PRIMARY KEY,
    raw_table text NOT NULL CHECK (raw_table IN ('raw_contacts', 'raw_members')),
    run_at timestamptz NOT NULL DEFAULT now(),
    source_row integer NOT NULL,
    source_name text,
    source_membership text,
    matched_id bigint,
    match_rule text NOT NULL,
    outcome text NOT NULL,
    candidate_count integer,
    candidate_ids jsonb,
    notes text
);

CREATE INDEX IF NOT EXISTS idx_raw_reconcile_match_audit_table_run
    ON public.raw_reconcile_match_audit (raw_table, run_at DESC);

CREATE INDEX IF NOT EXISTS idx_raw_reconcile_match_audit_outcome
    ON public.raw_reconcile_match_audit (outcome, raw_table, run_at DESC);

CREATE OR REPLACE FUNCTION public.reconcile_raw_contacts_from_staging()
RETURNS TABLE(updated_count integer, inserted_count integer, deactivated_count integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_now timestamptz := now();
    v_updated integer := 0;
    v_inserted integer := 0;
    v_deactivated integer := 0;
BEGIN
    CREATE TEMP TABLE tmp_stage_raw_contacts ON COMMIT DROP AS
    SELECT
        row_number() OVER (
            ORDER BY
                COALESCE("Venue ID", ''),
                COALESCE("Unique ID", ''),
                COALESCE("First name", ''),
                COALESCE("Last name", '')
        ) AS source_row,
        trim(concat_ws(' ', s."First name", s."Last name")) AS source_name,
        s.*,
        public.normalize_match_text(s."Venue ID") AS norm_venue_id,
        public.normalize_match_text(concat_ws(' ', s."First name", s."Last name")) AS norm_name,
        public.normalize_match_date(s."Date of birth") AS norm_dob,
        public.normalize_match_postcode(s.postcode) AS norm_postcode,
        public.normalize_match_address_line1(s."Address 1") AS norm_address_1,
        COALESCE(
            public.normalize_match_phone(s."Mobile number"),
            public.normalize_match_phone(s."Phone number")
        ) AS norm_phone,
        public.normalize_match_email(s."Email address") AS norm_email,
        (
            CASE WHEN public.normalize_match_address_line1(s."Address 1") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_postcode(s.postcode) IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_email(s."Email address") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(public.normalize_match_phone(s."Mobile number"), public.normalize_match_phone(s."Phone number")) IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_date(s."Date of birth") IS NOT NULL THEN 1 ELSE 0 END
        ) AS quality_score,
        CASE COALESCE(NULLIF(trim(s."Member status"), ''), '')
            WHEN 'Active Member' THEN 0
            WHEN 'Non Member' THEN 1
            WHEN 'Lapsed Member' THEN 2
            ELSE 3
        END AS status_rank
    FROM public.raw_contacts_import_staging s;

    CREATE TEMP TABLE tmp_current_raw_contacts ON COMMIT DROP AS
    SELECT
        c.id,
        trim(concat_ws(' ', c."First name", c."Last name")) AS source_name,
        public.normalize_match_text(c."Venue ID") AS norm_venue_id,
        public.normalize_match_text(concat_ws(' ', c."First name", c."Last name")) AS norm_name,
        public.normalize_match_date(c."Date of birth") AS norm_dob,
        public.normalize_match_postcode(c.postcode) AS norm_postcode,
        public.normalize_match_address_line1(c."Address 1") AS norm_address_1,
        COALESCE(
            public.normalize_match_phone(c."Mobile number"),
            public.normalize_match_phone(c."Phone number")
        ) AS norm_phone,
        public.normalize_match_email(c."Email address") AS norm_email,
        (
            CASE WHEN public.normalize_match_address_line1(c."Address 1") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_postcode(c.postcode) IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_email(c."Email address") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(public.normalize_match_phone(c."Mobile number"), public.normalize_match_phone(c."Phone number")) IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_date(c."Date of birth") IS NOT NULL THEN 1 ELSE 0 END
        ) AS quality_score,
        CASE COALESCE(NULLIF(trim(c."Member status"), ''), '')
            WHEN 'Active Member' THEN 0
            WHEN 'Non Member' THEN 1
            WHEN 'Lapsed Member' THEN 2
            ELSE 3
        END AS status_rank,
        public.normalize_match_date(c.created) AS created_date
    FROM public.raw_contacts c
    WHERE COALESCE(c.is_current, true) = true;

    CREATE TEMP TABLE tmp_matched_raw_contacts (
        source_row integer PRIMARY KEY,
        target_id bigint UNIQUE,
        match_rule text NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_venue_id'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.created_date DESC NULLS LAST, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_contacts s
        JOIN tmp_current_raw_contacts c
          ON c.norm_venue_id = s.norm_venue_id
         AND (
            s.norm_name IS NULL
            OR c.norm_name IS NULL
            OR c.norm_name = s.norm_name
         )
        LEFT JOIN tmp_matched_raw_contacts ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_contacts mc
          ON mc.target_id = c.id
        WHERE s.norm_venue_id IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            s.source_row,
            s.norm_name,
            s.norm_dob,
            row_number() OVER (
                PARTITION BY s.norm_name, s.norm_dob
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.source_row
            ) AS rn
        FROM tmp_stage_raw_contacts s
        LEFT JOIN tmp_matched_raw_contacts ms
          ON ms.source_row = s.source_row
        WHERE s.norm_name IS NOT NULL
          AND s.norm_dob IS NOT NULL
          AND ms.source_row IS NULL
    ),
    current_ranked AS (
        SELECT
            c.id AS target_id,
            c.norm_name,
            c.norm_dob,
            row_number() OVER (
                PARTITION BY c.norm_name, c.norm_dob
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.created_date DESC NULLS LAST, c.id
            ) AS rn
        FROM tmp_current_raw_contacts c
        LEFT JOIN tmp_matched_raw_contacts mc
          ON mc.target_id = c.id
        WHERE c.norm_name IS NOT NULL
          AND c.norm_dob IS NOT NULL
          AND mc.target_id IS NULL
    )
    SELECT
        s.source_row,
        c.target_id,
        'matched_by_name_dob'
    FROM stage_ranked s
    JOIN current_ranked c
      ON c.norm_name = s.norm_name
     AND c.norm_dob = s.norm_dob
     AND c.rn = s.rn;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_address'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.created_date DESC NULLS LAST, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_contacts s
        JOIN tmp_current_raw_contacts c
          ON c.norm_name = s.norm_name
         AND c.norm_postcode = s.norm_postcode
         AND c.norm_address_1 = s.norm_address_1
        LEFT JOIN tmp_matched_raw_contacts ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_contacts mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_postcode IS NOT NULL
          AND s.norm_address_1 IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_phone'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.created_date DESC NULLS LAST, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_contacts s
        JOIN tmp_current_raw_contacts c
          ON c.norm_name = s.norm_name
         AND c.norm_phone = s.norm_phone
        LEFT JOIN tmp_matched_raw_contacts ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_contacts mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_phone IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_email'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.created_date DESC NULLS LAST, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_contacts s
        JOIN tmp_current_raw_contacts c
          ON c.norm_name = s.norm_name
         AND c.norm_email = s.norm_email
        LEFT JOIN tmp_matched_raw_contacts ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_contacts mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_email IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_only'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.created_date DESC NULLS LAST, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_contacts s
        JOIN tmp_current_raw_contacts c
          ON c.norm_name = s.norm_name
        LEFT JOIN tmp_matched_raw_contacts ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_contacts mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    UPDATE public.raw_contacts rc
    SET
        "Venue ID" = s."Venue ID",
        "Unique ID" = s."Unique ID",
        "First name" = s."First name",
        "Last name" = s."Last name",
        gender = s.gender,
        age = s.age,
        junior = s.junior,
        "Date of birth" = s."Date of birth",
        "Email address" = s."Email address",
        "Phone number" = public.clean_phone_display(s."Phone number"),
        "Work number" = public.clean_phone_display(s."Work number"),
        "Mobile number" = public.clean_phone_display(s."Mobile number"),
        "Emergency contact name" = s."Emergency contact name",
        "Emergency phone number" = public.clean_phone_display(s."Emergency phone number"),
        "Address 1" = s."Address 1",
        "Address 2" = s."Address 2",
        "Address 3" = s."Address 3",
        town = s.town,
        county = s.county,
        country = s.country,
        postcode = s.postcode,
        "British Tennis Number" = s."British Tennis Number",
        "Date joined venue" = s."Date joined venue",
        "Medical history" = s."Medical history",
        occupation = s.occupation,
        registered = s.registered,
        unsubscribed = s.unsubscribed,
        "Member status" = s."Member status",
        "Last active" = s."Last active",
        created = s.created,
        "Receipt of Emails" = s."Receipt of Emails",
        "Share Contact Detail" = s."Share Contact Detail",
        "Member's Directory" = s."Member's Directory",
        photography = s.photography,
        last_seen_at = v_now,
        is_current = true
    FROM tmp_matched_raw_contacts m
    JOIN tmp_stage_raw_contacts s
      ON s.source_row = m.source_row
    WHERE rc.id = m.target_id;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    INSERT INTO public.raw_contacts (
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
        first_seen_at,
        last_seen_at,
        is_current
    )
    SELECT
        s."Venue ID",
        s."Unique ID",
        s."First name",
        s."Last name",
        s.gender,
        s.age,
        s.junior,
        s."Date of birth",
        s."Email address",
        public.clean_phone_display(s."Phone number"),
        public.clean_phone_display(s."Work number"),
        public.clean_phone_display(s."Mobile number"),
        s."Emergency contact name",
        public.clean_phone_display(s."Emergency phone number"),
        s."Address 1",
        s."Address 2",
        s."Address 3",
        s.town,
        s.county,
        s.country,
        s.postcode,
        s."British Tennis Number",
        s."Date joined venue",
        s."Medical history",
        s.occupation,
        s.registered,
        s.unsubscribed,
        s."Member status",
        s."Last active",
        s.created,
        s."Receipt of Emails",
        s."Share Contact Detail",
        s."Member's Directory",
        s.photography,
        v_now,
        v_now,
        true
    FROM tmp_stage_raw_contacts s
    LEFT JOIN tmp_matched_raw_contacts m
      ON m.source_row = s.source_row
    WHERE m.source_row IS NULL;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    INSERT INTO public.raw_reconcile_match_audit (
        raw_table,
        run_at,
        source_row,
        source_name,
        matched_id,
        match_rule,
        outcome,
        candidate_count,
        candidate_ids,
        notes
    )
    SELECT
        'raw_contacts',
        v_now,
        s.source_row,
        s.source_name,
        m.target_id,
        m.match_rule,
        m.match_rule,
        1,
        to_jsonb(ARRAY[m.target_id]),
        NULL
    FROM tmp_matched_raw_contacts m
    JOIN tmp_stage_raw_contacts s
      ON s.source_row = m.source_row;

    INSERT INTO public.raw_reconcile_match_audit (
        raw_table,
        run_at,
        source_row,
        source_name,
        matched_id,
        match_rule,
        outcome,
        candidate_count,
        candidate_ids,
        notes
    )
    WITH unmatched_stage AS (
        SELECT s.*
        FROM tmp_stage_raw_contacts s
        LEFT JOIN tmp_matched_raw_contacts m
          ON m.source_row = s.source_row
        WHERE m.source_row IS NULL
    ),
    unresolved AS (
        SELECT
            s.source_row,
            s.source_name,
            COUNT(c.id) FILTER (WHERE c.norm_name = s.norm_name) AS same_name_candidate_count,
            COUNT(c.id) FILTER (
                WHERE c.norm_name = s.norm_name
                  AND (
                    (s.norm_dob IS NOT NULL AND c.norm_dob = s.norm_dob)
                    OR (
                        s.norm_postcode IS NOT NULL
                        AND s.norm_address_1 IS NOT NULL
                        AND c.norm_postcode = s.norm_postcode
                        AND c.norm_address_1 = s.norm_address_1
                    )
                    OR (s.norm_phone IS NOT NULL AND c.norm_phone = s.norm_phone)
                    OR (s.norm_email IS NOT NULL AND c.norm_email = s.norm_email)
                  )
            ) AS corroborated_candidate_count,
            COALESCE(
                jsonb_agg(c.id ORDER BY c.id) FILTER (WHERE c.norm_name = s.norm_name),
                '[]'::jsonb
            ) AS candidate_ids
        FROM unmatched_stage s
        LEFT JOIN tmp_current_raw_contacts c
          ON c.norm_name = s.norm_name
        GROUP BY s.source_row, s.source_name
    )
    SELECT
        'raw_contacts',
        v_now,
        u.source_row,
        u.source_name,
        NULL::bigint,
        CASE
            WHEN u.corroborated_candidate_count > 1 THEN 'ambiguous_multiple_candidates'
            WHEN u.same_name_candidate_count > 1 THEN 'ambiguous_same_name'
            ELSE 'new_record'
        END AS match_rule,
        CASE
            WHEN u.corroborated_candidate_count > 1 THEN 'ambiguous_multiple_candidates'
            WHEN u.same_name_candidate_count > 1 THEN 'ambiguous_same_name'
            ELSE 'new_record'
        END AS outcome,
        GREATEST(u.same_name_candidate_count, u.corroborated_candidate_count),
        u.candidate_ids,
        CASE
            WHEN u.corroborated_candidate_count > 1 THEN 'Multiple corroborated current contact candidates remain'
            WHEN u.same_name_candidate_count > 1 THEN 'Multiple same-name current contact candidates remain'
            ELSE 'Inserted as new current contact row'
        END
    FROM unresolved u;

    UPDATE public.raw_contacts rc
    SET is_current = false
    FROM tmp_current_raw_contacts c
    LEFT JOIN tmp_matched_raw_contacts m
      ON m.target_id = c.id
    WHERE rc.id = c.id
      AND m.target_id IS NULL
      AND COALESCE(rc.is_current, true) = true;
    GET DIAGNOSTICS v_deactivated = ROW_COUNT;

    RETURN QUERY SELECT v_updated, v_inserted, v_deactivated;
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_raw_members_from_staging()
RETURNS TABLE(updated_count integer, inserted_count integer, deactivated_count integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_now timestamptz := now();
    v_updated integer := 0;
    v_inserted integer := 0;
    v_deactivated integer := 0;
BEGIN
    CREATE TEMP TABLE tmp_stage_raw_members ON COMMIT DROP AS
    SELECT
        row_number() OVER (
            ORDER BY
                COALESCE("Venue ID", ''),
                COALESCE("British Tennis Number", ''),
                COALESCE("First name", ''),
                COALESCE("Last name", ''),
                COALESCE("Membership", '')
        ) AS source_row,
        trim(concat_ws(' ', s."First name", s."Last name")) AS source_name,
        s.*,
        public.normalize_match_text(s."Venue ID") AS norm_venue_id,
        public.normalize_match_text(s."British Tennis Number") AS norm_btn,
        public.normalize_match_text(concat_ws(' ', s."First name", s."Last name")) AS norm_name,
        public.normalize_match_date(s."Date of birth") AS norm_dob,
        public.normalize_match_postcode(s."Postcode") AS norm_postcode,
        public.normalize_match_address_line1(s."Address 1") AS norm_address_1,
        COALESCE(
            public.normalize_match_phone(s."Mobile number"),
            public.normalize_match_phone(s."Phone number")
        ) AS norm_phone,
        public.normalize_match_email(s."Email address") AS norm_email,
        public.normalize_match_text(s."Membership") AS norm_membership,
        public.normalize_membership_category(s."Membership") AS norm_category,
        (
            CASE WHEN public.normalize_match_postcode(s."Postcode") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_address_line1(s."Address 1") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_email(s."Email address") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(public.normalize_match_phone(s."Mobile number"), public.normalize_match_phone(s."Phone number")) IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_date(s."Date of birth") IS NOT NULL THEN 1 ELSE 0 END
        ) AS quality_score,
        CASE COALESCE(NULLIF(trim(s."Status"), ''), '')
            WHEN 'Active' THEN 0
            WHEN 'Current' THEN 1
            WHEN 'Pending' THEN 2
            ELSE 3
        END AS status_rank,
        CASE COALESCE(NULLIF(trim(s."Payment"), ''), '')
            WHEN 'Paid' THEN 0
            WHEN 'Part Paid' THEN 1
            WHEN 'Not Paid' THEN 2
            ELSE 3
        END AS payment_rank
    FROM public.raw_members_import_staging s;

    CREATE TEMP TABLE tmp_current_raw_members ON COMMIT DROP AS
    SELECT
        m.id,
        trim(concat_ws(' ', m."First name", m."Last name")) AS source_name,
        public.normalize_match_text(m."Venue ID") AS norm_venue_id,
        public.normalize_match_text(m."British Tennis Number") AS norm_btn,
        public.normalize_match_text(concat_ws(' ', m."First name", m."Last name")) AS norm_name,
        public.normalize_match_date(m."Date of birth") AS norm_dob,
        public.normalize_match_postcode(m."Postcode") AS norm_postcode,
        public.normalize_match_address_line1(m."Address 1") AS norm_address_1,
        COALESCE(
            public.normalize_match_phone(m."Mobile number"),
            public.normalize_match_phone(m."Phone number")
        ) AS norm_phone,
        public.normalize_match_email(m."Email address") AS norm_email,
        public.normalize_match_text(m."Membership") AS norm_membership,
        public.normalize_membership_category(m."Membership") AS norm_category,
        (
            CASE WHEN public.normalize_match_postcode(m."Postcode") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_address_line1(m."Address 1") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_email(m."Email address") IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(public.normalize_match_phone(m."Mobile number"), public.normalize_match_phone(m."Phone number")) IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN public.normalize_match_date(m."Date of birth") IS NOT NULL THEN 1 ELSE 0 END
        ) AS quality_score,
        CASE COALESCE(NULLIF(trim(m."Status"), ''), '')
            WHEN 'Active' THEN 0
            WHEN 'Current' THEN 1
            WHEN 'Pending' THEN 2
            ELSE 3
        END AS status_rank,
        CASE COALESCE(NULLIF(trim(m."Payment"), ''), '')
            WHEN 'Paid' THEN 0
            WHEN 'Part Paid' THEN 1
            WHEN 'Not Paid' THEN 2
            ELSE 3
        END AS payment_rank
    FROM public.raw_members m
    WHERE COALESCE(m.is_current, true) = true;

    CREATE TEMP TABLE tmp_matched_raw_members (
        source_row integer PRIMARY KEY,
        target_id bigint UNIQUE,
        match_rule text NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_venue_id'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_venue_id = s.norm_venue_id
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
         AND (
            s.norm_name IS NULL
            OR c.norm_name IS NULL
            OR c.norm_name = s.norm_name
         )
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_venue_id IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_btn'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_btn = s.norm_btn
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
         AND (
            s.norm_name IS NULL
            OR c.norm_name IS NULL
            OR c.norm_name = s.norm_name
         )
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_btn IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_dob'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_name = s.norm_name
         AND c.norm_dob = s.norm_dob
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_dob IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_address'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_name = s.norm_name
         AND c.norm_postcode = s.norm_postcode
         AND c.norm_address_1 = s.norm_address_1
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_postcode IS NOT NULL
          AND s.norm_address_1 IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_phone'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_name = s.norm_name
         AND c.norm_phone = s.norm_phone
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_phone IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_email'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_name = s.norm_name
         AND c.norm_email = s.norm_email
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND s.norm_email IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH candidates AS (
        SELECT
            s.source_row,
            c.id AS target_id,
            'matched_by_name_only'::text AS match_rule,
            count(*) OVER (PARTITION BY s.source_row) AS candidate_count,
            row_number() OVER (
                PARTITION BY s.source_row
                ORDER BY c.quality_score DESC, c.status_rank ASC, c.payment_rank ASC, c.id
            ) AS source_rank,
            row_number() OVER (
                PARTITION BY c.id
                ORDER BY s.quality_score DESC, s.status_rank ASC, s.payment_rank ASC, s.source_row
            ) AS target_rank
        FROM tmp_stage_raw_members s
        JOIN tmp_current_raw_members c
          ON c.norm_name = s.norm_name
         AND COALESCE(c.norm_membership, '') = COALESCE(s.norm_membership, '')
        LEFT JOIN tmp_matched_raw_members ms
          ON ms.source_row = s.source_row
        LEFT JOIN tmp_matched_raw_members mc
          ON mc.target_id = c.id
        WHERE s.norm_name IS NOT NULL
          AND ms.source_row IS NULL
          AND mc.target_id IS NULL
    )
    SELECT source_row, target_id, match_rule
    FROM candidates
    WHERE source_rank = 1
      AND target_rank = 1;

    UPDATE public.raw_members rm
    SET
        "Venue ID" = s."Venue ID",
        "First name" = s."First name",
        "Last name" = s."Last name",
        "Gender" = s."Gender",
        "Age" = s."Age",
        "Junior" = s."Junior",
        "Date of birth" = s."Date of birth",
        "Membership" = s."Membership",
        "Payment" = s."Payment",
        "Cost" = s."Cost",
        "Paid" = s."Paid",
        "Paid Credit Card" = s."Paid Credit Card",
        "Paid Direct Debit" = s."Paid Direct Debit",
        "Paid Cash" = s."Paid Cash",
        "Paid Cheque" = s."Paid Cheque",
        "Paid Other" = s."Paid Other",
        "Gift aid" = s."Gift aid",
        "Status" = s."Status",
        "Start Date" = s."Start Date",
        "Expiry Date" = s."Expiry Date",
        "Email address" = s."Email address",
        "Phone number" = public.clean_phone_display(s."Phone number"),
        "Work number" = public.clean_phone_display(s."Work number"),
        "Mobile number" = public.clean_phone_display(s."Mobile number"),
        "Emergency contact name" = s."Emergency contact name",
        "Emergency phone number" = public.clean_phone_display(s."Emergency phone number"),
        "Address 1" = s."Address 1",
        "Address 2" = s."Address 2",
        "Address 3" = s."Address 3",
        "Town" = s."Town",
        "County" = s."County",
        "Country" = s."Country",
        "Postcode" = s."Postcode",
        "British Tennis Number" = s."British Tennis Number",
        "Date joined venue" = s."Date joined venue",
        "Medical history" = s."Medical history",
        "Venue source" = s."Venue source",
        "Contact source" = s."Contact source",
        "Occupation" = s."Occupation",
        "Tags provided" = s."Tags provided",
        "Key pin number" = s."Key pin number",
        "Registered" = s."Registered",
        "Member status" = s."Member status",
        "Receipt of Emails" = s."Receipt of Emails",
        "Share Contact Detail" = s."Share Contact Detail",
        "Member's Directory" = s."Member's Directory",
        "Photography" = s."Photography",
        " Venue source" = s." Venue source",
        last_seen_at = v_now,
        is_current = true
    FROM tmp_matched_raw_members m
    JOIN tmp_stage_raw_members s
      ON s.source_row = m.source_row
    WHERE rm.id = m.target_id;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    INSERT INTO public.raw_members (
        "Venue ID",
        "First name",
        "Last name",
        "Gender",
        "Age",
        "Junior",
        "Date of birth",
        "Membership",
        "Payment",
        "Cost",
        "Paid",
        "Paid Credit Card",
        "Paid Direct Debit",
        "Paid Cash",
        "Paid Cheque",
        "Paid Other",
        "Gift aid",
        "Status",
        "Start Date",
        "Expiry Date",
        "Email address",
        "Phone number",
        "Work number",
        "Mobile number",
        "Emergency contact name",
        "Emergency phone number",
        "Address 1",
        "Address 2",
        "Address 3",
        "Town",
        "County",
        "Country",
        "Postcode",
        "British Tennis Number",
        "Date joined venue",
        "Medical history",
        "Venue source",
        "Contact source",
        "Occupation",
        "Tags provided",
        "Key pin number",
        "Registered",
        "Member status",
        "Receipt of Emails",
        "Share Contact Detail",
        "Member's Directory",
        "Photography",
        " Venue source",
        first_seen_at,
        last_seen_at,
        is_current
    )
    SELECT
        s."Venue ID",
        s."First name",
        s."Last name",
        s."Gender",
        s."Age",
        s."Junior",
        s."Date of birth",
        s."Membership",
        s."Payment",
        s."Cost",
        s."Paid",
        s."Paid Credit Card",
        s."Paid Direct Debit",
        s."Paid Cash",
        s."Paid Cheque",
        s."Paid Other",
        s."Gift aid",
        s."Status",
        s."Start Date",
        s."Expiry Date",
        s."Email address",
        public.clean_phone_display(s."Phone number"),
        public.clean_phone_display(s."Work number"),
        public.clean_phone_display(s."Mobile number"),
        s."Emergency contact name",
        public.clean_phone_display(s."Emergency phone number"),
        s."Address 1",
        s."Address 2",
        s."Address 3",
        s."Town",
        s."County",
        s."Country",
        s."Postcode",
        s."British Tennis Number",
        s."Date joined venue",
        s."Medical history",
        s."Venue source",
        s."Contact source",
        s."Occupation",
        s."Tags provided",
        s."Key pin number",
        s."Registered",
        s."Member status",
        s."Receipt of Emails",
        s."Share Contact Detail",
        s."Member's Directory",
        s."Photography",
        s." Venue source",
        v_now,
        v_now,
        true
    FROM tmp_stage_raw_members s
    LEFT JOIN tmp_matched_raw_members m
      ON m.source_row = s.source_row
    WHERE m.source_row IS NULL;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    INSERT INTO public.raw_reconcile_match_audit (
        raw_table,
        run_at,
        source_row,
        source_name,
        source_membership,
        matched_id,
        match_rule,
        outcome,
        candidate_count,
        candidate_ids,
        notes
    )
    SELECT
        'raw_members',
        v_now,
        s.source_row,
        s.source_name,
        s."Membership",
        m.target_id,
        m.match_rule,
        m.match_rule,
        1,
        to_jsonb(ARRAY[m.target_id]),
        NULL
    FROM tmp_matched_raw_members m
    JOIN tmp_stage_raw_members s
      ON s.source_row = m.source_row;

    INSERT INTO public.raw_reconcile_match_audit (
        raw_table,
        run_at,
        source_row,
        source_name,
        source_membership,
        matched_id,
        match_rule,
        outcome,
        candidate_count,
        candidate_ids,
        notes
    )
    WITH unmatched_stage AS (
        SELECT s.*
        FROM tmp_stage_raw_members s
        LEFT JOIN tmp_matched_raw_members m
          ON m.source_row = s.source_row
        WHERE m.source_row IS NULL
    ),
    unresolved AS (
        SELECT
            s.source_row,
            s.source_name,
            s."Membership" AS source_membership,
            COUNT(c.id) FILTER (WHERE c.norm_name = s.norm_name) AS same_name_candidate_count,
            COUNT(c.id) FILTER (
                WHERE c.norm_name = s.norm_name
                  AND (
                    (s.norm_dob IS NOT NULL AND c.norm_dob = s.norm_dob)
                    OR (
                        s.norm_postcode IS NOT NULL
                        AND s.norm_address_1 IS NOT NULL
                        AND c.norm_postcode = s.norm_postcode
                        AND c.norm_address_1 = s.norm_address_1
                    )
                    OR (s.norm_phone IS NOT NULL AND c.norm_phone = s.norm_phone)
                    OR (s.norm_email IS NOT NULL AND c.norm_email = s.norm_email)
                  )
            ) AS corroborated_candidate_count,
            COALESCE(
                jsonb_agg(c.id ORDER BY c.id) FILTER (WHERE c.norm_name = s.norm_name),
                '[]'::jsonb
            ) AS candidate_ids
        FROM unmatched_stage s
        LEFT JOIN tmp_current_raw_members c
          ON c.norm_name = s.norm_name
        GROUP BY s.source_row, s.source_name, s."Membership"
    )
    SELECT
        'raw_members',
        v_now,
        u.source_row,
        u.source_name,
        u.source_membership,
        NULL::bigint,
        CASE
            WHEN u.corroborated_candidate_count > 1 THEN 'ambiguous_multiple_candidates'
            WHEN u.same_name_candidate_count > 1 THEN 'ambiguous_same_name'
            ELSE 'new_record'
        END AS match_rule,
        CASE
            WHEN u.corroborated_candidate_count > 1 THEN 'ambiguous_multiple_candidates'
            WHEN u.same_name_candidate_count > 1 THEN 'ambiguous_same_name'
            ELSE 'new_record'
        END AS outcome,
        GREATEST(u.same_name_candidate_count, u.corroborated_candidate_count),
        u.candidate_ids,
        CASE
            WHEN u.corroborated_candidate_count > 1 THEN 'Multiple corroborated current member candidates remain'
            WHEN u.same_name_candidate_count > 1 THEN 'Multiple same-name current member candidates remain'
            ELSE 'Inserted as new current member row'
        END
    FROM unresolved u;

    UPDATE public.raw_members rm
    SET is_current = false
    FROM tmp_current_raw_members c
    LEFT JOIN tmp_matched_raw_members m
      ON m.target_id = c.id
    WHERE rm.id = c.id
      AND m.target_id IS NULL
      AND COALESCE(rm.is_current, true) = true;
    GET DIAGNOSTICS v_deactivated = ROW_COUNT;

    RETURN QUERY SELECT v_updated, v_inserted, v_deactivated;
END;
$$;

CREATE OR REPLACE VIEW public.vw_raw_contacts_match_review AS
SELECT
    id,
    run_at,
    source_row,
    source_name,
    matched_id,
    match_rule,
    outcome,
    candidate_count,
    candidate_ids,
    notes
FROM public.raw_reconcile_match_audit
WHERE raw_table = 'raw_contacts'
ORDER BY run_at DESC, id DESC;

CREATE OR REPLACE VIEW public.vw_raw_members_match_review AS
SELECT
    id,
    run_at,
    source_row,
    source_name,
    source_membership,
    matched_id,
    match_rule,
    outcome,
    candidate_count,
    candidate_ids,
    notes
FROM public.raw_reconcile_match_audit
WHERE raw_table = 'raw_members'
ORDER BY run_at DESC, id DESC;

CREATE OR REPLACE VIEW public.vw_raw_ambiguous_matches AS
SELECT
    raw_table,
    run_at,
    source_row,
    source_name,
    source_membership,
    matched_id,
    match_rule,
    outcome,
    candidate_count,
    candidate_ids,
    notes
FROM public.raw_reconcile_match_audit
WHERE outcome IN ('ambiguous_same_name', 'ambiguous_multiple_candidates')
ORDER BY run_at DESC, raw_table, source_name, id DESC;

CREATE OR REPLACE VIEW public.vw_raw_weak_name_only_matches AS
SELECT
    raw_table,
    run_at,
    source_row,
    source_name,
    source_membership,
    matched_id,
    match_rule,
    outcome,
    candidate_count,
    candidate_ids,
    notes
FROM public.raw_reconcile_match_audit
WHERE outcome = 'matched_by_name_only'
ORDER BY run_at DESC, raw_table, source_name, id DESC;

COMMIT;
