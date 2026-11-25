# Database security test plan

Run these checks against a disposable Supabase project after applying the
supported `production_schema.sql`. Use generated UUIDs and synthetic data only.
Never copy test fixtures into a real environment. Inspect results with the
anon, authenticated patient, assigned doctor, unassigned doctor, admin, and
service-role contexts; do not place service-role keys in browser code.

## Identity and row access

1. Request OTP through Supabase Auth, verify it, and confirm the client receives
   an Auth session. An unverified phone must have no usable session.
2. Complete, exit, and timeout the kiosk flow. Confirm it signs out, clears
   `careportal_*` tab state, and falls back to local sign-out if remote logout
   fails.
3. Create two synthetic patient Auth users and two patient rows. Confirm each
   patient can select/update only its own row and cannot select, insert, update,
   or delete rows belonging to the other patient.
4. Confirm a patient row cannot be inserted unless the caller has a confirmed
   Auth phone that matches `contact_number`; unconfirmed/mismatched phones fail.
5. Confirm a new verified phone links only when exactly one unlinked patient
   row matches. With zero matches or multiple matching rows, confirm no existing
   row is linked and no row is disclosed through RLS.
6. Create two active doctor profiles and one active assignment. Verify the
   assigned doctor can read that patient's clinical data; the other doctor,
   an inactive doctor, and a revoked assignment cannot.
7. Verify the authenticated role cannot create, modify, or revoke assignment
   rows. Create/revoke assignments only through a trusted, separately
   authorized server/admin path.
8. Verify patient and doctor browser roles cannot insert queue items or set
   priority, status, token, or assigned-doctor fields; only a trusted server
   workflow may create queue rows.

## Clinical table matrix

For each of `patient_sessions`, `consents`, `consent_tracking`,
`clinical_histories`, `answers`, `pain_locations`, `family_medical_history`,
`previous_records`, `ayush_assessments`, `documents`,
`document_extractions`, `timeline_events`, `alerts`, `clinical_summaries`, and
`queue_items`, repeat cross-patient read/write denial and own/assigned access
checks. Confirm child rows cannot be accessed by supplying another patient's
session or document ID. Confirm no anonymous role can read or modify clinical
rows. Check doctor update permissions are limited to the documented clinical
workflow and do not let a doctor change a patient's owner or assignment.

## Profiles, administration, and privileged code

- A user can read only their own `user_profiles` row; users cannot assign
  themselves a staff/admin role or edit their active status.
- Audit logs are not readable by patients/doctors; only the intended audit
  administrator can read them. Browser roles cannot insert/update/delete audit
  records or system settings.
- Call `consume_api_rate_limit` with service-role and anon/authenticated JWTs.
  Only service-role succeeds; invalid hashes, limits, and windows fail closed.
- Review every service-role route for server-only key use, role checks, input
  validation, and bounded record IDs. Confirm no endpoint returns the key.

## Document storage and operational checks

- Confirm `patient-documents` has `public = false` and anonymous/authenticated
  object listing, upload, download, update, and delete all fail, including when
  any older permissive storage policies remain installed.
- Confirm no policy or view bypasses the base-table RLS rules. The queue view
  must execute with invoker rights and return only assigned/owned patients.
- Check RLS is both enabled and forced on each clinical table and verify
  privileges/policies in `pg_class`, `information_schema.role_table_grants`,
  and `pg_policies`.
- Test transaction rollback, migration ordering, and backup/restore on a
  disposable project before a live deployment.
