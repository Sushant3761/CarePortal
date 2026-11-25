# CarePortal Technical Audit

**Audit date:** 2026-11-21 (source review); implementation follow-up: 2026-11-23
**Scope:** Static source and configuration review of the checked-out workspace. No live Supabase project, Twilio/Exotel credentials, or deployed environment was available. Findings below distinguish source-confirmed behavior from deployment-dependent risk. The audit is broad but cannot claim runtime verification of every screen or external integration.

Findings describe the initial source review. The implementation follow-up below records mitigations through 2026-11-23; outstanding findings remain active unless explicitly marked otherwise. Historical findings should be read with the latest update at the end of this report.

## 1. Architecture overview

CarePortal is an npm workspace with two Next.js 16 applications and a small shared TypeScript types package. `apps/patient-kiosk` is a client-heavy, bilingual intake demo with Supabase Auth OTP routes, AI question/summary APIs, and a disabled SMS relay. `apps/doctor-dashboard` includes dashboard, patient, queue, reports, AYUSH, and admin routes; it uses Supabase SSR cookies and a request proxy for server-side role gating. SQL schema and setup scripts live under `database/`. No live Supabase authorization has been verified.

## 2. Existing features

- Patient intake routes cover identity, consent, complaint, pain location, history, family history, documents, review, and completion.
- English/Hindi translation helpers, voice guidance, symptom question generation, and AI summary generation are present.
- Doctor dashboard routes cover login, queues, patient records, reports, clinical summary, AYUSH, and doctor administration.
- SQL files define patient, session, consent, clinical, document, queue, and audit-related tables, plus seed/demo and RLS variants.
- Supabase Auth, Storage SDK, Gemini, Twilio Verify, and Exotel integrations are referenced. Their real-world operation is not verified.

## 3. Working functionality

Static source confirms the route and component implementations exist; it does not prove end-to-end behavior. The OTP service calls Twilio Verify, the AI routes call Gemini when configured and have fallback paths, and intake screens make direct Supabase calls. No live environment was available to verify delivery, persistence, queues, file access, or complete workflows. There are no automated workflow tests in the repository.

## 4. Incomplete functionality

| Priority | File / component | Finding and impact | Recommended action |
|---|---|---|---|
| HIGH | `apps/doctor-dashboard/app/login/page.tsx` | **Mitigated in this pass:** initial login presented prefilled demo credentials, accepted local demo profiles, and proceeded after Supabase auth failure. Login now requires Supabase Auth and an active matching profile role. | Continue with server-side authorization and remove localStorage as a role/session trust source on every dashboard route. |
| HIGH | `apps/doctor-dashboard/app/**`, `components/DoctorNavigation.tsx` | Many screens trust a `localStorage` JSON object for client-side role gating. It is user-editable and is not an authorization boundary. | Enforce roles and patient scope in server routes/RLS, then use verified auth session for presentation gating. |
| MEDIUM | `apps/doctor-dashboard/app/dashboard/page.tsx` and other dashboard pages | Dashboard includes seeded patient examples and default stats; these can be mistaken for real clinical data. | Keep mock fixtures behind an explicit development-only mode and label them. |
| MEDIUM | `apps/patient-kiosk/components/DocumentUpload.tsx` | Files are converted to base64 and inserted into `documents.file_url`; a comment confirms this is a development substitute, not Supabase Storage. The file reader is asynchronous while the upload loop ends early. | Upload to a private Storage bucket with server-validated size/type and signed access; await each upload and persist object paths. |
| MEDIUM | `apps/patient-kiosk/app/api/generate-questions/route.ts` | AI output is parsed but accepted with only a nonempty array check. User inputs are embedded into prompts and responses include raw error detail. | Bound and validate input/output with schemas, use fixed safe errors, and limit request rates. |
| MEDIUM | `apps/patient-kiosk/app/api/clinical-summary/generate/route.ts` | Anonymous request data can trigger expensive AI and privileged persistence when service role credentials exist; the route does not establish caller identity or prove ownership of supplied IDs. | Authenticate/attest kiosk intake, validate payload, scope writes, and protect the endpoint against abuse. |
| MEDIUM | `apps/patient-kiosk/app/(patient)/**` | Identifiers and demographic/clinical intake values are stored in browser localStorage. Shared kiosk browser persistence can expose data to the next user. | Minimize local persistence, clear all intake data on completion/timeout, and use short-lived server-side intake sessions. |

