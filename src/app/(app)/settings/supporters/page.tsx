'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardTitle } from '@/components/ui/card';
import { Input, Label } from '@/components/ui/input';
import { Alert, Badge } from '@/components/ui/misc';
import { rpcErrorToMessage } from '@/lib/constants';

interface Supporter {
  id: string;
  supporter_email: string;
  supporter_name: string;
  status: 'pending' | 'accepted' | 'stopped';
  consented_at: string | null;
}

export default function SupportersPage() {
  const supabase = useMemo(() => createClient(), []);
  const [supporters, setSupporters] = useState<Supporter[]>([]);
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [message, setMessage] = useState<{ tone: 'success' | 'error'; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [isPremium, setIsPremium] = useState(false);

  const load = useCallback(async () => {
    const { data } = await supabase
      .from('supporters')
      .select('id, supporter_email, supporter_name, status, consented_at')
      .order('created_at', { ascending: false });
    setSupporters((data ?? []) as Supporter[]);
    const { data: sub } = await supabase.from('subscriptions').select('plan').single();
    setIsPremium(sub?.plan === 'premium');
  }, [supabase]);

  useEffect(() => {
    void load();
  }, [load]);

  const invite = async () => {
    setBusy(true);
    setMessage(null);
    const res = await fetch('/api/supporters/invite', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: email.trim(), name: name.trim() }),
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      setMessage({
        tone: 'error',
        text: rpcErrorToMessage({ message: body.error ?? '' }),
      });
    } else {
      setMessage({
        tone: 'success',
        text: body.emailSent
          ? '招待メールを送信しました。相手が同意すると通知が始まります。'
          : '招待を登録しました(メール配信が未設定のため、招待リンクを直接お伝えください: ' +
            body.inviteUrl +
            ')',
      });
      setEmail('');
      setName('');
      void load();
    }
    setBusy(false);
  };

  const stop = async (id: string, mode: 'stop' | 'delete') => {
    if (mode === 'delete' && !confirm('この応援者を削除しますか?')) return;
    if (mode === 'delete') {
      await supabase.from('supporters').delete().eq('id', id);
    } else {
      await supabase.from('supporters').update({ status: 'stopped' }).eq('id', id);
    }
    void load();
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardTitle>応援・見守り通知とは</CardTitle>
        <p className="text-sm leading-relaxed text-brand-600 dark:text-brand-300">
          あなたが希望した相手(家族・友人など)にだけ、学習の開始・完了・週間レポートをメールでお知らせできます。
          <strong>映像が共有されることはありません。</strong>
          相手がメールで同意した場合のみ通知が始まり、いつでも停止・削除できます。
        </p>
        {!isPremium && (
          <Alert tone="info" className="mt-3">
            通知の自動送信はプレミアムプランの機能です。無料プランでも応援者の登録・招待はお試しいただけます。
          </Alert>
        )}
      </Card>

      <Card className="space-y-4">
        <CardTitle>応援者を招待</CardTitle>
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <Label htmlFor="sup-name">お名前(任意)</Label>
            <Input id="sup-name" value={name} onChange={(e) => setName(e.target.value)} maxLength={50} />
          </div>
          <div>
            <Label htmlFor="sup-email">メールアドレス</Label>
            <Input
              id="sup-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
        </div>
        {message && <Alert tone={message.tone}>{message.text}</Alert>}
        <Button onClick={invite} disabled={busy || !email.trim()}>
          {busy ? '送信中…' : '招待を送る'}
        </Button>
      </Card>

      <Card>
        <CardTitle>登録済みの応援者</CardTitle>
        {supporters.length === 0 ? (
          <p className="py-4 text-center text-sm text-brand-500">まだ応援者はいません。</p>
        ) : (
          <ul className="divide-y divide-brand-100 dark:divide-brand-800">
            {supporters.map((s) => (
              <li key={s.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
                <div>
                  <p className="font-medium">{s.supporter_name || s.supporter_email}</p>
                  <p className="text-xs text-brand-500">{s.supporter_email}</p>
                </div>
                <div className="flex items-center gap-2">
                  <Badge tone={s.status === 'accepted' ? 'brand' : s.status === 'pending' ? 'lantern' : 'gray'}>
                    {s.status === 'accepted' ? '同意済み' : s.status === 'pending' ? '同意待ち' : '停止中'}
                  </Badge>
                  {s.status !== 'stopped' && (
                    <Button variant="outline" size="sm" onClick={() => stop(s.id, 'stop')}>
                      共有停止
                    </Button>
                  )}
                  <Button variant="ghost" size="sm" onClick={() => stop(s.id, 'delete')}>
                    削除
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
