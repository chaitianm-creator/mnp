'use client';

// 共通レイアウト: サイドバー + トップバー + デモエンジン起動
import { useOffice } from '@/lib/store';
import { cn } from '@/lib/utils';
import {
  Activity,
  AlertTriangle,
  BadgeJapaneseYen,
  BarChart3,
  Briefcase,
  Building2,
  CalendarCheck,
  CheckCircle2,
  FileText,
  Handshake,
  Inbox,
  LayoutDashboard,
  Lightbulb,
  Link2,
  ListTodo,
  Megaphone,
  Menu,
  MessageSquare,
  Search,
  Settings,
  Users,
  X,
} from 'lucide-react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';

const NAV = [
  { section: 'ホーム', items: [
    { href: '/dashboard', label: '経営ダッシュボード', icon: LayoutDashboard },
    { href: '/office', label: 'バーチャルオフィス', icon: Building2 },
    { href: '/chat', label: '社長指示チャット', icon: MessageSquare },
    { href: '/proposals', label: 'CEO提案センター', icon: Lightbulb, badge: 'proposals' },
    { href: '/approvals', label: '承認センター', icon: CheckCircle2, badge: 'approvals' },
  ]},
  { section: '組織', items: [
    { href: '/agents', label: 'AI社員', icon: Users, badge: 'unread' },
    { href: '/tasks', label: 'タスク管理', icon: ListTodo },
    { href: '/logs', label: '活動ログ', icon: Activity },
  ]},
  { section: '営業', items: [
    { href: '/sales/leads', label: '営業リスト', icon: Search },
    { href: '/sales/inquiries', label: '問い合わせ・受付', icon: Inbox },
    { href: '/sales/deals', label: '商談管理', icon: Handshake },
  ]},
  { section: 'マーケ・制作', items: [
    { href: '/projects', label: '制作案件', icon: Briefcase },
    { href: '/marketing/sns', label: 'SNS投稿管理', icon: Megaphone },
    { href: '/marketing/seo', label: 'SEO・AIO', icon: BarChart3 },
  ]},
  { section: '管理', items: [
    { href: '/reports', label: 'レポート', icon: FileText },
    { href: '/billing', label: 'AI利用料金', icon: BadgeJapaneseYen },
    { href: '/errors', label: 'エラー・障害', icon: AlertTriangle },
    { href: '/integrations', label: '外部サービス連携', icon: Link2 },
    { href: '/settings', label: '設定', icon: Settings },
  ]},
];

