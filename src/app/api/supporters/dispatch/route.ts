import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { sendEmail } from '@/lib/email';

/**
 * 自分の応援者宛の未送信通知(キュー)を送信する。
 * セッション開始・完了時にクライアントからfire-and-forgetで呼ばれる。
 */
export async function POST() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name')
    .eq('id', user.id)
    .single();

  // 自分の応援者の未送信通知(RLSで自分の分のみ)
  const { data: pending } = await supabase
    .from('supporter_notifications')
    .select('id, type, payload, supporter_id')
    .is('sent_at', null)
    .eq('channel', 'email')
    .limit(20);

  if (!pending || pending.length === 0) return NextResponse.json({ sent: 0 });

  const supporterIds = Array.from(new Set(pending.map((n) => n.supporter_id)));
  const { data: supporterRows } = await supabase
    .from('supporters')
    .select('id, supporter_email, supporter_name, status, user_id')
    .in('id', supporterIds);
  const supporterMap = new Map((supporterRows ?? []).map((s) => [s.id, s]));

  const admin = createAdminClient();
  let sent = 0;

  for (const n of pending) {
    const supporter = supporterMap.get(n.supporter_id);
    if (!supporter || supporter.status !== 'accepted' || supporter.user_id !== user.id) continue;

    const payload = (n.payload ?? {}) as { minutes?: number; topic?: string };
    const name = profile?.display_name ?? 'ユーザー';
    const subject =
      n.type === 'session_start'
        ? `【MokuTomo】${name}さんが勉強を始めました`
        : `【MokuTomo】${name}さんが${payload.minutes ?? ''}分の集中を完了しました`;
    const text =
      n.type === 'session_start'
        ? `${name}さんが「${payload.topic || '学習'}」(${payload.minutes ?? ''}分)を始めました。そっと応援してあげてください。`
        : `${name}さんが「${payload.topic || '学習'}」の${payload.minutes ?? ''}分の集中を完了しました!`;

    const ok = await sendEmail({ to: supporter.supporter_email, subject, text });
    // メール未設定環境でも送信済み扱いにしてキューが溜まり続けないようにする
    await admin
      .from('supporter_notifications')
      .update({ sent_at: new Date().toISOString() })
      .eq('id', n.id);
    if (ok) sent++;
  }

  return NextResponse.json({ sent });
}
