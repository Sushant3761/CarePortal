-- CarePortal canonical fresh-install schema for Supabase PostgreSQL.
-- Uses verified Supabase Auth phone identities and explicit active doctor
-- assignments. Do not substitute database/legacy/schema.sql or other legacy scripts.

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable RLS (Row Level Security). Supabase manages its JWT signing secret;
-- do not set an application placeholder here.

-- ===========================
-- ENUMS
-- ===========================

CREATE TYPE user_role AS ENUM ('patient', 'doctor', 'nurse', 'admin', 'system_admin');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE language_type AS ENUM ('en', 'hi');
CREATE TYPE session_status AS ENUM ('active', 'completed', 'abandoned', 'timeout');
CREATE TYPE history_status AS ENUM ('in_progress', 'completed', 'verified');
CREATE TYPE document_type AS ENUM ('prescription', 'lab_report', 'discharge_summary', 'medical_certificate', 'investigation', 'surgical_record', 'imaging', 'other');
CREATE TYPE document_status AS ENUM ('uploaded', 'processing', 'processed', 'verified', 'failed');
CREATE TYPE alert_severity AS ENUM ('info', 'warning', 'critical');
CREATE TYPE alert_type AS ENUM ('red_flag', 'contradiction', 'drug_interaction', 'abnormal_lab', 'missing_info');
CREATE TYPE consent_status AS ENUM ('granted', 'denied', 'withdrawn');
CREATE TYPE priority_type AS ENUM ('normal', 'urgent', 'critical');
CREATE TYPE department_type AS ENUM ('allopathy', 'ayurveda', 'yoga', 'unani', 'siddha', 'homeopathy');

-- ===========================
-- USER PROFILES (extends Supabase Auth)
-- ===========================

CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'patient',
    full_name TEXT NOT NULL,
    contact_number TEXT,
    department TEXT,
    specialization TEXT,
    license_number TEXT,
    active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================
-- PATIENTS
-- ===========================

CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    hospital_id TEXT UNIQUE,
    abha_id TEXT UNIQUE,
    name TEXT NOT NULL,
    date_of_birth DATE,
    age INTEGER,
    gender gender_type NOT NULL,
    contact_number TEXT,
    preferred_language language_type DEFAULT 'en',
    emergency_contact TEXT,
    address TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_patients_hospital_id ON patients(hospital_id);
CREATE INDEX idx_patients_abha_id ON patients(abha_id);
CREATE INDEX idx_patients_contact ON patients(contact_number);

-- ===========================
-- PATIENT SESSIONS
-- ===========================

CREATE TABLE patient_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    status session_status DEFAULT 'active',
    language language_type DEFAULT 'en',
    department TEXT,
    current_step TEXT,
    progress INTEGER DEFAULT 0,
    device_info JSONB,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sessions_patient ON patient_sessions(patient_id);
CREATE INDEX idx_sessions_status ON patient_sessions(status);

-- ===========================
-- CONSENT
-- ===========================

CREATE TABLE consents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE CASCADE,
    version TEXT NOT NULL DEFAULT '1.0',
    language language_type DEFAULT 'en',
    purpose TEXT[] NOT NULL,
    status consent_status DEFAULT 'granted',
    granted_at TIMESTAMP WITH TIME ZONE,
    withdrawn_at TIMESTAMP WITH TIME ZONE,
    device_info JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_consents_patient ON consents(patient_id);

-- ===========================
-- CLINICAL HISTORY
-- ===========================

CREATE TABLE clinical_histories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE SET NULL,
    chief_complaint TEXT NOT NULL,
    history_of_present_illness TEXT,
    socrates JSONB,
    past_medical_history TEXT[],
    past_surgical_history TEXT[],
    medications JSONB DEFAULT '[]',
    allergies JSONB DEFAULT '[]',
    family_history JSONB DEFAULT '[]',
    personal_history JSONB DEFAULT '{}',
    review_of_systems JSONB DEFAULT '{}',
    completeness_score INTEGER DEFAULT 0,
    missing_information TEXT[],
    status history_status DEFAULT 'in_progress',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_clinical_patient ON clinical_histories(patient_id);
CREATE INDEX idx_clinical_status ON clinical_histories(status);

-- ===========================
-- QUESTIONS & ANSWERS
-- ===========================

CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category TEXT NOT NULL,
    question_en TEXT NOT NULL,
    question_hi TEXT NOT NULL,
    question_type TEXT NOT NULL,
    options JSONB,
    validation JSONB,
    required BOOLEAN DEFAULT FALSE,
    follow_up_rules JSONB,
    priority INTEGER DEFAULT 0,
    department TEXT,
    condition TEXT,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_questions_category ON questions(category);

