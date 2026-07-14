'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { PartyPopper, ArrowRight } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardTitle } from '@/components/ui/card';
import { Alert, Badge } from '@/components/ui/misc';
import { Textarea } from '@/components/ui/input';
import { TomoshibiMessage } from '@/components/tomoshibi';
import { RATINGS } from '@/lib/constants';
import {
  dailyMinutes,
  sumWeekMinutes,
  localDateKey,
  formatMinutes,
  type SessionRow,
} from '@/lib/history';
import { cn } from '@/lib/utils';

interface FinishSummary {
  attended_seconds: number;
  xp_awarded: number;
  level: number;
  xp: number;
  current_streak: number;
  new_achievements: string[];
}

const END_MESSAGES = [
  'おつかれさまでした。ちゃんと机に向かえましたね。',
  'ここまでよく集中しました。少し休みましょう。',
  '今日の積み重ねが、明日のあなたを助けます。',
];

export default function SessionCompletePage() {
  const params = useParams<{ sessionId: string }>();
  const sessionId = params.sessionId;
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const [summary, setSummary] = useState<FinishSummary | null>(null);
  const [session, setSession] = useState<SessionRow & { memo?: string | null } | null>(null);
  const [todayMin, setTodayMin] = useState(0);
  const [weekMin, setWeekMin] = useState(0);
  const [completedTotal, setCompletedTotal] = useState(0);
  const [rating, setRating] = useState<string | null>(null);
  const [memo, setMemo] = useState('');
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [achievementNames, setAchievementNames] = useState<string[]>([]);
  const [message] = useState(() => END_MESSAGES[Math.floor(Math.random() * END_MESSAGES.length)]);
  const initRef = useRef(false);

  useEffect(() => {
    if (initRef.current) return;
    initRef.current = true;

    const init = async () => {
      // セッション完了処理 (サーバー側で時刻検証・XP付与。二重実行は拒否される)
      const { data: finishData, error: finishError } = await supabase.rpc('finish_session', {
        p_session_id: sessionId,
      });
      if (finishData) {
        setSummary(finishData as unknown as FinishSummary);
        // 応援者への完了通知(キュー済み)を送信 (fire-and-forget)
        void fetch('/api/supporters/dispatch', { method: 'POST' }).catch(() => {});
      } else if (finishError && !finishError.message.includes('session_already_finished')) {
        // 既に完了済み以外のエラー(途中退出済み等)はそのまま表示用データだけ読む
      }

      const { data: s } = await supabase
        .from('study_sessions')
        .select('id, topic, planned_minutes, started_at, ended_at, attended_seconds, status, rating, memo, is_trial')
        .eq('id', sessionId)
        .maybeSingle();
      if (!s) {
        router.replace('/home');
        return;
      }
      setSession(s as SessionRow & { memo?: string | null });
      if (s.rating) setRating(s.rating);
      if (s.memo) setMemo(s.memo);

      // 体験セッション完了時はオンボーディング完了をマーク
      if (s.is_trial) {
        const {
          data: { user },
        } = await supabase.auth.getUser();
        if (user) {
          await supabase
            .from('profiles')
            .update({ onboarding_completed_at: new Date().toISOString() })
            .eq('id', user.id)
            .is('onboarding_completed_at', null);
        }
      }

      const [{ data: profile }, { data: sessions }] = await Promise.all([
        supabase.from('profiles').select('timezone').single(),
        supabase
          .from('study_sessions')
          .select('id, topic, planned_minutes, started_at, ended_at, attended_seconds, status, rating, is_trial')
          .gte('started_at', new Date(Date.now() - 8 * 86400000).toISOString()),
      ]);
      const tz = profile?.timezone ?? 'Asia/Tokyo';
      const rows = (sessions ?? []) as SessionRow[];
      const now = new Date();
      setTodayMin(dailyMinutes(rows, tz).get(localDateKey(now, tz)) ?? 0);
      setWeekMin(sumWeekMinutes(rows, now, tz));
      const { data: stats } = await supabase
        .from('user_stats')
        .select('total_completed_sessions')
        .single();
      setCompletedTotal(stats?.total_completed_sessions ?? 0);

      const newIds = (finishData as unknown as FinishSummary | null)?.new_achievements ?? [];
      if (newIds.length > 0) {
        const { data: achievements } = await supabase
          .from('achievements')
          .select('id, name')
          .in('id', newIds);
        setAchievementNames((achievements ?? []).map((a) => a.name));
      }
    };
    void init();
  }, [supabase, sessionId, router]);

  const saveRating = async () => {
    setError('');
    const { error } = await supabase.rpc('rate_session', {
      p_session_id: sessionId,
      p_rating: rating,
      p_memo: memo,
    });
    if (error) {
      setError('保存に失敗しました。');
      return;
    }
    setSaved(true);
  };

  if (!session) {
    return <div className="flex min-h-dvh items-center justify-center">読み込み中…</div>;
  }

  const isCompleted = session.status === 'completed';
  const attendedMin = Math.floor(session.attended_seconds / 60);

  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-4 py-10">
      <div className="text-center">
        <PartyPopper className="mx-auto h-10 w-10 text-lantern-400" aria-hidden />
        <h1 className="mt-3 text-2xl font-bold">
          {session.is_trial
            ? '体験セッション完了!'
            : isCompleted
              ? 'コマ完了!おつかれさまでした'
              : 'ここまでの記録を保存しました'}
        </h1>
      </div>

      <TomoshibiMessage glow message={message} />

      {achievementNames.length > 0 && (
        <Alert tone="warning" className="text-center">
          🏅 新しいバッジを獲得: <strong>{achievementNames.join('、')}</strong>
        </Alert>
      )}

      <Card>
        <div className="grid grid-cols-2 gap-4 text-center">
          <div>
            <CardTitle className="mb-1">今回の集中時間</CardTitle>
            <p className="text-xl font-bold">{formatMinutes(attendedMin)}</p>
          </div>
          <div>
            <CardTitle className="mb-1">勉強した内容</CardTitle>
            <p className="truncate text-xl font-bold">{session.topic || '学習'}</p>
          </div>
          <div>
            <CardTitle className="mb-1">本日の累計</CardTitle>
            <p className="text-xl font-bold">{formatMinutes(todayMin)}</p>
          </div>
          <div>
            <CardTitle className="mb-1">今週の累計</CardTitle>
            <p className="text-xl font-bold">{formatMinutes(weekMin)}</p>
          </div>
        </div>
        <div className="mt-4 flex flex-wrap items-center justify-center gap-2 border-t border-brand-100 pt-4 text-sm dark:border-brand-800">
          <Badge tone="brand">累計 {completedTotal} コマ</Badge>
          {summary && summary.xp_awarded > 0 && <Badge tone="lantern">+{summary.xp_awarded} XP</Badge>}
          {summary && <Badge tone="gray">レベル {summary.level}</Badge>}
          {summary && summary.current_streak > 1 && (
            <Badge tone="lantern">🔥 {summary.current_streak}日連続</Badge>
          )}
        </div>
      </Card>

      {!session.is_trial && (
        <Card>
          <CardTitle>今回の集中はどうでしたか?</CardTitle>
          <div className="grid grid-cols-3 gap-2" role="radiogroup" aria-label="自己評価">
            {RATINGS.map((r) => (
              <button
                key={r.value}
                type="button"
                role="radio"
                aria-checked={rating === r.value}
                onClick={() => setRating(r.value)}
                className={cn(
                  'rounded-xl border px-2 py-3 text-sm transition-colors',
                  rating === r.value
                    ? 'border-brand-600 bg-brand-50 font-bold dark:bg-brand-800'
                    : 'border-brand-200 hover:border-brand-400 dark:border-brand-700'
                )}
              >
                <span className="block text-xl">{r.emoji}</span>
                {r.label}
              </button>
            ))}
          </div>
          <Textarea
            className="mt-3"
            rows={2}
            placeholder="振り返りメモ(任意)"
            value={memo}
            onChange={(e) => setMemo(e.target.value)}
            maxLength={500}
          />
          {error && <Alert tone="error" className="mt-2">{error}</Alert>}
          <Button variant="secondary" className="mt-3 w-full" onClick={saveRating} disabled={saved}>
            {saved ? '保存しました ✓' : '振り返りを保存'}
          </Button>
        </Card>
      )}

      <div className="space-y-3">
        {session.is_trial ? (
          <Link href="/home" className="block">
            <Button variant="lantern" size="xl" className="w-full">
              ホームへ進む <ArrowRight className="h-5 w-5" />
            </Button>
          </Link>
        ) : (
          <>
            <Link href={`/prejoin?topic=${encodeURIComponent(session.topic)}`} className="block">
              <Button variant="lantern" size="lg" className="w-full">
                もう1コマ続ける
              </Button>
            </Link>
            <div className="flex gap-3">
              <Link href="/home" className="flex-1">
                <Button variant="outline" size="lg" className="w-full">
                  休憩する
                </Button>
              </Link>
              <Link href="/home" className="flex-1">
                <Button variant="ghost" size="lg" className="w-full">
                  ホームへ戻る
                </Button>
              </Link>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
