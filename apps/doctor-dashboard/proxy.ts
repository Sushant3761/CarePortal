import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { canAccessDashboardPath, isAdminRole, isClinicalRole } from '@/lib/authz';

const publicPaths = new Set(['/login']);

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const isApi = pathname.startsWith('/api/');

  if (publicPaths.has(pathname)) {
    return NextResponse.next();
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    if (isApi) {
      return NextResponse.json({ error: 'Authentication service is unavailable.' }, { status: 503 });
    }
    return NextResponse.redirect(new URL('/login?error=configuration', request.url));
  }

  let response = NextResponse.next({ request });
  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, {
            ...options,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'lax',
          });
        });
      },
    },
  });

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    if (isApi) return NextResponse.json({ error: 'Authentication required.' }, { status: 401 });
    return NextResponse.redirect(new URL('/login', request.url));
  }

  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('role, active, full_name')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError || !profile || profile.active !== true) {
    await supabase.auth.signOut();
    if (isApi) return NextResponse.json({ error: 'Account is not authorized.' }, { status: 403 });
    return NextResponse.redirect(new URL('/login?error=unauthorized', request.url));
  }

  const role = profile.role as string;
  if (!canAccessDashboardPath(role, pathname)) {
    if (isApi) return NextResponse.json({ error: 'Insufficient permissions.' }, { status: 403 });
    const fallback = isAdminRole(role)
      ? '/admin'
      : isClinicalRole(role)
        ? '/dashboard'
        : '/login?error=unauthorized';
    return NextResponse.redirect(new URL(fallback, request.url));
  }

  if (pathname === '/') {
    return NextResponse.redirect(new URL(isAdminRole(role) ? '/admin' : '/dashboard', request.url));
  }

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|css|js|mjs|map|woff|woff2|ttf|eot|ico|txt|xml|json)$).*)'],
};
