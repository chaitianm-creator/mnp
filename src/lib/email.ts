/**
 * メール送信 (Resend)。APIキー未設定の環境では送信せず false を返す
 * (開発環境でも他機能が動作するようフェイルソフトにする)。
 */
export async function sendEmail(opts: {
  to: string;
  subject: string;
  text: string;
}): Promise<boolean> {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.EMAIL_FROM;
  if (!apiKey || !from || apiKey === 're_xxx') return false;

  try {
    const { Resend } = await import('resend');
    const resend = new Resend(apiKey);
    const { error } = await resend.emails.send({
      from,
      to: opts.to,
      subject: opts.subject,
      text: opts.text,
    });
    return !error;
  } catch {
    return false;
  }
}
