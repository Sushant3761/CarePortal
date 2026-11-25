# Credentials and Test Data

CarePortal does not provide shared demo login credentials or a fixed OTP. Earlier copies of this file listed credentials that are no longer supported by the dashboard and should not be reused.

## Doctor dashboard accounts

Create accounts through the trusted Supabase Auth administration workflow for your environment. Add an active `user_profiles` record with the correct `doctor`, `admin`, or `system_admin` role and profile details. Use unique, temporary passwords and deliver them through an approved secure channel. The role selector on the login page only selects which portal the user intends to enter; the account's database role determines whether access is allowed.

## Patient OTP

Patient OTP uses Supabase Auth phone verification. Configure the SMS provider in the Supabase dashboard; provider credentials are not stored in the application environment. There is no always-valid test OTP in the application. Use a provider test environment and synthetic test phone numbers.

## Seed data

SQL seed files contain synthetic sample records for isolated demonstrations. Treat all seed records as test data, keep them out of production, and never substitute real patient records. Do not use `database/legacy/disable_rls_for_dev.sql` or permissive legacy policies on a shared project.
