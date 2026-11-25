-- Shared, atomic rate limiting for server-side API routes.
-- Apply only after reviewing on a disposable Supabase project.
-- Identifiers are HMACed by the application; this table must not store phone/IP plaintext.

BEGIN;

CREATE TABLE IF NOT EXISTS public.api_rate_limit_buckets (
  bucket_hash TEXT PRIMARY KEY CHECK (bucket_hash ~ '^[0-9a-f]{64}$'),
  window_started_at TIMESTAMPTZ NOT NULL,
  request_count INTEGER NOT NULL CHECK (request_count >= 1)
);

ALTER TABLE public.api_rate_limit_buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_rate_limit_buckets FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.api_rate_limit_buckets FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.consume_api_rate_limit(
  p_bucket_hash TEXT,
  p_max_requests INTEGER,
  p_window_seconds INTEGER
)
RETURNS TABLE (allowed BOOLEAN, retry_after_seconds INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  current_time TIMESTAMPTZ := clock_timestamp();
  current_count INTEGER;
  current_window TIMESTAMPTZ;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_bucket_hash !~ '^[0-9a-f]{64}$'
     OR p_max_requests < 1 OR p_max_requests > 10000
     OR p_window_seconds < 1 OR p_window_seconds > 86400 THEN
    RAISE EXCEPTION 'invalid limiter parameters' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.api_rate_limit_buckets AS buckets (bucket_hash, window_started_at, request_count)
  VALUES (p_bucket_hash, current_time, 1)
  ON CONFLICT (bucket_hash) DO UPDATE SET
    window_started_at = CASE
      WHEN current_time >= buckets.window_started_at + make_interval(secs => p_window_seconds)
        THEN current_time
      ELSE buckets.window_started_at
    END,
    request_count = CASE
      WHEN current_time >= buckets.window_started_at + make_interval(secs => p_window_seconds)
        THEN 1
      ELSE buckets.request_count + 1
    END
  RETURNING buckets.request_count, buckets.window_started_at
  INTO current_count, current_window;

  RETURN QUERY SELECT
    current_count <= p_max_requests,
    GREATEST(1, CEIL(EXTRACT(EPOCH FROM (current_window + make_interval(secs => p_window_seconds) - current_time)))::INTEGER);
END;
$$;

REVOKE ALL ON FUNCTION public.consume_api_rate_limit(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_api_rate_limit(TEXT, INTEGER, INTEGER) TO service_role;

COMMIT;

-- Old buckets may be cleaned periodically by a trusted database maintenance job.
