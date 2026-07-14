import Link from 'next/link';
import { Plus, Repeat } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { Card, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/misc';
import { ReservationActions, RecurringActions } from './actions';
import { WEEKDAYS_JA } from '@/lib/constants';

export const metadata = { title: '予約' };
export const dynamic = 'force-dynamic';

export default async function ReservationsPage() {
  const supabase = createClient();
  await supabase.rpc('sync_reservations');

  const [{ data: profile }, { data: upcoming }, { data: past }, { data: recurring }, { data: sub }] =
    await Promise.all([
      supabase.from('profiles').select('timezone').single(),
      supabase
        .from('reservations')
        .select('*')
        .eq('status', 'scheduled')
        .order('starts_at', { ascending: true })
        .limit(50),
      supabase
        .from('reservations')
        .select('*')
        .neq('status', 'scheduled')
        .order('starts_at', { ascending: false })
        .limit(10),
      supabase.from('recurring_reservations').select('*').eq('active', true).order('weekday'),
      supabase.from('subscriptions').select('plan').single(),
    ]);

  const tz = profile?.timezone ?? 'Asia/Tokyo';
  const fmt = new Intl.DateTimeFormat('ja-JP', {
    timeZone: tz,
    month: 'numeric',
    day: 'numeric',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
  const isFree = (sub?.plan ?? 'free') === 'free';

  const statusLabel: Record<string, { label: string; tone: 'brand' | 'gray' | 'red' }> = {
    completed: { label: '完了', tone: 'brand' },
    missed: { label: '欠席', tone: 'red' },
    cancelled: { label: 'キャンセル', tone: 'gray' },
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">予約</h1>
        <Link href="/reservations/new">
          <Button>
            <Plus className="h-4 w-4" /> 新しい予約
          </Button>
        </Link>
      </div>

      {isFree && (
        <p className="text-sm text-brand-500">
          無料プランでは予約を3件まで登録できます(繰り返し予約はプレミアム限定)。
        </p>
      )}

      <Card>
        <CardTitle>今後の予約</CardTitle>
        {(upcoming?.length ?? 0) === 0 ? (
          <p className="py-6 text-center text-sm text-brand-500">
            予約はありません。「勉強する時間」を先に決めておくと、始める強制力が生まれます。
          </p>
        ) : (
          <ul className="divide-y divide-brand-100 dark:divide-brand-800">
            {upcoming!.map((r) => (
              <li key={r.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
                <div>
                  <p className="font-bold">{fmt.format(new Date(r.starts_at))}</p>
                  <p className="text-sm text-brand-600 dark:text-brand-300">
                    {r.topic || '学習'}({r.duration_minutes}分)
                    {r.recurring_reservation_id && (
                      <Badge tone="gray" className="ml-2">
                        <Repeat className="mr-1 h-3 w-3" />
                        毎週
                      </Badge>
                    )}
                  </p>
                </div>
                <ReservationActions
                  id={r.id}
                  startsAt={r.starts_at}
                  topic={r.topic ?? ''}
                  duration={r.duration_minutes}
                />
              </li>
            ))}
          </ul>
        )}
      </Card>

      {(recurring?.length ?? 0) > 0 && (
        <Card>
          <CardTitle>毎週の繰り返し予約</CardTitle>
          <ul className="divide-y divide-brand-100 dark:divide-brand-800">
            {recurring!.map((r) => (
              <li key={r.id} className="flex items-center justify-between gap-3 py-3">
                <div>
                  <p className="font-bold">
                    毎週{WEEKDAYS_JA[r.weekday]}曜日 {String(r.start_time).slice(0, 5)}
                  </p>
                  <p className="text-sm text-brand-600 dark:text-brand-300">
                    {r.topic || '学習'}({r.duration_minutes}分)
                  </p>
                </div>
                <RecurringActions id={r.id} />
              </li>
            ))}
          </ul>
        </Card>
      )}

      {(past?.length ?? 0) > 0 && (
        <Card>
          <CardTitle>過去の予約</CardTitle>
          <ul className="divide-y divide-brand-100 dark:divide-brand-800">
            {past!.map((r) => (
              <li key={r.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                <span>
                  {fmt.format(new Date(r.starts_at))} ・ {r.topic || '学習'}
                </span>
                <Badge tone={statusLabel[r.status]?.tone ?? 'gray'}>
                  {statusLabel[r.status]?.label ?? r.status}
                </Badge>
              </li>
            ))}
          </ul>
        </Card>
      )}
    </div>
  );
}
