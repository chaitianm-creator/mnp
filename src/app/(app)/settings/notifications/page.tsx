'use client';

import { useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Card, CardTitle } from '@/components/ui/card';
import { Switch, Alert } from '@/components/ui/misc';
import { requestNotificationPermission } from '@/lib/notify';
import { Button } from '@/components/ui/button';

interface Settings {
  browser_reservation: boolean;
  email_reservation: boolean;
  email_weekly_summary: boolean;
  sound_enabled: boolean;
}

export default function NotificationSettingsPage() {
  const supabase = useMemo(() => createClient(), []);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [permission, setPermission] = useState<string>('default');

  useEffect(() => {
    void supabase
      .from('notification_settings')
      .select('*')
      .single()
      .then(({ data }) => data && setSettings(data));
    if (typeof Notification !== 'undefined') setPermission(Notification.permission);
  }, [supabase]);

  const update = async (patch: Partial<Settings>) => {
    if (!settings) return;
    const next = { ...settings, ...patch };
    setSettings(next);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    await supabase.from('notification_settings').update(patch).eq('user_id', user!.id);
  };

  if (!settings) return <p className="py-10 text-center text-sm text-brand-500">読み込み中…</p>;

  const rows: Array<{ key: keyof Settings; title: string; desc: string }> = [
    {
      key: 'browser_reservation',
      title: '予約のブラウザ通知',
      desc: '予約時刻が近づいたら、ブラウザ通知でお知らせします(このサイトを開いている間)。',
    },
    {
      key: 'email_reservation',
      title: '予約のメール通知',
      desc: '予約開始前にメールでお知らせします(メール配信の設定が有効な環境のみ)。',
    },
    {
      key: 'email_weekly_summary',
      title: '週間サマリーメール',
      desc: '1週間の学習のまとめを週明けにお届けします。',
    },
    {
      key: 'sound_enabled',
      title: '開始・終了の通知音',
      desc: '集中タイムの開始時・終了時にやわらかいチャイムを鳴らします。',
    },
  ];

  return (
    <div className="space-y-6">
      {permission === 'denied' && (
        <Alert tone="warning">
          ブラウザの通知がブロックされています。アドレスバーのサイト設定から通知を許可してください。
        </Alert>
      )}
      {permission === 'default' && (
        <Alert tone="info" className="flex items-center justify-between gap-3">
          <span>ブラウザ通知を使うには許可が必要です。</span>
          <Button
            size="sm"
            variant="outline"
            onClick={async () => {
              await requestNotificationPermission();
              if (typeof Notification !== 'undefined') setPermission(Notification.permission);
            }}
          >
            許可する
          </Button>
        </Alert>
      )}
      <Card>
        <CardTitle>通知設定</CardTitle>
        <ul className="divide-y divide-brand-100 dark:divide-brand-800">
          {rows.map((r) => (
            <li key={r.key} className="flex items-center justify-between gap-4 py-4">
              <div>
                <p className="font-medium">{r.title}</p>
                <p className="text-sm text-brand-500">{r.desc}</p>
              </div>
              <Switch
                checked={settings[r.key]}
                onChange={(v) => update({ [r.key]: v } as Partial<Settings>)}
                label={r.title}
              />
            </li>
          ))}
        </ul>
      </Card>
      <p className="text-xs text-brand-500">
        LINE通知は正式版で対応予定です。応援者への通知は「応援者」タブで管理できます。
      </p>
    </div>
  );
}
