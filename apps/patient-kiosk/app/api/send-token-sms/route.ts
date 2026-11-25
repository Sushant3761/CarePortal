import { NextResponse } from 'next/server';

/**
 * SMS sending is disabled until the caller can be tied to an authenticated
 * staff action or a verified intake session and a shared rate limiter.
 * Keeping an anonymous provider relay here would permit cost abuse and PHI leaks.
 */
export async function POST() {
  return NextResponse.json(
    { success: false, error: 'SMS delivery is temporarily unavailable.' },
    { status: 503 }
  );
}
