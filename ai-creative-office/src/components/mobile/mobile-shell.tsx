'use client';

// スマホ専用シェル: 「AI会社を持ち歩くアプリ」
// PC版(管理画面)とは別設計。下部タブバー + 片手操作前提の5画面構成
// - ホーム / オフィス / チャット / 通知(承認・提案・呼びかけ) / AI社員
import { AgentDetailPanel } from '@/components/agent-detail-panel';
import { useOffice } from '@/lib/store';
import { cn } from '@/lib/utils';
import { Bell, Building2, Home, MessageSquare, Users } from 'lucide-react';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { MobileAgents } from './mobile-agents';
import { MobileChat } from './mobile-chat';
import { MobileDeliverables } from './mobile-deliverables';
import { MobileHome } from './mobile-home';
import { MobileInbox } from './mobile-inbox';
import { MobileOffice } from './mobile-office';

export type MobileTab = 'home' | 'office' | 'chat' | 'inbox' | 'agents';

const TABS: { id: MobileTab; label: string; icon: typeof Home }[] = [
  { id: 'home', label: 'ホーム', icon: Home },
  { id: 'office', label: 'オフィス', icon: Building2 },
  { id: 'chat', label: 'チャット', icon: MessageSquare },
  { id: 'inbox', label: '通知', icon: Bell },
  { id: 'agents', label: 'AI社員', icon: Users },
];

export function MobileApp() {
  const pathname = usePathname();
  const companyName = useOffice((s) => s.settings.companyName);
  const demoMode = useOffice((s) => s.settings.demoMode);
  const agents = useOffice((s) => s.agents);
  const totalUnread = useOffice((s) => Object.values(s.unread).reduce((a, b) => a + b, 0));
  const inboxCount = useOffice(
    (s) =>
      s.approvals.filter((a) => a.status === 'pending').length +
      s.proposals.filter((p) => ['new', 'reviewing', 'revision'].includes(p.status)).length +
      s.ceoAlerts.filter((a) => a.status === 'new').length,
  );

  const [tab, setTab] = useState<MobileTab>('home');
  const [thread, setThread] = useState<string | null>(null); // 'ceo' | agentId
  const [showDeliverables, setShowDeliverables] = useState(false);
  const [selectedAgentId, setSelectedAgentId] = useState<string | null>(null);
  const selectedAgent = agents.find((a) => a.id === selectedAgentId) ?? null;

  // チャット内のリンクアクション等でURLが変わった場合、対応するタブへ同期する
  useEffect(() => {
    if (pathname.startsWith('/office')) setTab('office');
    else if (pathname.startsWith('/chat')) {
      setTab('chat');
      setThread('ceo');
    } else if (pathname.startsWith('/approvals') || pathname.startsWith('/proposals')) setTab('inbox');
    else if (pathname.startsWith('/agents')) setTab('agents');
    else if (pathname.startsWith('/deliverables')) {
      setTab('home');
      setShowDeliverables(true);
    } else if (pathname.startsWith('/dashboard')) setTab('home');
  }, [pathname]);

  const badgeFor = (id: MobileTab) => (id === 'chat' ? totalUnread : id === 'inbox' ? inboxCount : 0);

  return (
    <div className="fixed inset-0 flex flex-col bg-slate-50" style={{ height: '100dvh' }}>
      {/* ヘッダー(最小限。親指が届かない上部には操作を置かない) */}
      <header className="flex shrink-0 items-center gap-2 border-b border-slate-200 bg-white/95 px-4 pb-2 backdrop-blur pt-safe-2">
        <p className="bg-gradient-to-r from-brand-600 to-accent-600 bg-clip-text text-sm font-extrabold tracking-tight text-transparent">
          {companyName}
        </p>
        <span
          className={cn('h-1.5 w-1.5 rounded-full', demoMode ? 'animate-pulse bg-emerald-500' : 'bg-slate-300')}
          aria-label={demoMode ? 'デモモード稼働中' : 'デモモード停止中'}
        />
        <span className="ml-auto text-[10px] text-slate-400">AI会社をポケットに</span>
      </header>

      {/* 画面本体 */}
      <main className="relative min-h-0 flex-1 overflow-hidden">
        {tab === 'home' && (
          <MobileHome
            onOpenDeliverables={() => setShowDeliverables(true)}
            onOpenCeoChat={() => {
              setTab('chat');
              setThread('ceo');
            }}
            onGoInbox={() => setTab('inbox')}
            onSelectAgent={(id) => setSelectedAgentId(id)}
          />
        )}
        {tab === 'office' && <MobileOffice onSelect={(a) => setSelectedAgentId(a.id)} />}
        {tab === 'chat' && <MobileChat thread={thread} setThread={setThread} />}
        {tab === 'inbox' && <MobileInbox />}
        {tab === 'agents' && <MobileAgents onSelect={(a) => setSelectedAgentId(a.id)} />}

        {/* 成果物(ホームの上に重なるサブ画面) */}
        {showDeliverables && <MobileDeliverables onClose={() => setShowDeliverables(false)} />}
      </main>

      {/* 下部タブバー(片手操作の主動線・44px以上のタップ領域) */}
      <nav
        className="shrink-0 border-t border-slate-200 bg-white/95 backdrop-blur pb-safe"
        aria-label="メインナビゲーション"
      >
        <div className="grid grid-cols-5">
          {TABS.map((t) => {
            const active = tab === t.id;
            const badge = badgeFor(t.id);
            const Icon = t.icon;
            return (
              <button
                key={t.id}
                onClick={() => {
                  setTab(t.id);
                  if (t.id !== 'chat') setThread(null);
                  setShowDeliverables(false);
                }}
                aria-label={`${t.label}${badge > 0 ? `(未処理${badge}件)` : ''}`}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'relative flex min-h-[52px] flex-col items-center justify-center gap-0.5 outline-none transition-colors focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-500',
                  active ? 'text-brand-600' : 'text-slate-400 active:text-slate-600',
                )}
              >
                <span className="relative">
                  <Icon className="h-5 w-5" strokeWidth={active ? 2.4 : 2} />
                  {badge > 0 && (
                    <span className="absolute -right-2.5 -top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
                      {badge > 99 ? '99+' : badge}
                    </span>
                  )}
                </span>
                <span className={cn('text-[9.5px]', active ? 'font-bold' : 'font-medium')}>{t.label}</span>
              </button>
            );
          })}
        </div>
      </nav>

      {/* AI社員詳細(全タブ共通のオーバーレイ) */}
      <AgentDetailPanel agent={selectedAgent} onClose={() => setSelectedAgentId(null)} />
    </div>
  );
}
