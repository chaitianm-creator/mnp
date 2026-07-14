'use client';

import { useEffect, useMemo, useState } from 'react';
import { Check } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardTitle } from '@/components/ui/card';
import { Alert, Badge } from '@/components/ui/misc';

const freeFeatures = ['1日2コマまで', '基本の自習室', '基本の学習履歴', '予約3件まで'];
const premiumFeatures = [
  'コマ数無制限',
  '詳細な学習分析',
  '毎週の繰り返し予約',
  '応援者への自動通知',
  '追加の習慣化機能',
];

export default function PlanPage() {
  const supabase = useMemo(() => createClient(), []);
  const [plan, setPlan] = useState<'free' | 'premium'>('free');
  const [periodEnd, setPeriodEnd] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void supabase
      .from('subscriptions')
      .select('plan, current_period_end')
      .single()
      .then(({ data }) => {
        if (data) {
          setPlan(data.plan as 'free' | 'premium');
          setPeriodEnd(data.current_period_end);
        }
      });
  }, [supabase]);

  const go = async (endpoint: 'checkout' | 'portal') => {
    setBusy(true);
    setError('');
    const res = await fetch(`/api/stripe/${endpoint}`, { method: 'POST' });
    const body = await res.json().catch(() => ({}));
    if (res.ok && body.url) {
      location.href = body.url;
      return;
    }
    setError(
      body.error === 'stripe_not_configured'
        ? '決済機能は現在準備中です(Stripeキーが未設定の環境です)。'
        : '処理に失敗しました。時間をおいてお試しください。'
    );
    setBusy(false);
  };

  return (
    <div className="space-y-6">
      {error && <Alert tone="warning">{error}</Alert>}
      <div className="grid gap-4 sm:grid-cols-2">
        <Card className={plan === 'free' ? 'ring-2 ring-brand-400' : ''}>
          <div className="flex items-center justify-between">
            <CardTitle className="mb-0">無料プラン</CardTitle>
            {plan === 'free' && <Badge tone="brand">現在のプラン</Badge>}
          </div>
          <p className="mt-2 text-2xl font-bold">
            ¥0<span className="text-sm font-normal">/月</span>
          </p>
          <ul className="mt-4 space-y-2 text-sm">
            {freeFeatures.map((f) => (
              <li key={f} className="flex items-center gap-2">
                <Check className="h-4 w-4 text-brand-400" /> {f}
              </li>
            ))}
          </ul>
        </Card>
        <Card className={plan === 'premium' ? 'ring-2 ring-lantern-400' : ''}>
          <div className="flex items-center justify-between">
            <CardTitle className="mb-0">プレミアム</CardTitle>
            {plan === 'premium' && <Badge tone="lantern">現在のプラン</Badge>}
          </div>
          <p className="mt-2 text-2xl font-bold">
            ¥980<span className="text-sm font-normal">/月(税込)</span>
          </p>
          <ul className="mt-4 space-y-2 text-sm">
            {premiumFeatures.map((f) => (
              <li key={f} className="flex items-center gap-2">
                <Check className="h-4 w-4 text-lantern-500" /> {f}
              </li>
            ))}
          </ul>
          <div className="mt-5">
            {plan === 'premium' ? (
              <>
                {periodEnd && (
                  <p className="mb-2 text-xs text-brand-500">
                    次回更新: {new Date(periodEnd).toLocaleDateString('ja-JP')}
                  </p>
                )}
                <Button variant="outline" className="w-full" onClick={() => go('portal')} disabled={busy}>
                  支払い管理・解約(Stripe)
                </Button>
              </>
            ) : (
              <Button variant="lantern" className="w-full" onClick={() => go('checkout')} disabled={busy}>
                {busy ? '処理中…' : 'プレミアムにアップグレード'}
              </Button>
            )}
          </div>
        </Card>
      </div>
      <p className="text-xs text-brand-500">
        決済はStripeの安全なページで行われます。カード情報が当サービスのサーバーに保存されることはありません。
      </p>
    </div>
  );
}
