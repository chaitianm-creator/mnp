import Link from 'next/link';
import { Play, Video, Users, Megaphone, ChevronRight, CalendarClock } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { Button } from '@/components/ui/button';
import { Card, CardTitle } from '@/components/ui/card';
import { Badge, Progress, Alert } from '@/components/ui/misc';
import { TomoshibiMessage } from '@/components/tomoshibi';
import {
  dailyMinutes,
  sumWeekMinutes,
  completedCount,
  weekDateKeys,
  localDateKey,
  formatMinutes,
  type SessionRow,
} from '@/lib/history';

export const metadata = { title: 'ホーム' };
export const dynamic = 'force-dynamic';

export default async function HomePage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // 欠席記録+繰り返し予約の実体化(副作用RPC)
  await supabase.rpc('sync_reservations');

  const [profileRes, sessionsRes, goalsRes, statsRes, reservationRes, announcementsRes, studyingRes] =
    await Promise.all([
      supabase.from('profiles').select('display_name, timezone').eq('id', user!.id).single(),
      supabase
        .from('study_sessions')
        .select('id, topic, planned_minutes, started_at, ended_at, attended_seconds, status, rating, is_trial')
        .gte('started_at', new Date(Date.now() - 90 * 86400000).toISOString())
        .order('started_at', { ascending: false })
        .limit(500),
      supabase.from('study_goals').select('*').single(),
      supabase.from('user_stats').select('*').single(),
      supabase
        .from('reservations')
        .select('id, starts_at, duration_minutes, topic')
        .eq('status', 'scheduled')
        .gte('starts_at', new Date(Date.now() - 10 * 60000).toISOString())
        .order('starts_at', { ascending: true })
        .limit(1),
      supabase
        .from('announcements')
        .select('id, title, body, published_at')
        .eq('is_published', true)
        .order('published_at', { ascending: false })
        .limit(3),
      supabase.rpc('current_studying_count'),
    ]);

  const tz = profileRes.data?.timezone ?? 'Asia/Tokyo';
  const sessions = (sessionsRes.data ?? []) as SessionRow[];
  const now = new Date();
  const todayKey = localDateKey(now, tz);
  const daily = dailyMinutes(sessions, tz);
  const todayMinutes = daily.get(todayKey) ?? 0;
  const weekMinutes = sumWeekMinutes(sessions, now, tz);
  const weekKeys = new Set(weekDateKeys(now, tz));
  const weekSlots = completedCount(sessions, weekKeys, tz);
  const streak = statsRes.data?.current_streak ?? 0;
  const dailyGoal = goalsRes.data?.daily_minutes_goal ?? 0;
  const studyingNow = (studyingRes.data as number | null) ?? 0;
  const nextReservation = reservationRes.data?.[0];
  const reservationSoon =
    nextReservation && new Date(nextReservation.starts_at).getTime() - now.getTime() < 15 * 60000;

  const fmtDate = new Intl.DateTimeFormat('ja-JP', {
    timeZone: tz,
    month: 'numeric',
    day: 'numeric',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });

  const hour = parseInt(
    new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', hour12: false }).format(now),
    10
  );
  const greeting =
    hour < 4 ? 'こんばんは' : hour < 11 ? 'おはようございます' : hour < 18 ? 'こんにちは' : 'こんばんは';

  return (
    <div className="space-y-6">
      <TomoshibiMessage
        glow
        message={`${greeting}、${profileRes.data?.display_name ?? ''}さん。${
          todayMinutes > 0 ? `今日はもう${formatMinutes(todayMinutes)}がんばりましたね。` : '今日も一緒に始めましょう。'
        }`}
      />

      {reservationSoon && nextReservation && (
        <Alert tone="warning" className="flex flex-wrap items-center justify-between gap-3">
          <span className="font-medium">
            まもなく予約の時間です: {fmtDate.format(new Date(nextReservation.starts_at))}「
            {nextReservation.topic || '学習'}」
          </span>
          <Link
            href={`/prejoin?topic=${encodeURIComponent(nextReservation.topic ?? '')}&duration=${nextReservation.duration_minutes}`}
          >
            <Button variant="lantern" size="sm">
              予約から入室する
            </Button>
          </Link>
        </Alert>
      )}

      {/* 最重要ボタン */}
      <div className="rounded-3xl bg-gradient-to-br from-brand-600 to-brand-800 p-6 text-white shadow-lg sm:p-8">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 className="text-xl font-bold sm:text-2xl">自習室はいつでも開いています</h1>
            <p className="mt-1 flex items-center gap-1.5 text-sm text-brand-100">
              <Users className="h-4 w-4" />
              いま {studyingNow} 人が自習中
            </p>
          </div>
          <Link href="/prejoin" className="w-full sm:w-auto">
            <Button variant="lantern" size="xl" className="w-full">
              <Play className="h-6 w-6" />
              今すぐ入室
            </Button>
          </Link>
        </div>
      </div>

      {/* 統計 */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Card>
          <CardTitle>本日の集中時間</CardTitle>
          <p className="text-2xl font-bold">{formatMinutes(todayMinutes)}</p>
          {dailyGoal > 0 && (
            <div className="mt-2">
              <Progress value={todayMinutes / dailyGoal} />
              <p className="mt-1 text-xs text-brand-500">
                今日の目標 {formatMinutes(dailyGoal)} ・ 達成率 {Math.min(100, Math.round((todayMinutes / dailyGoal) * 100))}%
              </p>
            </div>
          )}
        </Card>
        <Card>
          <CardTitle>今週の集中時間</CardTitle>
          <p className="text-2xl font-bold">{formatMinutes(weekMinutes)}</p>
        </Card>
        <Card>
          <CardTitle>今週の完了コマ</CardTitle>
          <p className="text-2xl font-bold">
            {weekSlots}
            <span className="ml-1 text-sm font-normal">コマ</span>
          </p>
        </Card>
        <Card>
          <CardTitle>連続利用日数</CardTitle>
          <p className="text-2xl font-bold">
            {streak}
            <span className="ml-1 text-sm font-normal">日</span>
          </p>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* 次回予約 */}
        <Card>
          <CardTitle className="flex items-center gap-2">
            <CalendarClock className="h-4 w-4" /> 次回の予約
          </CardTitle>
          {nextReservation ? (
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="font-bold">{fmtDate.format(new Date(nextReservation.starts_at))}</p>
                <p className="text-sm text-brand-600 dark:text-brand-300">
                  {nextReservation.topic || '学習'}({nextReservation.duration_minutes}分)
                </p>
              </div>
              <Link href="/reservations">
                <Button variant="outline" size="sm">
                  予約一覧
                </Button>
              </Link>
            </div>
          ) : (
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm text-brand-600 dark:text-brand-300">
                予約はまだありません。先に予定を決めると始めやすくなります。
              </p>
              <Link href="/reservations/new">
                <Button variant="secondary" size="sm">
                  予約する
                </Button>
              </Link>
            </div>
          )}
        </Card>

        {/* カメラテスト */}
        <Card>
          <CardTitle className="flex items-center gap-2">
            <Video className="h-4 w-4" /> カメラの動作確認
          </CardTitle>
          <div className="flex items-center justify-between gap-3">
            <p className="text-sm text-brand-600 dark:text-brand-300">
              入室前にぼかしの見え方とカメラの位置を確認できます。
            </p>
            <Link href="/camera-test">
              <Button variant="outline" size="sm">
                カメラテスト
              </Button>
            </Link>
          </div>
        </Card>
      </div>

      {/* 最近の学習履歴 */}
      <Card>
        <div className="mb-3 flex items-center justify-between">
          <CardTitle className="mb-0">最近の学習</CardTitle>
          <Link
            href="/history"
            className="flex items-center text-sm text-brand-600 hover:underline dark:text-brand-300"
          >
            すべて見る <ChevronRight className="h-4 w-4" />
          </Link>
        </div>
        {sessions.filter((s) => !s.is_trial).length === 0 ? (
          <p className="py-6 text-center text-sm text-brand-500">
            まだ記録がありません。最初の1コマを始めてみましょう。
          </p>
        ) : (
          <ul className="divide-y divide-brand-100 dark:divide-brand-800">
            {sessions
              .filter((s) => !s.is_trial)
              .slice(0, 5)
              .map((s) => (
                <li key={s.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                  <div className="min-w-0">
                    <p className="truncate font-medium">{s.topic || '学習'}</p>
                    <p className="text-xs text-brand-500">
                      {fmtDate.format(new Date(s.started_at))} ・ {Math.floor(s.attended_seconds / 60)}分
                    </p>
                  </div>
                  <Badge tone={s.status === 'completed' ? 'brand' : 'gray'}>
                    {s.status === 'completed' ? '完了' : s.status === 'left_early' ? '途中退出' : '中断'}
                  </Badge>
                </li>
              ))}
          </ul>
        )}
      </Card>

      {/* お知らせ */}
      {(announcementsRes.data?.length ?? 0) > 0 && (
        <Card>
          <CardTitle className="flex items-center gap-2">
            <Megaphone className="h-4 w-4" /> お知らせ
          </CardTitle>
          <ul className="space-y-3">
            {announcementsRes.data!.map((a) => (
              <li key={a.id}>
                <p className="font-medium">{a.title}</p>
                <p className="mt-0.5 whitespace-pre-wrap text-sm text-brand-600 dark:text-brand-300">
                  {a.body}
                </p>
              </li>
            ))}
          </ul>
        </Card>
      )}
    </div>
  );
}
