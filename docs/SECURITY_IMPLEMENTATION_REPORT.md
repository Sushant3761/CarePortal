# CarePortal Security Implementation Report

**Date:** 2026-11-22
**Scope:** Patient kiosk and doctor dashboard source, API routes, SQL snapshots/migrations, environment template, storage handling, and available local checks. No live Supabase project or provider credentials were available.

> **Current status (2026-11-23):** This report's findings and verification results below are a 2026-11-22 snapshot. Dependency versions, OTP flow, patient session cleanup, database model, and demo UI have since changed. Read the current implementation addendum at the end; no live Supabase integration is claimed.

## Problems found

- Conflicting SQL snapshots grant broad access, allow role/profile changes, or disable RLS. No consistent patient-owner or doctor-assignment relationship exists.
- Doctor authentication checks used editable localStorage values and did not protect server-rendered routes.
- Browser code called Supabase Auth admin methods for staff creation and wrote staff profiles directly.
- Public clinical-summary code used service-role access to create/match patients, save summaries, and enqueue visits. The kiosk SMS endpoint was an unauthenticated Exotel relay.
- OTP success did not create an authenticated intake session. Patient and clinical data paths still depend on browser-side direct Supabase calls.
- Document handling included base64 persistence in a clinical table and a simulated OCR/save flow with fabricated sample records.
- OTP and AI endpoints had no shared rate limiter. Windows optional dependencies were absent from the installed package tree.
- The pinned Next.js 14.0.4 version is unsupported and affected by critical upstream security advisories. See the release blockers below.

## Changes implemented

- Added a Supabase SSR browser/server client, cookie refresh middleware, server-verified active-profile/role gates, and client guards that no longer treat localStorage as authentication.
- Moved staff list, invitation, and status operations to a server-only API. It verifies active system-admin authority, validates input, limits roles, and does not accept a browser-supplied password.
- Removed clinical database writes and service-role fallback from the public summary API. It now bounds request size and key input fields, generates a stateless summary, and returns persisted=false.
- Disabled the anonymous SMS provider relay with a generic 503.
- Added an atomic database-backed rate limiter for OTP send/verify and public AI endpoints. Phone/IP-derived bucket identifiers are HMACed. It fails closed without migration 0002, the service-role key, or a trusted x-real-ip header.
- Removed base64 document database writes and simulated OCR/save behavior from kiosk and doctor patient-detail document flows. Upload controls now explain that secure uploads are unavailable.
- Moved kiosk patient identifiers and intake answers from persistent `localStorage` to tab-scoped `sessionStorage`; the identity screen clears legacy `careportal_*` values from `localStorage` while retaining only the language preference. Removed an unused clinical-summary storage write.
- Added a private patient-documents bucket migration with MIME/size limits and restrictive deny policies for anon/authenticated roles. This migration intentionally permits no object operations yet.
- Added a fail-closed RLS migration that removes client grants/policies on clinical tables and permits self-profile reads only. Legacy unsafe SQL scripts now carry prominent warnings.
- Added an API security inventory, implementation plan updates, and role authorization tests.

## Authentication and authorization

The doctor dashboard now uses Supabase SSR cookies. Middleware calls auth.getUser(), reads the active caller's user_profiles role server-side, and gates pages/APIs. Clinical roles are doctor/nurse; admin pages require admin/system_admin; staff administration requires system_admin. The staff API repeats identity/role validation before service-role use.

These source checks are not sufficient until the restrictive profile policy is deployed: existing unsafe profile-update policies could let a caller modify their database role. Migration 0001 denies such writes, but it also blocks current kiosk/dashboard direct clinical queries. It must not be applied to production until a tested API cutover and rollback plan exist.

Patients still have no signed intake credential after OTP verification. Therefore, patient ownership and doctor assignment are not claimed or inferred. Doctor clinical pages still query Supabase tables directly and need server APIs plus a real assignment model.

## RLS migrations

- database/migrations/0001_fail_closed_clinical_access.sql: default-denies direct access to clinical tables; permits a user to read only their own profile; allows public reads only on reference tables.
- database/migrations/0002_shared_api_rate_limits.sql: creates the private rate bucket table and service-role-only atomic limiter function.
- database/migrations/0003_private_documents_default_deny.sql: creates a private bucket and restrictive deny rules until an ownership policy can be implemented.

None of these migrations has been executed or verified against PostgreSQL. They must first be tested on a disposable Supabase project. Do not use the current application with real PHI.

## Storage

Existing base64 document records were not migrated or deleted. No authenticated patient/session token, verified storage ownership link, signed URL flow, or upload/download API exists. Kiosk and doctor document controls no longer claim a successful upload; they refuse to save files. Migration 0003 is deny-only and does not provide usable uploads. A safe migration for old documents requires an inventory, retention decision, patient identity mapping, and a separately tested migration plan.

