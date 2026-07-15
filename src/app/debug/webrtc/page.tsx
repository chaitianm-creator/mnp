import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { WebRTCDiagnostics } from './diagnostics';

export const metadata = { title: 'WebRTC診断' };
export const dynamic = 'force-dynamic';

/**
 * WebRTC診断ページ。
 * 開発環境、または管理者のみアクセス可能。
 * NEXT_PUBLIC_ENABLE_DIAGNOSTICS=1 で一般公開環境でも管理者に開放できる。
 */
export default async function WebRTCDebugPage() {
  const isDev = process.env.NODE_ENV === 'development';
  const enabled = isDev || process.env.NEXT_PUBLIC_ENABLE_DIAGNOSTICS === '1';

  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?next=/debug/webrtc');

  if (!isDev) {
    const { data: isAdmin } = await supabase.rpc('is_admin');
    if (!enabled || !isAdmin) redirect('/home');
  }

  return <WebRTCDiagnostics />;
}
