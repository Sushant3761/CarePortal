import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { consumeRateLimit, getClientAddress } from '@/lib/rateLimit';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { phone, code } = body || {};

    if (
      typeof phone !== 'string' ||
      !/^(?:\+91)?[6-9]\d{9}$/.test(phone.trim()) ||
      typeof code !== 'string' ||
      !/^\d{6}$/.test(code.trim())
    ) {
      return NextResponse.json(
        { success: false, error: 'Phone number and verification code are required' },
        { status: 400 }
      );
    }

    const normalizedPhone = phone.trim().replace(/^\+91/, '');
    const address = getClientAddress(req);
    if (!address) {
      return NextResponse.json({ success: false, error: 'Verification service is unavailable.' }, { status: 503 });
    }
    const limits = await Promise.all([
      consumeRateLimit('otp-verify:phone:' + normalizedPhone, 8, 900),
      consumeRateLimit('otp-verify:ip:' + address, 30, 900),
    ]);
    if (limits.some((limit) => !limit.allowed)) {
      const retryAfter = Math.max(...limits.map((limit) => limit.retryAfterSeconds || 1));
      return NextResponse.json(
        { success: false, error: 'Unable to verify the code right now. Please try again later.' },
        { status: limits.some((limit) => limit.retryAfterSeconds === null) ? 503 : 429, headers: { 'Retry-After': String(retryAfter) } }
      );
    }

    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anonKey) {
      return NextResponse.json({ success: false, error: 'Phone verification is unavailable.' }, { status: 503 });
    }
    const supabase = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await supabase.auth.verifyOtp({ phone: `+91${normalizedPhone}`, token: code.trim(), type: 'sms' });
    if (error || !data.session) {
      return NextResponse.json(
        { success: false, error: 'Invalid or expired verification code.' },
        { status: 400 }
      );
    }

    return NextResponse.json(
      {
        success: true,
        verified: true,
        session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token },
        message: 'Phone number verified successfully'
      },
      { status: 200 }
    );
  } catch {
    return NextResponse.json(
      { success: false, error: 'Unable to verify the code right now. Please try again later.' },
      { status: 400 }
    );
  }
}
