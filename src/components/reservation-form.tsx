'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';
import { DURATIONS, rpcErrorToMessage } from '@/lib/constants';
import { requestNotificationPermission } from '@/lib/notify';
import { cn } from '@/lib/utils';

export interface ReservationFormValues {
  id?: string;
  date: string;
  time: string;
  duration: number;
  topic: string;
  repeatWeekly: boolean;
}

export function ReservationForm({
  initial,
  isPremium,
}: {
  initial?: Partial<ReservationFormValues>;
  isPremium: boolean;
}) {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [date, setDate] = useState(initial?.date ?? '');
  const [time, setTime] = useState(initial?.time ?? '');
  const [duration, setDuration] = useState(initial?.duration ?? 25);
  const [topic, setTopic] = useState(initial?.topic ?? '');
  const [repeatWeekly, setRepeatWeekly] = useState(initial?.repeatWeekly ?? false);
  const [error, setError] = useState('');
  const [fieldError, setFieldError] = useState('');
  const [busy, setBusy] = useState(false);
  const isEdit = !!initial?.id;

  const submit = async () => {
    setError('');
    setFieldError('');
    const startsAt = new Date(`${date}T${time}`);
    if (!date || !time || Number.isNaN(startsAt.getTime())) {
      setFieldError('日付と開始時刻を入力してください');
      return;
    }
    if (startsAt.getTime() < Date.now() + 60000) {
      setFieldError('開始時刻は現在より後にしてください');
      return;
    }
    setBusy(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;

    if (repeatWeekly && !isEdit) {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Tokyo';
      const { error } = await supabase.from('recurring_reservations').insert({
        user_id: user.id,
        weekday: startsAt.getDay(),
        start_time: time,
        timezone: tz,
        duration_minutes: duration,
        topic: topic.trim().slice(0, 100),
      });
      if (error) {
        setError(rpcErrorToMessage(error));
        setBusy(false);
        return;
      }
      await supabase.rpc('sync_reservations');
    } else if (isEdit) {
      const { error } = await supabase
        .from('reservations')
        .update({
          starts_at: startsAt.toISOString(),
          duration_minutes: duration,
          topic: topic.trim().slice(0, 100),
        })
        .eq('id', initial!.id!);
      if (error) {
        setError(rpcErrorToMessage(error));
        setBusy(false);
        return;
      }
    } else {
      const { error } = await supabase.from('reservations').insert({
        user_id: user.id,
        starts_at: startsAt.toISOString(),
        duration_minutes: duration,
        topic: topic.trim().slice(0, 100),
      });
      if (error) {
        setError(rpcErrorToMessage(error));
        setBusy(false);
        return;
      }
    }
    // 開始前ブラウザ通知のための許可を取得
    void requestNotificationPermission();
    router.push('/reservations');
    router.refresh();
  };

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-4">
        <div>
          <Label htmlFor="res-date">日付</Label>
          <Input id="res-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </div>
        <div>
          <Label htmlFor="res-time">開始時刻</Label>
          <Input id="res-time" type="time" value={time} onChange={(e) => setTime(e.target.value)} />
        </div>
      </div>
      <FieldError message={fieldError} />
      <div>
        <Label>集中時間</Label>
        <div className="grid grid-cols-4 gap-2" role="radiogroup" aria-label="集中時間">
          {DURATIONS.map((d) => (
            <button
              key={d}
              type="button"
              role="radio"
              aria-checked={duration === d}
              onClick={() => setDuration(d)}
              className={cn(
                'h-11 rounded-xl border text-sm font-bold',
                duration === d
                  ? 'border-brand-600 bg-brand-600 text-white'
                  : 'border-brand-200 bg-white text-brand-700 dark:border-brand-700 dark:bg-brand-950 dark:text-brand-200'
              )}
            >
              {d}分
            </button>
          ))}
        </div>
      </div>
      <div>
        <Label htmlFor="res-topic">学習内容</Label>
        <Input
          id="res-topic"
          value={topic}
          onChange={(e) => setTopic(e.target.value)}
          placeholder="例: 英単語"
          maxLength={100}
        />
      </div>
      {!isEdit && (
        <label
          className={cn(
            'flex items-center gap-2 text-sm',
            !isPremium && 'cursor-not-allowed opacity-60'
          )}
        >
          <input
            type="checkbox"
            checked={repeatWeekly}
            disabled={!isPremium}
            onChange={(e) => setRepeatWeekly(e.target.checked)}
            className="h-4 w-4 rounded"
          />
          毎週この曜日・時刻に繰り返す
          {!isPremium && <span className="text-xs text-brand-500">(プレミアム限定)</span>}
        </label>
      )}
      {error && <Alert tone="error">{error}</Alert>}
      <div className="flex gap-3">
        <Button variant="outline" className="flex-1" onClick={() => router.back()}>
          戻る
        </Button>
        <Button className="flex-1" onClick={submit} disabled={busy}>
          {busy ? '保存中…' : isEdit ? '変更を保存' : '予約する'}
        </Button>
      </div>
    </div>
  );
}