## 5. Confirmed bugs

| Priority | File / component | Problem | Why it matters | Recommended solution |
|---|---|---|---|---|
| HIGH | `apps/doctor-dashboard/app/login/page.tsx` | **Mitigated in this pass:** initial login ignored auth errors, prefilled demo credentials, and had demo buttons. It now requires Supabase Auth success and an active matching `user_profiles` role. Dashboard pages still trust localStorage for client-side route gating. | Anyone who forges browser storage may pass UI checks; server/database authorization remains required. | Enforce roles and patient scope server-side/RLS and replace localStorage role trust across dashboard routes. |
| HIGH | `database/legacy/fix_rls_policies.sql` | Policies grant `anon` and `authenticated` broad `USING (true)` access on sessions, consent, clinical histories, answers, documents, assessments, summaries, alerts, and queue items. The file itself calls these permissive development policies. | With these policies applied, any public/anonymous client may read or modify sensitive records. | Isolated under `database/legacy/`; do not apply. The supported schema and migration path use fail-closed policies pending live integration validation. |
| HIGH | `database/legacy/disable_rls_for_dev.sql`; `README.md` | The legacy script disables RLS on listed tables. | Applying it removes database protection entirely. | Isolated under `database/legacy/` and removed from normal setup instructions. |
| HIGH | `apps/patient-kiosk/app/api/clinical-summary/generate/route.ts` | Helper silently falls back from `supabaseAdmin()` to anon client, while the route accepts caller-controlled patient/session/history IDs and performs summary/queue writes. | Deployment behavior changes with env configuration; privileged use has no authentication or ownership proof. | Do not silently elevate/fallback. Split trusted writes behind authenticated server logic and validate relationships. |
| HIGH (potential) | `apps/patient-kiosk/services/ai-service.ts`; AI API routes | **Mitigated in this pass:** source accepted `NEXT_PUBLIC_GEMINI_API_KEY`; if configured and client-imported, a provider key could be bundled for browser access. All AI code now reads only server-side `GEMINI_API_KEY`. | Public-prefixed credentials are exposed to browser code by Next.js when inlined. | Keep provider keys server-side and use authenticated API routes; rotate any key previously deployed under a public name. |
| HIGH | `apps/patient-kiosk/components/DocumentUpload.tsx` | Medical documents are saved as base64 in a table field and exposed as data URLs in component state; uploads are not awaited and failures can be reported after busy state is cleared. | Large PHI payloads, fragile persistence, possible database/logging exposure, and race conditions. | Use private object storage with scoped access and awaited upload/metadata workflow. |
| MEDIUM | `apps/patient-kiosk/app/(patient)/consent/page.tsx`; `documents/page.tsx`; `review/page.tsx` | **Mitigated in this pass:** screens previously claimed compliance, encryption, secure sharing, and ABDM verification without evidence. They now show a synthetic-data-only development notice in English/Hindi and remove unsupported badges. | Patients could make decisions based on unsupported privacy/security assurances. | Keep privacy descriptions tied to verified controls and obtain policy review before real use. |
| MEDIUM | `apps/patient-kiosk/app/api/otp/send/route.ts`; `lib/otpService.ts` | **Mitigated in this pass:** phone syntax is validated, provider calls have timeouts, provider errors are generic, logs no longer include phone numbers/provider payloads, and failed sends return a non-2xx status. Shared rate limiting is still missing. | Limits malformed calls and information leaks; unthrottled requests can still consume provider resources. | Add shared rate limiting before deployment and test with provider credentials. |
| MEDIUM | `apps/patient-kiosk/app/api/otp/verify/route.ts`; `lib/otpService.ts` | **Mitigated in this pass:** phone and six-digit code are validated; provider calls time out and return generic failures; phone logs were removed. Shared rate limiting is still missing. | Reduces provider detail leakage and hanging calls; unthrottled verification attempts remain an abuse risk. | Add shared rate limiting and test with provider credentials. |
| MEDIUM | `apps/patient-kiosk/app/api/send-token-sms/route.ts` | Caller controls recipient and message fields; provider error and raw response are sent back to caller and logs. No authorization/rate limiting is visible. | Endpoint can be abused for SMS costs and leak provider response data. | Gate to authenticated/authorized workflow, validate fields, throttle, and return only safe status. |
| MEDIUM | `database/legacy/schema.sql` | **Mitigated:** removed the placeholder `app.jwt_secret` database setting. | A sample value could mislead setup and diverge from managed Supabase JWT configuration. | Rely on the project's managed JWT configuration. This script remains legacy; use the documented production schema for a fresh setup. |
| MEDIUM | `apps/doctor-dashboard/app/login/page.tsx` | **Mitigated in this pass:** the selected portal role is now checked against the active authenticated profile; demo credentials were removed. | Previously, a client-selected role could disagree with the account's actual privilege. | Keep authorization enforced server-side and in RLS, independent of this UI check. |
| LOW | root `package.json` | **Partially mitigated in this pass:** root lint, typecheck, and test scripts now invoke real tools. No tests exist yet; `install:all` still repeats installation inside workspaces. | Earlier placeholder scripts could appear successful without checking code; setup remains slower/confusing. | Add tests and use one workspace install. |
| LOW | `README.md`, `START_HERE.md`, `SUPABASE_SETUP.md`, `CREDENTIALS_REFERENCE.md`, `INSTALLATION.md` | **Mitigated in this pass:** README's NUL byte and unsafe quick-start guidance were replaced; setup docs now warn about RLS and no longer prescribe demo passwords or fixed OTPs. Other legacy guides were corrected to remove fixed OTP claims. | Documentation previously led developers toward unsafe setup and false expectations. | Keep docs synchronized with code and validate steps against a disposable Supabase project. |

