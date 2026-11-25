-- Creates a private bucket for future patient documents and denies all direct
-- anon/authenticated object operations until an authenticated patient/session
-- ownership model is implemented. Existing database/base64 records are untouched.
--
-- Review existing Storage policies and the bucket state on a disposable project
-- before applying. This migration intentionally does not enable uploads.

BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'patient-documents',
  'patient-documents',
  FALSE,
  10485760,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM storage.buckets
    WHERE id = 'patient-documents' AND public IS TRUE
  ) THEN
    RAISE EXCEPTION 'patient-documents bucket already exists as public; review manually before continuing';
  END IF;
END $$;

UPDATE storage.buckets
SET public = FALSE,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
WHERE id = 'patient-documents';

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS careportal_patient_documents_deny_anon ON storage.objects;
CREATE POLICY careportal_patient_documents_deny_anon
ON storage.objects AS RESTRICTIVE
FOR ALL TO anon
USING (bucket_id <> 'patient-documents')
WITH CHECK (bucket_id <> 'patient-documents');

DROP POLICY IF EXISTS careportal_patient_documents_deny_authenticated ON storage.objects;
CREATE POLICY careportal_patient_documents_deny_authenticated
ON storage.objects AS RESTRICTIVE
FOR ALL TO authenticated
USING (bucket_id <> 'patient-documents')
WITH CHECK (bucket_id <> 'patient-documents');

COMMIT;
