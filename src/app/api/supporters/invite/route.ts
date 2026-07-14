import { NextResponse } from 'next/server';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';
import { sendEmail } from '@/lib/email';
import { emailSchema } from '@/lib/validation';

const bodySchema = z.object({
  email: emailSchema,
  name: z.string().trim().max(50).optional().default(''),
});

export async function POST(request: Request) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const parsed = bodySchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid_email' }, { status: 400 });
  }

  // レート制限・重複はRPC側で検証される
  const { data, error } = await supabase.rpc('invite_supporter', {
    p_email: parsed.data.email,
    p_name: parsed.data.name,
  });
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 400 });
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name')
    .eq('id', user.id)
    .single();

  const token = (data as { invite_token: string }).invite_token;
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000';
  const inviteUrl = `${appUrl}/supporters/consent/${token}`;

  const emailSent = await sendEmail({
    to: parsed.data.email,
    subject: `【MokuTomo】${profile?.display_name ?? 'ユーザー'}さんの学習を応援しませんか?`,
    text: [
      `${parsed.data.name || 'こんにちは'} 様`,
      '',
      `${profile?.display_name ?? 'ユーザー'}さんが、オンライン自習室MokuTomoでの学習状況をあなたに共有したいと希望しています。`,
      '同意いただくと、学習の開始・完了・週間レポートがメールで届きます(映像は共有されません)。',
      '',
      '同意する場合は、次のリンクを開いてください:',
      inviteUrl,
      '',
      '心当たりがない場合は、このメールを無視してください。',
    ].join('\n'),
  });

  return NextResponse.json({ ok: true, emailSent, inviteUrl });
}
