--
-- PostgreSQL database dump
--

\restrict 01FhOXeWKRx0LSdtlPSIrfECu4pNYWRI0rTCnGAo4lQ7Pj6BX96ljAqh0miPeS0

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
-- Name: case_emails case_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_emails
    ADD CONSTRAINT case_emails_pkey PRIMARY KEY (id);


--
-- Name: cases cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (id);


--
-- Name: email_status email_status_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_status
    ADD CONSTRAINT email_status_pk PRIMARY KEY (message_id);


--
-- Name: email_templates email_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_templates
    ADD CONSTRAINT email_templates_pkey PRIMARY KEY (id);


--
-- Name: email_templates email_templates_template_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_templates
    ADD CONSTRAINT email_templates_template_key_key UNIQUE (template_key);


--
-- Name: global_settings global_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_settings
    ADD CONSTRAINT global_settings_pkey PRIMARY KEY (key);


--
-- Name: html_templates html_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.html_templates
    ADD CONSTRAINT html_templates_pkey PRIMARY KEY (id);


--
-- Name: html_templates html_templates_webhook_path_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.html_templates
    ADD CONSTRAINT html_templates_webhook_path_key UNIQUE (webhook_path);


--
-- Name: images images_image_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_image_key_key UNIQUE (image_key);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: member_signups member_signups_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_signups
    ADD CONSTRAINT member_signups_pk PRIMARY KEY (signup_date, member, product);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY ("First_Name", "Last_Name", "Membership");


--
-- Name: membership_history_snapshots membership_history_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_history_snapshots
    ADD CONSTRAINT membership_history_snapshots_pkey PRIMARY KEY (id);


--
-- Name: membership_history_snapshots membership_history_snapshots_snapshot_key_membership_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_history_snapshots
    ADD CONSTRAINT membership_history_snapshots_snapshot_key_membership_key UNIQUE (snapshot_key, membership);


--
-- Name: membership_packages membership_packages_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_packages
    ADD CONSTRAINT membership_packages_pk PRIMARY KEY (season, name);


--
-- Name: membership_signup_match_groups membership_signup_match_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_signup_match_groups
    ADD CONSTRAINT membership_signup_match_groups_pkey PRIMARY KEY (season, package_name);


--
-- Name: raw_contacts raw_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_contacts
    ADD CONSTRAINT raw_contacts_pkey PRIMARY KEY (id);


--
-- Name: raw_members_main_contacts raw_members_main_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_members_main_contacts
    ADD CONSTRAINT raw_members_main_contacts_pkey PRIMARY KEY (id);


--
-- Name: raw_members raw_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_members
    ADD CONSTRAINT raw_members_pkey PRIMARY KEY (id);


--
-- Name: raw_reconcile_match_audit raw_reconcile_match_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_reconcile_match_audit
    ADD CONSTRAINT raw_reconcile_match_audit_pkey PRIMARY KEY (id);


--
-- Name: raw_snapshot_state raw_snapshot_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_snapshot_state
    ADD CONSTRAINT raw_snapshot_state_pkey PRIMARY KEY (table_name);


--
-- Name: refunds refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT refunds_pkey PRIMARY KEY (id);


--
-- Name: signup_batch_manual_items signup_batch_manual_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signup_batch_manual_items
    ADD CONSTRAINT signup_batch_manual_items_pkey PRIMARY KEY (id);


--
-- Name: signup_batches signup_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signup_batches
    ADD CONSTRAINT signup_batches_pkey PRIMARY KEY (id);


--
-- Name: team_name_overrides team_name_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_name_overrides
    ADD CONSTRAINT team_name_overrides_pkey PRIMARY KEY (id);


--
-- Name: team_name_overrides team_name_overrides_source_target_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_name_overrides
    ADD CONSTRAINT team_name_overrides_source_target_key UNIQUE (source, target);


--
-- Name: team_nicknames team_nicknames_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_nicknames
    ADD CONSTRAINT team_nicknames_pkey PRIMARY KEY (id);


--
-- Name: team_nicknames team_nicknames_source_target_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_nicknames
    ADD CONSTRAINT team_nicknames_source_target_key UNIQUE (source, target);


--
-- Name: team_players team_players_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_players
    ADD CONSTRAINT team_players_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: email_templates_is_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_templates_is_active_idx ON public.email_templates USING btree (is_active);


--
-- Name: html_templates_is_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX html_templates_is_active_idx ON public.html_templates USING btree (is_active);


--
-- Name: html_templates_webhook_path_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX html_templates_webhook_path_idx ON public.html_templates USING btree (webhook_path);


--
-- Name: idx_case_emails_case_id_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_case_id_created_at ON public.case_emails USING btree (case_id, created_at DESC);


--
-- Name: idx_case_emails_case_id_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_case_id_sent_at ON public.case_emails USING btree (case_id, sent_at DESC);


--
-- Name: idx_case_emails_direction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_direction ON public.case_emails USING btree (direction);


--
-- Name: idx_case_emails_gmail_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_gmail_message_id ON public.case_emails USING btree (gmail_message_id);


--
-- Name: idx_case_emails_gmail_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_gmail_thread_id ON public.case_emails USING btree (gmail_thread_id) WHERE (gmail_thread_id IS NOT NULL);


--
-- Name: idx_case_emails_in_reply_to_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_in_reply_to_message_id ON public.case_emails USING btree (in_reply_to_message_id) WHERE (in_reply_to_message_id IS NOT NULL);


--
-- Name: idx_case_emails_open_tracking_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_open_tracking_status ON public.case_emails USING btree (open_tracking_status);


--
-- Name: idx_case_emails_parent_case_email_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_case_emails_parent_case_email_id ON public.case_emails USING btree (parent_case_email_id) WHERE (parent_case_email_id IS NOT NULL);


