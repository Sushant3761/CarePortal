import { createHmac } from 'node:crypto';
import type { NextRequest } from 'next/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

export function getClientAddress(request: NextRequest): string | null {
  // Configure the deployment proxy to overwrite x-real-ip. Never accept arbitrary
  // client-supplied forwarding headers when the app can be reached directly.
  return request.headers.get('x-real-ip')?.trim() || null;
}

export async function consumeRateLimit(bucket: string, limit: number, windowSeconds: number) {
  try {
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) return { allowed: false, retryAfterSeconds: null };
    const bucketHash = createHmac('sha256', key).update(bucket).digest('hex');
    const supabase = createSupabaseAdminClient();
    const { data, error } = await supabase.rpc('consume_api_rate_limit', {
      p_bucket_hash: bucketHash,
      p_max_requests: limit,
      p_window_seconds: windowSeconds,
    });

    if (error || !Array.isArray(data) || !data[0]) {
      return { allowed: false, retryAfterSeconds: null };
    }
    return {
      allowed: data[0].allowed === true,
      retryAfterSeconds: Number(data[0].retry_after_seconds) || 1,
    };
  } catch {
    // The API denies work if shared limiter configuration is unavailable.
    return { allowed: false, retryAfterSeconds: null };
  }
}
