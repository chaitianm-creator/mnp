'use client';

// スマホ版ホーム: 会社の「今」がひと目でわかる + 主要アクションへの入口
import { LiveFeed } from '@/components/office/office-widgets';
import { useOffice } from '@/lib/store';
import { cn } from '@/lib/utils';
import { AlertTriangle, CheckCircle2, ChevronRight, FolderOpen, ListTodo, MessageSquare, Sparkles, Users } from 'lucide-react';
import Link from 'next/link';

function greeting() {
  const h = new Date().getHours();
  if (h < 5) return '深夜も一部のAIが働いています';
  if (h < 11) return 'おはようございます、社長';
  if (h < 17) return 'おつかれさまです、社長';
  return 'こんばんは、社長';
}

export function MobileHome({
  onOpenDeliverables,
  onOpenCeoChat,
  onGoInbox,
  onSelectAgent,
}: {
  onOpenDeliverables: () => void;
  onOpenCeoChat: () => void;
  onGoInbox: () => void;
  onSelectAgent: (agentId: string) => void;
}) {
  const agents = useOffice((s) => s.agents);
  const dailyStats = useOffice((s) => s.dailyStats);
  const announcement = useOffice((s) => s.announcements[0]);
  const alerts = useOffice((s) => s.ceoAlerts.filter((a) => a.status === 'new').slice(0, 2));
  const decideAlert = useOffice((s) => s.decideAlert);
  const pendingApprovals = useOffice((s) => s.approvals.filter((a) => a.status === 'pending').length);
  const unresolvedErrors = useOffice((s) => s.errors.filter((e) => !e.resolved).length);
  const deliverableCount = useOffice((s) => s.deliverables.length);
  const taskCount = useOffice((s) => s.tasks.length);
  const taskUnread = useOffice((s) => Object.values(s.taskRooms).reduce((acc, r) => acc + r.unreadCount, 0));

  const working = agents.filter((a) => ['working', 'checking', 'delegating', 'meeting'].includes(a.status)).length;
  const todayDone = dailyStats[dailyStats.length - 1]?.tasksCompleted ?? 0;
  const onboardingDismissed = useOffice((s) => s.onboardingDismissed);
  const dismissOnboarding = useOffice((s) => s.dismissOnboarding);

  return (
    <div className="h-full space-y-3 overflow-y-auto overscroll-contain px-4 pb-6 pt-3">
      {/* 初回オンボーディング */}
      {!onboardingDismissed && (
        <section className="relative rounded-2xl border border-brand-200 bg-brand-50/60 px-4 py-4">
          <p className="text-sm font-extrabold text-brand-800">ようこそ!🎉</p>
          <p className="mt-1 text-[12px] leading-relaxed text-brand-700">まずはCEOへ仕事を依頼してください。AI社員たちが動き出します。</p>
          <button
            onClick={() => {
              dismissOnboarding();
              onOpenCeoChat();
            }}
            className="mt-2.5 w-full rounded-lg bg-brand-600 px-3 py-2.5 text-[12px] font-bold text-white outline-none active:bg-brand-700 focus-visible:ring-2 focus-visible:ring-brand-500"
          >
            CEOへ仕事を依頼する
          </button>
          <button
            onClick={() => dismissOnboarding()}
            aria-label="オンボーディングを閉じる"
            className="absolute right-2.5 top-2.5 rounded-full p-1 text-brand-400 outline-none active:bg-brand-100 focus-visible:ring-2 focus-visible:ring-brand-500"
          >
            ✕
          </button>
        </section>
      )}

      {/* あいさつ */}
      <section className="rounded-2xl bg-gradient-to-br from-brand-600 to-accent-600 px-4 py-4 text-white shadow-card">
        <p className="text-sm font-bold">{greeting()}</p>
        <p className="mt-1 text-[12px] text-white/85">
          いま <span className="text-lg font-extrabold tabular-nums">{working}</span> 名のAI社員が働いています
        </p>
      </section>

      {/* 会社の今(2x2) */}
      <section className="grid grid-cols-2 gap-2" aria-label="会社の現在の状況">
        <StatTile label="稼働中のAI社員" value={`${working}名`} tone="brand" />
        <StatTile label="完了タスク(今日)" value={`${todayDone}件`} tone="emerald" />
        <button onClick={onGoInbox} className="text-left outline-none focus-visible:ring-2 focus-visible:ring-brand-500 rounded-xl">
          <StatTile label="承認待ち" value={`${pendingApprovals}件`} tone={pendingApprovals > 0 ? 'amber' : 'slate'} chevron />
        </button>
        <StatTile label="エラー・障害" value={`${unresolvedErrors}件`} tone={unresolvedErrors > 0 ? 'red' : 'slate'} />
      </section>

      {/* CEOアナウンス */}
      {announcement && (
        <section
          className={cn(
            'flex items-start gap-2 rounded-xl border px-3 py-2.5 text-[12px] leading-relaxed',
            announcement.tone === 'warning'
              ? 'border-amber-200 bg-amber-50 text-amber-800'
              : announcement.tone === 'success'
                ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
                : 'border-slate-200 bg-white text-slate-600',
          )}
        >
          <span className="mt-0.5 shrink-0">📣</span>
          <p>
            <span className="font-bold">CEO AI:</span> {announcement.message}
          </p>
        </section>
      )}

      {/* CEOからの呼びかけ(承認するまで実行しない) */}
      {alerts.map((alert) => (
        <section key={alert.id} className="rounded-xl border border-brand-200 bg-brand-50/50 p-3">
          <p className="flex items-center gap-1.5 text-[11px] font-bold text-brand-700">
            <Sparkles className="h-3.5 w-3.5" /> CEO AIからのご相談
          </p>
          <p className="mt-1.5 text-[13px] font-bold leading-snug text-slate-800">{alert.conclusion}</p>
          {alert.evidence[0] && <p className="mt-1 text-[11px] text-slate-500">根拠: {alert.evidence[0]}</p>}
          <p className="mt-1 text-[11px] text-slate-500">提案: {alert.recommendation}</p>
          <div className="mt-2.5 flex gap-1.5">
            <button
              onClick={() => decideAlert(alert.id, 'accepted')}
              className="flex-1 rounded-lg bg-brand-600 px-2 py-2 text-[12px] font-bold text-white outline-none active:bg-brand-700 focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              承認して実行
            </button>
            <button
              onClick={() => decideAlert(alert.id, 'later')}
              className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-[12px] font-medium text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              後で
            </button>
            <button
              onClick={() => decideAlert(alert.id, 'dismissed')}
              className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-[12px] font-medium text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              却下
            </button>
          </div>
        </section>
      ))}

      {/* クイックアクション */}
      <section className="grid grid-cols-3 gap-2" aria-label="クイックアクション">
        <QuickAction icon={MessageSquare} label="社長チャット" sub="CEOに依頼" onClick={onOpenCeoChat} />
        <QuickAction icon={FolderOpen} label="成果物" sub={`${deliverableCount}件`} onClick={onOpenDeliverables} />
        <QuickAction icon={CheckCircle2} label="承認する" sub={pendingApprovals > 0 ? `${pendingApprovals}件待ち` : 'なし'} onClick={onGoInbox} highlight={pendingApprovals > 0} />
      </section>

      {/* タスク・案件ルームへの入口 */}
      <Link
        href="/tasks"
        className="flex items-center gap-2.5 rounded-xl border border-slate-200 bg-white px-3.5 py-3 shadow-sm outline-none active:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
      >
        <ListTodo className="h-5 w-5 shrink-0 text-brand-600" />
        <span className="min-w-0 flex-1">
          <span className="block text-[13px] font-bold text-slate-800">タスク・案件ルーム</span>
          <span className="block text-[10.5px] text-slate-400">タスク{taskCount}件 — タップで案件ごとのルームを開けます</span>
        </span>
        {taskUnread > 0 && (
          <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1.5 text-[10px] font-bold text-white">
            {taskUnread}
          </span>
        )}
        <ChevronRight className="h-4 w-4 shrink-0 text-slate-300" />
      </Link>

      {/* ライブフィード */}
      <LiveFeed onSelectAgent={onSelectAgent} className="max-h-[340px]" limit={15} />

      {unresolvedErrors > 0 && (
        <p className="flex items-center gap-1.5 rounded-lg bg-red-50 px-3 py-2 text-[11px] text-red-600">
          <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
          エラーが発生中です。詳しくはPC版の「エラー・障害」で確認できます。
        </p>
      )}
      <p className="flex items-center gap-1.5 px-1 text-[10px] text-slate-400">
        <Users className="h-3 w-3" /> 詳細な管理・設定はPC版で行えます。スマホ版は確認と承認に最適化されています。
      </p>
    </div>
  );
}

