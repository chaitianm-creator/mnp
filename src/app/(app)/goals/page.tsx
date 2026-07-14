'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input, Label } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';

export default function GoalsPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [daily, setDaily] = useState(50);
  const [weekly, setWeekly] = useState(300);
  const [monthly, setMonthly] = useState(1200);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    void supabase
      .from('study_goals')
      .select('*')
      .single()
      .then(({ data }) => {
        if (data) {
          setDaily(data.daily_minutes_goal);
          setWeekly(data.weekly_minutes_goal);
          setMonthly(data.monthly_minutes_goal);
        }
      });
  }, [supabase]);

  const save = async () => {
    setError('');
    setSaved(false);
    const clamp = (v: number, max: number) => Math.max(0, Math.min(max, Math.round(v) || 0));
    const { error } = await supabase
      .from('study_goals')
      .update({
        daily_minutes_goal: clamp(daily, 1440),
        weekly_minutes_goal: clamp(weekly, 10080),
        monthly_minutes_goal: clamp(monthly, 44640),
      })
      .eq('user_id', (await supabase.auth.getUser()).data.user!.id);
    if (error) {
      setError('保存に失敗しました。');
      return;
    }
    setSaved(true);
    router.refresh();
  };

  return (
    <div className="mx-auto max-w-lg space-y-6">
      <h1 className="text-2xl font-bold">目標設定</h1>
      <p className="text-sm text-brand-600 dark:text-brand-300">
        無理のない目標から始めるのが続けるコツです。25分×2コマ=50分が目安です。
      </p>
      <Card className="space-y-5">
        <div>
          <Label htmlFor="daily">1日の目標(分)</Label>
          <Input
            id="daily"
            type="number"
            min={0}
            max={1440}
            value={daily}
            onChange={(e) => setDaily(Number(e.target.value))}
          />
        </div>
        <div>
          <Label htmlFor="weekly">1週間の目標(分)</Label>
          <Input
            id="weekly"
            type="number"
            min={0}
            max={10080}
            value={weekly}
            onChange={(e) => setWeekly(Number(e.target.value))}
          />
        </div>
        <div>
          <Label htmlFor="monthly">1か月の目標(分)</Label>
          <Input
            id="monthly"
            type="number"
            min={0}
            max={44640}
            value={monthly}
            onChange={(e) => setMonthly(Number(e.target.value))}
          />
        </div>
        {error && <Alert tone="error">{error}</Alert>}
        {saved && <Alert tone="success">保存しました。</Alert>}
        <Button size="lg" className="w-full" onClick={save}>
          目標を保存
        </Button>
      </Card>
    </div>
  );
}
