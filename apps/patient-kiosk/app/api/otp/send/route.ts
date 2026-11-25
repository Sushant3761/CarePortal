import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { consumeRateLimit, getClientAddress } from '@/lib/rateLimit';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const phone = body?.phone;

    if (typeof phone !== 'string' || !/^(?:\+91)?[6-9]\d{9}$/.test(phone.trim())) {
      return NextResponse.json(
        { success: false, error: 'Please provide a valid 10-digit mobile number' },
        { status: 400 }
      );
    }

    const normalizedPhone = phone.trim().replace(/^\+91/, '');
    const address = getClientAddress(req);
    if (!address) {
      return NextResponse.json({ success: false, error: 'Verification service is unavailable.' }, { status: 503 });
    }
    const limits = await Promise.all([
      consumeRateLimit('otp-send:phone:' + normalizedPhone, 3, 900),
      consumeRateLimit('otp-send:ip:' + address, 12, 3600),
    ]);
    if (limits.some((limit) => !limit.allowed)) {
      const retryAfter = Math.max(...limits.map((limit) => limit.retryAfterSeconds || 1));
      return NextResponse.json(
        { success: false, error: 'Unable to send a verification code right now.' },
        { status: limits.some((limit) => limit.retryAfterSeconds === null) ? 503 : 429, headers: { 'Retry-After': String(retryAfter) } }
      );
    }

    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anonKey) {
      return NextResponse.json({ success: false, error: 'Phone verification is unavailable.' }, { status: 503 });
    }
    const supabase = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { error } = await supabase.auth.signInWithOtp({ phone: `+91${normalizedPhone}` });
    if (error) {
      return NextResponse.json({ success: false, error: 'Unable to send a verification code right now.' }, { status: 502 });
    }
    return NextResponse.json({ success: true, message: 'Verification code sent by SMS.' }, { status: 200 });
  } catch {
    return NextResponse.json(
      { success: false, error: 'Unable to send a verification code right now.' },
      { status: 400 }
    );
  }
}
