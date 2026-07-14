import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

/** メール確認・パスワード再設定リンクからのコールバック */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const nextParam = searchParams.get('next') ?? '/home';
  const next = nextParam.startsWith('/') ? nextParam : '/home';

  if (code) {
    const supabase = createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }
  return NextResponse.redirect(`${origin}/auth/login?error=link_invalid`);
}
