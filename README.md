# CarePortal

CarePortal is an early-stage clinical intake and doctor dashboard workspace. It contains a patient-facing kiosk and a separate doctor-facing Next.js application. Supabase Auth provides the patient phone OTP flow; Supabase Auth SMS, Gemini, and any enabled provider integrations require deployment configuration and security validation.

**This repository is not production-ready for real patient information.** The audit found permissive RLS setup scripts, client-side authorization patterns, and a development document-upload implementation. See [the technical audit](docs/TECHNICAL_AUDIT.md) and [development roadmap](docs/DEVELOPMENT_ROADMAP.md).

## Features in source

- Patient intake with identity, consent, symptoms, pain location, medical and family history, and review pages.
- English and Hindi UI support, voice guidance, optional AI-generated follow-up questions and summaries.
- Doctor dashboard pages for queues, patient records, summaries, reports, AYUSH, and administration.
- Supabase Auth and PostgreSQL client integration; optional Gemini generation. Exotel SMS delivery remains disabled.

Source presence does not mean a live service is configured or a workflow is verified.

## Technology

- Next.js 16, React 19, TypeScript, Tailwind CSS, Framer Motion
- Supabase JavaScript client with Supabase Auth/PostgreSQL
- Gemini SDK; phone OTP uses the SMS provider configured in Supabase Auth
- npm workspaces: `apps/patient-kiosk`, `apps/doctor-dashboard`, `packages/types`

## Architecture and folders

```text
apps/
  patient-kiosk/       Patient intake UI and Next.js API routes
  doctor-dashboard/    Doctor and admin UI
packages/types/        Shared TypeScript types
database/               SQL schema variants, seed, and setup scripts
docs/                   Audit, roadmap, and verification reports
```

The kiosk currently makes direct browser Supabase calls. API routes handle OTP, AI, and token SMS. The dashboard uses browser Supabase Auth and client-side route checks. Those client checks are not a security boundary; database RLS and server authorization must be made least-privilege before real PHI is used.

## Prerequisites

- Node.js 18 or later (the app uses `AbortSignal.timeout` in server integrations)
- npm
- A Supabase project for database/auth-backed operation
- Optional server credentials: Gemini; Supabase Auth phone-provider credentials are configured in Supabase, not in this app's `.env`.

## Install

From the project root:

```bash
npm install
```

Create local env files from `.env.example` as needed. Next.js reads `.env.local` in each app directory:

```powershell
Copy-Item .env.example apps/patient-kiosk/.env.local
Copy-Item .env.example apps/doctor-dashboard/.env.local
```

Fill only the values required for your environment. Do not commit local env files or place privileged keys in variables prefixed with `NEXT_PUBLIC_`.

## Environment configuration

`NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` are required for browser clients. `SUPABASE_SERVICE_ROLE_KEY` and `GEMINI_API_KEY` must remain server-side. The sample file documents integration placeholders; some optional variables may not currently be consumed by the code.

Configure phone authentication and its SMS provider in Supabase Auth. Exotel token SMS is disabled until an authorized server flow is implemented. Gemini routes use `GEMINI_API_KEY` when enabled.

## Database setup

For a fresh Supabase project, use `database/production_schema.sql`. For an existing schema, review and test migrations 0001–0004 on a disposable project first. Historical scripts are isolated in `database/legacy/`; they include broad or disabled RLS policies and must not be used for production setup. See `database/README.md` and `database/SECURITY_TEST_PLAN.md`.

**Do not run `database/legacy/disable_rls_for_dev.sql` or the permissive policies in `database/legacy/fix_rls_policies.sql` on a shared or production project.** They disable or broadly bypass row-level controls. Do not use real patient information until the RLS and Storage access model has been independently verified. See [current Supabase setup notes](SUPABASE_SETUP.md) and the database security test plan.

## Local development

Open two terminals at the repository root:

```bash
npm run dev:patient
```

```bash
npm run dev:doctor
```

The patient app uses port 3000 and doctor dashboard uses port 3001 by default. Doctor sign-in now requires an actual Supabase Auth account with an active matching `user_profiles` role. No demo credentials are provided.

## Checks and builds

```bash
npm run typecheck
npm run lint
npm test
npm run build:patient
npm run build:doctor
npm run build
```

The repository currently has no test files, so `npm test` cannot provide workflow coverage yet. Current verification results and environment limitations are recorded in [TESTING_REPORT.md](docs/TESTING_REPORT.md).

## Privacy and deployment notes

- Keep patient records in a project with enforced, reviewed least-privilege RLS.
- Configure private Storage buckets and object policies before enabling uploads.
- Keep secrets server-side; rotate any credential that was previously committed or shared.
- Configure request throttling for OTP, SMS, and AI endpoints at a shared service boundary.
- Review retention, consent, audit, backup, incident response, legal, accessibility, and hosting requirements with the responsible organization.
- The code does not establish HIPAA, ABDM, or other compliance certification.

## Git

This workspace is intentionally prepared without initializing or modifying Git. Initialize the repository and create its first commit separately when ready.
