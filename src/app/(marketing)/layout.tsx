import Link from 'next/link';
import { Logo } from '@/components/tomoshibi';
import { ThemeToggle } from '@/components/theme-toggle';
import { Button } from '@/components/ui/button';

export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="sticky top-0 z-40 border-b border-brand-100 bg-surface-light/90 backdrop-blur dark:border-brand-800 dark:bg-surface-dark/90">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-4">
          <Link href="/" aria-label="MokuTomo トップページ">
            <Logo />
          </Link>
          <nav className="flex items-center gap-2">
            <ThemeToggle />
            <Link href="/auth/login">
              <Button variant="ghost">ログイン</Button>
            </Link>
            <Link href="/auth/register">
              <Button variant="lantern">無料ではじめる</Button>
            </Link>
          </nav>
        </div>
      </header>
      <main className="flex-1">{children}</main>
      <footer className="border-t border-brand-100 py-8 text-sm dark:border-brand-800">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 text-brand-600 dark:text-brand-300">
          <Logo className="opacity-80" />
          <nav className="flex flex-wrap gap-4">
            <Link href="/terms" className="hover:underline">
              利用規約
            </Link>
            <Link href="/privacy" className="hover:underline">
              プライバシーポリシー
            </Link>
            <Link href="/contact" className="hover:underline">
              お問い合わせ
            </Link>
          </nav>
        </div>
      </footer>
    </div>
  );
}