--
-- Name: idx_cases_contact_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_contact_email ON public.cases USING btree (contact_email);


--
-- Name: idx_cases_metadata_gmail_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_metadata_gmail_thread_id ON public.cases USING btree (((metadata ->> 'gmail_thread_id'::text))) WHERE (COALESCE((metadata ->> 'gmail_thread_id'::text), ''::text) <> ''::text);


--
-- Name: idx_cases_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_priority ON public.cases USING btree (priority);


--
-- Name: idx_cases_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_status ON public.cases USING btree (status);


--
-- Name: idx_cases_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cases_updated_at ON public.cases USING btree (updated_at DESC);


--
-- Name: idx_images_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_images_is_active ON public.images USING btree (is_active);


--
-- Name: idx_member_signups_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_member_signups_batch_id ON public.member_signups USING btree (batch_id);


--
-- Name: idx_member_signups_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_member_signups_id ON public.member_signups USING btree (id);


--
-- Name: idx_member_signups_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_member_signups_source ON public.member_signups USING btree (source);


--
-- Name: idx_member_signups_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_member_signups_status ON public.member_signups USING btree (status);


--
-- Name: idx_membership_history_snapshots_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_history_snapshots_lookup ON public.membership_history_snapshots USING btree (snapshot_key);


--
-- Name: idx_raw_contacts_historical_snapshot_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_contacts_historical_snapshot_year ON public.raw_contacts_historical USING btree (snapshot_year);


--
-- Name: idx_raw_members_historical_snapshot_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_members_historical_snapshot_year ON public.raw_members_historical USING btree (snapshot_year);


--
-- Name: idx_raw_reconcile_match_audit_outcome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_reconcile_match_audit_outcome ON public.raw_reconcile_match_audit USING btree (outcome, raw_table, run_at DESC);


--
-- Name: idx_raw_reconcile_match_audit_table_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_reconcile_match_audit_table_run ON public.raw_reconcile_match_audit USING btree (raw_table, run_at DESC);


--
-- Name: idx_refunds_from_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refunds_from_date ON public.refunds USING btree (from_date);


--
-- Name: idx_refunds_membership; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refunds_membership ON public.refunds USING btree (membership);


--
-- Name: idx_refunds_refund_for; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refunds_refund_for ON public.refunds USING btree (refund_for);


--
-- Name: idx_refunds_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refunds_status ON public.refunds USING btree (status);


--
-- Name: idx_signup_batch_manual_items_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_signup_batch_manual_items_batch_id ON public.signup_batch_manual_items USING btree (batch_id);


--
-- Name: idx_signup_batch_manual_items_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_signup_batch_manual_items_member ON public.signup_batch_manual_items USING btree (member);


--
-- Name: idx_signup_batch_manual_items_payer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_signup_batch_manual_items_payer ON public.signup_batch_manual_items USING btree (payer);


--
-- Name: idx_signup_batches_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_signup_batches_status ON public.signup_batches USING btree (status);


--
-- Name: idx_team_name_overrides_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_team_name_overrides_source ON public.team_name_overrides USING btree (source);


--
-- Name: idx_team_players_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_team_players_team_id ON public.team_players USING btree (team_id);


--
-- Name: idx_teams_season; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_season ON public.teams USING btree (season);


--
-- Name: raw_contacts_historical_yearly_identity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX raw_contacts_historical_yearly_identity_idx ON public.raw_contacts_historical USING btree (snapshot_year, public.raw_contacts_history_identity_key("Venue ID", "Unique ID", "British Tennis Number", "Email address", "First name", "Last name", postcode, "Address 1"));


--
-- Name: raw_contacts_is_current_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX raw_contacts_is_current_idx ON public.raw_contacts USING btree (is_current);


--
-- Name: raw_members_is_current_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX raw_members_is_current_idx ON public.raw_members USING btree (is_current);


--
-- Name: raw_members_main_contacts_is_current_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX raw_members_main_contacts_is_current_idx ON public.raw_members_main_contacts USING btree (is_current);


--
-- Name: uq_case_emails_gmail_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_case_emails_gmail_message_id ON public.case_emails USING btree (gmail_message_id) WHERE (gmail_message_id IS NOT NULL);


--
-- Name: uq_case_emails_internet_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_case_emails_internet_message_id ON public.case_emails USING btree (internet_message_id) WHERE (internet_message_id IS NOT NULL);


--
-- Name: uq_case_emails_open_tracking_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_case_emails_open_tracking_token ON public.case_emails USING btree (open_tracking_token) WHERE (open_tracking_token IS NOT NULL);


--
-- Name: case_emails case_emails_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_emails
    ADD CONSTRAINT case_emails_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.cases(id) ON DELETE CASCADE;


--
-- Name: case_emails case_emails_parent_case_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_emails
    ADD CONSTRAINT case_emails_parent_case_email_id_fkey FOREIGN KEY (parent_case_email_id) REFERENCES public.case_emails(id) ON DELETE SET NULL;


--
-- Name: member_signups fk_member_signups_batch; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_signups
    ADD CONSTRAINT fk_member_signups_batch FOREIGN KEY (batch_id) REFERENCES public.signup_batches(id);


--
-- Name: signup_batch_manual_items signup_batch_manual_items_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signup_batch_manual_items
    ADD CONSTRAINT signup_batch_manual_items_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.signup_batches(id) ON DELETE CASCADE;


--
-- Name: team_players team_players_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_players
    ADD CONSTRAINT team_players_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 01FhOXeWKRx0LSdtlPSIrfECu4pNYWRI0rTCnGAo4lQ7Pj6BX96ljAqh0miPeS0

