# CarePortal Testing Report

**Review date:** 2026-11-23
**Environment:** Windows, Node v25.2.1. No live or disposable Supabase project or provider credentials were available.

## Most recent completed validation

Validation ran in an isolated copy of the complete worktree, excluding `.git`, local dependencies, build output, and private `.env` files. The isolated lockfile selected ESLint 9.39.5. Builds used placeholder Supabase and Gemini values. npm audit used the registry successfully. The working checkout's incomplete `node_modules` was not changed.

| Check | Last result | Scope and limits |
|---|---|---|
| Isolated lock refresh and `npm ci` | PASS | Lock updated for ESLint 9; 587 packages installed successfully on Windows. npm printed optional-peer warnings for the WASI-only `@emnapi` tree. |
| Patient and doctor TypeScript | PASS | `npm run typecheck` completed both checks. |
| Patient ESLint | FAIL | 128 errors / 86 warnings. Frequent rules: `no-explicit-any`, React Hooks purity/state-in-effect, unused values, and `no-require-imports`. |
| Doctor ESLint | FAIL | 57 errors / 80 warnings. Frequent rules: `no-explicit-any`, React Hooks declarations/effect diagnostics, and unused values. |
| Auth/security file ESLint | PASS | OTP send/verify, rate limiter, admin client, dashboard proxy, auth helpers, and admin API route passed targeted lint. |
| Patient production build | PASS | Webpack build passed with placeholder environment variables. |
| Doctor production build | PASS | Webpack build passed with placeholder environment variables. |
| Vitest | PASS | 2 test files / 5 tests passed, including patient session cleanup. |
| `npm audit` | PASS | 0 info, low, moderate, high, or critical advisories; 671 dependencies in the report. |
| Git whitespace checks | PASS | `git diff --check` and `git diff --cached --check` report no whitespace errors; Git reports LF-to-CRLF conversion notices. |

## ESLint dependency compatibility

All three package manifests now request ESLint `^9.39.2`; the refreshed lock resolves 9.39.5. This satisfies the peer ranges of the Next 16 plugin set and avoids the earlier ESLint 10 peer mismatch. npm marks 9.39.5 deprecated/unsupported, so the project should revisit this after Next's lint plugin dependencies officially support ESLint 10. Do not treat the remaining lint failures as a clean lint result.

## Security and integration limits

- Unit tests pass, but they do not exercise Supabase services, SQL RLS, or browser flows.
- No live Supabase Auth OTP, phone-link trigger, RLS, Storage, rate-limiter, or migration test has been run. `database/SECURITY_TEST_PLAN.md` lists the required disposable-project checks.
- The kiosk Auth bearer session is stored in tab-scoped browser storage and can be read by same-origin JavaScript. Completion, exit, and timeout now sign out and clear workflow keys, with a local sign-out fallback; this does not provide HttpOnly-cookie protection.
- The patient summary route returns `persisted: false`; Exotel SMS is disabled; document object access is denied pending authenticated upload/download APIs. Demo UI now says no clinician assignment or real queue token is created.
- Use synthetic data only. Do not deploy or process real patient information until the database policies, Auth linking, trusted assignment lifecycle, and server-side document/API controls have been validated.
