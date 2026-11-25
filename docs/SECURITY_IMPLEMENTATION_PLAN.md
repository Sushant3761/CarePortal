# Security Implementation Plan

**Re-audit date:** 2026-11-23
**Scope:** Current source in both Next.js apps, all five patient API routes, Supabase clients, SQL schema variants, RLS and Storage declarations, environment template, package manifests, and test inventory. No live Supabase project or provider credentials are available. This plan records source-confirmed issues separately from deployment-state questions.

> **Status update (2026-11-23):** The detailed findings below include a historical snapshot dated 2026-11-22. Since then, patient OTP was moved to Supabase Auth, migrations 0001–0004 and a canonical fresh-install schema were prepared, and unsafe/superseded SQL was isolated under `database/legacy/`. The approved model is confirmed Supabase Auth identity for patients and explicit active doctor-patient assignments. These SQL changes have not been applied to a database; the current validation boundary and remaining gaps are recorded at the end of this document.

## Historical architecture snapshot (2026-11-22)

- Both apps use `@supabase/supabase-js` directly in the browser. The doctor client persists Supabase Auth to the SDK's browser storage; there is no `@supabase/ssr` dependency, server cookie client, Next middleware, or authenticated server action/API layer for dashboard data.
- Doctor login now performs `signInWithPassword` and checks the profile role, but writes a copied profile into editable localStorage. Protected page checks are React effects and some combine that local value with browser `auth.getUser()`. These checks do not protect server rendering or data APIs.
- The kiosk uses the Supabase anon key from browser code. OTP verification only returns `{ verified: true }`; it does not create a Supabase user, a signed intake session, or an HttpOnly cookie. Patient identity and intake identifiers/content are stored in localStorage and client components write directly to PostgREST.
- `clinical-summary/generate` can select the service-role client and write patient, summary, and queue data without verifying a caller. `send-token-sms` accepts arbitrary recipients/message fields and calls Exotel without authorization. AI question generation is public and can incur provider cost.
- `documents` are written as base64 data URLs in a database text field by `DocumentUpload`; the separate kiosk documents screen mostly simulates upload/OCR. No Storage bucket, Storage object policy, signed URL flow, or migration is present in reviewed SQL.
- SQL variants conflict. `schema.sql` enables RLS on its listed tables but gives staff broad clinical access and has no ownership/assignment scope. `fix_rls_policies.sql` grants anon/authenticated broad `USING (true)` policies. `careportal_complete_schema.sql` and `add_new_features.sql` explicitly disable RLS on their tables. `disable_rls_for_dev.sql` disables it broadly. There is no versioned migration directory.

## Historical findings snapshot (2026-11-22)

| Priority | Issue | Affected files | Existing protection | Missing protection / safe direction |
|---|---|---|---|---|
| CRITICAL | Legacy SQL setup paths permit public/all-user access or turn RLS off for clinical data. | `database/legacy/schema.sql`, `database/legacy/fix_rls_policies.sql`, `database/legacy/careportal_complete_schema.sql`, `database/legacy/add_new_features.sql`, `database/legacy/disable_rls_for_dev.sql` | Unsafe scripts are now isolated in `database/legacy/`; the supported schema and migrations define fail-closed policies. | Verify deployment inventory and policies against a disposable Supabase project. Never apply legacy scripts. |
| CRITICAL | Privileged clinical writes are exposed through a public summary route. | `apps/patient-kiosk/app/api/clinical-summary/generate/route.ts`, `apps/patient-kiosk/lib/supabase.ts` | Service key is server-only in source; the browser itself uses anon key. | Route does not authenticate caller, prove patient/session relationship, or validate ownership. Remove implicit trust and bind writes to an authenticated/attested intake workflow before enabling service-role writes. |
| HIGH | Dashboard session and page checks rely on browser storage/client effects. | `apps/doctor-dashboard/lib/supabase.ts`, `app/login/page.tsx`, `app/**/page.tsx`, `components/DoctorNavigation.tsx` | Login checks Supabase credentials and profile role; some pages call client `auth.getUser()`. | Cookie-based SSR session, server route guards, server-side role checks, expiry handling, and server data authorization are absent. |
| HIGH | Doctor access requires lifecycle-managed assignments and integration verification. | `database/migrations/0004_assignment_scoped_patient_access.sql`, `database/production_schema.sql` | Patient clinical access is scoped to the linked Auth identity; doctor clinical access requires an explicit active doctor-patient assignment. | Assignment creation/revocation workflow and disposable-database RLS tests remain. |
| HIGH | Doctor account creation calls `auth.admin` from a browser client. | `apps/doctor-dashboard/app/admin/doctors/page.tsx` | UI has a client-side profile lookup. | No server-side admin guard or service-role-only handler. Move creation behind authenticated server code and enforce system-admin role there; avoid returning temporary passwords. |
| HIGH | No private document object-storage implementation; base64 data persists in records. | `apps/patient-kiosk/components/DocumentUpload.tsx`, `app/(patient)/documents/page.tsx`, SQL `documents` | Client checks MIME type and 10 MB limit in one component. | Private bucket/object RLS, server validation, safe object paths, authorization, signed downloads, async completion, and legacy data migration are missing. |
| HIGH | OTP success is not bound to an intake identity/session; no shared throttle/attempt policy. | `app/api/otp/send/route.ts`, `verify/route.ts`, `lib/otpService.ts`, `app/(patient)/identity/page.tsx` | Indian phone/code format validation, provider timeout, generic provider errors, redacted phone logging. | No shared rate limiter/cooldown; verification response is not an HttpOnly credential; browser can then directly query/update patient records. |
| HIGH | SMS route can be used as a provider relay. | `app/api/send-token-sms/route.ts` | Basic recipient length validation and fetch timeout. | No caller auth, role/resource authorization, schema bounds, throttle, or safe provider error redaction. |
| MEDIUM | Public AI question endpoint can be called for provider spend and has weak output validation. | `app/api/generate-questions/route.ts` | Fallback questions and bounded output token request. | Request size/type bounds, shared throttling, strict response schema, safe failure behavior, and abuse controls. |
| MEDIUM | Patient PHI remains in kiosk localStorage across screens and some exit paths. | `apps/patient-kiosk/app/(patient)/**`, `app/page.tsx` | Completion clears several keys and visible text warns synthetic data only. | A server-held short-lived intake state, complete cleanup on timeout/exit, and no PHI in persistent browser storage. |
| MEDIUM | Environment template contains many unused security variables; env requirements are not centrally validated. | `.env.example`, both app configs and Supabase helpers | Placeholders only; server-only key names are used for Gemini/Twilio/Exotel. | Remove unused pseudo-controls or document actual use; validate only needed env vars on server startup. |
| MEDIUM | No automated tests exist; Vitest and Next builds are currently blocked by missing Windows optional packages. | root `package.json`, `package-lock.json`, app manifests | Vitest, Playwright, and lint/typecheck scripts are declared; lint/typecheck ran previously. | No test files, test config, API auth tests, RLS tests, or E2E tests. Fix installation in a connected environment and add tests around extracted pure helpers first. |

