-- ========================================
-- CREATE DEMO DOCTOR ACCOUNTS IN SUPABASE
-- ========================================
-- This script links manually created Supabase Auth users to sample profiles.
-- Use synthetic accounts in an isolated project and set unique temporary passwords.

-- ===========================
-- STEP 1: Create Auth Users via Supabase Dashboard
-- ===========================
-- Go to: Supabase Dashboard > Authentication > Users > Add User
-- Create the following users manually (Supabase requires manual user creation for security):

-- Create any desired synthetic Auth accounts manually in Supabase.
-- Never reuse shared passwords or use these sample identities in production.

-- ===========================
-- STEP 2: Link User Profiles
-- ===========================
-- After creating the auth users above, run the queries below
-- Replace 'REPLACE_WITH_ACTUAL_UUID' with the actual UUID from Supabase Auth Users table

-- System Administrator Profile
INSERT INTO user_profiles (id, role, full_name, contact_number, department, specialization, license_number, active)
VALUES
('REPLACE_WITH_ADMIN_UUID', 'system_admin', 'Sample System Administrator', NULL, 'Administration', 'System Admin', NULL, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Sample Doctor One - General Medicine
INSERT INTO user_profiles (id, role, full_name, contact_number, department, specialization, license_number, active)
VALUES
('REPLACE_WITH_SHARMA_UUID', 'doctor', 'Sample Doctor One', NULL, 'General Medicine', 'General Medicine', NULL, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Sample Doctor Two - Cardiology
INSERT INTO user_profiles (id, role, full_name, contact_number, department, specialization, license_number, active)
VALUES
('REPLACE_WITH_PATEL_UUID', 'doctor', 'Sample Doctor Two', NULL, 'Cardiology', 'Cardiology', NULL, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Sample Doctor Three - Ayurveda
INSERT INTO user_profiles (id, role, full_name, contact_number, department, specialization, license_number, active)
VALUES
('REPLACE_WITH_KUMAR_UUID', 'doctor', 'Sample Doctor Three', NULL, 'Ayurveda', 'Ayurveda', NULL, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Sample Doctor Four - Pediatrics
INSERT INTO user_profiles (id, role, full_name, contact_number, department, specialization, license_number, active)
VALUES
('REPLACE_WITH_REDDY_UUID', 'doctor', 'Sample Doctor Four', NULL, 'Pediatrics', 'Pediatrics', NULL, TRUE)
ON CONFLICT (id) DO NOTHING;

-- ===========================
-- VERIFICATION QUERY
-- ===========================
-- Run this to verify the doctor accounts were created successfully:

SELECT
  up.id,
  up.role,
  up.full_name,
  up.department,
  up.specialization,
  up.license_number,
  up.active,
  au.email,
  au.created_at
FROM user_profiles up
JOIN auth.users au ON au.id = up.id
WHERE up.role IN ('doctor', 'system_admin')
ORDER BY up.role, up.full_name;

-- ===========================
-- SUMMARY
-- ===========================
-- Synthetic sample profiles linked (no credentials are created by this SQL):
--
-- 1. Sample System Admin
--    Email: admin@example.test
--    Role: System Administrator
--
-- 2. Sample Doctor One
--    Email: doctor1@example.test
--    Department: General Medicine
--    Specialization: MD Internal Medicine
--
-- 3. Sample Doctor Two
--    Email: doctor2@example.test
--    Department: Cardiology
--    Specialization: DM Cardiology
--
-- 4. Sample Doctor Three
--    Email: doctor3@example.test
--    Department: Ayurveda
--    Specialization: BAMS, MD Ayurveda
--
-- 5. Sample Doctor Four
--    Email: doctor4@example.test
--    Department: Pediatrics
--    Specialization: MD Pediatrics
--
-- NOTE: Only system admins can create new doctor accounts through the dashboard
-- Doctors cannot self-register - they must be created by administrators