CREATE TABLE answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES patient_sessions(id) ON DELETE CASCADE,
    question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
    value TEXT NOT NULL,
    confidence NUMERIC(3,2),
    input_method TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_answers_session ON answers(session_id);

-- ===========================
-- AYUSH ASSESSMENTS
-- ===========================

CREATE TABLE ayush_assessments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE SET NULL,
    department department_type NOT NULL,
    dashavidha_pariksha JSONB,
    prakriti JSONB,
    ahara JSONB,
    vihara JSONB,
    nidana TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ayush_patient ON ayush_assessments(patient_id);

-- ===========================
-- DOCUMENTS
-- ===========================

CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE SET NULL,
    type document_type NOT NULL,
    file_url TEXT NOT NULL,
    thumbnail_url TEXT,
    mime_type TEXT NOT NULL,
    file_size BIGINT,
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ocr_status document_status DEFAULT 'uploaded',
    extraction_status document_status DEFAULT 'uploaded',
    verification_status document_status DEFAULT 'uploaded',
    uploaded_via TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_documents_patient ON documents(patient_id);
CREATE INDEX idx_documents_type ON documents(type);

-- ===========================
-- DOCUMENT EXTRACTIONS
-- ===========================

CREATE TABLE document_extractions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    ocr_text TEXT,
    entities JSONB DEFAULT '[]',
    confidence_score NUMERIC(3,2),
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_extractions_document ON document_extractions(document_id);

-- ===========================
-- MEDICAL TIMELINE
-- ===========================

CREATE TABLE timeline_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    event_date DATE NOT NULL,
    source_type TEXT,
    source_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_timeline_patient ON timeline_events(patient_id);
CREATE INDEX idx_timeline_date ON timeline_events(event_date);

-- ===========================
-- ALERTS
-- ===========================

CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE SET NULL,
    alert_type alert_type NOT NULL,
    severity alert_severity NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    reason TEXT,
    triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by UUID REFERENCES auth.users(id),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_alerts_patient ON alerts(patient_id);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_acknowledged ON alerts(acknowledged);

-- ===========================
-- CLINICAL SUMMARIES
-- ===========================

CREATE TABLE IF NOT EXISTS clinical_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    clinical_history_id UUID REFERENCES clinical_histories(id) ON DELETE SET NULL,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE SET NULL,
    chief_complaint TEXT,
    history_present_illness TEXT,
    past_medical_history TEXT,
    past_surgical_history TEXT,
    medications TEXT,
    allergies TEXT,
    family_history TEXT,
    personal_history TEXT,
    review_of_systems TEXT,
    prior_investigations TEXT,
    ayush_summary TEXT,
    red_flags TEXT[],
    missing_information TEXT[],
    generated_by TEXT DEFAULT 'ai',
    ai_confidence NUMERIC(4,2) DEFAULT 0.95,
    status TEXT DEFAULT 'pending',
    doctor_edits TEXT,
    verified_by UUID REFERENCES auth.users(id),
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_summaries_patient ON clinical_summaries(patient_id);
CREATE INDEX IF NOT EXISTS idx_summaries_status ON clinical_summaries(status);

-- ===========================
-- QUEUE
-- ===========================

CREATE TABLE IF NOT EXISTS queue_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES patient_sessions(id) ON DELETE CASCADE,
    priority priority_type DEFAULT 'normal',
    department TEXT NOT NULL,
    token_number TEXT,
    assigned_to UUID REFERENCES auth.users(id),
    status TEXT DEFAULT 'waiting',
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_queue_priority ON queue_items(priority);
CREATE INDEX IF NOT EXISTS idx_queue_department ON queue_items(department);

-- ===========================
-- DEPARTMENTS
-- ===========================

CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    type department_type DEFAULT 'allopathy',
    active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================
-- AUDIT LOGS
-- ===========================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    user_role user_role,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    details JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);

-- ===========================
-- SYSTEM SETTINGS
-- ===========================

CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    category TEXT,
    description TEXT,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================
