'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { Home, BarChart3, CalendarClock, Award, Settings, LogOut, Play } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Logo } from '@/components/tomoshibi';
import { ThemeToggle } from '@/components/theme-toggle';
import { createClient } from '@/lib/supabase/client';

const items = [
  { href: '/home', label: 'ホーム', icon: Home },
  { href: '/history', label: '学習履歴', icon: BarChart3 },
  { href: '/reservations', label: '予約', icon: CalendarClock },
  { href: '/achievements', label: '実績', icon: Award },
  { href: '/settings/profile', label: '設定', icon: Settings },
];

export function AppNav({ displayName }: { displayName: string }) {
  const pathname = usePathname();
  const router = useRouter();

  const logout = async () => {
    await createClient().auth.signOut();
    router.push('/');
    router.refresh();
  };

  return (
    <>
      {/* PC: 左サイドバー */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r border-brand-100 bg-white p-4 dark:border-brand-800 dark:bg-brand-900/60 md:flex">
        <Link href="/home" className="mb-6 block px-2" aria-label="ホームへ">
          <Logo />
        </Link>
        <Link
          href="/prejoin"
          className="mb-6 flex h-12 items-center justify-center gap-2 rounded-xl bg-lantern-400 font-bold text-brand-950 shadow-lg shadow-lantern-400/30 hover:bg-lantern-300"
        >
          <Play className="h-5 w-5" />
          今すぐ入室
        </Link>
        <nav className="flex-1 space-y-1">
          {items.map((item) => {
            const active = pathname.startsWith(item.href.split('/').slice(0, 2).join('/'));
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium',
                  active
                    ? 'bg-brand-100 text-brand-900 dark:bg-brand-800 dark:text-brand-50'
                    : 'text-brand-600 hover:bg-brand-50 dark:text-brand-300 dark:hover:bg-brand-800/60'
                )}
              >
                <item.icon className="h-5 w-5" />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="space-y-2 border-t border-brand-100 pt-3 dark:border-brand-800">
          <div className="flex items-center justify-between px-2">
            <span className="truncate text-sm font-medium">{displayName}</span>
            <ThemeToggle />
          </div>
          <button
            onClick={logout}
            className="flex w-full items-center gap-3 rounded-xl px-3 py-2 text-sm text-brand-600 hover:bg-brand-50 dark:text-brand-300 dark:hover:bg-brand-800/60"
          >
            <LogOut className="h-4 w-4" />
            ログアウト
          </button>
        </div>
      </aside>

      {/* スマホ: 下部タブ */}
      <nav
        aria-label="メインナビゲーション"
        className="fixed inset-x-0 bottom-0 z-30 flex border-t border-brand-100 bg-white pb-[env(safe-area-inset-bottom)] dark:border-brand-800 dark:bg-brand-900 md:hidden"
      >
        {items.map((item) => {
          const active = pathname.startsWith(item.href.split('/').slice(0, 2).join('/'));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px]',
                active ? 'text-brand-700 dark:text-lantern-300' : 'text-brand-400 dark:text-brand-400'
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </>
  );
}
