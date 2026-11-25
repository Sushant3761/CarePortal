import { createClient } from '@supabase/supabase-js';
import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';
import { createSupabaseServerClient } from '@/lib/supabase/server';

const inviteSchema = z.object({
  email: z.string().trim().email().max(254),
  full_name: z.string().trim().min(2).max(120),
  contact_number: z.string().trim().max(32).optional().default(''),
  department: z.string().trim().max(120).optional().default(''),
  specialization: z.string().trim().max(160).optional().default(''),
  license_number: z.string().trim().max(80).optional().default(''),
  role: z.enum(['doctor', 'nurse', 'admin']),
});

const statusSchema = z.object({
  id: z.string().uuid(),
  active: z.boolean(),
});

async function getAuthorizedAdmin() {
  let sessionClient;
  try {
    sessionClient = await createSupabaseServerClient();
  } catch {
    return { response: NextResponse.json({ error: 'Authentication service is unavailable.' }, { status: 503 }) };
  }

  const { data: { user }, error: authError } = await sessionClient.auth.getUser();
  if (authError || !user) {
    return { response: NextResponse.json({ error: 'Authentication required.' }, { status: 401 }) };
  }

  const { data: profile, error: profileError } = await sessionClient
    .from('user_profiles')
    .select('role, active')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError || profile?.active !== true || profile.role !== 'system_admin') {
    return { response: NextResponse.json({ error: 'Insufficient permissions.' }, { status: 403 }) };
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    return { response: NextResponse.json({ error: 'Account management is not configured.' }, { status: 503 }) };
  }

  return {
    admin: createClient(url, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    }),
    actorId: user.id,
  };
}

export async function GET() {
  const context = await getAuthorizedAdmin();
  if ('response' in context) return context.response;

  const [{ data: profiles, error: profilesError }, { data: users, error: usersError }] = await Promise.all([
    context.admin
      .from('user_profiles')
      .select('id, role, full_name, contact_number, department, specialization, license_number, active, created_at')
      .in('role', ['doctor', 'nurse', 'admin', 'system_admin'])
      .order('created_at', { ascending: false }),
    context.admin.auth.admin.listUsers({ page: 1, perPage: 1000 }),
  ]);

  if (profilesError || usersError) {
    return NextResponse.json({ error: 'Unable to load staff accounts.' }, { status: 500 });
  }

  const emailById = new Map(users.users.map((authUser) => [authUser.id, authUser.email || '']));
  return NextResponse.json({
    doctors: (profiles || []).map((profile) => ({ ...profile, email: emailById.get(profile.id) || '' })),
  });
}

export async function POST(request: NextRequest) {
  const context = await getAuthorizedAdmin();
  if ('response' in context) return context.response;

  let input: z.infer<typeof inviteSchema>;
  try {
    input = inviteSchema.parse(await request.json());
  } catch {
    return NextResponse.json({ error: 'Invalid staff invitation details.' }, { status: 400 });
  }

  const { data: invited, error: inviteError } = await context.admin.auth.admin.inviteUserByEmail(input.email, {
    data: { full_name: input.full_name },
  });

  if (inviteError || !invited.user) {
    return NextResponse.json({ error: 'Unable to invite this staff member.' }, { status: 502 });
  }

  const { error: profileError } = await context.admin.from('user_profiles').insert({
    id: invited.user.id,
    role: input.role,
    full_name: input.full_name,
    contact_number: input.contact_number || null,
    department: input.department || null,
    specialization: input.specialization || null,
    license_number: input.license_number || null,
    active: true,
  });

  if (profileError) {
    await context.admin.auth.admin.deleteUser(invited.user.id);
    return NextResponse.json({ error: 'Unable to create the staff profile.' }, { status: 500 });
  }

  return NextResponse.json({ success: true }, { status: 201 });
}

export async function PATCH(request: NextRequest) {
  const context = await getAuthorizedAdmin();
  if ('response' in context) return context.response;

  let input: z.infer<typeof statusSchema>;
  try {
    input = statusSchema.parse(await request.json());
  } catch {
    return NextResponse.json({ error: 'Invalid staff status request.' }, { status: 400 });
  }

  if (input.id === context.actorId) {
    return NextResponse.json({ error: 'You cannot change your own account status.' }, { status: 409 });
  }

  const { data: target, error: targetError } = await context.admin
    .from('user_profiles')
    .select('id, role')
    .eq('id', input.id)
    .maybeSingle();
  if (targetError || !target) return NextResponse.json({ error: 'Staff account not found.' }, { status: 404 });
  if (target.role === 'system_admin') {
    return NextResponse.json({ error: 'System administrator accounts require an offline recovery process.' }, { status: 409 });
  }

  const { error: authError } = await context.admin.auth.admin.updateUserById(input.id, {
    ban_duration: input.active ? 'none' : '876600h',
  });
  if (authError) return NextResponse.json({ error: 'Unable to update staff authentication.' }, { status: 502 });

  const { error: updateError } = await context.admin
    .from('user_profiles')
    .update({ active: input.active })
    .eq('id', input.id);
  if (updateError) {
    await context.admin.auth.admin.updateUserById(input.id, {
      ban_duration: input.active ? '876600h' : 'none',
    });
    return NextResponse.json({ error: 'Unable to update staff status.' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
