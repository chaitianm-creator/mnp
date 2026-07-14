import { createClient } from '@/lib/supabase/server';
import { ReservationForm } from '@/components/reservation-form';

export const metadata = { title: '予約作成' };
export const dynamic = 'force-dynamic';

export default async function NewReservationPage() {
  const supabase = createClient();
  const { data: sub } = await supabase.from('subscriptions').select('plan').single();

  return (
    <div className="mx-auto max-w-lg space-y-6">
      <h1 className="text-2xl font-bold">予約を作成</h1>
      <ReservationForm isPremium={(sub?.plan ?? 'free') === 'premium'} />
    </div>
  );
}
