import Link from 'next/link';
import { redirect } from 'next/navigation';
import { LayoutDashboard, Users, DoorOpen, Flag, Megaphone } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { Logo } from '@/components/tomoshibi';
import { ThemeToggle } from '@/components/theme-toggle';

export const dynamic = 'force-dynamic';

const items = [
  { href: '/admin', label: 'ダッシュボード', icon: LayoutDashboard },
  { href: '/admin/users', label: 'ユーザー管理', icon: Users },
  { href: '/admin/rooms', label: 'ルーム管理', icon: DoorOpen },
  { href: '/admin/reports', label: '通報管理', icon: Flag },
  { href: '/admin/announcements', label: 'お知らせ', icon: Megaphone },
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login');

  // サーバー側の管理者チェック (RLSと二重の防衛線)
  const { data: isAdmin } = await supabase.rpc('is_admin');
  if (!isAdmin) redirect('/home');

  return (
    <div className="min-h-dvh bg-surface-light dark:bg-surface-dark">
      <header className="sticky top-0 z-40 border-b border-brand-100 bg-white dark:border-brand-800 dark:bg-brand-900">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4">
          <div className="flex items-center gap-3">
            <Logo />
            <span className="rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-bold text-red-700 dark:bg-red-900/60 dark:text-red-300">
              管理者
            </span>
          </div>
          <div className="flex items-center gap-3">
            <ThemeToggle />
            <Link href="/home" className="text-sm text-brand-600 underline dark:text-brand-300">
              利用者画面へ
            </Link>
          </div>
        </div>
        <nav className="mx-auto flex max-w-6xl gap-1 overflow-x-auto px-4 pb-2">
          {items.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-1.5 whitespace-nowrap rounded-lg px-3 py-1.5 text-sm text-brand-700 hover:bg-brand-100 dark:text-brand-200 dark:hover:bg-brand-800"
            >
              <item.icon className="h-4 w-4" />
              {item.label}
            </Link>
          ))}
        </nav>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">{children}</main>
    </div>
  );
}
