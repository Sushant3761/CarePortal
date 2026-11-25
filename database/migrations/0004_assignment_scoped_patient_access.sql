-- Restore authenticated clinical access after 0001's fail-closed cutover,
-- using verified patient ownership and explicit active doctor assignments.
-- Apply only after reviewing the access model and testing on a disposable DB.
-- Service-role keys remain trusted server credentials and bypass RLS by design.

BEGIN;

DO $$
DECLARE required_table TEXT;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'user_profiles','patients','patient_sessions','consents','clinical_histories',
    'questions','departments','answers','ayush_assessments','documents',
    'document_extractions','timeline_events','alerts','clinical_summaries',
    'queue_items','audit_logs','system_settings','pain_locations',
    'family_medical_history','previous_records','consent_tracking'
  ] LOOP
    IF to_regclass(format('public.%I', required_table)) IS NULL THEN
      RAISE EXCEPTION 'required CarePortal table public.% is missing; apply the reviewed base schema first', required_table;
    END IF;
  END LOOP;
END $$;

CREATE SCHEMA IF NOT EXISTS careportal_private;
REVOKE ALL ON SCHEMA careportal_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA careportal_private TO authenticated;

CREATE TABLE IF NOT EXISTS public.doctor_patient_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE RESTRICT,
  assigned_by UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  CHECK (revoked_at IS NULL OR revoked_at >= assigned_at)
);
CREATE UNIQUE INDEX IF NOT EXISTS doctor_patient_assignments_one_active
  ON public.doctor_patient_assignments(patient_id, doctor_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS doctor_patient_assignments_doctor_active
  ON public.doctor_patient_assignments(doctor_id, patient_id) WHERE revoked_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS patients_user_id_unique_idx
  ON public.patients(user_id) WHERE user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION careportal_private.patient_phone_matches_verified_auth(
  target_user UUID,
  target_phone TEXT
)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, auth
AS $$
  SELECT target_user = auth.uid() AND EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.phone_confirmed_at IS NOT NULL
      AND right(regexp_replace(COALESCE(u.phone, ''), '\D', '', 'g'), 10) =
          right(regexp_replace(COALESCE(target_phone, ''), '\D', '', 'g'), 10)
  )
$$;

CREATE OR REPLACE FUNCTION careportal_private.can_access_patient(target_patient UUID)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth SET row_security = off
AS $$
  SELECT target_patient IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.patients p WHERE p.id = target_patient AND p.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.doctor_patient_assignments a
      JOIN public.user_profiles u ON u.id = a.doctor_id AND u.role = 'doctor' AND u.active
      WHERE a.patient_id = target_patient AND a.doctor_id = auth.uid() AND a.revoked_at IS NULL
    )
  )
$$;

CREATE OR REPLACE FUNCTION careportal_private.can_access_session(target_session UUID)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, public SET row_security = off
AS $$
  SELECT careportal_private.can_access_patient(s.patient_id)
  FROM public.patient_sessions s WHERE s.id = target_session
$$;

CREATE OR REPLACE FUNCTION careportal_private.can_access_document(target_document UUID)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, public SET row_security = off
AS $$
  SELECT careportal_private.can_access_patient(d.patient_id)
  FROM public.documents d WHERE d.id = target_document
$$;

REVOKE ALL ON FUNCTION careportal_private.can_access_patient(UUID),
  careportal_private.can_access_session(UUID),
  careportal_private.can_access_document(UUID),
  careportal_private.patient_phone_matches_verified_auth(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION careportal_private.can_access_patient(UUID),
  careportal_private.can_access_session(UUID),
  careportal_private.can_access_document(UUID),
  careportal_private.patient_phone_matches_verified_auth(UUID, TEXT) TO authenticated;

-- A verified phone links to one existing record only if the normalized number
-- has exactly one unlinked match. Ambiguous or absent matches do not link.
CREATE OR REPLACE FUNCTION careportal_private.link_verified_phone_to_patient()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth, careportal_private SET row_security = off
AS $$
DECLARE matching_count INTEGER;
BEGIN
  IF NEW.phone_confirmed_at IS NULL OR NEW.phone IS NULL OR NEW.phone = '' THEN RETURN NEW; END IF;
  SELECT COUNT(*) INTO matching_count FROM public.patients p
  WHERE p.user_id IS NULL
    AND right(regexp_replace(COALESCE(p.contact_number, ''), '\D', '', 'g'), 10) =
        right(regexp_replace(NEW.phone, '\D', '', 'g'), 10);
  IF matching_count = 1 THEN
    UPDATE public.patients p SET user_id = NEW.id
    WHERE p.user_id IS NULL
      AND right(regexp_replace(COALESCE(p.contact_number, ''), '\D', '', 'g'), 10) =
          right(regexp_replace(NEW.phone, '\D', '', 'g'), 10);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS careportal_link_verified_phone ON auth.users;
CREATE TRIGGER careportal_link_verified_phone
AFTER INSERT OR UPDATE OF phone, phone_confirmed_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION careportal_private.link_verified_phone_to_patient();
REVOKE ALL ON FUNCTION careportal_private.link_verified_phone_to_patient() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE table_name TEXT; policy_row RECORD;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'user_profiles','patients','patient_sessions','consents','clinical_histories',
    'answers','ayush_assessments','documents','document_extractions','timeline_events',
    'alerts','clinical_summaries','queue_items','doctor_patient_assignments',
    'audit_logs','system_settings','pain_locations','family_medical_history',
    'previous_records','consent_tracking'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', table_name);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated', table_name);
    FOR policy_row IN SELECT p.policyname FROM pg_policies AS p
      WHERE p.schemaname = 'public' AND p.tablename = table_name
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', policy_row.policyname, table_name);
    END LOOP;
  END LOOP;

  FOREACH table_name IN ARRAY ARRAY['questions','departments'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', table_name);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO anon, authenticated', table_name);
    FOR policy_row IN SELECT p.policyname FROM pg_policies AS p
      WHERE p.schemaname = 'public' AND p.tablename = table_name
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', policy_row.policyname, table_name);
    END LOOP;
  END LOOP;