-- TRIGGERS FOR UPDATED_AT
-- ===========================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_clinical_histories_updated_at BEFORE UPDATE ON clinical_histories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ayush_assessments_updated_at BEFORE UPDATE ON ayush_assessments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_clinical_summaries_updated_at BEFORE UPDATE ON clinical_summaries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_queue_items_updated_at BEFORE UPDATE ON queue_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Schema extensions used by the current patient intake UI. These were
-- historically defined by add_new_features.sql, whose RLS disable statements
-- are intentionally not copied into this supported production schema.
ALTER TABLE clinical_histories
  ADD COLUMN pain_description TEXT,
  ADD COLUMN symptom_duration TEXT,
  ADD COLUMN symptom_severity TEXT,
  ADD COLUMN aggravating_factors TEXT[],
  ADD COLUMN relieving_factors TEXT[];
ALTER TABLE patient_sessions
  ADD COLUMN consent_given BOOLEAN DEFAULT FALSE,
  ADD COLUMN documents_uploaded INTEGER DEFAULT 0,
  ADD COLUMN pain_locations_added INTEGER DEFAULT 0;

CREATE TABLE pain_locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  history_id UUID REFERENCES clinical_histories(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  session_id UUID REFERENCES patient_sessions(id) ON DELETE SET NULL,
  body_part TEXT NOT NULL,
  intensity INTEGER CHECK (intensity BETWEEN 1 AND 10),
  x_position DECIMAL,
  y_position DECIMAL,
  view TEXT CHECK (view IN ('front', 'back')),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_pain_locations_patient ON pain_locations(patient_id);

CREATE TABLE family_medical_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  relation TEXT NOT NULL,
  condition TEXT NOT NULL,
  age_of_onset INTEGER,
  status TEXT CHECK (status IN ('alive', 'deceased', 'unknown')),
  genetic_marker TEXT,
  notes TEXT,
  severity TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_family_history_patient ON family_medical_history(patient_id);
CREATE TRIGGER update_family_medical_history_updated_at BEFORE UPDATE ON family_medical_history
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE previous_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  record_type TEXT NOT NULL,
  record_date DATE,
  hospital_name TEXT,
  doctor_name TEXT,
  diagnosis TEXT,
  treatment TEXT,
  document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
  linked_history_id UUID REFERENCES clinical_histories(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_previous_records_patient ON previous_records(patient_id);

CREATE TABLE consent_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  session_id UUID REFERENCES patient_sessions(id) ON DELETE CASCADE,
  consent_version TEXT DEFAULT '1.0',
  consent_type TEXT NOT NULL,
  granted BOOLEAN NOT NULL,
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET,
  device_info JSONB,
  consent_text TEXT,
  signature_data TEXT,
  withdrawn_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_consent_tracking_patient ON consent_tracking(patient_id);

-- Production access model: authenticated patients can access only their own
-- record; doctors can access only patients with an active explicit assignment.
-- All clinical writes are row-scoped. Storage remains private and denied to
-- browser roles until a reviewed ownership-aware upload API is deployed.
CREATE SCHEMA IF NOT EXISTS careportal_private;
REVOKE ALL ON SCHEMA careportal_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA careportal_private TO authenticated;

CREATE TABLE doctor_patient_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
    assigned_by UUID NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    CHECK (revoked_at IS NULL OR revoked_at >= assigned_at)
);
CREATE UNIQUE INDEX doctor_patient_assignments_one_active
    ON doctor_patient_assignments(patient_id, doctor_id) WHERE revoked_at IS NULL;
CREATE INDEX doctor_patient_assignments_doctor_active
    ON doctor_patient_assignments(doctor_id, patient_id) WHERE revoked_at IS NULL;

ALTER TABLE patients ADD CONSTRAINT patients_user_id_unique UNIQUE (user_id);

CREATE OR REPLACE FUNCTION careportal_private.patient_phone_matches_verified_auth(
    target_user UUID,
    target_phone TEXT
)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
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
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
SET row_security = off
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
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
SET row_security = off
AS $$
  SELECT careportal_private.can_access_patient(s.patient_id)
  FROM public.patient_sessions s WHERE s.id = target_session
$$;

CREATE OR REPLACE FUNCTION careportal_private.can_access_document(target_document UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
SET row_security = off
AS $$
  SELECT careportal_private.can_access_patient(d.patient_id)
  FROM public.documents d WHERE d.id = target_document
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA careportal_private FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION careportal_private.can_access_patient(UUID),
  careportal_private.can_access_session(UUID),
  careportal_private.can_access_document(UUID),
  careportal_private.patient_phone_matches_verified_auth(UUID, TEXT) TO authenticated;

-- Link an Auth user to an existing patient record only when exactly one
-- unlinked record matches the verified phone number. Ambiguous matches fail closed.
CREATE OR REPLACE FUNCTION careportal_private.link_verified_phone_to_patient()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth, careportal_private
SET row_security = off
AS $$
DECLARE matching_count INTEGER;
BEGIN
  IF NEW.phone_confirmed_at IS NULL THEN RETURN NEW; END IF;
  IF NEW.phone IS NULL OR NEW.phone = '' THEN RETURN NEW; END IF;
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

CREATE TRIGGER careportal_link_verified_phone
AFTER INSERT OR UPDATE OF phone, phone_confirmed_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION careportal_private.link_verified_phone_to_patient();
REVOKE ALL ON FUNCTION careportal_private.link_verified_phone_to_patient() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'user_profiles','patients','patient_sessions','consents','clinical_histories',
    'answers','ayush_assessments','documents','document_extractions','timeline_events',
    'alerts','clinical_summaries','queue_items','doctor_patient_assignments',
    'pain_locations','family_medical_history','previous_records','consent_tracking',
    'audit_logs','system_settings'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', table_name);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated', table_name);
  END LOOP;
END $$;

-- Reference data is non-clinical; grant read only.
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions FORCE ROW LEVEL SECURITY;
ALTER TABLE departments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON questions, departments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON questions, departments TO anon, authenticated;
CREATE POLICY questions_read_reference ON questions FOR SELECT TO anon, authenticated USING (active);
CREATE POLICY departments_read_reference ON departments FOR SELECT TO anon, authenticated USING (active);

CREATE POLICY user_profiles_read_self ON user_profiles
  FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY patients_access_own_or_assigned ON patients
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(id));
CREATE POLICY patients_create_own ON patients
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid() AND
    careportal_private.patient_phone_matches_verified_auth(user_id, contact_number)
  );