## 6. Security vulnerabilities and potential risks

**Confirmed:** permissive RLS scripts (above); unauthenticated AI/SMS API surfaces; PHI in browser storage; base64 document storage. OTP service logging was redacted in this pass. Dashboard login now verifies Supabase Auth/profile but other route checks remain localStorage-based.

**Potential / deployment-dependent:** `schema.sql` enables RLS on its tables, but the actual effective policies depend on which SQL scripts have been run and in what order. `fix_rls_policies.sql` drops some named policies but does not first remove every policy name it creates, so reruns may fail on duplicate policy names. The separate `disable_rls_for_dev.sql` fully disables RLS. Storage bucket policies were not found in the inspected SQL, so actual bucket exposure must be checked in the Supabase project. The dashboard's direct browser queries rely on deployed RLS; no route-level staff authorization was found in this source scan. CORS/CSRF and production transport controls depend on hosting configuration.

The service role key was found only in the server-side Supabase helper and placeholder `.env.example`. Gemini code previously read a public-prefixed key; that usage was removed. Verify deployment secret injection and rotate any key that may have been deployed with a `NEXT_PUBLIC_` name.

## 7. Database problems

- Multiple schema/setup scripts exist (`schema.sql`, `careportal_complete_schema.sql`, feature additions, RLS fixes, disable-RLS development script, and demo seed). Their ordering and compatibility are unclear; they are not versioned migrations.
- `fix_rls_policies.sql` broad policies defeat least-privilege access. `disable_rls_for_dev.sql` removes the database security boundary.
- Several tables hold sensitive data and their access model does not clearly connect authenticated staff to a hospital/tenant or patient assignment.
- Storage policies/bucket provisioning are not included in the reviewed SQL.
- The initial schema's placeholder JWT database setting was removed in this pass.
- Foreign keys and indexes exist in the main schema, but consistency between duplicate schema variants and live database was not testable without a project connection.

## 8. Performance problems