function useDemoEngine() {
  const tick = useOffice((s) => s.tick);
  const demoMode = useOffice((s) => s.settings.demoMode);
  useEffect(() => {
    if (!demoMode) return;
    // 小さな変化は約3秒ごと。大イベント(会議・アナウンス・エラー)はストア側で6tickごとに発生
    const id = setInterval(() => tick(), 3000);
    return () => clearInterval(id);
  }, [demoMode, tick]);
}

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const hydrated = useOffice((s) => s.hydrated);
  const setupCompleted = useOffice((s) => s.settings.setupCompleted);
  const companyName = useOffice((s) => s.settings.companyName);
  const demoMode = useOffice((s) => s.settings.demoMode);
  const pendingApprovals = useOffice((s) => s.approvals.filter((a) => a.status === 'pending').length);
  const openProposals = useOffice(
    (s) => s.proposals.filter((p) => ['new', 'reviewing', 'revision'].includes(p.status)).length,
  );
  const totalUnread = useOffice((s) => Object.values(s.unread).reduce((a, b) => a + b, 0));
  const [mobileOpen, setMobileOpen] = useState(false);

  const badgeCount = (badge?: string) =>
    badge === 'approvals' ? pendingApprovals : badge === 'proposals' ? openProposals : badge === 'unread' ? totalUnread : 0;

  useDemoEngine();

  useEffect(() => {
    if (hydrated && !setupCompleted) router.replace('/setup');
  }, [hydrated, setupCompleted]);

  useEffect(() => setMobileOpen(false), [pathname]);

  if (!hydrated) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50">
        <div className="text-center">
          <div className="mx-auto mb-3 h-10 w-10 animate-spin rounded-full border-4 border-brand-200 border-t-brand-600" />
          <p className="text-sm text-slate-500">オフィスを準備しています…</p>
        </div>
      </div>
    );
  }

  const nav = (
    <nav className="flex-1 space-y-4 overflow-y-auto px-3 py-4">
      {NAV.map((group) => (
        <div key={group.section}>
          <p className="px-2 pb-1 text-[10px] font-semibold uppercase tracking-wider text-slate-400">
            {group.section}
          </p>
          <ul className="space-y-0.5">
            {group.items.map((item) => {
              const active = pathname === item.href || pathname.startsWith(item.href + '/');
              const Icon = item.icon;
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className={cn(
                      'flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-[13px] font-medium transition',
                      active
                        ? 'bg-gradient-to-r from-brand-600 to-accent-600 text-white shadow-sm'
                        : 'text-slate-600 hover:bg-slate-100',
                    )}
                  >
                    <Icon className="h-4 w-4 shrink-0" />
                    <span className="flex-1">{item.label}</span>
                    {'badge' in item && badgeCount(item.badge) > 0 && (
                      <span
                        className={cn(
                          'rounded-full px-1.5 py-0.5 text-[10px] font-bold',
                          active
                            ? 'bg-white/20 text-white'
                            : item.badge === 'unread'
                              ? 'bg-brand-100 text-brand-700'
                              : 'bg-amber-100 text-amber-700',
                        )}
                        aria-label={`${item.label}の未処理 ${badgeCount(item.badge)}件`}
                      >
                        {badgeCount(item.badge)}
                      </span>
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );

  return (
    <div className="flex min-h-screen bg-slate-50">
      {/* デスクトップサイドバー */}
      <aside className="sticky top-0 hidden h-screen w-60 shrink-0 flex-col border-r border-slate-200 bg-white lg:flex">
        <div className="border-b border-slate-100 px-4 py-4">
          <Link href="/dashboard" className="block">
            <p className="bg-gradient-to-r from-brand-600 to-accent-600 bg-clip-text text-sm font-extrabold tracking-tight text-transparent">
              {companyName}
            </p>
            <p className="mt-0.5 text-[10px] text-slate-400">AI社員と一緒に働く制作会社</p>
          </Link>
        </div>
        {nav}
        <div className="border-t border-slate-100 px-4 py-3">
          <div className="flex items-center gap-2 text-xs text-slate-500">
            <span className={cn('h-2 w-2 rounded-full', demoMode ? 'animate-pulse bg-emerald-500' : 'bg-slate-300')} />
            {demoMode ? 'デモモード稼働中' : 'デモモード停止中'}
          </div>
        </div>
      </aside>

      {/* モバイルドロワー */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-slate-900/40" onClick={() => setMobileOpen(false)} />
          <aside className="absolute left-0 top-0 flex h-full w-64 flex-col bg-white shadow-panel">
            <div className="flex items-center justify-between border-b border-slate-100 px-4 py-3">
              <p className="bg-gradient-to-r from-brand-600 to-accent-600 bg-clip-text text-sm font-extrabold text-transparent">
                {companyName}
              </p>
              <button onClick={() => setMobileOpen(false)} aria-label="閉じる">
                <X className="h-5 w-5 text-slate-500" />
              </button>
            </div>
            {nav}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        {/* モバイルトップバー */}
        <header className="sticky top-0 z-40 flex items-center gap-3 border-b border-slate-200 bg-white/90 px-4 py-2.5 backdrop-blur lg:hidden">
          <button onClick={() => setMobileOpen(true)} aria-label="メニュー">
            <Menu className="h-5 w-5 text-slate-600" />
          </button>
          <p className="bg-gradient-to-r from-brand-600 to-accent-600 bg-clip-text text-sm font-extrabold text-transparent">
            {companyName}
          </p>
          {pendingApprovals > 0 && (
            <Link
              href="/approvals"
              className="ml-auto flex items-center gap-1 rounded-full bg-amber-100 px-2 py-1 text-[11px] font-bold text-amber-700"
            >
              <CalendarCheck className="h-3 w-3" />
              承認 {pendingApprovals}
            </Link>
          )}
        </header>
        <main className="min-w-0 flex-1 px-4 py-5 lg:px-6">{children}</main>
      </div>
    </div>
  );
}
