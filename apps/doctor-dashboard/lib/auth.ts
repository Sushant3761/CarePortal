import { supabase } from '@/lib/supabase';

export interface AuthenticatedProfile {
  id: string;
  name: string;
  email: string;
  role: string;
  department: string | null;
  specialization: string | null;
}

/** Reads the authenticated Supabase user and their own profile from Supabase. */
export async function getAuthenticatedProfile(): Promise<AuthenticatedProfile | null> {
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return null;

  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('full_name, role, active, department, specialization')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError || !profile || profile.active !== true) return null;

  return {
    id: user.id,
    name: profile.full_name,
    email: user.email || '',
    role: profile.role,
    department: profile.department,
    specialization: profile.specialization,
  };
}