Kiosk intake data now lasts for the browser tab session and is cleared when the identity flow starts on a browser with legacy persistent data. `sessionStorage` is still readable by same-origin JavaScript and is not a substitute for an authenticated server-side intake session or XSS protection.

## API protection

See docs/API_SECURITY_INVENTORY.md for every route, method, role, validation, side effect, and limiter status. Admin APIs have server-side identity/role checks. Kiosk OTP/AI routes remain public, with shared rate checks that are inactive until configured and migrated. OTP verification is not a credential for subsequent requests.

## Rate limiting

Migration 0002 provides atomic fixed-window counters. Current configured source limits:

- OTP send: 3 per phone per 15 minutes; 12 per IP per hour.
- OTP verification: 8 per phone per 15 minutes; 30 per IP per 15 minutes.
- Clinical summary generation: 10 per IP per hour.
- Question generation: 30 per IP per hour.

These are not active in a deployment until migration 0002 is applied, SUPABASE_SERVICE_ROLE_KEY is configured server-side, and the platform proxy overwrites x-real-ip. Admin invitation rate controls remain external.

## Verification results

- Both TypeScript checks: PASS.
- Both ESLint checks: PASS with existing hook-dependency, image, and remote-font warnings.
- Doctor production build: PASS with placeholders from .env.example; external Google font CSS could not be fetched, but no build-time font download was required.
- Patient production build: PASS with placeholders from .env.example; external Google font CSS could not be fetched.
- Direct Node authorization assertions: PASS (7 assertions).
- Vitest: BLOCKED. The locked @rollup/rollup-win32-x64-msvc binary is absent. npm test and direct Vitest invocation fail before test discovery. A targeted no-save install was attempted but stalled because the registry is unreachable.
- Live authentication/RLS/Storage/API integration and E2E tests: NOT EXECUTED; no disposable/live Supabase project or credentials.

## Configuration and release blockers

Required server environment values include NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, Twilio Verify credentials, and Gemini credentials where those integrations are enabled. Do not expose the service-role, Twilio, or Gemini keys with a NEXT_PUBLIC_ prefix. The deployment proxy must overwrite x-real-ip.

Both apps pin Next.js 14.0.4, which is unsupported. Upstream advisory GHSA-2464-fhr4-w9xw / CVE-2026-96889 lists affected Next versions through 15.5.27 and fixes at 15.5.28 or 16.4.1; it also describes a sharp >=0.35.5 workaround. The patient app's React Three Fiber 8 and Drei 9 peers require React 18, so a framework upgrade needs a coordinated React 19 / compatible Three package upgrade. This was not attempted with the registry unavailable. Do not deploy until this is addressed.

## Next milestone

Use a disposable Supabase project to confirm the canonical schema, OTP identity mapping, clinician assignment/revocation rules, admin scope, and document retention. Implement authenticated patient intake and server APIs, then test migrations 0001–0003 and RLS cross-user cases. In parallel, restore Windows optional packages and upgrade both apps to a patched supported Next release before any real patient data is processed.

## Current implementation addendum (2026-11-23)

- Dependency versions are Next.js 16.4.6, React 19.3.1, React Three Fiber 9.8.2 / Drei 10.7.9, and Vitest 4.1.12. The ESLint manifests and lockfile now resolve ESLint 9.39.5 to match the Next plugin peer ranges. Isolated `npm ci`, typechecks, Vitest, and both production builds pass; `npm audit` reports zero advisories. See `TESTING_REPORT.md` for remaining lint debt and the ESLint 9 deprecation warning.
- Patient OTP send/verify now use Supabase Auth, and the verified session is installed by the kiosk. Migration 0004 and `production_schema.sql` link a confirmed Auth phone to a unique unlinked patient row and require explicit active doctor-patient assignments. No Auth, trigger, or RLS behavior has been tested against a database.
- Patient session state uses tab storage. Completion, exit, and timeout now attempt Supabase sign-out, fall back to local sign-out, and clear `careportal_*` workflow keys. This does not prevent same-origin JavaScript from reading the active token before logout.
- The kiosk completion UI no longer fabricates a doctor, queue position, wait time, or claim of dashboard delivery. Its generated reference is labeled demo-only; the summary API remains non-persistent, and SMS/document object access remain disabled.
- Unsafe SQL scripts remain preserved under `database/legacy/`; fresh install instructions select `database/production_schema.sql`, and existing installations must test migrations 0001–0004 in order on a disposable project.
- Remaining release blockers: disposable-project database tests, trusted assignment creation/revocation workflow, server-side APIs for clinical read/write and private documents, policy decisions for admin scope and retention, and the remaining lint debt. Keep real patient data out of this project.
