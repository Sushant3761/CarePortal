# Supabase Setup Notes

CarePortal uses Supabase Auth and database access policies. For a fresh project, use `database/production_schema.sql` and read `database/README.md`; do not apply the legacy SQL snapshots blindly or use a shared project with real patient information until policies have been tested.

## Required configuration

Set the project URL and anon key in each app's local `.env.local`:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

Keep `SUPABASE_SERVICE_ROLE_KEY` server-only. Never name it with a `NEXT_PUBLIC_` prefix or expose it to browser code. The dashboard sign-in flow expects Supabase Auth users to have an active `user_profiles` row whose role matches their portal access.

## Database and RLS

Versioned migrations 0001-0003 are preserved unchanged. Migration 0001 is a fail-closed cutover baseline, 0002 provides service-role-only shared rate limiting, 0003 keeps patient documents private, and 0004 restores access only for a patient’s own verified Auth identity or an explicitly assigned active doctor. For fresh installs use `database/production_schema.sql`; for existing schemas validate the ordered migration path on a disposable Supabase project first. Next.js is upgraded to 16.4.6; keep the lockfile synchronized and use the current patched framework line.

The scripts under `database/legacy/` are retained only for historical review and are not part of the supported production setup. Their classification and disposition are documented in `database/README.md`.

Do not use these legacy files as a production security baseline:

- `database/legacy/fix_rls_policies.sql` grants broad anonymous/authenticated access to sensitive tables.
- `database/legacy/disable_rls_for_dev.sql` turns off RLS on application tables.
- `database/legacy/schema.sql` has broad staff policies and lacks the explicit assignment model.

Do not apply any permissive or RLS-disabling legacy script to a shared or production database. Before processing real data, apply and test the canonical schema, configure the Supabase Auth SMS provider, and verify anonymous and cross-user access is denied for every clinical record and object.

## Phone OTP

The kiosk OTP routes now call Supabase Auth `signInWithOtp` and `verifyOtp`. Configure phone authentication and the SMS provider (such as Twilio) in the Supabase project dashboard; provider credentials belong there and are not application `.env` values. The API keeps the shared server-side rate limits. Use a provider test environment and synthetic phone numbers for testing.

## Validation checklist

- Use synthetic data in a disposable project.
- Apply the selected schema and migrations in a documented order.
- Test login for doctor, admin, inactive, and wrong-role accounts.
- Test anon access and cross-patient access for each table and Storage bucket.
- Confirm the service role key is available only to trusted server code.
- Configure backups, retention, audit policies, and operational access with your organization.

See `docs/TECHNICAL_AUDIT.md`, `docs/DEVELOPMENT_ROADMAP.md`, and `docs/TESTING_REPORT.md` for findings and verification limits.