function StatTile({
  label,
  value,
  tone,
  chevron,
}: {
  label: string;
  value: string;
  tone: 'brand' | 'emerald' | 'amber' | 'red' | 'slate';
  chevron?: boolean;
}) {
  const tones = {
    brand: 'text-brand-700',
    emerald: 'text-emerald-600',
    amber: 'text-amber-600',
    red: 'text-red-600',
    slate: 'text-slate-700',
  } as const;
  return (
    <div className="flex items-center rounded-xl border border-slate-200 bg-white px-3 py-2.5 shadow-card">
      <div className="min-w-0 flex-1">
        <p className="text-[10px] text-slate-400">{label}</p>
        <p className={cn('text-lg font-extrabold tabular-nums', tones[tone])}>{value}</p>
      </div>
      {chevron && <ChevronRight className="h-4 w-4 shrink-0 text-slate-300" />}
    </div>
  );
}

function QuickAction({
  icon: Icon,
  label,
  sub,
  onClick,
  highlight,
}: {
  icon: typeof MessageSquare;
  label: string;
  sub: string;
  onClick: () => void;
  highlight?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'flex min-h-[76px] flex-col items-center justify-center gap-1 rounded-xl border px-2 py-2.5 outline-none transition active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-brand-500',
        highlight ? 'border-amber-300 bg-amber-50' : 'border-slate-200 bg-white shadow-card',
      )}
    >
      <Icon className={cn('h-5 w-5', highlight ? 'text-amber-600' : 'text-brand-600')} />
      <span className="text-[11px] font-bold text-slate-700">{label}</span>
      <span className="text-[9.5px] text-slate-400">{sub}</span>
    </button>
  );
}
