'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';

export function ReservationActions({
  id,
  startsAt,
  topic,
  duration,
}: {
  id: string;
  startsAt: string;
  topic: string;
  duration: number;
}) {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [busy, setBusy] = useState(false);
  const soon = new Date(startsAt).getTime() - Date.now() < 15 * 60000;

  const cancel = async () => {
    if (!confirm('この予約を削除しますか?')) return;
    setBusy(true);
    await supabase.from('reservations').update({ status: 'cancelled' }).eq('id', id);
    router.refresh();
  };

  return (
    <div className="flex items-center gap-2">
      {soon && (
        <Link href={`/prejoin?topic=${encodeURIComponent(topic)}&duration=${duration}`}>
          <Button variant="lantern" size="sm">
            入室する
          </Button>
        </Link>
      )}
      <Link href={`/reservations/${id}/edit`}>
        <Button variant="outline" size="sm">
          変更
        </Button>
      </Link>
      <Button variant="ghost" size="sm" onClick={cancel} disabled={busy}>
        削除
      </Button>
    </div>
  );
}

export function RecurringActions({ id }: { id: string }) {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [busy, setBusy] = useState(false);

  const remove = async () => {
    if (!confirm('この繰り返し予約を停止しますか?(今後の自動生成が止まります)')) return;
    setBusy(true);
    await supabase.from('recurring_reservations').update({ active: false }).eq('id', id);
    // 未来の未消化予約も取り消す
    await supabase
      .from('reservations')
      .update({ status: 'cancelled' })
      .eq('recurring_reservation_id', id)
      .eq('status', 'scheduled')
      .gte('starts_at', new Date().toISOString());
    router.refresh();
  };

  return (
    <Button variant="ghost" size="sm" onClick={remove} disabled={busy}>
      停止
    </Button>
  );
}
