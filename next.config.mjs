/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  headers: async () => [
    {
      source: '/(.*)',
      headers: [
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