END $$;

CREATE POLICY user_profiles_read_self ON public.user_profiles
  FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY patients_read_own_or_assigned ON public.patients
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(id));
CREATE POLICY patients_insert_self ON public.patients
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid() AND
    careportal_private.patient_phone_matches_verified_auth(user_id, contact_number)
  );
CREATE POLICY patients_update_self ON public.patients
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY assignments_read_own_doctor ON public.doctor_patient_assignments
  FOR SELECT TO authenticated USING (doctor_id = auth.uid() AND revoked_at IS NULL);

CREATE POLICY sessions_read_scoped ON public.patient_sessions FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY sessions_insert_scoped ON public.patient_sessions FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY sessions_update_scoped ON public.patient_sessions FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id)) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY consents_read_scoped ON public.consents FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY consents_insert_scoped ON public.consents FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY consents_update_scoped ON public.consents FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id)) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY consent_tracking_read_scoped ON public.consent_tracking FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY consent_tracking_insert_scoped ON public.consent_tracking FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY histories_read_scoped ON public.clinical_histories FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY histories_insert_scoped ON public.clinical_histories FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY histories_update_scoped ON public.clinical_histories FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id)) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY answers_read_scoped ON public.answers FOR SELECT TO authenticated
  USING (careportal_private.can_access_session(session_id));
CREATE POLICY answers_insert_scoped ON public.answers FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_session(session_id));
CREATE POLICY answers_update_scoped ON public.answers FOR UPDATE TO authenticated
  USING (careportal_private.can_access_session(session_id)) WITH CHECK (careportal_private.can_access_session(session_id));
CREATE POLICY ayush_read_scoped ON public.ayush_assessments FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY ayush_insert_scoped ON public.ayush_assessments FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY ayush_update_scoped ON public.ayush_assessments FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id)) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY documents_read_scoped ON public.documents FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY documents_insert_scoped ON public.documents FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY documents_update_scoped ON public.documents FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id)) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY extractions_read_scoped ON public.document_extractions FOR SELECT TO authenticated
  USING (careportal_private.can_access_document(document_id));
CREATE POLICY timeline_read_scoped ON public.timeline_events FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY alerts_read_scoped ON public.alerts FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY alerts_update_scoped ON public.alerts FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id) AND acknowledged_by = auth.uid() AND EXISTS (
    SELECT 1 FROM public.user_profiles u WHERE u.id = auth.uid() AND u.role = 'doctor' AND u.active
  )) WITH CHECK (careportal_private.can_access_patient(patient_id) AND acknowledged_by = auth.uid() AND EXISTS (
    SELECT 1 FROM public.user_profiles u WHERE u.id = auth.uid() AND u.role = 'doctor' AND u.active
  ));
CREATE POLICY summaries_read_scoped ON public.clinical_summaries FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY summaries_update_doctor ON public.clinical_summaries FOR UPDATE TO authenticated
  USING (careportal_private.can_access_patient(patient_id) AND EXISTS (
    SELECT 1 FROM public.user_profiles u WHERE u.id = auth.uid() AND u.role = 'doctor' AND u.active
  )) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY queue_read_scoped ON public.queue_items FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
-- Queue creation and assignment fields must be set by a trusted server workflow;
-- browser roles receive no INSERT policy on queue_items.
CREATE POLICY pain_read_scoped ON public.pain_locations FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY pain_insert_scoped ON public.pain_locations FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY family_history_read_scoped ON public.family_medical_history FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY family_history_insert_scoped ON public.family_medical_history FOR INSERT TO authenticated
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY previous_records_read_scoped ON public.previous_records FOR SELECT TO authenticated
  USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY audit_logs_read_system_admin ON public.audit_logs FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles u WHERE u.id = auth.uid() AND u.role = 'system_admin' AND u.active));
CREATE POLICY settings_read_admin ON public.system_settings FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles u WHERE u.id = auth.uid() AND u.role IN ('admin','system_admin') AND u.active));

CREATE POLICY questions_read_active ON public.questions FOR SELECT TO anon, authenticated USING (active);
CREATE POLICY departments_read_active ON public.departments FOR SELECT TO anon, authenticated USING (active);

-- Keep the private patient document bucket inaccessible to browser roles,
-- including when older permissive Storage policies are present.
INSERT INTO storage.buckets(id, name, public)
VALUES ('patient-documents','patient-documents',FALSE)
ON CONFLICT (id) DO UPDATE SET public = FALSE;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS careportal_patient_documents_deny_anon ON storage.objects;
CREATE POLICY careportal_patient_documents_deny_anon ON storage.objects AS RESTRICTIVE
  FOR ALL TO anon USING (bucket_id <> 'patient-documents') WITH CHECK (bucket_id <> 'patient-documents');
DROP POLICY IF EXISTS careportal_patient_documents_deny_authenticated ON storage.objects;
CREATE POLICY careportal_patient_documents_deny_authenticated ON storage.objects AS RESTRICTIVE
  FOR ALL TO authenticated USING (bucket_id <> 'patient-documents') WITH CHECK (bucket_id <> 'patient-documents');

ALTER VIEW public.patient_queue_view SET (security_invoker = true);

COMMIT;
