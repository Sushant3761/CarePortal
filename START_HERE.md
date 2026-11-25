# Start Here

CarePortal is an early-stage project and is **not ready for real patient data**. The old quick-start steps disabled Row Level Security and used shared demo credentials/OTP values; those steps are retired.

For prerequisites, environment setup, app commands, and the current security limitations, follow [README.md](README.md). Do not run scripts in `database/legacy/` on a shared project. The [database guide](database/README.md), [security test plan](database/SECURITY_TEST_PLAN.md), [technical audit](docs/TECHNICAL_AUDIT.md), and [roadmap](docs/DEVELOPMENT_ROADMAP.md) explain the supported setup and remaining work.

Local app startup from the workspace root:

```bash
npm install
npm run dev:patient
```

In a second terminal:

```bash
npm run dev:doctor
```

Doctor sign-in requires a real Supabase Auth account and an active `user_profiles` record with the corresponding doctor or administrator role. Patient OTP uses Supabase Auth; configure an SMS provider in the Supabase project dashboard. No fixed development OTP or demo login is implemented.
