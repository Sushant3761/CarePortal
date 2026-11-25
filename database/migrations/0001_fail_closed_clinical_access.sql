-- CarePortal access lockdown baseline.
--
-- IMPORTANT: This migration intentionally denies direct anon/authenticated
-- access to every patient/clinical table until ownership and staff-assignment
-- semantics are finalized and protected server routes are deployed. Applying
-- it will stop the current browser-direct kiosk/dashboard database workflows.
-- Review against a disposable Supabase project first. Do not apply to a live
-- project until the application cutover and rollback plan are ready.
-- This migration changes privileges/policies only; it does not delete rows.

BEGIN;

DO $$
DECLARE
  target_table TEXT;
  existing_policy RECORD;
  protected_tables TEXT[] := ARRAY[
    'user_profiles',
    'patients',
    'patient_sessions',
    'consents',
    'clinical_histories',
    'answers',
    'ayush_assessments',
    'documents',
    'document_extractions',
    'timeline_events',
    'alerts',
    'clinical_summaries',
    'queue_items',
    'audit_logs',
    'system_settings',
    'pain_locations',
    'family_medical_history',
    'previous_records',
    'consent_tracking'
  ];
BEGIN
  FOREACH target_table IN ARRAY protected_tables LOOP
    IF to_regclass(format('public.%I', target_table)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', target_table);
      EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', target_table);
      EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM anon, authenticated', target_table);

      FOR existing_policy IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = target_table
      LOOP
        EXECUTE format('DROP POLICY %I ON public.%I', existing_policy.policyname, target_table);
      END LOOP;
    END IF;
  END LOOP;

  -- A signed-in user may read their own profile for login/session display.
  IF to_regclass('public.user_profiles') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON TABLE public.user_profiles TO authenticated';
    EXECUTE 'CREATE POLICY user_profiles_read_self ON public.user_profiles FOR SELECT TO authenticated USING (auth.uid() = id)';
  END IF;

  -- These tables contain reference configuration, not patient records.
  FOREACH target_table IN ARRAY ARRAY['questions', 'departments'] LOOP
    IF to_regclass(format('public.%I', target_table)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', target_table);
      EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', target_table);
      EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM anon, authenticated', target_table);
      EXECUTE format('GRANT SELECT ON TABLE public.%I TO anon, authenticated', target_table);

      FOR existing_policy IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = target_table
      LOOP
        EXECUTE format('DROP POLICY %I ON public.%I', existing_policy.policyname, target_table);
      END LOOP;

      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR SELECT TO anon, authenticated USING (true)',
        target_table || '_read_reference',
        target_table
      );
    END IF;
  END LOOP;
END $$;

COMMIT;

-- Verify that RLS is on and that anon/authenticated have no policies on
-- clinical tables before deploying any new API-backed workflow.
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = ANY(ARRAY[
    'patients', 'patient_sessions', 'consents', 'clinical_histories',
    'answers', 'ayush_assessments', 'documents', 'document_extractions',
    'timeline_events', 'alerts', 'clinical_summaries', 'queue_items',
    'pain_locations', 'family_medical_history', 'previous_records', 'consent_tracking'
  ])
ORDER BY tablename;
