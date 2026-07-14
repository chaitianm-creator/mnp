import { Sparkles, Layers, Mountain, Flame, Trophy, Award, Lock } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { Card, CardTitle } from '@/components/ui/card';
import { Progress, Badge } from '@/components/ui/misc';
import { levelProgress } from '@/lib/xp';
import { formatMinutes } from '@/lib/history';
import { cn } from '@/lib/utils';

export const metadata = { title: '実績・バッジ' };
export const dynamic = 'force-dynamic';

const icons: Record<string, React.ComponentType<{ className?: string }>> = {
  sparkles: Sparkles,
  layers: Layers,
  mountain: Mountain,
  flame: Flame,
  trophy: Trophy,
};

export default async function AchievementsPage() {
  const supabase = createClient();
  const [{ data: stats }, { data: achievements }, { data: earned }] = await Promise.all([
    supabase.from('user_stats').select('*').single(),
    supabase.from('achievements').select('*').order('sort_order'),
    supabase.from('user_achievements').select('achievement_id, earned_at'),
  ]);

  const earnedMap = new Map((earned ?? []).map((e) => [e.achievement_id, e.earned_at]));
  const xp = stats?.xp ?? 0;
  const lp = levelProgress(xp);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">実績・バッジ</h1>

      <Card>
        <div className="flex items-center justify-between">
          <CardTitle className="mb-0">レベル {lp.level}</CardTitle>
          <span className="text-sm text-brand-500">
            {xp} XP(次のレベルまで {lp.needed - lp.current} XP)
          </span>
        </div>
        <Progress value={lp.ratio} className="mt-3" />
        <div className="mt-4 flex flex-wrap gap-2 text-sm">
          <Badge tone="brand">累計 {formatMinutes(stats?.total_focus_minutes ?? 0)}</Badge>
          <Badge tone="brand">{stats?.total_completed_sessions ?? 0} コマ完了</Badge>
          <Badge tone="lantern">🔥 連続 {stats?.current_streak ?? 0} 日</Badge>
          <Badge tone="gray">最長 {stats?.longest_streak ?? 0} 日</Badge>
        </div>
        <p className="mt-3 text-xs text-brand-500">
          XPは学習時間に応じてサーバー側で自動的に付与されます(1分=2XP+完了ボーナス10XP)。
        </p>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2">
        {(achievements ?? []).map((a) => {
          const earnedAt = earnedMap.get(a.id);
          const Icon = icons[a.icon] ?? Award;
          return (
            <Card
              key={a.id}
              className={cn('flex items-center gap-4', !earnedAt && 'opacity-60 grayscale')}
            >
              <div
                className={cn(
                  'flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl',
                  earnedAt ? 'bg-lantern-100 dark:bg-lantern-900/50' : 'bg-brand-100 dark:bg-brand-800'
                )}
              >
                {earnedAt ? (
                  <Icon className="h-7 w-7 text-lantern-600 dark:text-lantern-300" />
                ) : (
                  <Lock className="h-6 w-6 text-brand-400" />
                )}
              </div>
              <div>
                <p className="font-bold">{a.name}</p>
                <p className="text-sm text-brand-600 dark:text-brand-300">{a.description}</p>
                {earnedAt && (
                  <p className="mt-0.5 text-xs text-brand-500">
                    {new Date(earnedAt).toLocaleDateString('ja-JP')} 獲得
                  </p>
                )}
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
