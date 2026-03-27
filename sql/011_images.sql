CREATE TABLE IF NOT EXISTS public.images (
    id bigserial PRIMARY KEY,
    image_key text NOT NULL UNIQUE,
    file_name text NOT NULL,
    file_ext text NOT NULL,
    content_type text NOT NULL,
    byte_size integer NOT NULL CHECK (byte_size >= 0),
    source_path text NOT NULL,
    data bytea NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_images_is_active
    ON public.images (is_active);