CREATE POLICY patients_update_own ON patients
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY assignments_read_assigned_doctor ON doctor_patient_assignments
  FOR SELECT TO authenticated USING (doctor_id = auth.uid() AND revoked_at IS NULL);

CREATE POLICY sessions_access_patient ON patient_sessions
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY sessions_create_own ON patient_sessions
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY sessions_update_own ON patient_sessions
  FOR UPDATE TO authenticated USING (careportal_private.can_access_patient(patient_id))
  WITH CHECK (careportal_private.can_access_patient(patient_id));

CREATE POLICY consents_access_patient ON consents
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY consents_create_own ON consents
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY consents_update_own ON consents
  FOR UPDATE TO authenticated USING (careportal_private.can_access_patient(patient_id))
  WITH CHECK (careportal_private.can_access_patient(patient_id));

CREATE POLICY histories_access_patient ON clinical_histories
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY histories_create_own ON clinical_histories
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY histories_update_accessible ON clinical_histories
  FOR UPDATE TO authenticated USING (careportal_private.can_access_patient(patient_id))
  WITH CHECK (careportal_private.can_access_patient(patient_id));

CREATE POLICY answers_access_patient ON answers
  FOR SELECT TO authenticated USING (careportal_private.can_access_session(session_id));
CREATE POLICY answers_create_patient ON answers
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_session(session_id));
CREATE POLICY answers_update_patient ON answers
  FOR UPDATE TO authenticated USING (careportal_private.can_access_session(session_id))
  WITH CHECK (careportal_private.can_access_session(session_id));

CREATE POLICY ayush_access_patient ON ayush_assessments
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY ayush_create_patient ON ayush_assessments
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY ayush_update_patient ON ayush_assessments
  FOR UPDATE TO authenticated USING (careportal_private.can_access_patient(patient_id))
  WITH CHECK (careportal_private.can_access_patient(patient_id));

CREATE POLICY documents_access_patient ON documents
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY documents_create_patient ON documents
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY documents_update_patient ON documents
  FOR UPDATE TO authenticated USING (careportal_private.can_access_patient(patient_id))
  WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY extractions_access_patient ON document_extractions
  FOR SELECT TO authenticated USING (careportal_private.can_access_document(document_id));
CREATE POLICY timeline_access_patient ON timeline_events
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY alerts_access_patient ON alerts
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY alerts_acknowledge_assigned ON alerts
  FOR UPDATE TO authenticated USING (
    careportal_private.can_access_patient(patient_id) AND acknowledged_by = auth.uid()
  ) WITH CHECK (
    careportal_private.can_access_patient(patient_id) AND acknowledged_by = auth.uid()
  );
