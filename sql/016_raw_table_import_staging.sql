-- Stage 5 of the raw table primary-key rollout.
-- Introduce local staging tables for raw_members and raw_contacts imports
-- without changing the live import workflows yet.

BEGIN;

CREATE TABLE IF NOT EXISTS public.raw_members_import_staging (
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

CREATE TABLE IF NOT EXISTS public.raw_contacts_import_staging (
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

CREATE OR REPLACE FUNCTION public.prepare_raw_members_import_staging()
RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE public.raw_members_import_staging;
    RETURN 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.prepare_raw_contacts_import_staging()
RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE public.raw_contacts_import_staging;
    RETURN 1;
END;
$$;

COMMIT;
