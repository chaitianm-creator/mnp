import Stripe from 'stripe';

/** Stripeクライアント。キー未設定の環境では null (機能を無効化) */
export function getStripe(): Stripe | null {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key || key === 'sk_test_xxx') return null;
  return new Stripe(key);
}