- Patient app includes Three.js/React Three Fiber, OCR/Tesseract, QR, and Gemini dependencies in one app; bundle splitting/use on demand should be verified with production analyzer.
- `DocumentUpload` base64 encodes files, increasing memory and database payload size.
- Several dashboard pages use broad Supabase `.select('*')` patterns (source-level scan); restrict selected fields and page queue/history queries.
- AI routes may retry expensive calls; no rate limit is visible. Runtime/bundle and query performance were not measured.

## 9. Testing gaps

- No test files were present in the source inventory; the root Vitest command has no suite to run.
- Root lint/typecheck scripts were added in this pass. No end-to-end flows exist for either application.
- Auth, patient isolation, RLS, uploads, SMS, AI fallback, and logout have no automated security/workflow coverage.
- TypeScript is strict in both app configs, but actual compile/build status must be captured separately.

## 10. Documentation gaps

- Several SQL setup variants remain unordered and have not been verified against a clean live Supabase project.
- `.env.example` contains placeholders only; some optional variables may not be consumed by code.
- No precise private Storage bucket policy or live Supabase authorization setup is documented.

## 11. Verification limits

This report is based on static review. No external credentials or live Supabase instance were available. Do not treat the listed UI flows or integrations as production-tested. Build/type/lint results are in `TESTING_REPORT.md` after local verification.

## 12. Historical implementation follow-up (2026-11-22)

- Dashboard login no longer has demo shortcuts or prefilled credentials. It now requires a successful Supabase sign-in and an active `user_profiles` role matching the selected portal. The rest of the dashboard still trusts a localStorage profile for client-side route gating; this is not server authorization and remains a HIGH issue.
- OTP send/verify input validation, provider timeouts, safe error handling, and failed-send HTTP status were improved. Shared rate limiting and live provider verification remain open.
- Removed `NEXT_PUBLIC_GEMINI_API_KEY` fallbacks so AI provider credentials are read only from `GEMINI_API_KEY` on server code.
- Removed unsupported patient-facing claims about encryption, compliance, ABDM verification, and secure sharing; consent/review/upload screens now warn in both languages that only synthetic data should be used.
- Removed the placeholder JWT database setting from `database/legacy/schema.sql`.
- Standard Next.js ESLint configurations were added and unescaped JSX text errors were fixed; both lint commands complete with warnings.
- Root `lint`, `typecheck`, and `test` scripts now invoke real workspace tools; no test cases exist yet.
- README and setup documents were rewritten to avoid instructing developers to disable RLS or rely on fixed demo credentials/OTP. Demo SQL comments no longer publish shared passwords.
- Effective database policies, Storage privacy, AI/SMS route authorization, document storage, and live functional flows remain unresolved and block production use with real patient data.

## 13. Current implementation follow-up (2026-11-23)

- Next.js/React and vulnerable dependencies were upgraded; the latest successful `npm audit` reported zero advisories. The current ESLint 10 selection has peer-range warnings from three bundled Next plugins; ESLint 9 is the compatible common-version recommendation.
- Kiosk OTP now uses Supabase Auth and installs the returned session. The database design links only a unique unlinked patient row with a confirmed phone and scopes doctor reads to an explicit active assignment. This design has not been exercised against PostgreSQL/Supabase.
- Kiosk completion, start-over, and exit now sign out and clear intake state. The browser token remains accessible to same-origin JavaScript before logout.
- Replaced fabricated doctor/queue assignment and false dashboard-transmission copy with explicit demo-only messaging. The AI summary API returns `persisted: false`; the UI no longer implies a clinical handoff.
- Added a test for logout cleanup and local fallback; it has not yet run because the checkout's dependency install is incomplete. The most recent successful clean-copy suite predates it.
- Current workspace lint results from the last clean-copy run: patient 128 errors / 86 warnings and doctor 63 errors / 100 warnings. Builds/typechecks passed before the final-review edits; lint, tests, and builds need rerunning after a successful clean install.
- Database schema/migrations 0001–0004 remain unexecuted. Continue to use only synthetic data until RLS, trigger, Storage denial, rate-limit, and migration-order checks pass in a disposable Supabase project.
