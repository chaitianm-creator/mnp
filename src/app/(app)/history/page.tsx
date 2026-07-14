import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { Card, CardTitle } from '@/components/ui/card';
import { Badge, Progress } from '@/components/ui/misc';
import { BarChart, CalendarHeatmap } from '@/components/charts';
import { Button } from '@/components/ui/button';
import {
  dailyMinutes,
  weekDateKeys,
  sumWeekMinutes,
  completedCount,
  leftEarlyCount,
  weekdayTrend,
  hourBandTrend,
  formatMinutes,
  localDateKey,
  type SessionRow,
} from '@/lib/history';
import { WEEKDAYS_JA } from '@/lib/constants';

export const metadata = { title: '学習履歴' };
export const dynamic = 'force-dynamic';

export default async function HistoryPage() {
  const supabase = createClient();
  const [{ data: profile }, { data: stats }, { data: goals }, { data: sessionsData }] =
    await Promise.all([
      supabase.from('profiles').select('timezone').single(),
      supabase.from('user_stats').select('*').single(),
      supabase.from('study_goals').select('*').single(),
      supabase
        .from('study_sessions')
        .select(
          'id, topic, planned_minutes, started_at, ended_at, attended_seconds, status, rating, is_trial, memo'
        )
        .gte('started_at', new Date(Date.now() - 190 * 86400000).toISOString())
        .order('started_at', { ascending: false })
        .limit(1000),
    ]);

  const tz = profile?.timezone ?? 'Asia/Tokyo';
  const sessions = (sessionsData ?? []) as (SessionRow & { memo?: string | null })[];
  const real = sessions.filter((s) => !s.is_trial);
  const now = new Date();
  const daily = dailyMinutes(real, tz);

  // 日別 (直近14日)
  const daily14 = Array.from({ length: 14 }, (_, i) => {
    const d = new Date(now.getTime() - (13 - i) * 86400000);
    const key = localDateKey(d, tz);
    return { label: key.slice(5).replace('-', '/'), value: daily.get(key) ?? 0 };
  });

  // 週別 (直近8週: 各週の月曜起点)
  const weekly8 = Array.from({ length: 8 }, (_, i) => {
    const ref = new Date(now.getTime() - (7 - i) * 7 * 86400000);
    const keys = weekDateKeys(ref, tz);
    const total = keys.reduce((acc, k) => acc + (daily.get(k) ?? 0), 0);
    return { label: keys[0].slice(5).replace('-', '/') + '〜', value: total };
  });

  // 月別 (直近6か月)
  const monthly6 = Array.from({ length: 6 }, (_, i) => {
    const d = new Date(now);
    d.setMonth(d.getMonth() - (5 - i));
    const prefix = localDateKey(d, tz).slice(0, 7);
    let total = 0;
    daily.forEach((v, k) => {
      if (k.startsWith(prefix)) total += v;
    });
    return { label: `${parseInt(prefix.slice(5), 10)}月`, value: total };
  });

  const todayKey = localDateKey(now, tz);
  const [y, m] = todayKey.split('-').map((v) => parseInt(v, 10));

  const weekMinutes = sumWeekMinutes(real, now, tz);
  const monthPrefix = todayKey.slice(0, 7);
  let monthMinutes = 0;
  daily.forEach((v, k) => {
    if (k.startsWith(monthPrefix)) monthMinutes += v;
  });

  const byWeekday = weekdayTrend(real, tz);
  const byHourBand = hourBandTrend(real, tz);
  const hourLabels = ['0-4時', '4-8時', '8-12時', '12-16時', '16-20時', '20-24時'];

  const weeklyGoal = goals?.weekly_minutes_goal ?? 0;
  const monthlyGoal = goals?.monthly_minutes_goal ?? 0;

  const hasData = real.length > 0;

  const fmtDate = new Intl.DateTimeFormat('ja-JP', {
    timeZone: tz,
    month: 'numeric',
    day: 'numeric',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">学習履歴</h1>
        <Link href="/goals">
          <Button variant="outline" size="sm">
            目標を設定
          </Button>
        </Link>
      </div>

      {!hasData && (
        <Card className="py-10 text-center">
          <p className="text-lg font-bold">まだ記録がありません</p>
          <p className="mt-2 text-sm text-brand-600 dark:text-brand-300">
            最初の1コマを終えると、ここに集中時間やグラフが表示されます。
            まずは25分、始めてみましょう。
          </p>
          <Link href="/prejoin" className="mt-4 inline-block">
            <Button variant="lantern" size="lg">
              今すぐ入室
            </Button>
          </Link>
        </Card>
      )}

      {hasData && (
        <>
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <Card>
              <CardTitle>累計集中時間</CardTitle>
              <p className="text-2xl font-bold">{formatMinutes(stats?.total_focus_minutes ?? 0)}</p>
            </Card>
            <Card>
              <CardTitle>完了コマ数</CardTitle>
              <p className="text-2xl font-bold">{stats?.total_completed_sessions ?? 0}</p>
            </Card>
            <Card>
              <CardTitle>途中退出</CardTitle>
              <p className="text-2xl font-bold">{leftEarlyCount(real)}</p>
            </Card>
            <Card>
              <CardTitle>連続日数(最長)</CardTitle>
              <p className="text-2xl font-bold">
                {stats?.current_streak ?? 0}
                <span className="text-sm font-normal">日({stats?.longest_streak ?? 0}日)</span>
              </p>
            </Card>
          </div>

          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardTitle>今週の目標達成率</CardTitle>
              <p className="mb-2 text-sm">
                {formatMinutes(weekMinutes)} / {formatMinutes(weeklyGoal)}
              </p>
              <Progress value={weeklyGoal > 0 ? weekMinutes / weeklyGoal : 0} />
            </Card>
            <Card>
              <CardTitle>今月の目標達成率</CardTitle>
              <p className="mb-2 text-sm">
                {formatMinutes(monthMinutes)} / {formatMinutes(monthlyGoal)}
              </p>
              <Progress value={monthlyGoal > 0 ? monthMinutes / monthlyGoal : 0} />
            </Card>
          </div>

          <Card>
            <CardTitle>日別の集中時間(直近14日)</CardTitle>
            <BarChart data={daily14} />
          </Card>

          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardTitle>週別の集中時間(直近8週)</CardTitle>
              <BarChart data={weekly8} />
            </Card>
            <Card>
              <CardTitle>月別の集中時間(直近6か月)</CardTitle>
              <BarChart data={monthly6} />
            </Card>
          </div>

          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardTitle>今月のカレンダー</CardTitle>
              <CalendarHeatmap year={y} month={m} values={daily} />
            </Card>
            <div className="space-y-6">
              <Card>
                <CardTitle>曜日別の傾向</CardTitle>
                <BarChart data={byWeekday.map((v, i) => ({ label: WEEKDAYS_JA[i], value: v }))} />
              </Card>
              <Card>
                <CardTitle>時間帯別の傾向</CardTitle>
                <BarChart data={byHourBand.map((v, i) => ({ label: hourLabels[i], value: v }))} />
              </Card>
            </div>
          </div>

          <Card>
            <CardTitle>学習内容の履歴</CardTitle>
            <ul className="divide-y divide-brand-100 dark:divide-brand-800">
              {real.slice(0, 30).map((s) => (
                <li key={s.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                  <div className="min-w-0">
                    <p className="truncate font-medium">{s.topic || '学習'}</p>
                    <p className="text-xs text-brand-500">
                      {fmtDate.format(new Date(s.started_at))} ・ {Math.floor(s.attended_seconds / 60)}分
                      {s.memo ? ` ・ ${s.memo}` : ''}
                    </p>
                  </div>
                  <Badge tone={s.status === 'completed' ? 'brand' : 'gray'}>
                    {s.status === 'completed' ? '完了' : s.status === 'left_early' ? '途中退出' : '中断'}
                  </Badge>
                </li>
              ))}
            </ul>
          </Card>
        </>
      )}
    </div>
  );
}
