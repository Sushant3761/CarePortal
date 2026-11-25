# API Security Inventory

Reviewed: 2026-11-22. This describes source behavior, not live deployment configuration.

| Endpoint | Methods | Authentication / role | Data and side effects | Validation | Rate limit / status |
|---|---|---|---|---|---|
| Patient kiosk /api/otp/send | POST | Public; phone possession is not established until verification | Requests an OTP from configured provider | Indian mobile format; provider timeout and generic provider errors | Shared limits: 3 per phone per 15 minutes and 12 per trusted IP per hour. Requires migration 0002 and proxy x-real-ip configuration. |
| Patient kiosk /api/otp/verify | POST | Public; returns verified=true but does not issue an authenticated intake session | Verifies a code with configured OTP service | Indian mobile format and six-digit code | Shared limits: 8 per phone and 30 per trusted IP per 15 minutes. Requires migration 0002 and proxy x-real-ip configuration. |
| Patient kiosk /api/send-token-sms | POST | No caller authorization | None; handler is disabled | No body is processed | Returns generic 503 until verified caller/resource binding and shared throttling exist. |
| Patient kiosk /api/generate-questions | POST | Public | Calls configured Gemini model and can incur provider cost | 16 KB request cap; bounded complaint, locations, intensity, onset and character | Shared limit: 30 per trusted IP per hour. Requires migration 0002 and proxy x-real-ip configuration. |
| Patient kiosk /api/clinical-summary/generate | POST | Public | Generates a summary using caller-supplied intake data; does not persist to the database | 64 KB request cap; field-level validation remains incomplete | Shared limit: 10 per trusted IP per hour. Requires migration 0002 and proxy x-real-ip configuration. Response explicitly returns persisted=false. |
| Doctor dashboard /api/admin/doctors | GET | Supabase cookie session; active system_admin verified in middleware and handler | Lists staff profiles and auth email addresses | No caller parameters | No shared rate limit; administrative endpoint. |
| Doctor dashboard /api/admin/doctors | POST | Supabase cookie session; active system_admin verified in middleware and handler | Invites staff by email and creates a profile; allowed roles are doctor, nurse, admin | Zod email, name, optional field bounds, and role allowlist | No shared rate limit; invitation provider may impose its own limits. |
| Doctor dashboard /api/admin/doctors | PATCH | Supabase cookie session; active system_admin verified in middleware and handler | Activates/deactivates non-system-admin accounts and bans/unbans Supabase Auth user | UUID and boolean schema; cannot modify own account or a system admin | No shared rate limit; administrative endpoint. |

## Security boundaries

- Doctor dashboard middleware calls Supabase auth.getUser() and reads the caller's own user_profiles row server-side. Unknown, inactive, and unauthorized roles are denied. This is route-level protection; direct clinical table queries still require deployed RLS.
- The admin API independently checks identity and role before using its server-only service-role client. The browser no longer invokes auth.admin or writes staff profiles.
- No kiosk API creates an authenticated patient session. OTP verification alone is not an authorization token. Do not add service-role clinical writes until a signed, short-lived intake credential and verified patient/session relationship are implemented.
- OTP and AI routes now call an atomic database-backed limiter defined in migration 0002. This protection is not active until that migration is applied, the service-role secret is configured, and the trusted proxy overwrites x-real-ip. Admin invitation limiting remains a deployment/provider control.

## Required before production

1. Apply migration 0002 on a disposable Supabase project, validate concurrency and limits, and configure a proxy that overwrites x-real-ip.
2. Implement a signed intake session after OTP verification and define patient identity mapping.
3. Restrict or disable public AI generation until shared throttling and request bounds are deployed.
4. Complete server-backed upload/download routes and private Storage policies before handling real medical documents.
5. Apply and verify RLS on a disposable Supabase project after choosing the canonical schema and staff assignment model.

## Document storage

There is no upload/download API. The kiosk upload page and reusable component now clearly disable storage and do not persist base64 data. Migration 0003 creates a private bucket and deny-only object policies pending an authenticated patient/session ownership model. Existing document rows are untouched.
