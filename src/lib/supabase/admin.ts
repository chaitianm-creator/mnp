import { createClient as createSupabaseClient } from '@supabase/supabase-js';

/**
 * service roleクライアント。RLSをバイパスするため、
 * サーバー側のRoute Handler内でのみ使用し、権限チェックを必ず先に行うこと。
 */
export function createAdminClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
