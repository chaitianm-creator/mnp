import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { ReservationForm } from '@/components/reservation-form';

export const metadata = { title: '予約変更' };
export const dynamic = 'force-dynamic';

export default async function EditReservationPage({ params }: { params: { id: string } }) {
  const supabase = createClient();
  const [{ data: reservation }, { data: sub }, { data: profile }] = await Promise.all([
    supabase.from('reservations').select('*').eq('id', params.id).maybeSingle(),
    supabase.from('subscriptions').select('plan').single(),
    supabase.from('profiles').select('timezone').single(),
  ]);
  if (!reservation || reservation.status !== 'scheduled') notFound();

  const tz = profile?.timezone ?? 'Asia/Tokyo';
  const d = new Date(reservation.starts_at);
  const dateFmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const timeFmt = new Intl.DateTimeFormat('en-GB', {
    timeZone: tz,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });

  return (
    <div className="mx-auto max-w-lg space-y-6">
      <h1 className="text-2xl font-bold">予約を変更</h1>
      <ReservationForm
        isPremium={(sub?.plan ?? 'free') === 'premium'}
        initial={{
          id: reservation.id,
          date: dateFmt.format(d),
          time: timeFmt.format(d),
          duration: reservation.duration_minutes,
          topic: reservation.topic ?? '',
          repeatWeekly: false,
        }}
      />
    </div>
  );
}
