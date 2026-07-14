import { createClient } from '@/lib/supabase/server';
import { Card, CardTitle } from '@/components/ui/card';
import { BarChart } from '@/components/charts';

export const metadata = { title: '管理者ダッシュボード' };
export const dynamic = 'force-dynamic';

interface AdminStats {
  total_users: number;
  dau_today: number;
  mau: number;
  total_focus_minutes: number;
  completed_sessions: number;
  studying_now: number;
  open_reports: number;
  active_rooms: number;
  daily_users_14d: Array<{ day: string; users: number }>;
}

export default async function AdminDashboardPage() {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_stats');
  const stats = data as AdminStats | null;

  const [{ data: auditLogs }] = await Promise.all([
    supabase
      .from('admin_audit_logs')
      .select('id, action, target_type, target_id, detail, created_at')
      .order('created_at', { ascending: false })
      .limit(10),
  ]);

  if (error || !stats) {
    return <p className="py-10 text-center text-sm text-red-600">集計の取得に失敗しました。</p>;
  }

  const cards = [
    { label: '総ユーザー数', value: stats.total_users },
    { label: '本日の利用者', value: stats.dau_today },
    { label: '月間アクティブ (30日)', value: stats.mau },
    { label: 'いま自習中', value: stats.studying_now },
    { label: '総集中時間', value: `${Math.floor(stats.total_focus_minutes / 60)}時間` },
    { label: '完了セッション数', value: stats.completed_sessions },
    { label: '稼働中ルーム', value: stats.active_rooms },
    { label: '未対応の通報', value: stats.open_reports },
  ];

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-bold">利用状況</h1>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {cards.map((c) => (
          <Card key={c.label}>
            <CardTitle>{c.label}</CardTitle>
            <p className="text-2xl font-bold">{c.value}</p>
          </Card>
        ))}
      </div>

      <Card>
        <CardTitle>日別利用者数(直近14日)</CardTitle>
        <BarChart
          data={(stats.daily_users_14d ?? []).map((d) => ({
            label: d.day.slice(5).replace('-', '/'),
            value: d.users,
          }))}
          unit="人"
        />
      </Card>

      <Card>
        <CardTitle>最近の管理操作ログ</CardTitle>
        {(auditLogs?.length ?? 0) === 0 ? (
          <p className="py-4 text-center text-sm text-brand-500">操作ログはまだありません。</p>
        ) : (
          <ul className="divide-y divide-brand-100 text-sm dark:divide-brand-800">
            {auditLogs!.map((log) => (
              <li key={log.id} className="py-2.5">
                <span className="font-mono text-xs text-brand-500">
                  {new Date(log.created_at).toLocaleString('ja-JP')}
                </span>{' '}
                <span className="font-medium">{log.action}</span>{' '}
                <span className="text-brand-500">
                  {log.target_type}:{log.target_id?.slice(0, 8)}… {JSON.stringify(log.detail)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <p className="text-xs text-brand-500">
        エラーログの確認: 本番環境ではSentry(設定済みDSN)およびVercelのログを参照してください。
        プライバシー保護のため、利用者のカメラ映像を閲覧・録画する機能は存在しません。
      </p>
    </div>
  );
}
