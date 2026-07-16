import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AI CREATIVE OFFICE',
  description: 'AI社員と一緒に働く、次世代のWeb制作会社。',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
