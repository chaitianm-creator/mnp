'use client';

// ライブオフィスの周辺ウィジェット:
// 今日の会社サマリー / CEOアナウンス / 社内ライブフィード / 進行中の主要タスク
import { selectDashboardStats, useOffice } from '@/lib/store';
import { cn, formatDateTime, timeAgo, todayKey, yen } from '@/lib/utils';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { ArrowRight, Megaphone } from 'lucide-react';
import Link from 'next/link';
import { memo } from 'react';
import { ProgressBar } from '../ui';

// ---------- 今日の会社サマリー(最大6項目に絞る) ----------

export const OfficeSummary = memo(function OfficeSummary() {
  const stats = useOffice(selectDashboardStats);
  const todayRevenue = useOffice(
    (s) => s.dailyStats.find((d) => d.date === todayKey())?.revenueJpy ?? 0,
  );

  const items: { label: string; value: string; tone?: 'warn' | 'danger' | 'good' }[] = [
    { label: '稼働中AI社員', value: `${stats.activeAgents}名` },
    { label: '完了タスク(今日)', value: `${stats.todayTasksDone}件` },
    { label: '承認待ち', value: `${stats.pendingApprovals}件`, tone: stats.pendingApprovals > 0 ? 'warn' : undefined },
    { label: 'エラー', value: `${stats.errorCount}件`, tone: stats.errorCount > 0 ? 'danger' : 'good' },
    { label: '今日の売上', value: yen(todayRevenue), tone: todayRevenue > 0 ? 'good' : undefined },
    { label: 'AI利用料(今月)', value: yen(stats.aiCostJpy) },
  ];

  return (
    <div className="flex flex-wrap items-center gap-2">
      {items.map((item) => (
        <div
          key={item.label}
          className="flex items-baseline gap-1.5 rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 shadow-card"
        >
          <span className="text-[10px] text-slate-400">{item.label}</span>
          <span
            className={cn(
              'text-sm font-bold tabular-nums',
              item.tone === 'warn' && 'text-amber-600',
              item.tone === 'danger' && 'text-red-600',
              item.tone === 'good' && 'text-emerald-600',
              !item.tone && 'text-slate-800',
            )}
          >
            {item.value}
          </span>
        </div>
      ))}
      <Link
        href="/dashboard"
        className="ml-auto flex items-center gap-1 text-xs font-medium text-brand-600 outline-none hover:underline focus-visible:ring-2 focus-visible:ring-brand-500"
      >
        詳細はダッシュボード <ArrowRight className="h-3 w-3" />
      </Link>
    </div>
  );
});

// ---------- CEO AI 全社アナウンス ----------

