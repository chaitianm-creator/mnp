import { NextResponse } from 'next/server';
import type Stripe from 'stripe';
import { getStripe } from '@/lib/stripe';
import { createAdminClient } from '@/lib/supabase/admin';

/**
 * Stripe Webhook: 購読状態をsubscriptionsテーブルへ反映する。
 * 署名検証により偽リクエストを拒否する。
 */
export async function POST(request: Request) {
  const stripe = getStripe();
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!stripe || !secret || secret === 'whsec_xxx') {
    return NextResponse.json({ error: 'stripe_not_configured' }, { status: 503 });
  }

  const signature = request.headers.get('stripe-signature');
  if (!signature) return NextResponse.json({ error: 'no_signature' }, { status: 400 });

  let event: Stripe.Event;
  try {
    const body = await request.text();
    event = stripe.webhooks.constructEvent(body, signature, secret);
  } catch {
    return NextResponse.json({ error: 'invalid_signature' }, { status: 400 });
  }

  const admin = createAdminClient();

  const applySubscription = async (sub: Stripe.Subscription) => {
    const userId = sub.metadata?.user_id;
    if (!userId) return;
    const active = sub.status === 'active' || sub.status === 'trialing';
    // current_period_end はStripe APIバージョンにより Subscription / SubscriptionItem のどちらかに載る
    const periodEnd =
      (sub as unknown as { current_period_end?: number }).current_period_end ??
      (sub.items.data[0] as unknown as { current_period_end?: number } | undefined)
        ?.current_period_end;
    await admin
      .from('subscriptions')
      .update({
        plan: active ? 'premium' : 'free',
        status: sub.status === 'past_due' ? 'past_due' : active ? 'active' : 'canceled',
        stripe_customer_id: String(sub.customer),
        stripe_subscription_id: sub.id,
        current_period_end: periodEnd ? new Date(periodEnd * 1000).toISOString() : null,
      })
      .eq('user_id', userId);
  };

  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session;
      if (session.subscription && session.client_reference_id) {
        const sub = await stripe.subscriptions.retrieve(String(session.subscription));
        if (!sub.metadata?.user_id) {
          sub.metadata = { ...sub.metadata, user_id: session.client_reference_id };
        }
        await applySubscription(sub);
      }
      break;
    }
    case 'customer.subscription.updated':
    case 'customer.subscription.deleted': {
      await applySubscription(event.data.object as Stripe.Subscription);
      break;
    }
    default:
      break;
  }

  return NextResponse.json({ received: true });
}