CREATE POLICY summaries_access_patient ON clinical_summaries
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY summaries_update_assigned ON clinical_summaries
  FOR UPDATE TO authenticated USING (
    careportal_private.can_access_patient(patient_id) AND EXISTS (
      SELECT 1 FROM user_profiles u WHERE u.id = auth.uid() AND u.role = 'doctor' AND u.active
    )
  ) WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY queue_access_patient ON queue_items
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
-- Queue creation and assignment fields must be set by a trusted server workflow;
-- browser roles receive no INSERT policy on queue_items.

CREATE POLICY pain_locations_access_patient ON pain_locations
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY pain_locations_create_patient ON pain_locations
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY family_history_access_patient ON family_medical_history
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY family_history_create_patient ON family_medical_history
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));
CREATE POLICY previous_records_access_patient ON previous_records
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY consent_tracking_access_patient ON consent_tracking
  FOR SELECT TO authenticated USING (careportal_private.can_access_patient(patient_id));
CREATE POLICY consent_tracking_create_patient ON consent_tracking
  FOR INSERT TO authenticated WITH CHECK (careportal_private.can_access_patient(patient_id));

CREATE POLICY audit_logs_read_system_admin ON audit_logs
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM user_profiles u WHERE u.id = auth.uid() AND u.role = 'system_admin' AND u.active
  ));
CREATE POLICY system_settings_read_admin ON system_settings
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM user_profiles u WHERE u.id = auth.uid() AND u.role IN ('admin','system_admin') AND u.active
  ));

-- No browser role gets access to this private bucket. Upload/download must go
-- through a server route that validates auth, assignment, and object ownership.
INSERT INTO storage.buckets(id, name, public)
VALUES ('patient-documents', 'patient-documents', FALSE)
ON CONFLICT (id) DO UPDATE SET public = FALSE;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS careportal_patient_documents_deny_anon ON storage.objects;
CREATE POLICY careportal_patient_documents_deny_anon
  ON storage.objects AS RESTRICTIVE FOR ALL TO anon
  USING (bucket_id <> 'patient-documents')
  WITH CHECK (bucket_id <> 'patient-documents');
DROP POLICY IF EXISTS careportal_patient_documents_deny_authenticated ON storage.objects;
CREATE POLICY careportal_patient_documents_deny_authenticated
  ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
  USING (bucket_id <> 'patient-documents')
  WITH CHECK (bucket_id <> 'patient-documents');

CREATE OR REPLACE VIEW patient_queue_view WITH (security_invoker = true) AS
SELECT q.id, q.patient_id, p.name AS patient_name, p.age, p.gender,
       ch.chief_complaint, q.priority, ch.status AS history_status,
       q.department, q.token_number, q.added_at, q.updated_at
FROM queue_items q
JOIN patients p ON q.patient_id = p.id
LEFT JOIN clinical_histories ch ON ch.patient_id = p.id AND ch.session_id = q.session_id;
REVOKE ALL ON patient_queue_view FROM PUBLIC, anon;
GRANT SELECT ON patient_queue_view TO authenticated;

-- Shared server-side rate limit storage. Only the service-role RPC can mutate
-- buckets; raw phone numbers and IP addresses must remain HMACed by the app.
CREATE TABLE api_rate_limit_buckets (
  bucket_hash TEXT PRIMARY KEY CHECK (bucket_hash ~ '^[0-9a-f]{64}$'),
  window_started_at TIMESTAMPTZ NOT NULL,
  request_count INTEGER NOT NULL CHECK (request_count >= 1)
);
ALTER TABLE api_rate_limit_buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_rate_limit_buckets FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE api_rate_limit_buckets FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.consume_api_rate_limit(
  p_bucket_hash TEXT,
  p_max_requests INTEGER,
  p_window_seconds INTEGER
)
RETURNS TABLE (allowed BOOLEAN, retry_after_seconds INTEGER)
LANGUAGE plpgsql SECURITY DEFINER
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
        THEN current_time ELSE buckets.window_started_at END,
    request_count = CASE
      WHEN current_time >= buckets.window_started_at + make_interval(secs => p_window_seconds)
        THEN 1 ELSE buckets.request_count + 1 END
  RETURNING buckets.request_count, buckets.window_started_at
  INTO current_count, current_window;
  RETURN QUERY SELECT current_count <= p_max_requests,
    GREATEST(1, CEIL(EXTRACT(EPOCH FROM (current_window + make_interval(secs => p_window_seconds) - current_time)))::INTEGER);
END;
$$;
REVOKE ALL ON FUNCTION public.consume_api_rate_limit(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_api_rate_limit(TEXT, INTEGER, INTEGER) TO service_role;

COMMENT ON DATABASE postgres IS 'CarePortal - AI-Powered Clinical Intake Platform';
