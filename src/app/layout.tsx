import type { Metadata, Viewport } from 'next';
import './globals.css';
import { APP_NAME, APP_TAGLINE } from '@/lib/constants';

export const metadata: Metadata = {
  title: { default: `${APP_NAME} | ${APP_TAGLINE}`, template: `%s | ${APP_NAME}` },
  description:
    'やる気に頼らず机に向かえるオンライン自習室。強いぼかしの入った映像でゆるくつながり、25分の集中タイムをみんなで共有します。',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja" suppressHydrationWarning>
      <head>
        {/* ダークモード: 保存済み設定 or OS設定を初期描画前に適用 */}
        <script
          dangerouslySetInnerHTML={{
            __html: `try{var t=localStorage.getItem('theme');if(t==='dark'||(!t&&matchMedia('(prefers-color-scheme: dark)').matches))document.documentElement.classList.add('dark')}catch(e){}`,
          }}
        />
      </head>
      <body className="min-h-dvh">{children}</body>
    </html>
  );
}