## Protections verified in the 2026-11-22 snapshot

- The previous pass removed dashboard demo credentials, public Gemini-key fallbacks, and unsupported privacy/compliance claims.
- OTP routes validate Indian mobile syntax and six-digit codes. Twilio calls have 10-second timeouts and generic errors.
- `.env.example` uses placeholders. The Supabase service-role key is only referenced in the kiosk Supabase module and summary route's server code, not imported by client pages.
- Main `schema.sql` enables RLS on its original tables, but this is not sufficient: other scripts disable it and the policies themselves do not establish patient/doctor scope.

## Database decisions pending at the 2026-11-22 snapshot

These are not safe to infer from current files:

1. Is a patient authenticated through Supabase Auth or only by phone OTP? How does a verified phone map to an existing patient when numbers may be shared or changed?
2. Does a doctor see only patients assigned through `queue_items.assigned_to`, a care-team/assignment table, department, hospital tenancy, or a combination? What is the reassignment/revocation lifecycle?
3. Do admins have global access, tenant/hospital-scoped access, or only user-management privileges?
4. Should intake sessions/documents remain available after kiosk completion, and what are their retention/deletion rules?
5. Which schema file is canonical and which tables/columns are present in the real project? The SQL variants are inconsistent, including table names used by the app that do not appear in the main schema.

Until those choices and live schema inventory are available, a policy claiming patients/doctors can access only the right rows would be fabricated. Keep real PHI out of this build.

## Original implementation order (historical)

1. **Contain unsafe access:** label/retire RLS-disabling SQL from setup workflows; add an explicit security warning to destructive policy scripts. Do not execute SQL against a database.
2. **Create testable security primitives:** request schemas, role predicates, safe response helpers, and file/OTP validators, then unit-test them with the installed toolchain when dependencies work.
3. **Doctor SSR authentication:** add the Supabase SSR package only after checking compatible version/lockfile and install availability; build server cookie client, login/logout handlers, middleware or server layouts, and server profile/role verification. Remove localStorage as proof of auth.
4. **API inventory and authorization:** require verified identity/role and resource scope for privileged routes. For kiosk APIs, first implement an OTP-verified, short-lived intake session bound to the patient/session; retain no service-role fallback.
5. **Resolve schema decisions:** inventory a disposable/live schema and get owner/assignment semantics. Then create additive, versioned migrations and fail-closed RLS for all existing/new tables, including `pain_locations`, `family_medical_history`, `previous_records`, and `consent_tracking`.
6. **Private document storage:** design a private bucket and policies tied to the agreed patient/assignment model, implement server-validated upload/download, and provide a non-destructive migration for base64 records.
7. **Abuse controls:** add a shared-store rate limiter for OTP/AI/SMS and verification-attempt/cooldown logic. Do not present process-memory throttling as production protection.
8. **Tests and release checks:** restore platform dependencies in a connected environment; add unit, API, RLS integration, and browser tests using synthetic fixtures; rerun both builds and security regressions.

## Original verification boundary (historical)

