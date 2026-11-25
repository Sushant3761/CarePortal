# CarePortal Testing Report

**Review date:** 2026-11-25
**Environment:** Windows, Node v26.12.1, npm 11.20.0. No live or disposable Supabase project or provider credentials were available.

## Verification results

| Check | Result | Scope and limits |
|---|---|---|
| `npm ci` | PASS | Clean install from the refreshed lockfile; 589 packages audited. npm notes that ESLint 9.39.5 is deprecated and that Tesseract's optional postinstall script is not approved. |
| TypeScript | PASS | `npm run typecheck` completed patient and doctor app checks. |
| Patient ESLint | FAIL | 128 errors and 86 warnings, mainly `no-explicit-any`, React purity/hooks rules, unused values, and `no-require-imports`. |
| Doctor ESLint | FAIL | 57 errors and 80 warnings, mainly `no-explicit-any`, React hooks diagnostics, and unused values. |
| Vitest | PASS | 2 test files and 5 tests passed. These cover role authorization and patient session cleanup, not end-to-end browser flows. |
| Patient production build | PASS | `next build --webpack` completed with placeholder Supabase URL and anon key set only for the build process. |
| Doctor production build | PASS | `next build --webpack` completed with placeholder Supabase URL and anon key set only for the build process. |
| `npm audit` | PASS | 0 vulnerabilities reported after updating i18next to 26.7.2. |

## Dependency notes

The original lockfile omitted optional `@emnapi` platform packages required by the locked dependency tree, so `npm ci` initially failed. The lockfile was refreshed and then clean install succeeded. The i18next advisory was fixed by upgrading the patient workspace to i18next 26.7.2, which satisfies the installed react-i18next peer range. ESLint resolves to 9.39.5 and has no install-time peer conflict with the configured Next 16 packages; npm does emit a deprecation warning for that ESLint release.

## Integration and security limits

- No Supabase Auth phone OTP, SMS delivery, phone-to-patient linking, database persistence, SQL migration, RLS, Storage, rate-limiter, or live API workflow was tested.
- Doctor sign-in requires a real Supabase Auth account with an active matching `user_profiles` role. The server proxy checks that profile and dashboard role; database RLS must still enforce access to individual patient records.
- The kiosk uses tab-scoped browser storage for its Supabase session and intake workflow. This reduces persistence across kiosk tabs but is readable by same-origin JavaScript; it is not an HttpOnly cookie session.
- The review/completion flow creates a local demo reference. The clinical-summary route reports `persisted: false`; it does not deliver the intake to the doctor dashboard or create a real OPD queue token or clinician assignment.
- Phone OTP sends through the SMS provider configured in Supabase Auth. No SMS was sent during validation. Exotel token SMS remains disabled.
- Patient document browser access is denied by the database policies. Authenticated server-side upload/download handling still needs implementation and validation.
- The test suite does not validate SQL policies or clinical decisions. Use synthetic data only until a disposable Supabase project has passed the database security plan.

The builds prove compilation and static generation with placeholder public Supabase values; they do not demonstrate connectivity, authentication, SMS, database writes, or clinical-data security.
