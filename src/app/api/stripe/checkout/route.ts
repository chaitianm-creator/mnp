import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getStripe } from '@/lib/stripe';

export async function POST() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const stripe = getStripe();
  const priceId = process.env.STRIPE_PRICE_ID_PREMIUM;
  if (!stripe || !priceId || priceId === 'price_xxx') {
    return NextResponse.json({ error: 'stripe_not_configured' }, { status: 503 });
  }

  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000';

  try {
    const { data: sub } = await supabase
      .from('subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .single();

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      customer: sub?.stripe_customer_id ?? undefined,
      customer_email: sub?.stripe_customer_id ? undefined : user.email,
      client_reference_id: user.id,
      subscription_data: { metadata: { user_id: user.id } },
      success_url: `${appUrl}/settings/plan?checkout=success`,
      cancel_url: `${appUrl}/settings/plan?checkout=cancelled`,
    });
    return NextResponse.json({ url: session.url });
  } catch {
    return NextResponse.json({ error: 'checkout_failed' }, { status: 500 });
  }
}