export function CeoAnnouncement() {
  const latest = useOffice((s) => s.announcements[0]);
  const reduced = useReducedMotion();
  if (!latest) return null;
  return (
    <div aria-live="polite">
      <AnimatePresence mode="wait">
        <motion.div
          key={latest.id}
          initial={reduced ? false : { opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={reduced ? undefined : { opacity: 0, y: 6 }}
          transition={{ duration: 0.35 }}
          className={cn(
            'flex items-center gap-2 rounded-xl border px-3 py-2 text-xs',
            latest.tone === 'warning' && 'border-amber-200 bg-amber-50 text-amber-800',
            latest.tone === 'success' && 'border-emerald-200 bg-emerald-50 text-emerald-800',
            latest.tone === 'info' && 'border-brand-100 bg-brand-50/70 text-brand-800',
          )}
        >
          <Megaphone className="h-3.5 w-3.5 shrink-0" />
          <span className="font-semibold">CEO AI:</span>
          <span className="min-w-0 flex-1 truncate">{latest.message}</span>
          <span className="shrink-0 text-[10px] opacity-60">{timeAgo(latest.createdAt)}</span>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}

// ---------- 社内ライブフィード ----------

export function LiveFeed({
  onSelectAgent,
  className,
  limit = 30,
}: {
  onSelectAgent: (agentId: string) => void;
  className?: string;
  limit?: number;
}) {
  const logs = useOffice((s) => s.logs);
  const agents = useOffice((s) => s.agents);
  const reduced = useReducedMotion();

  return (
    <div className={cn('flex flex-col rounded-2xl border border-slate-200 bg-white', className)}>
      <div className="flex items-center gap-2 border-b border-slate-100 px-4 py-3">
        <span className="relative flex h-2 w-2">
          <span className="absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75 motion-safe:animate-ping" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
        </span>
        <p className="text-sm font-semibold text-slate-800">社内ライブフィード</p>
        <Link href="/logs" className="ml-auto text-[11px] text-brand-600 hover:underline">
          すべて見る
        </Link>
      </div>
      <ul className="min-h-0 flex-1 space-y-1 overflow-y-auto px-2 py-2">
        {logs.length === 0 && (
          <li className="px-3 py-8 text-center text-xs text-slate-400">
            まだ活動履歴がありません。
            <br />
            CEOへ仕事を依頼すると、ここに記録が流れます。
          </li>
        )}
        <AnimatePresence initial={false}>
          {logs.slice(0, limit).map((log) => {
            const agent = agents.find((a) => a.id === log.agentId);
            return (
              <motion.li
                key={log.id}
                layout={!reduced}
                initial={reduced ? false : { opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3 }}
              >
                <div className="group flex gap-2 rounded-lg px-2 py-1.5 hover:bg-slate-50">
                  <button
                    onClick={() => onSelectAgent(log.agentId)}
                    aria-label={`${agent?.name ?? log.agentId}の詳細を開く`}
                    className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                    style={{
                      backgroundColor: `${agent?.color ?? '#94a3b8'}18`,
                      border: `1.5px solid ${agent?.color ?? '#94a3b8'}55`,
                    }}
                  >
                    {agent?.avatar ?? '🤖'}
                  </button>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => onSelectAgent(log.agentId)}
                        className="truncate text-[11px] font-bold text-slate-700 outline-none hover:text-brand-600 focus-visible:ring-2 focus-visible:ring-brand-500"
                      >
                        {agent?.name ?? log.agentId}
                      </button>
                      <span
                        className={cn(
                          'h-1.5 w-1.5 shrink-0 rounded-full',
                          log.status === 'success' && 'bg-emerald-500',
                          log.status === 'info' && 'bg-sky-400',
                          log.status === 'warning' && 'bg-amber-500',
                          log.status === 'error' && 'bg-red-500',
                        )}
                        aria-hidden
                      />
                      <span className="ml-auto shrink-0 text-[10px] tabular-nums text-slate-400">
                        {formatDateTime(log.timestamp)}
                      </span>
                    </div>
                    <p className="text-[11px] leading-snug text-slate-600">{log.message}</p>
                    {(log.taskId || log.projectId) && (
                      <div className="mt-0.5 flex gap-2">
                        {log.taskId && (
                          <Link href={`/tasks/${log.taskId}`} className="text-[10px] text-brand-600 hover:underline">
                            関連タスク →
                          </Link>
                        )}
                        {log.projectId && (
                          <Link href={`/projects/${log.projectId}`} className="text-[10px] text-brand-600 hover:underline">
                            関連案件 →
                          </Link>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              </motion.li>
            );
          })}
        </AnimatePresence>
      </ul>
    </div>
  );
}

// ---------- CEO AIから社長への呼びかけ(承認されるまで実行しない) ----------

export function CeoAlertBar() {
  const alerts = useOffice((s) => s.ceoAlerts);
  const decideAlert = useOffice((s) => s.decideAlert);
  const reduced = useReducedMotion();
  const newAlerts = alerts.filter((a) => a.status === 'new');
  const alert = newAlerts[0];
  if (!alert) return null;

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={alert.id}
        initial={reduced ? false : { opacity: 0, y: -6 }}
        animate={{ opacity: 1, y: 0 }}
        exit={reduced ? undefined : { opacity: 0 }}
        transition={{ duration: 0.3 }}
        role="region"
        aria-live="polite"
        aria-label="CEO AIからの呼びかけ"
        className={cn(
          'rounded-xl border bg-white p-3.5 shadow-card',
          alert.severity === 'high' ? 'border-amber-300' : 'border-brand-200',
        )}
      >
        <div className="flex flex-wrap items-start gap-3">
          <div className="min-w-0 flex-1">
            <p className="flex flex-wrap items-center gap-1.5 text-[10px] font-semibold text-slate-400">
              👔 CEO AIからの呼びかけ
              <span
                className={cn(
                  'rounded-full px-1.5 py-px text-[9px] font-bold',
                  alert.severity === 'high' ? 'bg-amber-100 text-amber-700' : 'bg-brand-50 text-brand-700',
                )}
              >
                {alert.severity === 'high' ? '重要' : '提案'}
              </span>
              {newAlerts.length > 1 && <span className="text-slate-400">他{newAlerts.length - 1}件</span>}
            </p>
            <p className="mt-1 text-[13px] font-bold text-slate-900">{alert.conclusion}</p>
            <p className="mt-0.5 text-[11px] text-slate-500">
              根拠: {alert.evidence.join(' / ')}
            </p>
            <p className="mt-0.5 text-[11px] text-slate-600">推奨: {alert.recommendation}</p>
            <p className="mt-0.5 text-[11px] text-emerald-600">想定効果: {alert.expectedEffect}</p>
            {alert.risk && <p className="mt-0.5 text-[11px] text-amber-600">リスク: {alert.risk}</p>}
          </div>
          <div className="flex shrink-0 flex-wrap gap-1.5">
            <button
              onClick={() => decideAlert(alert.id, 'accepted')}
              className="rounded-lg bg-gradient-to-r from-brand-600 to-accent-600 px-3 py-1.5 text-xs font-semibold text-white outline-none transition hover:opacity-90 focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              承認して実行
            </button>
            <button
              onClick={() => decideAlert(alert.id, 'later')}
              className="rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-600 outline-none hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              後で確認
            </button>
            <button
              onClick={() => decideAlert(alert.id, 'dismissed')}
              className="rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-400 outline-none hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              却下
            </button>
          </div>
        </div>
      </motion.div>
    </AnimatePresence>
  );
}

// ---------- 社内会話(AI社員同士の短い会話・重要イベント時のみ) ----------

export function TalkFeed({ onSelectAgent }: { onSelectAgent: (agentId: string) => void }) {
  const talks = useOffice((s) => s.agentTalks);
  const agents = useOffice((s) => s.agents);
  if (talks.length === 0) return null;

  return (
    <div className="rounded-2xl border border-slate-200 bg-white">
      <div className="border-b border-slate-100 px-4 py-3">
        <p className="text-sm font-semibold text-slate-800">社内会話</p>
        <p className="text-[10px] text-slate-400">AI社員同士のやりとり(重要イベント時のみ)</p>
      </div>
      <ul className="max-h-72 space-y-3 overflow-y-auto px-3 py-3">
        {talks.slice(0, 6).map((talk) => (
          <li key={talk.id} className="space-y-1.5 border-l-2 border-slate-100 pl-2">
            {talk.topic === 'standup' && (
              <span className="rounded-full bg-violet-50 px-1.5 py-px text-[9px] font-semibold text-violet-600">
                朝会・夕会
              </span>
            )}
            {talk.topic === 'achievement' && (
              <span className="rounded-full bg-emerald-50 px-1.5 py-px text-[9px] font-semibold text-emerald-600">
                成果報告
              </span>
            )}
            {talk.lines.map((line, i) => {
              const agent = agents.find((a) => a.id === line.agentId);
              return (
                <div key={i} className={cn('flex items-start gap-2', line.isReaction && 'pl-4 opacity-80')}>
                  <button
                    onClick={() => onSelectAgent(line.agentId)}
                    aria-label={`${agent?.name ?? line.agentId}の詳細を開く`}
                    className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                    style={{
                      backgroundColor: `${agent?.color ?? '#94a3b8'}18`,
                      border: `1.5px solid ${agent?.color ?? '#94a3b8'}55`,
                    }}
                  >
                    {agent?.avatar ?? '🤖'}
                  </button>
                  <div className="min-w-0 flex-1">
                    <p className="text-[10px] font-bold text-slate-600">{agent?.name ?? line.agentId}</p>
                    <p
                      className={cn(
                        'rounded-lg rounded-tl-sm px-2 py-1 text-[11px] leading-snug text-slate-600',
                        line.isReaction ? 'bg-white ring-1 ring-slate-100' : 'bg-slate-50',
                      )}
                    >
                      {line.text}
                    </p>
                  </div>
                </div>
              );
            })}
            <div className="flex items-center gap-2 pl-8">
              <span className="text-[9px] tabular-nums text-slate-300">{timeAgo(talk.timestamp)}</span>
              {talk.taskId && (
                <Link href={`/tasks/${talk.taskId}`} className="text-[10px] text-brand-600 hover:underline">
                  関連タスク →
                </Link>
              )}
              {talk.projectId && (
                <Link href={`/projects/${talk.projectId}`} className="text-[10px] text-brand-600 hover:underline">
                  関連案件 →
                </Link>
              )}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}

// ---------- 進行中の主要タスク ----------

export function RunningTasksBar() {
  const tasks = useOffice((s) => s.tasks);
  const agents = useOffice((s) => s.agents);
  const running = tasks
    .filter((t) => t.status === 'running')
    .sort((a, b) => (a.priority === 'urgent' ? -1 : 1) - (b.priority === 'urgent' ? -1 : 1))
    .slice(0, 4);
  if (running.length === 0) return null;

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-3">
      <p className="mb-2 text-xs font-semibold text-slate-500">現在進行中の主要タスク</p>
      <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
        {running.map((task) => {
          const agent = agents.find((a) => a.id === task.assigneeId);
          return (
            <Link
              key={task.id}
              href={`/tasks/${task.id}`}
              className="rounded-lg border border-slate-100 px-2.5 py-2 outline-none transition hover:border-brand-300 focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              <div className="flex items-center gap-1.5">
                <span className="text-sm" aria-hidden>{agent?.avatar}</span>
                <p className="truncate text-[11px] font-semibold text-slate-700">{task.title}</p>
              </div>
              <div className="mt-1.5 flex items-center gap-2">
                <ProgressBar value={task.progress} className="h-1 flex-1" />
                <span className="text-[10px] font-semibold tabular-nums text-slate-500">{task.progress}%</span>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
