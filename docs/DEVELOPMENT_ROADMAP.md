# CarePortal Development Roadmap

Priorities reflect the source audit in `TECHNICAL_AUDIT.md`. Production use with real patient information must wait until the critical access-control and data-storage milestones are complete and independently verified.

## Milestone 1 — Contain unsafe access and demo authentication (CRITICAL)

- [ ] Remove scripts/instructions that disable RLS from normal setup; clearly mark them unsafe and isolate them from production guidance.
- [ ] Replace permissive anon/authenticated policies with least-privilege policies for each sensitive table.
- [ ] Require verified Supabase Auth for dashboard login; derive role from active `user_profiles`, never from a client-selected role or local JSON.
- [ ] Confirm patient/session ownership checks for all reads/writes, including AI summary and queue creation routes.
- [ ] Validate the effective policies in a real project with anon and cross-user security probes.

## Milestone 2 — Authentication and authorization

- [ ] Define trusted kiosk intake identity/session lifecycle and doctor/admin role lifecycle.
- [ ] Move privileged operations into server handlers and verify JWT/session on every request.
- [ ] Add rate limits to OTP, SMS, AI, and intake endpoints; use a shared store suitable for the deployment runtime.
- [ ] Ensure logout and kiosk completion clear sensitive transient data and revoke/expire sessions.

## Milestone 3 — Database integrity and private storage

- [ ] Convert schema variants into ordered, versioned migrations and validate on a clean Supabase project.
- [ ] Document tenant/hospital scope and staff assignment relationships; apply database constraints and indexes.
- [ ] Create private Storage bucket and object policies; replace base64 columns with private object paths and short-lived signed access.
- [ ] Verify RLS for all tables, views, RPCs, and Storage objects; review audit logging access.

## Milestone 4 — Patient Kiosk

- [ ] Minimize PHI in localStorage; implement short-lived intake recovery and reliable cleanup.
- [ ] Add validation, progress recovery, duplicate submission protection, and explicit loading/error/empty states.
- [ ] Await uploads and database writes; validate real file content/size server-side.
- [ ] Validate AI generated questions and summary structures; ensure clinicians review AI output.

## Milestone 5 — Doctor Dashboard

- [ ] Remove demo patients/default production-looking stats from normal mode.
- [ ] Load only authorized queue/record fields with pagination and explicit error/empty states.
- [ ] Add verified authorization for all patient, report, admin, and AYUSH routes and data operations.
- [ ] Verify logout, session expiry, and role changes across every dashboard page.

## Milestone 6 — API reliability

- [ ] Use strict request/response schemas, size limits, timeouts, safe errors, and structured redacted logs.
- [ ] Validate Supabase Auth SMS delivery and provider-side throttling in a disposable test project.
- [ ] Authenticate Exotel token SMS requests and constrain caller-controlled message values.
- [ ] Add health checks and observability without logging identifiers, tokens, or clinical payloads.

## Milestone 7 — Performance and accessibility

- [ ] Measure each production app bundle; lazy-load 3D and OCR features.
- [ ] Replace broad DB selects; paginate queues/history and cache safe reference data.
- [ ] Check responsive layouts, keyboard access, labels, focus management, and screen reader behavior.

## Milestone 8 — Automated verification

- [ ] Wire root lint, typecheck, and test commands to real tools.
- [ ] Add unit tests for validation/auth policy helpers and API error paths.
- [ ] Add synthetic-data end-to-end kiosk and doctor flows.
- [ ] Add automated RLS and storage isolation checks against a disposable Supabase project.
- [ ] Add CI builds for both workspaces and dependency/security review.

## Milestone 9 — Documentation and release readiness

- [ ] Document exact env variables, trusted service setup, database migration order, and private storage configuration.
- [ ] Separate local demo mode from production configuration and remove demo secrets/credentials.
- [ ] Complete privacy, retention, incident response, accessibility, and deployment reviews with qualified owners.
- [ ] Perform a release security review; only then initialize the repository and prepare a real first release.

## Work completed in this pass

- Static audit and source-confirmed findings recorded in `TECHNICAL_AUDIT.md`.
- Removed dashboard demo sign-in and prefilled passwords; login now validates Supabase Auth and the active profile role.
- Tightened OTP input validation, provider timeouts, returned errors, and logging.
- Replaced unsafe setup instructions, demo credential docs, and fixed-OTP claims; added standard ESLint configuration and fixed lint errors.
- Wired root lint, typecheck, and Vitest commands to actual tools.
- Local TypeScript and lint checks completed. Builds and Vitest were blocked by missing Windows optional binaries; see `TESTING_REPORT.md`.
- Effective RLS, Storage privacy, server-side route authorization, rate limiting, live provider workflows, and cross-patient isolation remain unresolved.
