-- Stage 6 of the raw table primary-key rollout.
-- Reconcile staging rows onto durable current tables while preserving IDs.

BEGIN;

CREATE OR REPLACE FUNCTION public.normalize_match_text(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        regexp_replace(lower(trim(COALESCE(value, ''))), '\s+', ' ', 'g'),
        ''
    );
$$;

CREATE OR REPLACE FUNCTION public.normalize_membership_category(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        trim(
            regexp_replace(
                regexp_replace(
                    lower(COALESCE(value, '')),
                    '^[a-z0-9]+\.\s*',
                    '',
                    'i'
                ),
                '\s+20\d{2}(\s*/\s*20\d{2})?$',
                '',
                'i'
            )
        ),
        ''
    );
$$;

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
        row_number() OVER (ORDER BY COALESCE("Venue ID", ''), COALESCE("Unique ID", ''), COALESCE("First name", ''), COALESCE("Last name", '')) AS source_row,
        s.*,
        public.normalize_match_text(s."Venue ID") AS norm_venue_id,
        public.normalize_match_text(COALESCE(s."British Tennis Number"::text, '')) AS norm_btn,
        public.normalize_match_text(CONCAT_WS(' ', s."First name", s."Last name")) AS norm_name,
        (
            CASE WHEN NULLIF(trim(COALESCE(s."Address 1", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN NULLIF(trim(COALESCE(s.postcode, '')), '') IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN NULLIF(trim(COALESCE(s."Email address", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN NULLIF(trim(COALESCE(s."Mobile number", '')), '') IS NOT NULL THEN 1 ELSE 0 END
        ) AS quality_score
    FROM public.raw_contacts_import_staging s;

    CREATE TEMP TABLE tmp_current_raw_contacts ON COMMIT DROP AS
    SELECT
        c.id,
        public.normalize_match_text(c."Venue ID") AS norm_venue_id,
        public.normalize_match_text(COALESCE(c."British Tennis Number"::text, '')) AS norm_btn,
        public.normalize_match_text(CONCAT_WS(' ', c."First name", c."Last name")) AS norm_name,
        (
            CASE WHEN NULLIF(trim(COALESCE(c."Address 1", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN NULLIF(trim(COALESCE(c.postcode, '')), '') IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN NULLIF(trim(COALESCE(c."Email address", '')), '') IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN NULLIF(trim(COALESCE(c."Mobile number", '')), '') IS NOT NULL THEN 1 ELSE 0 END
        ) AS quality_score
    FROM public.raw_contacts c
    WHERE COALESCE(c.is_current, true) = true;

    CREATE TEMP TABLE tmp_matched_raw_contacts (
        source_row integer PRIMARY KEY,
        target_id bigint UNIQUE,
        match_rule text NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            source_row,
            norm_venue_id,
            row_number() OVER (
                PARTITION BY norm_venue_id
                ORDER BY quality_score DESC, source_row
            ) AS rn
        FROM tmp_stage_raw_contacts
        WHERE norm_venue_id IS NOT NULL
    ),
    current_ranked AS (
        SELECT
            id,
            norm_venue_id,
            row_number() OVER (
                PARTITION BY norm_venue_id
                ORDER BY quality_score DESC, id
            ) AS rn
        FROM tmp_current_raw_contacts
        WHERE norm_venue_id IS NOT NULL
    )
    SELECT
        s.source_row,
        c.id,
        'venue_id'
    FROM stage_ranked s
    JOIN current_ranked c
      ON c.norm_venue_id = s.norm_venue_id
     AND c.rn = s.rn;

    INSERT INTO tmp_matched_raw_contacts (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            s.source_row,
            s.norm_name,
            row_number() OVER (
                PARTITION BY s.norm_name
                ORDER BY s.quality_score DESC, s.source_row
            ) AS rn
        FROM tmp_stage_raw_contacts s
        LEFT JOIN tmp_matched_raw_contacts m
          ON m.source_row = s.source_row
        WHERE m.source_row IS NULL
          AND s.norm_name IS NOT NULL
    ),
    current_ranked AS (
        SELECT
            c.id,
            c.norm_name,
            row_number() OVER (
                PARTITION BY c.norm_name
                ORDER BY c.quality_score DESC, c.id
            ) AS rn
        FROM tmp_current_raw_contacts c
        LEFT JOIN tmp_matched_raw_contacts m
          ON m.target_id = c.id
        WHERE m.target_id IS NULL
          AND c.norm_name IS NOT NULL
    )
    SELECT
        s.source_row,
        c.id,
        'name'
    FROM stage_ranked s
    JOIN current_ranked c
      ON c.norm_name = s.norm_name
     AND c.rn = s.rn;

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
        "Phone number" = s."Phone number",
        "Work number" = s."Work number",
        "Mobile number" = s."Mobile number",
        "Emergency contact name" = s."Emergency contact name",
        "Emergency phone number" = s."Emergency phone number",
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
        s."Phone number",
        s."Work number",
        s."Mobile number",
        s."Emergency contact name",
        s."Emergency phone number",
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
        row_number() OVER (ORDER BY COALESCE("Venue ID", ''), COALESCE("British Tennis Number", ''), COALESCE("First name", ''), COALESCE("Last name", ''), COALESCE("Membership", '')) AS source_row,
        s.*,
        public.normalize_match_text(s."Venue ID") AS norm_venue_id,
        public.normalize_match_text(s."British Tennis Number") AS norm_btn,
        public.normalize_match_text(CONCAT_WS(' ', s."First name", s."Last name")) AS norm_name,
        public.normalize_membership_category(s."Membership") AS norm_category
    FROM public.raw_members_import_staging s;

    CREATE TEMP TABLE tmp_current_raw_members ON COMMIT DROP AS
    SELECT
        m.id,
        public.normalize_match_text(m."Venue ID") AS norm_venue_id,
        public.normalize_match_text(m."British Tennis Number") AS norm_btn,
        public.normalize_match_text(CONCAT_WS(' ', m."First name", m."Last name")) AS norm_name,
        public.normalize_membership_category(m."Membership") AS norm_category
    FROM public.raw_members m
    WHERE COALESCE(m.is_current, true) = true;

    CREATE TEMP TABLE tmp_matched_raw_members (
        source_row integer PRIMARY KEY,
        target_id bigint UNIQUE,
        match_rule text NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            source_row,
            norm_venue_id,
            row_number() OVER (
                PARTITION BY norm_venue_id
                ORDER BY source_row
            ) AS rn
        FROM tmp_stage_raw_members
        WHERE norm_venue_id IS NOT NULL
    ),
    current_ranked AS (
        SELECT
            id,
            norm_venue_id,
            row_number() OVER (
                PARTITION BY norm_venue_id
                ORDER BY id
            ) AS rn
        FROM tmp_current_raw_members
        WHERE norm_venue_id IS NOT NULL
    )
    SELECT
        s.source_row,
        c.id,
        'venue_id'
    FROM stage_ranked s
    JOIN current_ranked c
      ON c.norm_venue_id = s.norm_venue_id
     AND c.rn = s.rn;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            s.source_row,
            s.norm_btn,
            row_number() OVER (
                PARTITION BY s.norm_btn
                ORDER BY s.source_row
            ) AS rn
        FROM tmp_stage_raw_members s
        LEFT JOIN tmp_matched_raw_members m
          ON m.source_row = s.source_row
        WHERE m.source_row IS NULL
          AND s.norm_btn IS NOT NULL
    ),
    current_ranked AS (
        SELECT
            c.id,
            c.norm_btn,
            row_number() OVER (
                PARTITION BY c.norm_btn
                ORDER BY c.id
            ) AS rn
        FROM tmp_current_raw_members c
        LEFT JOIN tmp_matched_raw_members m
          ON m.target_id = c.id
        WHERE m.target_id IS NULL
          AND c.norm_btn IS NOT NULL
    )
    SELECT
        s.source_row,
        c.id,
        'british_tennis_number'
    FROM stage_ranked s
    JOIN current_ranked c
      ON c.norm_btn = s.norm_btn
     AND c.rn = s.rn;

    INSERT INTO tmp_matched_raw_members (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            s.source_row,
            s.norm_name,
            s.norm_category,
            row_number() OVER (
                PARTITION BY s.norm_name, s.norm_category
                ORDER BY s.source_row
            ) AS rn
        FROM tmp_stage_raw_members s
        LEFT JOIN tmp_matched_raw_members m
          ON m.source_row = s.source_row
        WHERE m.source_row IS NULL
          AND s.norm_name IS NOT NULL
          AND s.norm_category IS NOT NULL
    ),
    current_ranked AS (
        SELECT
            c.id,
            c.norm_name,
            c.norm_category,
            row_number() OVER (
                PARTITION BY c.norm_name, c.norm_category
                ORDER BY c.id
            ) AS rn
        FROM tmp_current_raw_members c
        LEFT JOIN tmp_matched_raw_members m
          ON m.target_id = c.id
        WHERE m.target_id IS NULL
          AND c.norm_name IS NOT NULL
          AND c.norm_category IS NOT NULL
    )
    SELECT
        s.source_row,
        c.id,
        'name_category'
    FROM stage_ranked s
    JOIN current_ranked c
      ON c.norm_name = s.norm_name
     AND c.norm_category = s.norm_category
     AND c.rn = s.rn;

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
        "Phone number" = s."Phone number",
        "Work number" = s."Work number",
        "Mobile number" = s."Mobile number",
        "Emergency contact name" = s."Emergency contact name",
        "Emergency phone number" = s."Emergency phone number",
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
        s."Phone number",
        s."Work number",
        s."Mobile number",
        s."Emergency contact name",
        s."Emergency phone number",
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

COMMIT;
