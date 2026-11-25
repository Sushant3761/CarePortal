# Database setup and SQL inventory

## Supported fresh install

Use `production_schema.sql` for a new Supabase project. It creates the schema
used by the current patient intake UI, enables and forces RLS on clinical
tables, links phone-authenticated patients to `auth.users`, and requires an
active row in `doctor_patient_assignments` for doctor access. Phone OTP must be
configured in Supabase Auth with the project's SMS provider. Do not use the
legacy `schema.sql` as a production baseline.

The existing versioned migrations `migrations/0001` through `0003` are
preserved unchanged. Migration 0001 is fail-closed, 0002 provides service-role-
only shared rate limits, and 0003 keeps patient documents private and denies
browser object access. New migration `0004_assignment_scoped_patient_access.sql`
restores access only under the approved patient/Auth and active-assignment
model. For an established schema, validate the prerequisite tables and test
the ordered migrations on a disposable Supabase project before production.
Applying 0001 alone deliberately removes clinical access until 0004 is applied.
For a new project, use the self-contained `production_schema.sql` instead.

`production_schema.sql` currently permits authenticated patients to write
intake rows scoped to their own patient ID and permits assigned doctors to
read those records. Documents in Storage remain inaccessible to browser roles;
uploads/downloads need a server route that re-checks the authenticated user,
patient ownership/assignment, and object path.

## SQL file classification

| File | Classification | Public repository disposition |
| --- | --- | --- |
| `production_schema.sql` | Supported canonical fresh-install schema | Commit |
| `migrations/0001_fail_closed_clinical_access.sql` | Production cutover lockdown; intentionally deny-by-default | Commit, retain unchanged |
| `migrations/0002_shared_api_rate_limits.sql` | Production migration; service-role-only rate-limit store/function | Commit, retain unchanged |
| `migrations/0003_private_documents_default_deny.sql` | Production migration; private document bucket and deny policies | Commit, retain unchanged |
| `migrations/0004_assignment_scoped_patient_access.sql` | Production migration; restores own-patient and explicit active-assignment RLS after the fail-closed cutover | Commit after disposable-project SQL validation |
| `seed/seed.sql` | Development/demo reference rows and synthetic patient examples | Commit only as synthetic development seed |
| `create_demo_doctors.sql` | Development-only profile bootstrap using placeholder UUIDs | Commit after this file is clearly labeled and uses generic sample identities |
| `legacy/schema.sql` | Superseded legacy schema with broad staff policies | Commit under `legacy/` for review; never use as the supported setup |
| `legacy/add_new_features.sql` | Superseded legacy extension script; explicitly disables RLS | Commit under `legacy/` for review; never run on shared/production databases |
| `legacy/careportal_complete_schema.sql` | Superseded legacy full schema; disables RLS | Commit under `legacy/` for review; never run on shared/production databases |
| `legacy/fix_rls_policies.sql` | Superseded unsafe policy repair with broad access | Commit under `legacy/` for review; never run on shared/production databases |
| `legacy/disable_rls_for_dev.sql` | Development-only unsafe convenience script that disables RLS | Commit under `legacy/` for review; never run against shared/production databases |

No SQL file was deleted. The five unsafe/superseded scripts are isolated under
`database/legacy/` with their contents preserved. `create_demo_doctors.sql` contains no passwords or
credentials and now uses generic names, null contact/license fields, and
`.test` email examples. Seed rows use synthetic patient names and have no
phone/ABHA values.