The source review is complete for the currently present route and SQL inventory. No live database, credentials, Storage bucket, deployment runtime, or successful Windows native dependency install is available here. No database migration has been executed. The implementation work that follows will be limited to changes that are safe without inventing patient/doctor ownership semantics; unresolved work stays explicitly documented.

## Historical Phase 2 implementation update (2026-11-22)

- Doctor-dashboard Supabase browser/server clients now use @supabase/ssr cookie sessions. Middleware verifies sessions with auth.getUser(), checks active user_profiles roles, gates admin/system-admin routes, and returns API 401/403 responses. Client auth guards no longer treat careportal_doctor_auth localStorage as proof.
- Staff invitation/list/status actions now call /api/admin/doctors. That route independently verifies active system_admin and uses the service-role key only server-side. It blocks self-deactivation and system-admin status edits. The UI uses invitation email instead of setting a temporary password and no longer fabricates staff email values.
- Kiosk clinical-summary generation no longer has a service-role fallback and no longer writes patient, summary, or queue rows. It returns persisted=false because the public OTP flow does not establish an authenticated patient/session relationship.
- Kiosk SMS relay returns 503 until sender/resource authorization and shared throttling exist. Kiosk and doctor document routes no longer simulate OCR/save or write base64 files; upload is visibly unavailable until private Storage authorization exists.
- Added database/migrations/0001_fail_closed_clinical_access.sql. It enables and forces RLS, removes policies, revokes anon/authenticated grants for protected tables, permits users to SELECT only their own profile, and permits public reads only for reference tables. It deliberately blocks existing client-direct clinical workflows and has not been applied.
- Added database/migrations/0002_shared_api_rate_limits.sql and wired OTP send/verify plus public AI routes to an atomic shared database limiter. It HMAC-hashes phone/IP-derived bucket keys, fails closed if configuration is missing, and depends on the trusted deployment proxy setting x-real-ip. The migration has not been applied.
- Marked legacy SQL scripts that grant broad access or disable RLS as unsafe/superseded. Added docs/API_SECURITY_INVENTORY.md and docs/SECURITY_IMPLEMENTATION_REPORT.md.
- Added database/migrations/0003_private_documents_default_deny.sql for a private, size/MIME-limited bucket with restrictive deny rules. Existing document content is not migrated or deleted.
- Added a Vitest suite for role decisions. It does not prove middleware, database RLS, API sessions, or deployment configuration.
- Dependency review: both apps pin Next.js 14.0.4, which is unsupported and in the affected range for critical GHSA-2464-fhr4-w9xw / CVE-2026-96889. Upstream lists fixes in 15.5.28 or 16.4.1 and a sharp >=0.35.5 workaround. A safe upgrade was not completed because the patient app uses React 18-only React Three Fiber 8 / Drei 9 peers and registry installation stalled. Move to a patched supported Next release with React 19 and compatible Three packages, or apply the verified sharp workaround as an interim measure, before production. Vitest cannot start because the locked @rollup/rollup-win32-x64-msvc optional binary is missing; its targeted install also stalled.

Remaining material gaps: kiosk OTP does not issue a signed intake session; intake data is only tab-scoped in `sessionStorage`, which remains accessible to same-origin JavaScript; the shared rate limiter is inactive until migration 0002 and proxy configuration are deployed; public question/summary AI calls can incur provider cost; clinical dashboard pages still query tables directly and will fail closed after migration 0001 until server APIs and the real assignment model are implemented; existing database base64 records, if any, remain unmigrated; usable private Storage access and upload/download APIs are not implemented. The current unpatched Next dependency is also a production blocker. Do not apply any migration to a live environment before a tested application cutover and rollback plan.

## Current implementation update (2026-11-23)

- Patient OTP send/verify now call Supabase Auth and the kiosk applies the returned Auth session. Deployment must configure an SMS provider in Supabase Auth; this has not been integration-tested with real provider credentials.
- The chosen patient mapping is confirmed Auth user to a unique patient row with the same confirmed phone. The selected doctor access model requires an explicit active assignment row; queue membership alone does not authorize clinical record access.
- `database/production_schema.sql` is the documented fresh-install schema. Existing installations must assess compatibility and apply versioned migrations 0001–0004 in order. Migrations 0001–0003 are preserved; 0004 adds patient identity linking and assignment-scoped access. No migration has been run against a live or disposable database.
- Legacy scripts are preserved under `database/legacy/`, explicitly excluded from the supported setup, and may contain broad access grants or RLS-disabling statements. Only synthetic seed/demo values are retained.
- `database/SECURITY_TEST_PLAN.md` covers patient isolation, assignment lifecycle, unauthenticated access, privilege boundaries, private Storage, rate limiting, and fail-closed behavior. These checks still need to run against a disposable Supabase project before production.
- Remaining controls include a trusted assignment administration workflow, verification of admin scope and retention rules, migration integration/rollback testing, authenticated server APIs for clinical writes/reads where service-role access is required, private document upload/download implementation, and moving sensitive intake state out of browser storage. Do not use real patient data until these gaps are resolved and the database policies are validated.
