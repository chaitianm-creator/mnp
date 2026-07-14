'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';

const tabs = [
  { href: '/settings/profile', label: 'プロフィール' },
  { href: '/settings/notifications', label: '通知' },
  { href: '/settings/supporters', label: '応援者' },
  { href: '/settings/plan', label: 'プラン' },
];

export default function SettingsLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">設定</h1>
      <nav className="flex gap-1 overflow-x-auto rounded-xl bg-brand-100 p-1 dark:bg-brand-800" aria-label="設定タブ">
        {tabs.map((t) => (
          <Link
            key={t.href}
            href={t.href}
            className={cn(
              'flex-1 whitespace-nowrap rounded-lg px-4 py-2 text-center text-sm font-medium',
              pathname === t.href
                ? 'bg-white text-brand-900 shadow-sm dark:bg-brand-950 dark:text-brand-50'
                : 'text-brand-600 dark:text-brand-300'
            )}
          >
            {t.label}
          </Link>
        ))}
      </nav>
      {children}
    </div>
  );
}
