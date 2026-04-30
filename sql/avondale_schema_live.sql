--
-- PostgreSQL database dump
--

\restrict OenAnmWAd06GyAeKIURUwarG3he6g3VL2C9hc8IQTMWdisRrueYs12Wtn4aaUdh

-- Dumped from database version 15.16 (Debian 15.16-0+deb12u1)
-- Dumped by pg_dump version 18.3 (Ubuntu 18.3-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: archive_raw_contacts_yearly_snapshot(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.archive_raw_contacts_yearly_snapshot(p_snapshot_year integer DEFAULT (EXTRACT(year FROM CURRENT_DATE))::integer) RETURNS TABLE(snapshot_year integer, archived_row_count integer)
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


--
-- Name: capture_membership_history_snapshot(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.capture_membership_history_snapshot(p_snapshot_key text, p_source_season text DEFAULT NULL::text) RETURNS TABLE(snapshot_key text, source_season text, rows_written integer, updated_membership_history boolean)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_snapshot_key text := trim(coalesce(p_snapshot_key, ''));
  v_source_season text := trim(coalesce(p_source_season, ''));
  v_rows_written integer := 0;
BEGIN
  IF v_snapshot_key = '' THEN
    RAISE EXCEPTION 'snapshot_key is required';
  END IF;

  IF v_source_season = '' AND v_snapshot_key ~ '^\d{4}/\d{4}$' THEN
    v_source_season := split_part(v_snapshot_key, '/', 1);
  END IF;

  IF v_source_season = '' THEN
    RAISE EXCEPTION 'source_season is required';
  END IF;

  UPDATE public.membership_history
  SET membership = 'Honorary'
  WHERE membership = 'Senior - honorary';

  UPDATE public.membership_history
  SET membership = 'Student At Home'
  WHERE membership = 'Student at home';

  UPDATE public.membership_history
  SET membership = 'Student Away'
  WHERE membership = 'Student away from home';

  INSERT INTO public.membership_history (membership)
  SELECT v.membership
  FROM (VALUES
    ('Family'),
    ('Senior Junior'),
    ('Mini (U10)'),
    ('Parent'),
    ('Young Adult'),
    ('Total')
  ) AS v(membership)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.membership_history h
    WHERE h.membership = v.membership
  );

  WITH season_counts AS (
    SELECT
      p.category AS membership,
      COUNT(*)::integer AS member_count
    FROM public.raw_members m
    JOIN public.membership_packages p
      ON m."Membership" = p.name
    WHERE p.season = v_source_season
      AND p.category <> 'Pavilion Key'
      AND m."Payment" IN ('Paid', 'Part Paid')
      AND m."Status" = 'Active'
    GROUP BY p.category
  ),
  total_row AS (
    SELECT
      'Total'::text AS membership,
      COALESCE(SUM(member_count), 0)::integer AS member_count
    FROM season_counts
  ),
  snapshot_rows AS (
    SELECT * FROM season_counts
    UNION ALL
    SELECT * FROM total_row
  ),
  upserted AS (
    INSERT INTO public.membership_history_snapshots (
      snapshot_key,
      source_season,
      membership,
      member_count
    )
    SELECT
      v_snapshot_key,
      v_source_season,
      sr.membership,
      sr.member_count
    FROM snapshot_rows sr
    ON CONFLICT ON CONSTRAINT membership_history_snapshots_snapshot_key_membership_key
    DO UPDATE SET
      source_season = EXCLUDED.source_season,
      member_count = EXCLUDED.member_count,
      captured_at = now()
    RETURNING 1
  )
  SELECT COUNT(*)::integer INTO v_rows_written
  FROM upserted;

  IF v_snapshot_key ~ '^\d{4}/\d{4}$' THEN
    EXECUTE format(
      'ALTER TABLE public.membership_history ADD COLUMN IF NOT EXISTS %I integer',
      v_snapshot_key
    );

    EXECUTE format(
      'UPDATE public.membership_history h
       SET %1$I = s.member_count
       FROM public.membership_history_snapshots s
       WHERE s.snapshot_key = %2$L
         AND h.membership = s.membership',
      v_snapshot_key,
      v_snapshot_key
    );
  END IF;

  RETURN QUERY
  SELECT
    v_snapshot_key,
    v_source_season,
    v_rows_written,
    true;
END;
$_$;


--
-- Name: clean_phone_display(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clean_phone_display(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(
        trim(regexp_replace(COALESCE(value, ''), '[\[\]]+', '', 'g')),
        ''
    );
$$;


--
-- Name: fn_add_team_player(bigint, text, boolean, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_add_team_player(p_team_id bigint, p_source_name text, p_is_captain boolean DEFAULT false, p_sort_order integer DEFAULT NULL::integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id bigint;
    v_next_order integer;
BEGIN
    IF p_sort_order IS NULL THEN
        SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_next_order FROM public.team_players WHERE team_id = p_team_id;
    ELSE
        v_next_order := p_sort_order;
    END IF;

    INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
    VALUES (p_team_id, p_source_name, p_is_captain, v_next_order)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;


--
-- Name: fn_get_team_mailout_job(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_get_team_mailout_job(p_team_id bigint) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_res jsonb;
BEGIN
    WITH team_snapshot AS (
        SELECT 
            t.id, t.doc_source, t.team_name, t.section, t.sort_order, t.season,
            (SELECT team_name FROM public.teams 
             WHERE section = t.section AND season = t.season AND sort_order > t.sort_order 
             ORDER BY sort_order ASC LIMIT 1) AS next_team_name,
            -- Pre-calculate slugs
            trim(both '-' from regexp_replace(lower(t.team_name), '[^a-z0-9]+', '-', 'g')) as own_slug,
            (SELECT trim(both '-' from regexp_replace(lower(team_name), '[^a-z0-9]+', '-', 'g')) FROM public.teams 
             WHERE section = t.section AND season = t.season AND sort_order > t.sort_order 
             ORDER BY sort_order ASC LIMIT 1) as next_slug,
            'reserves' as reserves_slug
        FROM public.teams t
        WHERE t.id = p_team_id
    ),
    captain_info AS (
        SELECT 
            m.source_name AS captain_name,
            m.self_email AS captain_email,
            m.resolved_name AS captain_resolved_name
        FROM public.vw_appsmith_team_player_matching m
        JOIN public.team_players tp ON tp.id = m.team_player_id
        WHERE tp.team_id = p_team_id AND tp.is_captain = true
        LIMIT 1
    )
    SELECT jsonb_build_object(
        'source_doc', ts.doc_source,
        'section', ts.section,
        'team_name', ts.team_name,
        'next_team_name', COALESCE(ts.next_team_name, 'Reserves'),
        'captain_name', COALESCE(ci.captain_name, 'Unknown Captain'),
        'captain_email', COALESCE(ci.captain_email, ''),
        'own_pdf', ts.doc_source || ' - ' || ts.own_slug || '.pdf',
        'next_pdf', CASE 
                      WHEN ts.next_team_name IS NOT NULL THEN ts.doc_source || ' - ' || ts.next_slug || '.pdf' 
                      ELSE ts.doc_source || ' - ' || ts.reserves_slug || '.pdf' 
                    END,
        'reserves_pdf', ts.doc_source || ' - ' || ts.reserves_slug || '.pdf',
        'can_send', CASE WHEN ci.captain_email IS NOT NULL AND ci.captain_email != '' THEN true ELSE false END,
        'season', ts.season
    ) INTO v_res
    FROM team_snapshot ts
    LEFT JOIN captain_info ci ON true;

    RETURN v_res;
END;
$$;


--
-- Name: fn_remove_team_player(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_remove_team_player(p_player_id bigint) RETURNS boolean
    LANGUAGE sql
    AS $$
    DELETE FROM public.team_players WHERE id = p_player_id RETURNING true;
$$;


--
-- Name: fn_update_team_player(bigint, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_update_team_player(p_player_id bigint, p_source_name text DEFAULT NULL::text, p_is_captain boolean DEFAULT NULL::boolean) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.team_players
    SET source_name = COALESCE(p_source_name, source_name),
        is_captain = COALESCE(p_is_captain, is_captain)
    WHERE id = p_player_id;
    RETURN FOUND;
END;
$$;


--
-- Name: normalize_match_address_line1(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_address_line1(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(
        regexp_replace(lower(trim(COALESCE(value, ''))), '[^a-z0-9]+', '', 'g'),
        ''
    );
$$;


--
-- Name: normalize_match_date(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_date(value text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
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
$_$;


--
-- Name: normalize_match_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_email(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(lower(trim(COALESCE(value, ''))), '');
$$;


--
-- Name: normalize_match_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_phone(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(
        regexp_replace(COALESCE(value, ''), '[^0-9]+', '', 'g'),
        ''
    );
$$;


--
-- Name: normalize_match_postcode(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_postcode(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(
        regexp_replace(upper(trim(COALESCE(value, ''))), '\s+', '', 'g'),
        ''
    );
$$;


--
-- Name: normalize_match_text(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_text(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NULLIF(
        regexp_replace(lower(trim(COALESCE(value, ''))), '\s+', ' ', 'g'),
        ''
    );
$$;


--
-- Name: normalize_membership_category(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_membership_category(value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
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
$_$;


--
-- Name: prepare_raw_contacts_import(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prepare_raw_contacts_import(p_new_snapshot_year integer DEFAULT (EXTRACT(year FROM CURRENT_DATE))::integer) RETURNS TABLE(previous_snapshot_year integer, archived_row_count integer, current_snapshot_year integer)
    LANGUAGE plpgsql
    AS $$
begin
    raise exception 'prepare_raw_contacts_import(%) is retired. Use prepare_raw_contacts_import_staging() and reconcile_raw_contacts_from_staging() instead.', p_new_snapshot_year;
end;
$$;


--
-- Name: prepare_raw_contacts_import_staging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prepare_raw_contacts_import_staging() RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE public.raw_contacts_import_staging;
    RETURN 1;
END;
$$;


--
-- Name: prepare_raw_members_import(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prepare_raw_members_import(p_new_snapshot_year integer DEFAULT (EXTRACT(year FROM CURRENT_DATE))::integer) RETURNS TABLE(previous_snapshot_year integer, archived_row_count integer, current_snapshot_year integer)
    LANGUAGE plpgsql
    AS $$
begin
    raise exception 'prepare_raw_members_import(%) is retired. Use prepare_raw_members_import_staging() and reconcile_raw_members_from_staging() instead.', p_new_snapshot_year;
end;
$$;


--
-- Name: prepare_raw_members_import_staging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prepare_raw_members_import_staging() RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE public.raw_members_import_staging;
    RETURN 1;
END;
$$;


--
-- Name: prepare_raw_members_main_contacts_import_staging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prepare_raw_members_main_contacts_import_staging() RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE public.raw_members_main_contacts_import_staging;
    RETURN 1;
END;
$$;


--
-- Name: raw_contacts_history_identity_key(text, text, integer, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.raw_contacts_history_identity_key(p_venue_id text, p_unique_id text, p_british_tennis_number integer, p_email_address text, p_first_name text, p_last_name text, p_postcode text, p_address_1 text) RETURNS text
    LANGUAGE sql IMMUTABLE
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


--
-- Name: reconcile_raw_contacts_from_staging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reconcile_raw_contacts_from_staging() RETURNS TABLE(updated_count integer, inserted_count integer, deactivated_count integer)
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


--
-- Name: reconcile_raw_members_from_staging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reconcile_raw_members_from_staging() RETURNS TABLE(updated_count integer, inserted_count integer, deactivated_count integer)
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
        NULLIF(substring(s."Membership" from '(20[0-9]{2})'), '') AS membership_season,
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
        NULLIF(substring(m."Membership" from '(20[0-9]{2})'), '') AS membership_season,
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

    UPDATE public.raw_members rm
    SET "Status" = 'Cancelled'
    FROM tmp_current_raw_members c
    LEFT JOIN tmp_matched_raw_members m
      ON m.target_id = c.id
    WHERE rm.id = c.id
      AND m.target_id IS NULL
      AND c.membership_season IS NOT NULL
      AND COALESCE(rm."Status", '') <> 'Cancelled'
      AND EXISTS (
          SELECT 1
          FROM tmp_stage_raw_members s
          WHERE s.membership_season = c.membership_season
            AND s.norm_name = c.norm_name
            AND COALESCE(s.norm_membership, '') <> COALESCE(c.norm_membership, '')
            AND (
                (c.norm_venue_id IS NOT NULL AND s.norm_venue_id = c.norm_venue_id)
                OR (c.norm_btn IS NOT NULL AND s.norm_btn = c.norm_btn)
                OR (c.norm_dob IS NOT NULL AND s.norm_dob = c.norm_dob)
                OR (c.norm_email IS NOT NULL AND s.norm_email = c.norm_email)
                OR (c.norm_phone IS NOT NULL AND s.norm_phone = c.norm_phone)
                OR (
                    c.norm_postcode IS NOT NULL
                    AND c.norm_address_1 IS NOT NULL
                    AND s.norm_postcode = c.norm_postcode
                    AND s.norm_address_1 = c.norm_address_1
                )
            )
      );

    RETURN QUERY SELECT v_updated, v_inserted, v_deactivated;
END;
$$;


--
-- Name: reconcile_raw_members_main_contacts_from_staging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reconcile_raw_members_main_contacts_from_staging() RETURNS TABLE(updated_count integer, inserted_count integer, deactivated_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_now timestamptz := now();
    v_updated integer := 0;
    v_inserted integer := 0;
    v_deactivated integer := 0;
BEGIN
    CREATE TEMP TABLE tmp_stage_raw_members_main_contacts ON COMMIT DROP AS
    SELECT
        row_number() OVER (
            ORDER BY
                COALESCE("Venue ID", ''),
                COALESCE("British Tennis Number", ''),
                COALESCE("First name", ''),
                COALESCE("Last name", ''),
                COALESCE("Membership", '')
        ) AS source_row,
        s.*,
        public.normalize_match_text(s."Venue ID") AS norm_venue_id,
        public.normalize_match_text(s."British Tennis Number") AS norm_btn,
        public.normalize_match_text(CONCAT_WS(' ', s."First name", s."Last name")) AS norm_name,
        public.normalize_membership_category(s."Membership") AS norm_category
    FROM public.raw_members_main_contacts_import_staging s;

    CREATE TEMP TABLE tmp_current_raw_members_main_contacts ON COMMIT DROP AS
    SELECT
        m.id,
        public.normalize_match_text(m."Venue ID") AS norm_venue_id,
        public.normalize_match_text(m."British Tennis Number") AS norm_btn,
        public.normalize_match_text(CONCAT_WS(' ', m."First name", m."Last name")) AS norm_name,
        public.normalize_membership_category(m."Membership") AS norm_category
    FROM public.raw_members_main_contacts m
    WHERE COALESCE(m.is_current, true) = true;

    CREATE TEMP TABLE tmp_matched_raw_members_main_contacts (
        source_row integer PRIMARY KEY,
        target_id bigint UNIQUE,
        match_rule text NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO tmp_matched_raw_members_main_contacts (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            source_row,
            norm_venue_id,
            row_number() OVER (
                PARTITION BY norm_venue_id
                ORDER BY source_row
            ) AS rn
        FROM tmp_stage_raw_members_main_contacts
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
        FROM tmp_current_raw_members_main_contacts
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

    INSERT INTO tmp_matched_raw_members_main_contacts (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            s.source_row,
            s.norm_btn,
            row_number() OVER (
                PARTITION BY s.norm_btn
                ORDER BY s.source_row
            ) AS rn
        FROM tmp_stage_raw_members_main_contacts s
        LEFT JOIN tmp_matched_raw_members_main_contacts m
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
        FROM tmp_current_raw_members_main_contacts c
        LEFT JOIN tmp_matched_raw_members_main_contacts m
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

    INSERT INTO tmp_matched_raw_members_main_contacts (source_row, target_id, match_rule)
    WITH stage_ranked AS (
        SELECT
            s.source_row,
            s.norm_name,
            s.norm_category,
            row_number() OVER (
                PARTITION BY s.norm_name, s.norm_category
                ORDER BY s.source_row
            ) AS rn
        FROM tmp_stage_raw_members_main_contacts s
        LEFT JOIN tmp_matched_raw_members_main_contacts m
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
        FROM tmp_current_raw_members_main_contacts c
        LEFT JOIN tmp_matched_raw_members_main_contacts m
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

    UPDATE public.raw_members_main_contacts rm
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
    FROM tmp_matched_raw_members_main_contacts m
    JOIN tmp_stage_raw_members_main_contacts s
      ON s.source_row = m.source_row
    WHERE rm.id = m.target_id;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    INSERT INTO public.raw_members_main_contacts (
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
    FROM tmp_stage_raw_members_main_contacts s
    LEFT JOIN tmp_matched_raw_members_main_contacts m
      ON m.source_row = s.source_row
    WHERE m.source_row IS NULL;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    UPDATE public.raw_members_main_contacts rm
    SET is_current = false
    FROM tmp_current_raw_members_main_contacts c
    LEFT JOIN tmp_matched_raw_members_main_contacts m
      ON m.target_id = c.id
    WHERE rm.id = c.id
      AND m.target_id IS NULL
      AND COALESCE(rm.is_current, true) = true;
    GET DIAGNOSTICS v_deactivated = ROW_COUNT;

    RETURN QUERY SELECT v_updated, v_inserted, v_deactivated;
END;
$$;


--
-- Name: resolve_best_contact_row(text, text, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_best_contact_row(p_member_name text, p_member_email text DEFAULT NULL::text, p_member_last_name text DEFAULT NULL::text, p_is_family boolean DEFAULT false) RETURNS TABLE(contact_id bigint, payer_name text, first_name text, last_name text, email_address text, phone_number text, mobile_number text, address_1 text, address_2 text, address_3 text, town text, county text, postcode text, venue_id text, member_status text, resolve_rule text, candidate_count integer)
    LANGUAGE sql STABLE
    AS $$
    WITH params AS (
        SELECT
            public.normalize_match_text(p_member_name) AS norm_name,
            public.normalize_match_email(p_member_email) AS norm_email,
            public.normalize_match_text(p_member_last_name) AS norm_last_name,
            COALESCE(p_is_family, false) AS is_family
    ),
    candidates AS (
        SELECT
            c.contact_id,
            c.payer_name,
            c.first_name,
            c.last_name,
            c.email_address,
            c.phone_number,
            c.mobile_number,
            c.address_1,
            c.address_2,
            c.address_3,
            c.town,
            c.county,
            c.postcode,
            c.venue_id,
            c.member_status,
            CASE
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.status_rank = 0
                 AND c.junior_rank = 0
                 AND c.address_rank = 0
                THEN 0
                WHEN p.norm_name IS NOT NULL
                 AND p.norm_email IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND c.norm_email = p.norm_email
                 AND NOT p.is_family
                THEN 1
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND NOT p.is_family
                THEN 2
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.address_rank = 0
                THEN 3
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                THEN 4
                WHEN p.norm_email IS NOT NULL
                 AND c.norm_email = p.norm_email
                THEN 5
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                THEN 6
                ELSE 9
            END AS resolver_rank,
            CASE
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.status_rank = 0
                 AND c.junior_rank = 0
                 AND c.address_rank = 0
                THEN 'family_active_adult_address'
                WHEN p.norm_name IS NOT NULL
                 AND p.norm_email IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND c.norm_email = p.norm_email
                 AND NOT p.is_family
                THEN 'exact_name_email'
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND NOT p.is_family
                THEN 'exact_name'
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.address_rank = 0
                THEN 'family_last_name_address'
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                THEN 'exact_name'
                WHEN p.norm_email IS NOT NULL
                 AND c.norm_email = p.norm_email
                THEN 'email'
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                THEN 'family_last_name'
                ELSE 'fallback'
            END AS resolve_rule,
            c.address_rank,
            c.email_rank,
            c.phone_rank,
            c.quality_score,
            c.status_rank,
            c.junior_rank,
            c.created_date
        FROM public.vw_best_current_contacts c
        CROSS JOIN params p
        WHERE (
            p.norm_name IS NOT NULL
            AND c.norm_name = p.norm_name
        ) OR (
            p.norm_email IS NOT NULL
            AND c.norm_email = p.norm_email
        ) OR (
            p.is_family
            AND p.norm_last_name IS NOT NULL
            AND c.norm_last_name = p.norm_last_name
        )
    )
    SELECT
        contact_id,
        payer_name,
        first_name,
        last_name,
        email_address,
        phone_number,
        mobile_number,
        address_1,
        address_2,
        address_3,
        town,
        county,
        postcode,
        venue_id,
        member_status,
        resolve_rule,
        COUNT(*) OVER ()::integer AS candidate_count
    FROM candidates
    ORDER BY
        resolver_rank ASC,
        address_rank ASC,
        email_rank ASC,
        phone_rank ASC,
        quality_score DESC,
        status_rank ASC,
        junior_rank ASC,
        created_date DESC NULLS LAST,
        payer_name,
        contact_id
    LIMIT 1;
$$;


--
-- Name: run_main_contacts_resolution_regression_checks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.run_main_contacts_resolution_regression_checks() RETURNS TABLE(check_name text, ok boolean, expected text, actual text)
    LANGUAGE sql STABLE
    AS $$
    WITH checks AS (
        SELECT
            'antonios_nicolaidis_resolves_to_george_nicolaidis'::text AS check_name,
            (
                j.main_contact_name = 'George Nicolaidis'
                AND j.match_rule = 'direct_main_contacts_export_same_surname'
                AND j.candidate_count = 1
            ) AS ok,
            'main_contact_name=George Nicolaidis match_rule=direct_main_contacts_export_same_surname candidate_count=1'::text AS expected,
            format(
                'main_contact_name=%s match_rule=%s candidate_count=%s',
                COALESCE(j.main_contact_name, 'NULL'),
                COALESCE(j.match_rule, 'NULL'),
                COALESCE(j.candidate_count::text, 'NULL')
            ) AS actual
        FROM public.vw_junior_main_contacts j
        WHERE j.member_name = 'Antonios Nicolaidis'

        UNION ALL

        SELECT
            'gerasimos_nicolaidis_resolves_to_george_nicolaidis',
            (
                j.main_contact_name = 'George Nicolaidis'
                AND j.match_rule = 'direct_main_contacts_export_same_surname'
                AND j.candidate_count = 1
            ) AS ok,
            'main_contact_name=George Nicolaidis match_rule=direct_main_contacts_export_same_surname candidate_count=1',
            format(
                'main_contact_name=%s match_rule=%s candidate_count=%s',
                COALESCE(j.main_contact_name, 'NULL'),
                COALESCE(j.match_rule, 'NULL'),
                COALESCE(j.candidate_count::text, 'NULL')
            )
        FROM public.vw_junior_main_contacts j
        WHERE j.member_name = 'Gerasimos Nicolaidis'
    )
    SELECT check_name, ok, expected, actual
    FROM checks
    ORDER BY check_name;
$$;


--
-- Name: run_member_contact_matching_regression_checks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.run_member_contact_matching_regression_checks() RETURNS TABLE(check_name text, ok boolean, expected text, actual text)
    LANGUAGE sql STABLE
    AS $$
    WITH checks AS (
        SELECT
            'graham_family_prefers_household_contact'::text AS check_name,
            (
                r.contact_id = 4184
                AND r.payer_name = 'Hamish Graham'
                AND r.email_address = 'hamish.graham@outlook.com'
                AND r.postcode = 'GU52 8UH'
                AND r.resolve_rule = 'family_active_adult_address'
            ) AS ok,
            'contact_id=4184 payer=Hamish Graham rule=family_active_adult_address postcode=GU52 8UH'::text AS expected,
            format(
                'contact_id=%s payer=%s rule=%s postcode=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.payer_name, 'NULL'),
                coalesce(r.resolve_rule, 'NULL'),
                coalesce(r.postcode, 'NULL')
            ) AS actual
        FROM public.resolve_best_contact_row('Louise Graham', 'lugraham15@gmail.com', 'Graham', true) r

        UNION ALL

        SELECT
            'roni_asp_exact_name_single_match',
            (
                r.contact_id = 3717
                AND r.email_address = 'roniasp6@gmail.com'
                AND r.resolve_rule = 'exact_name_email'
                AND r.candidate_count = 1
            ) AS ok,
            'contact_id=3717 email=roniasp6@gmail.com rule=exact_name_email candidate_count=1',
            format(
                'contact_id=%s email=%s rule=%s candidate_count=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.email_address, 'NULL'),
                coalesce(r.resolve_rule, 'NULL'),
                coalesce(r.candidate_count::text, 'NULL')
            )
        FROM public.resolve_best_contact_row('Roni Asp', 'roniasp6@gmail.com', 'Asp', false) r

        UNION ALL

        SELECT
            'david_smith_kyrenia_email_distinguishes_duplicate',
            (
                r.contact_id = 4705
                AND r.email_address = 'dave.smith@kyrenia.co.uk'
                AND r.resolve_rule = 'exact_name_email'
            ) AS ok,
            'contact_id=4705 email=dave.smith@kyrenia.co.uk rule=exact_name_email',
            format(
                'contact_id=%s email=%s rule=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.email_address, 'NULL'),
                coalesce(r.resolve_rule, 'NULL')
            )
        FROM public.resolve_best_contact_row('David Smith', 'dave.smith@kyrenia.co.uk', 'Smith', false) r

        UNION ALL

        SELECT
            'david_smith_ntl_email_distinguishes_duplicate',
            (
                r.contact_id = 4710
                AND r.email_address = 'd.smith44@ntlworld.com'
                AND r.resolve_rule = 'exact_name_email'
            ) AS ok,
            'contact_id=4710 email=d.smith44@ntlworld.com rule=exact_name_email',
            format(
                'contact_id=%s email=%s rule=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.email_address, 'NULL'),
                coalesce(r.resolve_rule, 'NULL')
            )
        FROM public.resolve_best_contact_row('David Smith', 'd.smith44@ntlworld.com', 'Smith', false) r

        UNION ALL

        SELECT
            'david_smith_current_member_rows_stay_distinct',
            (
                count(*) = 2
                AND count(DISTINCT nullif(trim("British Tennis Number"), '')) = 2
                AND count(DISTINCT lower(trim("Email address"))) = 2
            ) AS ok,
            'rows=2 distinct_btn=2 distinct_email=2',
            format(
                'rows=%s distinct_btn=%s distinct_email=%s',
                count(*),
                count(DISTINCT nullif(trim("British Tennis Number"), '')),
                count(DISTINCT lower(trim("Email address")))
            )
        FROM public.raw_members
        WHERE trim(concat_ws(' ', "First name", "Last name")) = 'David Smith'
          AND "Membership" = '1. Senior 2026'
          AND coalesce(is_current, true) = true
    )
    SELECT check_name, ok, expected, actual
    FROM checks
    ORDER BY check_name;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: case_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_emails (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    case_id uuid NOT NULL,
    direction text NOT NULL,
    subject text,
    body_html text,
    body_text text,
    recipients jsonb DEFAULT '{}'::jsonb NOT NULL,
    template_key text,
    signature_template_key text,
    delivery_mode text,
    gmail_message_id text,
    gmail_thread_id text,
    created_by text,
    sent_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    internet_message_id text,
    in_reply_to_message_id text,
    references_header text,
    parent_case_email_id uuid,
    open_tracking_token text,
    open_tracking_enabled boolean DEFAULT false NOT NULL,
    open_tracking_status text DEFAULT 'Not Tracked'::text NOT NULL,
    first_opened_at timestamp with time zone,
    last_opened_at timestamp with time zone,
    open_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT case_emails_direction_check CHECK ((direction = ANY (ARRAY['incoming'::text, 'outgoing'::text, 'note'::text]))),
    CONSTRAINT case_emails_open_tracking_status_check CHECK ((open_tracking_status = ANY (ARRAY['Not Tracked'::text, 'Not Opened'::text, 'Opened'::text])))
);


--
-- Name: cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    contact_name text NOT NULL,
    contact_email text,
    contact_phone text,
    source text DEFAULT 'manual'::text NOT NULL,
    status text DEFAULT 'New'::text NOT NULL,
    priority text DEFAULT 'Medium'::text NOT NULL,
    notes text,
    last_inbound_at timestamp with time zone,
    last_outbound_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_by text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cases_priority_check CHECK ((priority = ANY (ARRAY['Low'::text, 'Medium'::text, 'High'::text, 'Urgent'::text]))),
    CONSTRAINT cases_status_check CHECK ((status = ANY (ARRAY['New'::text, 'In Progress'::text, 'Waiting'::text, 'Completed'::text])))
);


--
-- Name: email_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_status (
    message_id character varying(128) NOT NULL,
    send_date timestamp with time zone,
    "from" character varying(128) NOT NULL,
    subject character varying(128),
    status_date timestamp with time zone,
    status character varying(128)
);


--
-- Name: email_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_templates (
    id bigint NOT NULL,
    template_key text NOT NULL,
    template_name text NOT NULL,
    subject_template text,
    text_template text,
    html_template text,
    source_group text,
    source_txt_path text,
    source_html_path text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    template_type integer DEFAULT 0 NOT NULL,
    CONSTRAINT email_templates_template_type_check CHECK ((template_type = ANY (ARRAY[0, 1, 2])))
);


--
-- Name: email_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_templates_id_seq OWNED BY public.email_templates.id;


--
-- Name: global_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.global_settings (
    key text NOT NULL,
    value text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: html_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.html_templates (
    id bigint NOT NULL,
    template_name text NOT NULL,
    webhook_path text NOT NULL,
    html_template text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: html_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.html_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: html_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.html_templates_id_seq OWNED BY public.html_templates.id;


--
-- Name: images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images (
    id bigint NOT NULL,
    image_key text NOT NULL,
    file_name text NOT NULL,
    file_ext text NOT NULL,
    content_type text NOT NULL,
    byte_size integer NOT NULL,
    source_path text NOT NULL,
    data bytea NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT images_byte_size_check CHECK ((byte_size >= 0))
);


--
-- Name: images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.images_id_seq OWNED BY public.images.id;


--
-- Name: member_signups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.member_signups (
    signup_date timestamp with time zone NOT NULL,
    member character varying(32) NOT NULL,
    product character varying(128) NOT NULL,
    payer character varying(32),
    cost numeric,
    quantity integer,
    method character varying(32),
    status character varying(32),
    "First name" text,
    "Last name" text,
    "Age" integer,
    email_address text,
    address_1 text,
    address_2 text,
    address_3 text,
    town text,
    postcode text,
    "Tags provided" text,
    "Key pin number" text,
    id bigint NOT NULL,
    clubspark_status character varying(32),
    batch_id bigint,
    source text DEFAULT 'email_capture'::text NOT NULL
);


--
-- Name: member_signups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.member_signups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_signups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_signups_id_seq OWNED BY public.member_signups.id;


--
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    "First_Name" character varying(20) NOT NULL,
    "Last_Name" character varying(20) NOT NULL,
    "Gender" character varying(20),
    "Age" character varying(20),
    "Junior" character varying(20) NOT NULL,
    "Date_of_birth" date,
    "Membership" character varying(64) NOT NULL,
    "Status" character varying(20) NOT NULL,
    "Email_Address" character varying(64),
    "Phone_number" character varying(20),
    "Work_number" character varying(20),
    "Mobile_number" character varying(20),
    "Address1" character varying(64),
    "Address2" character varying(64),
    "Address3" character varying(64),
    "Town" character varying(64),
    "County" character varying(64),
    "Country" character varying(64),
    "Postcode" character varying(20),
    "Tags_provided" character varying(10),
    "Key_provided" character varying(10),
    "Member_status" character varying(20) NOT NULL
);


--
-- Name: membership_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_history (
    membership text,
    "2024/2025" integer,
    "2023/2024" integer,
    "2022/2023" integer,
    "2021/2022" integer,
    "2020/2021" integer,
    "2019/2020" integer,
    "2018/2019" integer,
    "2017/2018" integer,
    "2016/2017" integer,
    "2015/2016" integer,
    "2014/2015" integer,
    "2025/2026" integer,
    "2026/2027" integer
);


--
-- Name: membership_history_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_history_snapshots (
    id bigint NOT NULL,
    snapshot_key text NOT NULL,
    source_season text NOT NULL,
    membership text NOT NULL,
    member_count integer NOT NULL,
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: membership_history_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.membership_history_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: membership_history_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.membership_history_snapshots_id_seq OWNED BY public.membership_history_snapshots.id;


--
-- Name: membership_packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_packages (
    season character varying(16) NOT NULL,
    name character varying(64) NOT NULL,
    category character varying(64),
    display_order integer,
    cost numeric
);


--
-- Name: membership_signup_match_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_signup_match_groups (
    season character varying(16) NOT NULL,
    package_name character varying(64) NOT NULL,
    signup_match_group character varying(64) NOT NULL
);


--
-- Name: raw_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_contacts (
    "Venue ID" text,
    "Unique ID" text,
    "First name" text,
    "Last name" text,
    gender text,
    age integer,
    junior text,
    "Date of birth" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    town text,
    county text,
    country text,
    postcode text,
    "British Tennis Number" integer,
    "Date joined venue" text,
    "Medical history" text,
    occupation text,
    registered text,
    unsubscribed text,
    "Member status" text,
    "Last active" text,
    created text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    photography text,
    id bigint NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


--
-- Name: raw_contacts_historical; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_contacts_historical (
    "Venue ID" text,
    "Unique ID" text,
    "First name" text,
    "Last name" text,
    gender text,
    age integer,
    junior text,
    "Date of birth" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    town text,
    county text,
    country text,
    postcode text,
    "British Tennis Number" integer,
    "Date joined venue" text,
    "Medical history" text,
    occupation text,
    registered text,
    unsubscribed text,
    "Member status" text,
    "Last active" text,
    created text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    photography text,
    snapshot_year integer NOT NULL,
    archived_at timestamp with time zone DEFAULT now() NOT NULL,
    snapshot_source text DEFAULT 'raw_contacts'::text NOT NULL
);


--
-- Name: raw_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.raw_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.raw_contacts_id_seq OWNED BY public.raw_contacts.id;


--
-- Name: raw_contacts_import_staging; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_contacts_import_staging (
    "Venue ID" text,
    "Unique ID" text,
    "First name" text,
    "Last name" text,
    gender text,
    age integer,
    junior text,
    "Date of birth" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    town text,
    county text,
    country text,
    postcode text,
    "British Tennis Number" integer,
    "Date joined venue" text,
    "Medical history" text,
    occupation text,
    registered text,
    unsubscribed text,
    "Member status" text,
    "Last active" text,
    created text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    photography text
);


--
-- Name: raw_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_members (
    "Venue ID" text,
    "First name" text,
    "Last name" text,
    "Gender" text,
    "Age" integer,
    "Junior" text,
    "Date of birth" text,
    "Membership" text,
    "Payment" text,
    "Cost" numeric,
    "Paid" numeric,
    "Paid Credit Card" numeric,
    "Paid Direct Debit" numeric,
    "Paid Cash" numeric,
    "Paid Cheque" numeric,
    "Paid Other" numeric,
    "Gift aid" text,
    "Status" text,
    "Start Date" text,
    "Expiry Date" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    "Town" text,
    "County" text,
    "Country" text,
    "Postcode" text,
    "British Tennis Number" text,
    "Date joined venue" text,
    "Medical history" text,
    "Venue source" text,
    "Contact source" text,
    "Occupation" text,
    "Tags provided" text,
    "Key pin number" text,
    "Registered" text,
    "Member status" text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    "Photography" text,
    " Venue source" character varying(50),
    id bigint NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


--
-- Name: raw_members_historical; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_members_historical (
    "Venue ID" text,
    "First name" text,
    "Last name" text,
    "Gender" text,
    "Age" integer,
    "Junior" text,
    "Date of birth" text,
    "Membership" text,
    "Payment" text,
    "Cost" numeric,
    "Paid" numeric,
    "Paid Credit Card" numeric,
    "Paid Direct Debit" numeric,
    "Paid Cash" numeric,
    "Paid Cheque" numeric,
    "Paid Other" numeric,
    "Gift aid" text,
    "Status" text,
    "Start Date" text,
    "Expiry Date" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    "Town" text,
    "County" text,
    "Country" text,
    "Postcode" text,
    "British Tennis Number" text,
    "Date joined venue" text,
    "Medical history" text,
    "Venue source" text,
    "Contact source" text,
    "Occupation" text,
    "Tags provided" text,
    "Key pin number" text,
    "Registered" text,
    "Member status" text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    "Photography" text,
    " Venue source" character varying(50),
    snapshot_year integer NOT NULL,
    archived_at timestamp with time zone DEFAULT now() NOT NULL,
    snapshot_source text DEFAULT 'raw_members'::text NOT NULL
);


--
-- Name: raw_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.raw_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.raw_members_id_seq OWNED BY public.raw_members.id;


--
-- Name: raw_members_import_staging; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_members_import_staging (
    "Venue ID" text,
    "First name" text,
    "Last name" text,
    "Gender" text,
    "Age" integer,
    "Junior" text,
    "Date of birth" text,
    "Membership" text,
    "Payment" text,
    "Cost" numeric,
    "Paid" numeric,
    "Paid Credit Card" numeric,
    "Paid Direct Debit" numeric,
    "Paid Cash" numeric,
    "Paid Cheque" numeric,
    "Paid Other" numeric,
    "Gift aid" text,
    "Status" text,
    "Start Date" text,
    "Expiry Date" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    "Town" text,
    "County" text,
    "Country" text,
    "Postcode" text,
    "British Tennis Number" text,
    "Date joined venue" text,
    "Medical history" text,
    "Venue source" text,
    "Contact source" text,
    "Occupation" text,
    "Tags provided" text,
    "Key pin number" text,
    "Registered" text,
    "Member status" text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    "Photography" text,
    " Venue source" character varying
);


--
-- Name: raw_members_main_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_members_main_contacts (
    id bigint NOT NULL,
    "Venue ID" text,
    "First name" text,
    "Last name" text,
    "Gender" text,
    "Age" integer,
    "Junior" text,
    "Date of birth" text,
    "Membership" text,
    "Payment" text,
    "Cost" numeric,
    "Paid" numeric,
    "Paid Credit Card" numeric,
    "Paid Direct Debit" numeric,
    "Paid Cash" numeric,
    "Paid Cheque" numeric,
    "Paid Other" numeric,
    "Gift aid" text,
    "Status" text,
    "Start Date" text,
    "Expiry Date" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    "Town" text,
    "County" text,
    "Country" text,
    "Postcode" text,
    "British Tennis Number" text,
    "Date joined venue" text,
    "Medical history" text,
    "Venue source" text,
    "Contact source" text,
    "Occupation" text,
    "Tags provided" text,
    "Key pin number" text,
    "Registered" text,
    "Member status" text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    "Photography" text,
    " Venue source" character varying,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


--
-- Name: raw_members_main_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.raw_members_main_contacts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.raw_members_main_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: raw_members_main_contacts_import_staging; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_members_main_contacts_import_staging (
    "Venue ID" text,
    "First name" text,
    "Last name" text,
    "Gender" text,
    "Age" integer,
    "Junior" text,
    "Date of birth" text,
    "Membership" text,
    "Payment" text,
    "Cost" numeric,
    "Paid" numeric,
    "Paid Credit Card" numeric,
    "Paid Direct Debit" numeric,
    "Paid Cash" numeric,
    "Paid Cheque" numeric,
    "Paid Other" numeric,
    "Gift aid" text,
    "Status" text,
    "Start Date" text,
    "Expiry Date" text,
    "Email address" text,
    "Phone number" text,
    "Work number" text,
    "Mobile number" text,
    "Emergency contact name" text,
    "Emergency phone number" text,
    "Address 1" text,
    "Address 2" text,
    "Address 3" text,
    "Town" text,
    "County" text,
    "Country" text,
    "Postcode" text,
    "British Tennis Number" text,
    "Date joined venue" text,
    "Medical history" text,
    "Venue source" text,
    "Contact source" text,
    "Occupation" text,
    "Tags provided" text,
    "Key pin number" text,
    "Registered" text,
    "Member status" text,
    "Receipt of Emails" text,
    "Share Contact Detail" text,
    "Member's Directory" text,
    "Photography" text,
    " Venue source" character varying
);


--
-- Name: raw_reconcile_match_audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_reconcile_match_audit (
    id bigint NOT NULL,
    raw_table text NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    source_row integer NOT NULL,
    source_name text,
    source_membership text,
    matched_id bigint,
    match_rule text NOT NULL,
    outcome text NOT NULL,
    candidate_count integer,
    candidate_ids jsonb,
    notes text,
    CONSTRAINT raw_reconcile_match_audit_raw_table_check CHECK ((raw_table = ANY (ARRAY['raw_contacts'::text, 'raw_members'::text])))
);


--
-- Name: raw_reconcile_match_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.raw_reconcile_match_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_reconcile_match_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.raw_reconcile_match_audit_id_seq OWNED BY public.raw_reconcile_match_audit.id;


--
-- Name: raw_snapshot_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_snapshot_state (
    table_name text NOT NULL,
    current_snapshot_year integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refunds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refunds (
    id bigint NOT NULL,
    name text NOT NULL,
    refund_for text NOT NULL,
    reason text NOT NULL,
    membership text NOT NULL,
    amount numeric(12,2) NOT NULL,
    from_date date,
    to_date date,
    months integer NOT NULL,
    refund numeric(12,2) NOT NULL,
    status text DEFAULT 'New Request'::text NOT NULL,
    explanation text NOT NULL,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    request_email_message_id text,
    bank_details_message_id text,
    treasury_email_message_id text,
    paid_at timestamp with time zone,
    rejected_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    notes text,
    CONSTRAINT refunds_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT refunds_check CHECK ((to_date >= from_date)),
    CONSTRAINT refunds_months_check CHECK ((months >= 0)),
    CONSTRAINT refunds_refund_check CHECK ((refund >= (0)::numeric))
);


--
-- Name: refunds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.refunds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refunds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.refunds_id_seq OWNED BY public.refunds.id;


--
-- Name: signup_batch_manual_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signup_batch_manual_items (
    id bigint NOT NULL,
    batch_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    source text DEFAULT 'manual'::text NOT NULL,
    member text NOT NULL,
    payer text NOT NULL,
    email_address text,
    address_1 text,
    address_2 text,
    address_3 text,
    town text,
    postcode text,
    regular_tags integer DEFAULT 0 NOT NULL,
    parent_tags integer DEFAULT 0 NOT NULL,
    key_tags integer DEFAULT 0 NOT NULL,
    notes text,
    created_by text,
    CONSTRAINT signup_batch_manual_items_has_items CHECK ((((regular_tags + parent_tags) + key_tags) > 0)),
    CONSTRAINT signup_batch_manual_items_key_tags_check CHECK ((key_tags >= 0)),
    CONSTRAINT signup_batch_manual_items_parent_tags_check CHECK ((parent_tags >= 0)),
    CONSTRAINT signup_batch_manual_items_regular_tags_check CHECK ((regular_tags >= 0)),
    CONSTRAINT signup_batch_manual_items_source_check CHECK ((source = 'manual'::text))
);


--
-- Name: signup_batch_manual_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.signup_batch_manual_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: signup_batch_manual_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.signup_batch_manual_items_id_seq OWNED BY public.signup_batch_manual_items.id;


--
-- Name: signup_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signup_batches (
    id bigint NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    no_address_email_sent boolean DEFAULT false NOT NULL,
    CONSTRAINT signup_batches_status_check CHECK ((status = ANY (ARRAY['Processing'::text, 'Complete'::text])))
);


--
-- Name: signup_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.signup_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: signup_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.signup_batches_id_seq OWNED BY public.signup_batches.id;


--
-- Name: team_name_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_name_overrides (
    id bigint NOT NULL,
    source text NOT NULL,
    target text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: team_name_overrides_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.team_name_overrides ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.team_name_overrides_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: team_nicknames; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_nicknames (
    id bigint NOT NULL,
    source text NOT NULL,
    target text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: team_nicknames_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.team_nicknames_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: team_nicknames_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.team_nicknames_id_seq OWNED BY public.team_nicknames.id;


--
-- Name: team_players; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_players (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    source_name text NOT NULL,
    is_captain boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: team_players_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.team_players ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.team_players_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    doc_source text,
    section text,
    team_name text NOT NULL,
    season text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.teams ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ukpostcodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ukpostcodes (
    id integer,
    postcode character varying(50),
    latitude real,
    longitude real
);


--
-- Name: vw_best_current_contacts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_best_current_contacts AS
 SELECT rc.id AS contact_id,
    TRIM(BOTH FROM concat_ws(' '::text, rc."First name", rc."Last name")) AS payer_name,
    NULLIF(TRIM(BOTH FROM rc."First name"), ''::text) AS first_name,
    NULLIF(TRIM(BOTH FROM rc."Last name"), ''::text) AS last_name,
    NULLIF(TRIM(BOTH FROM rc."Email address"), ''::text) AS email_address,
    NULLIF(TRIM(BOTH FROM rc."Phone number"), ''::text) AS phone_number,
    NULLIF(TRIM(BOTH FROM rc."Mobile number"), ''::text) AS mobile_number,
    NULLIF(TRIM(BOTH FROM rc."Address 1"), ''::text) AS address_1,
    NULLIF(TRIM(BOTH FROM rc."Address 2"), ''::text) AS address_2,
    NULLIF(TRIM(BOTH FROM rc."Address 3"), ''::text) AS address_3,
    NULLIF(TRIM(BOTH FROM rc.town), ''::text) AS town,
    NULLIF(TRIM(BOTH FROM rc.county), ''::text) AS county,
    NULLIF(TRIM(BOTH FROM rc.postcode), ''::text) AS postcode,
    NULLIF(TRIM(BOTH FROM rc."Venue ID"), ''::text) AS venue_id,
    NULLIF(TRIM(BOTH FROM rc."Member status"), ''::text) AS member_status,
    public.normalize_match_text(concat_ws(' '::text, rc."First name", rc."Last name")) AS norm_name,
    public.normalize_match_text(rc."Last name") AS norm_last_name,
    public.normalize_match_email(rc."Email address") AS norm_email,
    public.normalize_match_date(rc.created) AS created_date,
    ((((
        CASE
            WHEN (public.normalize_match_address_line1(rc."Address 1") IS NOT NULL) THEN 1
            ELSE 0
        END +
        CASE
            WHEN (public.normalize_match_postcode(rc.postcode) IS NOT NULL) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (public.normalize_match_email(rc."Email address") IS NOT NULL) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (COALESCE(public.normalize_match_phone(rc."Mobile number"), public.normalize_match_phone(rc."Phone number")) IS NOT NULL) THEN 1
            ELSE 0
        END) +
        CASE
            WHEN (public.normalize_match_date(rc."Date of birth") IS NOT NULL) THEN 1
            ELSE 0
        END) AS quality_score,
        CASE COALESCE(NULLIF(TRIM(BOTH FROM rc."Member status"), ''::text), ''::text)
            WHEN 'Active Member'::text THEN 0
            WHEN 'Non Member'::text THEN 1
            WHEN 'Lapsed Member'::text THEN 2
            ELSE 3
        END AS status_rank,
        CASE
            WHEN (COALESCE(NULLIF(TRIM(BOTH FROM rc."Address 1"), ''::text), NULLIF(TRIM(BOTH FROM rc.postcode), ''::text)) IS NOT NULL) THEN 0
            ELSE 1
        END AS address_rank,
        CASE
            WHEN (NULLIF(TRIM(BOTH FROM rc."Email address"), ''::text) IS NOT NULL) THEN 0
            ELSE 1
        END AS email_rank,
        CASE
            WHEN (COALESCE(NULLIF(TRIM(BOTH FROM rc."Mobile number"), ''::text), NULLIF(TRIM(BOTH FROM rc."Phone number"), ''::text)) IS NOT NULL) THEN 0
            ELSE 1
        END AS phone_rank,
        CASE COALESCE(NULLIF(TRIM(BOTH FROM rc.junior), ''::text), 'No'::text)
            WHEN 'No'::text THEN 0
            ELSE 1
        END AS junior_rank
   FROM public.raw_contacts rc
  WHERE (COALESCE(rc.is_current, true) = true);


--
-- Name: vw_junior_main_contacts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_junior_main_contacts AS
 WITH junior_members AS (
         SELECT rm.id AS member_raw_id,
            TRIM(BOTH FROM concat_ws(' '::text, rm."First name", rm."Last name")) AS member_name,
            NULLIF(TRIM(BOTH FROM rm."First name"), ''::text) AS member_first_name,
            NULLIF(TRIM(BOTH FROM rm."Last name"), ''::text) AS member_last_name,
            NULLIF(TRIM(BOTH FROM rm."Email address"), ''::text) AS member_email,
            rm."Membership" AS membership,
            rm."Status" AS status,
            rm."Payment" AS payment,
            rm."Paid" AS paid_total,
            rm."Start Date" AS start_date,
            rm."Expiry Date" AS expiry_date,
            rm."Venue ID" AS venue_id,
            rm."British Tennis Number" AS british_tennis_number,
            rm."Address 1" AS member_address_1,
            rm."Postcode" AS member_postcode,
            public.normalize_match_text(concat_ws(' '::text, rm."First name", rm."Last name")) AS norm_member_name,
            public.normalize_match_text(rm."Last name") AS norm_member_last_name,
            NULLIF("substring"(rm."Membership", '(20[0-9]{2})'::text), ''::text) AS season
           FROM public.raw_members rm
          WHERE ((COALESCE(rm.is_current, true) = true) AND (COALESCE(NULLIF(TRIM(BOTH FROM rm."Junior"), ''::text), 'No'::text) = 'Yes'::text))
        ), main_contact_rows AS (
         SELECT mc.id AS main_contact_raw_id,
            TRIM(BOTH FROM concat_ws(' '::text, mc."First name", mc."Last name")) AS main_contact_name,
            NULLIF(TRIM(BOTH FROM mc."First name"), ''::text) AS main_contact_first_name,
            NULLIF(TRIM(BOTH FROM mc."Last name"), ''::text) AS main_contact_last_name,
            NULLIF(TRIM(BOTH FROM mc."Email address"), ''::text) AS main_contact_email,
            NULLIF(TRIM(BOTH FROM mc."Phone number"), ''::text) AS main_contact_phone,
            NULLIF(TRIM(BOTH FROM mc."Mobile number"), ''::text) AS main_contact_mobile,
            NULLIF(TRIM(BOTH FROM mc."Address 1"), ''::text) AS main_contact_address_1,
            NULLIF(TRIM(BOTH FROM mc."Address 2"), ''::text) AS main_contact_address_2,
            NULLIF(TRIM(BOTH FROM mc."Address 3"), ''::text) AS main_contact_address_3,
            NULLIF(TRIM(BOTH FROM mc."Town"), ''::text) AS main_contact_town,
            NULLIF(TRIM(BOTH FROM mc."County"), ''::text) AS main_contact_county,
            NULLIF(TRIM(BOTH FROM mc."Postcode"), ''::text) AS main_contact_postcode,
            mc."Membership" AS membership,
            mc."Status" AS status,
            mc."Payment" AS payment,
            mc."Paid" AS paid_total,
            mc."Start Date" AS start_date,
            mc."Expiry Date" AS expiry_date,
            public.normalize_match_text(concat_ws(' '::text, mc."First name", mc."Last name")) AS norm_main_contact_name,
            public.normalize_match_text(mc."Last name") AS norm_main_contact_last_name,
            public.normalize_match_email(mc."Email address") AS norm_main_contact_email
           FROM public.raw_members_main_contacts mc
          WHERE (COALESCE(mc.is_current, true) = true)
        ), candidate_rows AS (
         SELECT jm_1.member_raw_id,
            jm_1.member_name,
            jm_1.member_first_name,
            jm_1.member_last_name,
            jm_1.member_email,
            jm_1.membership,
            jm_1.status,
            jm_1.payment,
            jm_1.paid_total,
            jm_1.start_date,
            jm_1.expiry_date,
            jm_1.venue_id,
            jm_1.british_tennis_number,
            jm_1.member_address_1,
            jm_1.member_postcode,
            jm_1.season,
            mc.main_contact_raw_id,
            mc.main_contact_name,
            mc.main_contact_first_name,
            mc.main_contact_last_name,
            mc.main_contact_email,
            mc.main_contact_phone,
            mc.main_contact_mobile,
            mc.main_contact_address_1,
            mc.main_contact_address_2,
            mc.main_contact_address_3,
            mc.main_contact_town,
            mc.main_contact_county,
            mc.main_contact_postcode,
            mc.norm_main_contact_name,
            mc.norm_main_contact_email,
            row_number() OVER (PARTITION BY jm_1.member_raw_id, mc.norm_main_contact_name, COALESCE(mc.norm_main_contact_email, ''::text) ORDER BY mc.main_contact_raw_id) AS duplicate_rank
           FROM (junior_members jm_1
             JOIN main_contact_rows mc ON (((COALESCE(jm_1.membership, ''::text) = COALESCE(mc.membership, ''::text)) AND (COALESCE(jm_1.status, ''::text) = COALESCE(mc.status, ''::text)) AND (COALESCE(jm_1.payment, ''::text) = COALESCE(mc.payment, ''::text)) AND (COALESCE(jm_1.start_date, ''::text) = COALESCE(mc.start_date, ''::text)) AND (COALESCE(jm_1.expiry_date, ''::text) = COALESCE(mc.expiry_date, ''::text)) AND (COALESCE(jm_1.paid_total, ('-1'::integer)::numeric) = COALESCE(mc.paid_total, ('-1'::integer)::numeric)) AND (jm_1.norm_member_last_name = mc.norm_main_contact_last_name) AND (jm_1.norm_member_name <> mc.norm_main_contact_name))))
        ), candidate_identities AS (
         SELECT candidate_rows.member_raw_id,
            candidate_rows.member_name,
            candidate_rows.member_first_name,
            candidate_rows.member_last_name,
            candidate_rows.member_email,
            candidate_rows.membership,
            candidate_rows.status,
            candidate_rows.payment,
            candidate_rows.paid_total,
            candidate_rows.start_date,
            candidate_rows.expiry_date,
            candidate_rows.venue_id,
            candidate_rows.british_tennis_number,
            candidate_rows.member_address_1,
            candidate_rows.member_postcode,
            candidate_rows.season,
            candidate_rows.main_contact_raw_id,
            candidate_rows.main_contact_name,
            candidate_rows.main_contact_first_name,
            candidate_rows.main_contact_last_name,
            candidate_rows.main_contact_email,
            candidate_rows.main_contact_phone,
            candidate_rows.main_contact_mobile,
            candidate_rows.main_contact_address_1,
            candidate_rows.main_contact_address_2,
            candidate_rows.main_contact_address_3,
            candidate_rows.main_contact_town,
            candidate_rows.main_contact_county,
            candidate_rows.main_contact_postcode,
            candidate_rows.norm_main_contact_name,
            candidate_rows.norm_main_contact_email,
            candidate_rows.duplicate_rank
           FROM candidate_rows
          WHERE (candidate_rows.duplicate_rank = 1)
        ), candidate_counts AS (
         SELECT candidate_identities.member_raw_id,
            (count(*))::integer AS candidate_count
           FROM candidate_identities
          GROUP BY candidate_identities.member_raw_id
        ), ranked_candidates AS (
         SELECT ci.member_raw_id,
            ci.member_name,
            ci.member_first_name,
            ci.member_last_name,
            ci.member_email,
            ci.membership,
            ci.status,
            ci.payment,
            ci.paid_total,
            ci.start_date,
            ci.expiry_date,
            ci.venue_id,
            ci.british_tennis_number,
            ci.member_address_1,
            ci.member_postcode,
            ci.season,
            ci.main_contact_raw_id,
            ci.main_contact_name,
            ci.main_contact_first_name,
            ci.main_contact_last_name,
            ci.main_contact_email,
            ci.main_contact_phone,
            ci.main_contact_mobile,
            ci.main_contact_address_1,
            ci.main_contact_address_2,
            ci.main_contact_address_3,
            ci.main_contact_town,
            ci.main_contact_county,
            ci.main_contact_postcode,
            ci.norm_main_contact_name,
            ci.norm_main_contact_email,
            ci.duplicate_rank,
            row_number() OVER (PARTITION BY ci.member_raw_id ORDER BY
                CASE
                    WHEN (ci.main_contact_email IS NOT NULL) THEN 0
                    ELSE 1
                END,
                CASE
                    WHEN (COALESCE(ci.main_contact_mobile, ci.main_contact_phone) IS NOT NULL) THEN 0
                    ELSE 1
                END,
                CASE
                    WHEN (COALESCE(ci.main_contact_address_1, ci.main_contact_postcode) IS NOT NULL) THEN 0
                    ELSE 1
                END, ci.main_contact_name, ci.main_contact_raw_id) AS candidate_rank
           FROM candidate_identities ci
        )
 SELECT jm.member_raw_id,
    jm.member_name,
    jm.member_first_name,
    jm.member_last_name,
    jm.member_email,
    jm.membership,
    jm.season,
    jm.status,
    jm.payment,
    jm.start_date,
    jm.expiry_date,
    rc.main_contact_raw_id,
    rc.main_contact_name,
    rc.main_contact_first_name,
    rc.main_contact_last_name,
    COALESCE(bc.email_address, rc.main_contact_email) AS main_contact_email,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.mobile_number), ''::text), rc.main_contact_mobile) AS main_contact_mobile,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.phone_number), ''::text), rc.main_contact_phone) AS main_contact_phone,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.address_1), ''::text), rc.main_contact_address_1) AS main_contact_address_1,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.address_2), ''::text), rc.main_contact_address_2) AS main_contact_address_2,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.address_3), ''::text), rc.main_contact_address_3) AS main_contact_address_3,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.town), ''::text), rc.main_contact_town) AS main_contact_town,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.county), ''::text), rc.main_contact_county) AS main_contact_county,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.postcode), ''::text), rc.main_contact_postcode) AS main_contact_postcode,
    bc.contact_id AS resolved_contact_id,
    bc.resolve_rule AS resolved_contact_rule,
    COALESCE(cc.candidate_count, 0) AS candidate_count,
        CASE
            WHEN (COALESCE(cc.candidate_count, 0) = 1) THEN 'high'::text
            WHEN (COALESCE(cc.candidate_count, 0) > 1) THEN 'ambiguous'::text
            ELSE 'unresolved'::text
        END AS match_confidence,
        CASE
            WHEN (COALESCE(cc.candidate_count, 0) = 1) THEN 'direct_main_contacts_export_same_surname'::text
            WHEN (COALESCE(cc.candidate_count, 0) > 1) THEN 'ambiguous_main_contacts_export_same_surname'::text
            ELSE 'unresolved'::text
        END AS match_rule
   FROM (((junior_members jm
     LEFT JOIN candidate_counts cc ON ((cc.member_raw_id = jm.member_raw_id)))
     LEFT JOIN ranked_candidates rc ON (((rc.member_raw_id = jm.member_raw_id) AND (rc.candidate_rank = 1))))
     LEFT JOIN LATERAL public.resolve_best_contact_row(rc.main_contact_name, rc.main_contact_email, NULLIF(regexp_replace(rc.main_contact_name, '^\S+\s*'::text, ''::text), ''::text), false) bc(contact_id, payer_name, first_name, last_name, email_address, phone_number, mobile_number, address_1, address_2, address_3, town, county, postcode, venue_id, member_status, resolve_rule, candidate_count) ON (((COALESCE(cc.candidate_count, 0) = 1) AND (rc.main_contact_name IS NOT NULL))));


--
-- Name: vw_appsmith_team_player_matching; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_appsmith_team_player_matching AS
 WITH base_players AS (
         SELECT tp.id AS team_player_id,
            tp.team_id,
            t.team_name,
            t.season,
            tp.source_name,
            public.normalize_match_text(tp.source_name) AS norm_source_name,
            tp.is_captain,
            tp.sort_order
           FROM (public.team_players tp
             JOIN public.teams t ON ((t.id = tp.team_id)))
        ), exact_matches AS (
         SELECT bp_1.team_player_id,
            m.id AS member_id,
            'Exact Member'::text AS match_rule,
            1 AS match_priority,
            ((m."First name" || ' '::text) || m."Last name") AS resolved_name,
            m."Email address" AS email,
            COALESCE(m."Mobile number", m."Phone number") AS phone,
            m."Membership" AS category,
            m."Status" AS status,
            m."Share Contact Detail" AS consent
           FROM (base_players bp_1
             JOIN public.raw_members m ON (((public.normalize_match_text(((m."First name" || ' '::text) || m."Last name")) = bp_1.norm_source_name) AND (COALESCE(m.is_current, true) = true) AND (m."Status" = 'Active'::text))))
        ), override_matches AS (
         SELECT bp_1.team_player_id,
            m.id AS member_id,
            'Override (Full)'::text AS match_rule,
            2 AS match_priority,
            ((m."First name" || ' '::text) || m."Last name") AS resolved_name,
            m."Email address" AS email,
            COALESCE(m."Mobile number", m."Phone number") AS phone,
            m."Membership" AS category,
            m."Status" AS status,
            m."Share Contact Detail" AS consent
           FROM ((base_players bp_1
             JOIN public.team_name_overrides o ON ((public.normalize_match_text(o.source) = bp_1.norm_source_name)))
             JOIN public.raw_members m ON (((public.normalize_match_text(((m."First name" || ' '::text) || m."Last name")) = public.normalize_match_text(o.target)) AND (COALESCE(m.is_current, true) = true) AND (m."Status" = 'Active'::text))))
        ), nickname_matches AS (
         SELECT bp_1.team_player_id,
            m.id AS member_id,
            'Nickname'::text AS match_rule,
            2 AS match_priority,
            ((m."First name" || ' '::text) || m."Last name") AS resolved_name,
            m."Email address" AS email,
            COALESCE(m."Mobile number", m."Phone number") AS phone,
            m."Membership" AS category,
            m."Status" AS status,
            m."Share Contact Detail" AS consent
           FROM ((base_players bp_1
             JOIN public.team_name_overrides o ON ((public.normalize_match_text(o.source) = public.normalize_match_text(split_part(bp_1.norm_source_name, ' '::text, 1)))))
             JOIN public.raw_members m ON (((public.normalize_match_text(m."First name") = public.normalize_match_text(o.target)) AND (public.normalize_match_text(m."Last name") = public.normalize_match_text("substring"(bp_1.norm_source_name, '\s+(.*)$'::text))) AND (COALESCE(m.is_current, true) = true) AND (m."Status" = 'Active'::text))))
          WHERE (bp_1.source_name ~~ '% %'::text)
        ), contact_only_matches AS (
         SELECT bp_1.team_player_id,
            NULL::bigint AS member_id,
            'Not Signed Up'::text AS match_rule,
            3 AS match_priority,
            ((c.first_name || ' '::text) || c.last_name) AS resolved_name,
            c.email_address AS email,
            COALESCE(c.mobile_number, c.phone_number) AS phone,
            'Contact Only'::text AS category,
            c.member_status AS status,
            rc_1."Share Contact Detail" AS consent
           FROM ((base_players bp_1
             JOIN public.vw_best_current_contacts c ON ((c.norm_name = bp_1.norm_source_name)))
             LEFT JOIN public.raw_contacts rc_1 ON ((rc_1.id = c.contact_id)))
        ), fuzzy_matches AS (
         SELECT bp_1.team_player_id,
            m.id AS member_id,
            (('Fuzzy ('::text || round((public.similarity(public.normalize_match_text(((m."First name" || ' '::text) || m."Last name")), bp_1.norm_source_name))::numeric, 2)) || ')'::text) AS match_rule,
            4 AS match_priority,
            ((m."First name" || ' '::text) || m."Last name") AS resolved_name,
            m."Email address" AS email,
            COALESCE(m."Mobile number", m."Phone number") AS phone,
            m."Membership" AS category,
            m."Status" AS status,
            m."Share Contact Detail" AS consent
           FROM (base_players bp_1
             CROSS JOIN ( SELECT raw_members.id,
                    raw_members."First name",
                    raw_members."Last name",
                    raw_members."Email address",
                    raw_members."Mobile number",
                    raw_members."Phone number",
                    raw_members."Membership",
                    raw_members."Status",
                    raw_members."Share Contact Detail"
                   FROM public.raw_members
                  WHERE ((COALESCE(raw_members.is_current, true) = true) AND (raw_members."Status" = 'Active'::text))) m)
          WHERE (public.similarity(public.normalize_match_text(((m."First name" || ' '::text) || m."Last name")), bp_1.norm_source_name) >= (0.7)::double precision)
        ), all_candidates AS (
         SELECT exact_matches.team_player_id,
            exact_matches.member_id,
            exact_matches.match_rule,
            exact_matches.match_priority,
            exact_matches.resolved_name,
            exact_matches.email,
            exact_matches.phone,
            exact_matches.category,
            exact_matches.status,
            exact_matches.consent
           FROM exact_matches
        UNION ALL
         SELECT override_matches.team_player_id,
            override_matches.member_id,
            override_matches.match_rule,
            override_matches.match_priority,
            override_matches.resolved_name,
            override_matches.email,
            override_matches.phone,
            override_matches.category,
            override_matches.status,
            override_matches.consent
           FROM override_matches
        UNION ALL
         SELECT nickname_matches.team_player_id,
            nickname_matches.member_id,
            nickname_matches.match_rule,
            nickname_matches.match_priority,
            nickname_matches.resolved_name,
            nickname_matches.email,
            nickname_matches.phone,
            nickname_matches.category,
            nickname_matches.status,
            nickname_matches.consent
           FROM nickname_matches
        UNION ALL
         SELECT contact_only_matches.team_player_id,
            contact_only_matches.member_id,
            contact_only_matches.match_rule,
            contact_only_matches.match_priority,
            contact_only_matches.resolved_name,
            contact_only_matches.email,
            contact_only_matches.phone,
            contact_only_matches.category,
            contact_only_matches.status,
            contact_only_matches.consent
           FROM contact_only_matches
        UNION ALL
         SELECT fuzzy_matches.team_player_id,
            fuzzy_matches.member_id,
            fuzzy_matches.match_rule,
            fuzzy_matches.match_priority,
            fuzzy_matches.resolved_name,
            fuzzy_matches.email,
            fuzzy_matches.phone,
            fuzzy_matches.category,
            fuzzy_matches.status,
            fuzzy_matches.consent
           FROM fuzzy_matches
        ), ranked_candidates AS (
         SELECT all_candidates.team_player_id,
            all_candidates.member_id,
            all_candidates.match_rule,
            all_candidates.match_priority,
            all_candidates.resolved_name,
            all_candidates.email,
            all_candidates.phone,
            all_candidates.category,
            all_candidates.status,
            all_candidates.consent,
            row_number() OVER (PARTITION BY all_candidates.team_player_id ORDER BY all_candidates.match_priority, all_candidates.resolved_name) AS rn
           FROM all_candidates
        ), junior_parents AS (
         SELECT j.member_raw_id,
            j.main_contact_name,
            j.main_contact_email,
            COALESCE(j.main_contact_mobile, j.main_contact_phone) AS main_contact_phone,
            j.match_confidence
           FROM public.vw_junior_main_contacts j
          WHERE (j.match_confidence = 'high'::text)
        )
 SELECT bp.team_player_id,
    bp.team_id,
    bp.team_name,
    bp.season,
    bp.source_name,
    bp.is_captain,
    bp.sort_order,
    COALESCE(rc.resolved_name, 'No Match'::text) AS resolved_name,
    rc.match_rule,
    rc.category,
    rc.status,
    rc.email AS self_email,
    rc.phone AS self_phone,
    rc.consent AS self_consent,
    jp.main_contact_name,
    jp.main_contact_email,
    jp.main_contact_phone,
        CASE
            WHEN (rc.resolved_name IS NULL) THEN 'danger'::text
            WHEN (rc.match_rule = 'Exact Member'::text) THEN 'success'::text
            WHEN (rc.match_rule = ANY (ARRAY['Override (Full)'::text, 'Nickname'::text])) THEN 'info'::text
            WHEN (rc.match_rule = 'Not Signed Up'::text) THEN 'warning'::text
            ELSE 'primary'::text
        END AS match_ui_status
   FROM ((base_players bp
     LEFT JOIN ranked_candidates rc ON (((rc.team_player_id = bp.team_player_id) AND (rc.rn = 1))))
     LEFT JOIN junior_parents jp ON ((jp.member_raw_id = rc.member_id)));


--
-- Name: vw_raw_contacts_all; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_contacts_all AS
 SELECT rc."Venue ID",
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
    rss.current_snapshot_year AS snapshot_year,
    true AS is_current,
    rss.updated_at AS snapshot_recorded_at,
    'raw_contacts_current'::text AS snapshot_source
   FROM (public.raw_contacts rc
     JOIN public.raw_snapshot_state rss ON ((rss.table_name = 'raw_contacts'::text)))
  WHERE (COALESCE(rc.is_current, true) = true)
UNION ALL
 SELECT rch."Venue ID",
    rch."Unique ID",
    rch."First name",
    rch."Last name",
    rch.gender,
    rch.age,
    rch.junior,
    rch."Date of birth",
    rch."Email address",
    rch."Phone number",
    rch."Work number",
    rch."Mobile number",
    rch."Emergency contact name",
    rch."Emergency phone number",
    rch."Address 1",
    rch."Address 2",
    rch."Address 3",
    rch.town,
    rch.county,
    rch.country,
    rch.postcode,
    rch."British Tennis Number",
    rch."Date joined venue",
    rch."Medical history",
    rch.occupation,
    rch.registered,
    rch.unsubscribed,
    rch."Member status",
    rch."Last active",
    rch.created,
    rch."Receipt of Emails",
    rch."Share Contact Detail",
    rch."Member's Directory",
    rch.photography,
    rch.snapshot_year,
    false AS is_current,
    rch.archived_at AS snapshot_recorded_at,
    rch.snapshot_source
   FROM public.raw_contacts_historical rch;


--
-- Name: vw_contacts_current_and_historical; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_contacts_current_and_historical AS
 SELECT vw_raw_contacts_all."Venue ID",
    vw_raw_contacts_all."Unique ID",
    vw_raw_contacts_all."First name",
    vw_raw_contacts_all."Last name",
    vw_raw_contacts_all.gender,
    vw_raw_contacts_all.age,
    vw_raw_contacts_all.junior,
    vw_raw_contacts_all."Date of birth",
    vw_raw_contacts_all."Email address",
    vw_raw_contacts_all."Phone number",
    vw_raw_contacts_all."Work number",
    vw_raw_contacts_all."Mobile number",
    vw_raw_contacts_all."Emergency contact name",
    vw_raw_contacts_all."Emergency phone number",
    vw_raw_contacts_all."Address 1",
    vw_raw_contacts_all."Address 2",
    vw_raw_contacts_all."Address 3",
    vw_raw_contacts_all.town,
    vw_raw_contacts_all.county,
    vw_raw_contacts_all.country,
    vw_raw_contacts_all.postcode,
    vw_raw_contacts_all."British Tennis Number",
    vw_raw_contacts_all."Date joined venue",
    vw_raw_contacts_all."Medical history",
    vw_raw_contacts_all.occupation,
    vw_raw_contacts_all.registered,
    vw_raw_contacts_all.unsubscribed,
    vw_raw_contacts_all."Member status",
    vw_raw_contacts_all."Last active",
    vw_raw_contacts_all.created,
    vw_raw_contacts_all."Receipt of Emails",
    vw_raw_contacts_all."Share Contact Detail",
    vw_raw_contacts_all."Member's Directory",
    vw_raw_contacts_all.photography,
    vw_raw_contacts_all.snapshot_year,
    vw_raw_contacts_all.is_current,
    vw_raw_contacts_all.snapshot_recorded_at,
    vw_raw_contacts_all.snapshot_source
   FROM public.vw_raw_contacts_all;


--
-- Name: vw_main_contacts_resolution_regression_checks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_main_contacts_resolution_regression_checks AS
 SELECT run_main_contacts_resolution_regression_checks.check_name,
    run_main_contacts_resolution_regression_checks.ok,
    run_main_contacts_resolution_regression_checks.expected,
    run_main_contacts_resolution_regression_checks.actual
   FROM public.run_main_contacts_resolution_regression_checks() run_main_contacts_resolution_regression_checks(check_name, ok, expected, actual);


--
-- Name: vw_member_contact_matching_regression_checks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_member_contact_matching_regression_checks AS
 SELECT run_member_contact_matching_regression_checks.check_name,
    run_member_contact_matching_regression_checks.ok,
    run_member_contact_matching_regression_checks.expected,
    run_member_contact_matching_regression_checks.actual
   FROM public.run_member_contact_matching_regression_checks() run_member_contact_matching_regression_checks(check_name, ok, expected, actual);


--
-- Name: vw_raw_members_all; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_members_all AS
 SELECT rm."Venue ID",
    rm."First name",
    rm."Last name",
    rm."Gender",
    rm."Age",
    rm."Junior",
    rm."Date of birth",
    rm."Membership",
    rm."Payment",
    rm."Cost",
    rm."Paid",
    rm."Paid Credit Card",
    rm."Paid Direct Debit",
    rm."Paid Cash",
    rm."Paid Cheque",
    rm."Paid Other",
    rm."Gift aid",
    rm."Status",
    rm."Start Date",
    rm."Expiry Date",
    rm."Email address",
    rm."Phone number",
    rm."Work number",
    rm."Mobile number",
    rm."Emergency contact name",
    rm."Emergency phone number",
    rm."Address 1",
    rm."Address 2",
    rm."Address 3",
    rm."Town",
    rm."County",
    rm."Country",
    rm."Postcode",
    rm."British Tennis Number",
    rm."Date joined venue",
    rm."Medical history",
    rm."Venue source",
    rm."Contact source",
    rm."Occupation",
    rm."Tags provided",
    rm."Key pin number",
    rm."Registered",
    rm."Member status",
    rm."Receipt of Emails",
    rm."Share Contact Detail",
    rm."Member's Directory",
    rm."Photography",
    rm." Venue source",
    rss.current_snapshot_year AS snapshot_year,
    true AS is_current,
    rss.updated_at AS snapshot_recorded_at,
    'raw_members_current'::text AS snapshot_source
   FROM (public.raw_members rm
     JOIN public.raw_snapshot_state rss ON ((rss.table_name = 'raw_members'::text)))
  WHERE (COALESCE(rm.is_current, true) = true)
UNION ALL
 SELECT rmh."Venue ID",
    rmh."First name",
    rmh."Last name",
    rmh."Gender",
    rmh."Age",
    rmh."Junior",
    rmh."Date of birth",
    rmh."Membership",
    rmh."Payment",
    rmh."Cost",
    rmh."Paid",
    rmh."Paid Credit Card",
    rmh."Paid Direct Debit",
    rmh."Paid Cash",
    rmh."Paid Cheque",
    rmh."Paid Other",
    rmh."Gift aid",
    rmh."Status",
    rmh."Start Date",
    rmh."Expiry Date",
    rmh."Email address",
    rmh."Phone number",
    rmh."Work number",
    rmh."Mobile number",
    rmh."Emergency contact name",
    rmh."Emergency phone number",
    rmh."Address 1",
    rmh."Address 2",
    rmh."Address 3",
    rmh."Town",
    rmh."County",
    rmh."Country",
    rmh."Postcode",
    rmh."British Tennis Number",
    rmh."Date joined venue",
    rmh."Medical history",
    rmh."Venue source",
    rmh."Contact source",
    rmh."Occupation",
    rmh."Tags provided",
    rmh."Key pin number",
    rmh."Registered",
    rmh."Member status",
    rmh."Receipt of Emails",
    rmh."Share Contact Detail",
    rmh."Member's Directory",
    rmh."Photography",
    rmh." Venue source",
    rmh.snapshot_year,
    false AS is_current,
    rmh.archived_at AS snapshot_recorded_at,
    rmh.snapshot_source
   FROM public.raw_members_historical rmh;


--
-- Name: vw_members_current_and_historical; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_members_current_and_historical AS
 SELECT vw_raw_members_all."Venue ID",
    vw_raw_members_all."First name",
    vw_raw_members_all."Last name",
    vw_raw_members_all."Gender",
    vw_raw_members_all."Age",
    vw_raw_members_all."Junior",
    vw_raw_members_all."Date of birth",
    vw_raw_members_all."Membership",
    vw_raw_members_all."Payment",
    vw_raw_members_all."Cost",
    vw_raw_members_all."Paid",
    vw_raw_members_all."Paid Credit Card",
    vw_raw_members_all."Paid Direct Debit",
    vw_raw_members_all."Paid Cash",
    vw_raw_members_all."Paid Cheque",
    vw_raw_members_all."Paid Other",
    vw_raw_members_all."Gift aid",
    vw_raw_members_all."Status",
    vw_raw_members_all."Start Date",
    vw_raw_members_all."Expiry Date",
    vw_raw_members_all."Email address",
    vw_raw_members_all."Phone number",
    vw_raw_members_all."Work number",
    vw_raw_members_all."Mobile number",
    vw_raw_members_all."Emergency contact name",
    vw_raw_members_all."Emergency phone number",
    vw_raw_members_all."Address 1",
    vw_raw_members_all."Address 2",
    vw_raw_members_all."Address 3",
    vw_raw_members_all."Town",
    vw_raw_members_all."County",
    vw_raw_members_all."Country",
    vw_raw_members_all."Postcode",
    vw_raw_members_all."British Tennis Number",
    vw_raw_members_all."Date joined venue",
    vw_raw_members_all."Medical history",
    vw_raw_members_all."Venue source",
    vw_raw_members_all."Contact source",
    vw_raw_members_all."Occupation",
    vw_raw_members_all."Tags provided",
    vw_raw_members_all."Key pin number",
    vw_raw_members_all."Registered",
    vw_raw_members_all."Member status",
    vw_raw_members_all."Receipt of Emails",
    vw_raw_members_all."Share Contact Detail",
    vw_raw_members_all."Member's Directory",
    vw_raw_members_all."Photography",
    vw_raw_members_all." Venue source",
    vw_raw_members_all.snapshot_year,
    vw_raw_members_all.is_current,
    vw_raw_members_all.snapshot_recorded_at,
    vw_raw_members_all.snapshot_source
   FROM public.vw_raw_members_all;


--
-- Name: vw_raw_ambiguous_matches; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_ambiguous_matches AS
 SELECT raw_reconcile_match_audit.raw_table,
    raw_reconcile_match_audit.run_at,
    raw_reconcile_match_audit.source_row,
    raw_reconcile_match_audit.source_name,
    raw_reconcile_match_audit.source_membership,
    raw_reconcile_match_audit.matched_id,
    raw_reconcile_match_audit.match_rule,
    raw_reconcile_match_audit.outcome,
    raw_reconcile_match_audit.candidate_count,
    raw_reconcile_match_audit.candidate_ids,
    raw_reconcile_match_audit.notes
   FROM public.raw_reconcile_match_audit
  WHERE (raw_reconcile_match_audit.outcome = ANY (ARRAY['ambiguous_same_name'::text, 'ambiguous_multiple_candidates'::text]))
  ORDER BY raw_reconcile_match_audit.run_at DESC, raw_reconcile_match_audit.raw_table, raw_reconcile_match_audit.source_name, raw_reconcile_match_audit.id DESC;


--
-- Name: vw_raw_contacts_match_review; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_contacts_match_review AS
 SELECT raw_reconcile_match_audit.id,
    raw_reconcile_match_audit.run_at,
    raw_reconcile_match_audit.source_row,
    raw_reconcile_match_audit.source_name,
    raw_reconcile_match_audit.matched_id,
    raw_reconcile_match_audit.match_rule,
    raw_reconcile_match_audit.outcome,
    raw_reconcile_match_audit.candidate_count,
    raw_reconcile_match_audit.candidate_ids,
    raw_reconcile_match_audit.notes
   FROM public.raw_reconcile_match_audit
  WHERE (raw_reconcile_match_audit.raw_table = 'raw_contacts'::text)
  ORDER BY raw_reconcile_match_audit.run_at DESC, raw_reconcile_match_audit.id DESC;


--
-- Name: vw_raw_members_main_contacts_current; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_members_main_contacts_current AS
 SELECT raw_members_main_contacts.id,
    raw_members_main_contacts."Venue ID",
    raw_members_main_contacts."First name",
    raw_members_main_contacts."Last name",
    raw_members_main_contacts."Gender",
    raw_members_main_contacts."Age",
    raw_members_main_contacts."Junior",
    raw_members_main_contacts."Date of birth",
    raw_members_main_contacts."Membership",
    raw_members_main_contacts."Payment",
    raw_members_main_contacts."Cost",
    raw_members_main_contacts."Paid",
    raw_members_main_contacts."Paid Credit Card",
    raw_members_main_contacts."Paid Direct Debit",
    raw_members_main_contacts."Paid Cash",
    raw_members_main_contacts."Paid Cheque",
    raw_members_main_contacts."Paid Other",
    raw_members_main_contacts."Gift aid",
    raw_members_main_contacts."Status",
    raw_members_main_contacts."Start Date",
    raw_members_main_contacts."Expiry Date",
    raw_members_main_contacts."Email address",
    raw_members_main_contacts."Phone number",
    raw_members_main_contacts."Work number",
    raw_members_main_contacts."Mobile number",
    raw_members_main_contacts."Emergency contact name",
    raw_members_main_contacts."Emergency phone number",
    raw_members_main_contacts."Address 1",
    raw_members_main_contacts."Address 2",
    raw_members_main_contacts."Address 3",
    raw_members_main_contacts."Town",
    raw_members_main_contacts."County",
    raw_members_main_contacts."Country",
    raw_members_main_contacts."Postcode",
    raw_members_main_contacts."British Tennis Number",
    raw_members_main_contacts."Date joined venue",
    raw_members_main_contacts."Medical history",
    raw_members_main_contacts."Venue source",
    raw_members_main_contacts."Contact source",
    raw_members_main_contacts."Occupation",
    raw_members_main_contacts."Tags provided",
    raw_members_main_contacts."Key pin number",
    raw_members_main_contacts."Registered",
    raw_members_main_contacts."Member status",
    raw_members_main_contacts."Receipt of Emails",
    raw_members_main_contacts."Share Contact Detail",
    raw_members_main_contacts."Member's Directory",
    raw_members_main_contacts."Photography",
    raw_members_main_contacts." Venue source",
    raw_members_main_contacts.first_seen_at,
    raw_members_main_contacts.last_seen_at,
    raw_members_main_contacts.is_current
   FROM public.raw_members_main_contacts
  WHERE (COALESCE(raw_members_main_contacts.is_current, true) = true);


--
-- Name: vw_raw_members_match_review; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_members_match_review AS
 SELECT raw_reconcile_match_audit.id,
    raw_reconcile_match_audit.run_at,
    raw_reconcile_match_audit.source_row,
    raw_reconcile_match_audit.source_name,
    raw_reconcile_match_audit.source_membership,
    raw_reconcile_match_audit.matched_id,
    raw_reconcile_match_audit.match_rule,
    raw_reconcile_match_audit.outcome,
    raw_reconcile_match_audit.candidate_count,
    raw_reconcile_match_audit.candidate_ids,
    raw_reconcile_match_audit.notes
   FROM public.raw_reconcile_match_audit
  WHERE (raw_reconcile_match_audit.raw_table = 'raw_members'::text)
  ORDER BY raw_reconcile_match_audit.run_at DESC, raw_reconcile_match_audit.id DESC;


--
-- Name: vw_raw_weak_name_only_matches; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_raw_weak_name_only_matches AS
 SELECT raw_reconcile_match_audit.raw_table,
    raw_reconcile_match_audit.run_at,
    raw_reconcile_match_audit.source_row,
    raw_reconcile_match_audit.source_name,
    raw_reconcile_match_audit.source_membership,
    raw_reconcile_match_audit.matched_id,
    raw_reconcile_match_audit.match_rule,
    raw_reconcile_match_audit.outcome,
    raw_reconcile_match_audit.candidate_count,
    raw_reconcile_match_audit.candidate_ids,
    raw_reconcile_match_audit.notes
   FROM public.raw_reconcile_match_audit
  WHERE (raw_reconcile_match_audit.outcome = 'matched_by_name_only'::text)
  ORDER BY raw_reconcile_match_audit.run_at DESC, raw_reconcile_match_audit.raw_table, raw_reconcile_match_audit.source_name, raw_reconcile_match_audit.id DESC;


--
-- Name: vw_signup_batch_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_signup_batch_items AS
 WITH signup_rows AS (
         SELECT s.id AS source_id,
            s.batch_id,
            s.signup_date AS item_date,
            s.member,
            s.payer,
            s.product,
            COALESCE(NULLIF(TRIM(BOTH FROM s.email_address), ''::text), NULLIF(TRIM(BOTH FROM m."Email address"), ''::text)) AS resolver_email,
            NULLIF(regexp_replace((s.payer)::text, '^\S+\s*'::text, ''::text), ''::text) AS payer_last_name,
            COALESCE(NULLIF(TRIM(BOTH FROM s.source), ''::text), 'email_capture'::text) AS source
           FROM (public.member_signups s
             LEFT JOIN public.raw_members m ON ((((s.member)::text = concat(m."First name", ' ', m."Last name")) AND (m."Membership" = (s.product)::text) AND (COALESCE(m.is_current, true) = true))))
        )
 SELECT s.source_id,
    s.batch_id,
    s.item_date,
    s.member,
    s.payer,
    s.product,
    COALESCE(NULLIF(TRIM(BOTH FROM bc.email_address), ''::text), NULLIF(TRIM(BOTH FROM s.resolver_email), ''::text)) AS email_address,
    bc.address_1,
    bc.address_2,
    bc.address_3,
    bc.town,
    bc.postcode,
        CASE
            WHEN ((s.product)::text <> ALL ((ARRAY['6. Parent 2026'::character varying, 'b. Pavilion Key'::character varying, 'a. Social 2026'::character varying])::text[])) THEN 1
            ELSE 0
        END AS regular_tags,
        CASE
            WHEN ((s.product)::text = '6. Parent 2026'::text) THEN 1
            ELSE 0
        END AS parent_tags,
        CASE
            WHEN ((s.product)::text = 'b. Pavilion Key'::text) THEN 1
            ELSE 0
        END AS key_tags,
    s.source,
    NULL::text AS notes,
    'member_signups'::text AS source_table
   FROM (signup_rows s
     LEFT JOIN LATERAL public.resolve_best_contact_row((s.payer)::text, s.resolver_email, s.payer_last_name, false) bc(contact_id, payer_name, first_name, last_name, email_address, phone_number, mobile_number, address_1, address_2, address_3, town, county, postcode, venue_id, member_status, resolve_rule, candidate_count) ON (true))
UNION ALL
 SELECT mi.id AS source_id,
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


--
-- Name: vw_signup_batch_consolidated; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_signup_batch_consolidated AS
 SELECT vw_signup_batch_items.batch_id,
    vw_signup_batch_items.payer,
    vw_signup_batch_items.address_1,
    vw_signup_batch_items.address_2,
    vw_signup_batch_items.address_3,
    vw_signup_batch_items.town,
    vw_signup_batch_items.postcode,
    sum(vw_signup_batch_items.regular_tags) AS regular_tags,
    sum(vw_signup_batch_items.parent_tags) AS parent_tags,
    sum(vw_signup_batch_items.key_tags) AS key_tags,
    sum(((vw_signup_batch_items.regular_tags + vw_signup_batch_items.parent_tags) + vw_signup_batch_items.key_tags)) AS total_items,
    bool_or((vw_signup_batch_items.source = 'manual'::text)) AS has_manual_items
   FROM public.vw_signup_batch_items
  WHERE ((COALESCE(vw_signup_batch_items.product, ''::character varying))::text <> 'a. Social 2026'::text)
  GROUP BY vw_signup_batch_items.batch_id, vw_signup_batch_items.payer, vw_signup_batch_items.address_1, vw_signup_batch_items.address_2, vw_signup_batch_items.address_3, vw_signup_batch_items.town, vw_signup_batch_items.postcode;


--
-- Name: vw_signup_batches_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_signup_batches_summary AS
 SELECT b.id AS batch_id,
    b.status,
    b.created_at,
    b.completed_at,
    count(*) FILTER (WHERE (i.source_table = 'member_signups'::text)) AS signup_rows,
    count(*) FILTER (WHERE (i.source = 'manual'::text)) AS manual_rows,
    COALESCE(sum(i.regular_tags), (0)::bigint) AS regular_tags,
    COALESCE(sum(i.parent_tags), (0)::bigint) AS parent_tags,
    COALESCE(sum(i.key_tags), (0)::bigint) AS key_tags,
    COALESCE(sum(((i.regular_tags + i.parent_tags) + i.key_tags)), (0)::bigint) AS total_items
   FROM (public.signup_batches b
     LEFT JOIN public.vw_signup_batch_items i ON ((i.batch_id = b.id)))
  GROUP BY b.id, b.status, b.created_at, b.completed_at;


--
-- Name: vw_team_management_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_team_management_summary AS
 WITH captain_info AS (
         SELECT DISTINCT ON (tp.team_id) tp.team_id,
            tp.source_name AS captain_name,
            m.match_ui_status AS captain_match_status,
            m.resolved_name AS captain_resolved_name,
            m.self_email AS captain_email
           FROM (public.team_players tp
             LEFT JOIN public.vw_appsmith_team_player_matching m ON ((m.team_player_id = tp.id)))
          WHERE (tp.is_captain = true)
          ORDER BY tp.team_id, tp.id
        )
 SELECT t.id AS team_id,
    t.team_name,
    t.section,
    t.season,
    t.sort_order,
    ci.captain_name,
    ci.captain_match_status,
    ( SELECT count(*) AS count
           FROM public.team_players tp
          WHERE (tp.team_id = t.id)) AS player_count,
        CASE
            WHEN ((ci.captain_email IS NOT NULL) AND (ci.captain_email <> ''::text) AND (ci.captain_resolved_name IS NOT NULL) AND (ci.captain_resolved_name <> 'No Match'::text)) THEN true
            ELSE false
        END AS ready_for_mailout
   FROM (public.teams t
     LEFT JOIN captain_info ci ON ((ci.team_id = t.id)));


--
-- Name: vw_team_roster_consolidated; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_team_roster_consolidated AS
 SELECT t.id AS team_id,
    t.team_name,
    t.section,
    t.season,
    t.sort_order AS team_sort_order,
    tp.id AS team_player_id,
    tp.source_name,
    tp.is_captain,
    tp.sort_order AS player_sort_order,
    m.resolved_name,
    m.match_rule,
    m.category,
    m.status AS membership_status,
    m.self_email,
    m.self_phone,
    m.self_consent,
    m.main_contact_name,
    m.main_contact_email,
    m.main_contact_phone,
    m.match_ui_status
   FROM ((public.teams t
     LEFT JOIN public.team_players tp ON ((tp.team_id = t.id)))
     LEFT JOIN public.vw_appsmith_team_player_matching m ON ((m.team_player_id = tp.id)));


--
-- Name: email_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_templates ALTER COLUMN id SET DEFAULT nextval('public.email_templates_id_seq'::regclass);


--
-- Name: html_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.html_templates ALTER COLUMN id SET DEFAULT nextval('public.html_templates_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images ALTER COLUMN id SET DEFAULT nextval('public.images_id_seq'::regclass);


--
-- Name: member_signups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_signups ALTER COLUMN id SET DEFAULT nextval('public.member_signups_id_seq'::regclass);


--
-- Name: membership_history_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_history_snapshots ALTER COLUMN id SET DEFAULT nextval('public.membership_history_snapshots_id_seq'::regclass);


--
-- Name: raw_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_contacts ALTER COLUMN id SET DEFAULT nextval('public.raw_contacts_id_seq'::regclass);


--
-- Name: raw_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_members ALTER COLUMN id SET DEFAULT nextval('public.raw_members_id_seq'::regclass);


--
-- Name: raw_reconcile_match_audit id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_reconcile_match_audit ALTER COLUMN id SET DEFAULT nextval('public.raw_reconcile_match_audit_id_seq'::regclass);


--
-- Name: refunds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds ALTER COLUMN id SET DEFAULT nextval('public.refunds_id_seq'::regclass);


--
-- Name: signup_batch_manual_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signup_batch_manual_items ALTER COLUMN id SET DEFAULT nextval('public.signup_batch_manual_items_id_seq'::regclass);


--
-- Name: signup_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signup_batches ALTER COLUMN id SET DEFAULT nextval('public.signup_batches_id_seq'::regclass);


--
-- Name: team_nicknames id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_nicknames ALTER COLUMN id SET DEFAULT nextval('public.team_nicknames_id_seq'::regclass);


--
-- PostgreSQL database dump complete
--

\unrestrict OenAnmWAd06GyAeKIURUwarG3he6g3VL2C9hc8IQTMWdisRrueYs12Wtn4aaUdh

