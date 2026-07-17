import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AI CREATIVE OFFICE',
  description: 'AI社員と一緒に働く、次世代のWeb制作会社。',
};

// スマホ専用UI: ノッチまで使う(viewport-fit=cover)+ 端末幅基準
export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#f8fafc',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
