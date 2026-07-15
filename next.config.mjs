// CSPのconnect-srcにSupabase(REST/Auth/Realtime WebSocket)を許可する。
// ビルド時に環境変数が無い場合はhttps/wss全体を許可(開発用フォールバック)。
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
const supabaseOrigin = supabaseUrl.replace(/\/$/, '');
const supabaseWs = supabaseOrigin.replace(/^http/, 'ws');
const connectSrc = supabaseOrigin
  ? `'self' ${supabaseOrigin} ${supabaseWs} https://api.stripe.com https://*.ingest.sentry.io`
  : `'self' https: wss: ws://127.0.0.1:* ws://localhost:*`;

const csp = [
  `default-src 'self'`,
  // Next.jsのハイドレーション用インラインスクリプトとテーマ初期化に'unsafe-inline'が必要。
  // 開発モードのみeval(Fast Refresh)を許可
  `script-src 'self' 'unsafe-inline'${process.env.NODE_ENV === 'development' ? " 'unsafe-eval'" : ''} https://js.stripe.com`,
  `style-src 'self' 'unsafe-inline'`,
  `img-src 'self' data: blob:`,
  `media-src 'self' blob: mediastream:`,
  `connect-src ${connectSrc}`,
  `frame-src https://js.stripe.com https://checkout.stripe.com`,
  `font-src 'self'`,
  `object-src 'none'`,
  `base-uri 'self'`,
  `form-action 'self'`,
  `frame-ancestors 'none'`,
].join('; ');

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  headers: async () => [
    {
      source: '/(.*)',
      headers: [
        { key: 'Content-Security-Policy', value: csp },
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        {
          key: 'Permissions-Policy',
          // カメラは自オリジンのみ許可、マイクは全面的に無効(音声を扱わない設計)
          value: 'camera=(self), microphone=(), geolocation=()',
        },
      ],
    },
  ],
};

export default nextConfig;
