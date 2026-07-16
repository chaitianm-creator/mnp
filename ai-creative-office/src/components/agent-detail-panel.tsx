'use client';

// AI社員詳細パネル(バーチャルオフィス/AI社員一覧から共用)
// - Escで閉じる / 開いた時にフォーカス移動 / 簡易フォーカストラップ対応
import { AGENT_STATUS } from '@/lib/labels';
import { agentZoneLabel } from '@/lib/office';
import { useOffice } from '@/lib/store';
import type { Agent } from '@/lib/types';
import { formatDateTime, num, usd, yen } from '@/lib/utils';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { MapPin, Pause, Play, Send, X } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { AgentAvatar, AgentStatusBadge, DepartmentBadge } from './agent-bits';
import { AgentChat } from './agent-chat';
import { Button, ProgressBar } from './ui';
import { cn } from '@/lib/utils';

export function AgentDetailPanel({ agent, onClose }: { agent: Agent | null; onClose: () => void }) {
  const tasks = useOffice((s) => s.tasks);
  const logs = useOffice((s) => s.logs);
  const projects = useOffice((s) => s.projects);
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);
  const instructAgent = useOffice((s) => s.instructAgent);
  const pauseAgent = useOffice((s) => s.pauseAgent);
  const resumeAgent = useOffice((s) => s.resumeAgent);
  const reduced = useReducedMotion();
  const panelRef = useRef<HTMLElement>(null);
  const [instruction, setInstruction] = useState('');
  const [sent, setSent] = useState(false);
  const [tab, setTab] = useState<'chat' | 'profile'>('chat');

  // 別の社員を開いたら会話タブに戻す
  useEffect(() => setTab('chat'), [agent?.id]);

  // Escで閉じる + 簡易フォーカストラップ
  useEffect(() => {
    if (!agent) return;
    panelRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'Tab' && panelRef.current) {
        const focusables = panelRef.current.querySelectorAll<HTMLElement>(
          'button, [href], input, textarea, select, [tabindex]:not([tabindex="-1"])',
        );
        if (focusables.length === 0) return;
        const first = focusables[0];
        const last = focusables[focusables.length - 1];
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [agent?.id, onClose]);

  const currentTask = agent?.currentTaskId ? tasks.find((t) => t.id === agent.currentTaskId) : null;
  const agentLogs = agent ? logs.filter((l) => l.agentId === agent.id).slice(0, 8) : [];
  const doneCount = agent ? tasks.filter((t) => t.assigneeId === agent.id && t.status === 'done').length : 0;
  const errorCount = agent
    ? logs.filter((l) => l.agentId === agent.id && l.status === 'error').length
    : 0;
  const assignedProjects = agent ? projects.filter((p) => p.memberIds.includes(agent.id)) : [];
  const latestAchievement = useOffice((s) =>
    agent ? s.achievements.find((a) => a.agentId === agent.id) : undefined,
  );

  const sendInstruction = () => {
    if (!agent || !instruction.trim()) return;
    instructAgent(agent.id, instruction.trim());
    setInstruction('');
    setSent(true);
    setTimeout(() => setSent(false), 2500);
  };

  return (
    <AnimatePresence>
      {agent && (
        <>
          <motion.div
            key="backdrop"
            className="fixed inset-0 z-50 bg-slate-900/30 lg:bg-transparent"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.aside
            key="panel"
            ref={panelRef}
            role="dialog"
            aria-modal="true"
            aria-label={`${agent.name}の詳細`}
            tabIndex={-1}
            initial={reduced ? { opacity: 0 } : { x: 420, opacity: 0.5 }}
            animate={reduced ? { opacity: 1 } : { x: 0, opacity: 1 }}
            exit={reduced ? { opacity: 0 } : { x: 420, opacity: 0 }}
            transition={reduced ? { duration: 0.1 } : { type: 'spring', damping: 28, stiffness: 300 }}
            className="fixed right-0 top-0 z-50 flex h-full w-full max-w-md flex-col border-l border-slate-200 bg-white shadow-panel outline-none"
          >
            <div className="z-10 flex items-start justify-between gap-3 border-b border-slate-100 bg-white/95 px-5 py-4 backdrop-blur">
              <div className="flex items-center gap-3">
                <AgentAvatar agent={agent} size="lg" />
                <div>
                  <p className="text-base font-bold text-slate-900">
                    {agent.name}
                    {agent.nickname && (
                      <span className="ml-1.5 text-xs font-medium text-slate-400">「{agent.nickname}」</span>
                    )}
                  </p>
                  <div className="mt-1 flex flex-wrap items-center gap-1.5">
                    <DepartmentBadge departmentId={agent.departmentId} />
                    <AgentStatusBadge agent={agent} />
                  </div>
                  <p className="mt-1 flex items-center gap-1 text-[11px] text-slate-500">
                    <MapPin className="h-3 w-3" /> {agentZoneLabel(agent)} ・ {agent.statusNote}
                  </p>
                </div>
              </div>
              <button
                onClick={onClose}
                className="rounded-lg p-1 outline-none hover:bg-slate-100 focus-visible:ring-2 focus-visible:ring-brand-500"
                aria-label="詳細パネルを閉じる"
              >
                <X className="h-5 w-5 text-slate-500" />
              </button>
            </div>

            {/* タブ */}
            <div className="flex gap-1 border-b border-slate-100 px-5 pt-2" role="tablist" aria-label="表示切り替え">
              {(
                [
                  ['chat', '会話'],
                  ['profile', 'プロフィール'],
                ] as const
              ).map(([key, label]) => (
                <button
                  key={key}
                  role="tab"
                  aria-selected={tab === key}
                  onClick={() => setTab(key)}
                  className={cn(
                    'rounded-t-lg border-b-2 px-3 py-1.5 text-xs font-semibold outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand-500',
                    tab === key ? 'border-brand-600 text-brand-700' : 'border-transparent text-slate-400 hover:text-slate-600',
                  )}
                >
                  {label}
                </button>
              ))}
            </div>

            {/* 会話タブ */}
            {tab === 'chat' && (
              <div className="min-h-0 flex-1 px-4 pb-3">
                <AgentChat agent={agent} onClose={onClose} />
              </div>
            )}

            {/* プロフィールタブ */}
            <div className={cn('min-h-0 flex-1 overflow-y-auto', tab !== 'profile' && 'hidden')}>
            <div className="space-y-5 px-5 py-4">
              <section>
                <p className="text-xs text-slate-500">{agent.description}</p>
                <div className="mt-2 flex flex-wrap gap-1">
                  {agent.responsibilities.map((r) => (
                    <span key={r} className="rounded-md bg-slate-100 px-1.5 py-0.5 text-[10px] text-slate-600">
                      {r}
                    </span>
                  ))}
                </div>
              </section>

              {/* 個性・得意分野 */}
              {(agent.trait || agent.strengths) && (
                <section className="rounded-lg border border-slate-100 bg-gradient-to-br from-brand-50/40 to-accent-400/5 p-3">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs font-semibold text-slate-600">✨ 特徴: {agent.trait}</p>
                    {agent.signatureStat && (
                      <p className="rounded-full bg-white px-2 py-0.5 text-[10px] font-bold text-brand-700 shadow-sm">
                        {agent.signatureStat.label} {agent.signatureStat.value}
                      </p>
                    )}
                  </div>
                  {agent.strengths && (
                    <div className="mt-2">
                      <p className="text-[10px] text-slate-400">得意業務</p>
                      <div className="mt-0.5 flex flex-wrap gap-1">
                        {agent.strengths.map((sk) => (
                          <span key={sk} className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] text-emerald-700">
                            {sk}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                  {agent.weaknesses && agent.weaknesses.length > 0 && (
                    <div className="mt-1.5">
                      <p className="text-[10px] text-slate-400">苦手業務</p>
                      <div className="mt-0.5 flex flex-wrap gap-1">
                        {agent.weaknesses.map((sk) => (
                          <span key={sk} className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] text-slate-500">
                            {sk}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                  {/* 集中度・疲労度 */}
                  <div className="mt-3 grid grid-cols-2 gap-3">
                    <Meter label="集中度" value={agent.focus ?? 75} color="#6366f1" />
                    <Meter label="疲労度" value={agent.fatigue ?? 20} color={(agent.fatigue ?? 20) > 65 ? '#ef4444' : '#f59e0b'} />
                  </div>
                  {agent.weeklyHighlight && (
                    <p className="mt-3 rounded-lg bg-white px-2.5 py-1.5 text-[11px] text-slate-600 shadow-sm">
                      🏆 <span className="font-semibold">今週の成果:</span> {agent.weeklyHighlight}
                    </p>
                  )}
                </section>
              )}

              {/* 担当案件 */}
              {assignedProjects.length > 0 && (
                <section>
                  <p className="mb-2 text-xs font-semibold text-slate-500">担当案件</p>
                  <div className="space-y-1.5">
                    {assignedProjects.map((p) => (
                      <Link
                        key={p.id}
                        href={`/projects/${p.id}`}
                        className="flex items-center gap-2 rounded-lg border border-slate-100 px-2.5 py-2 outline-none transition-colors hover:border-brand-300 focus-visible:ring-2 focus-visible:ring-brand-500"
                      >
                        <span className="min-w-0 flex-1 truncate text-xs font-medium text-slate-700">{p.name}</span>
                        <span className="shrink-0 rounded-full bg-brand-50 px-2 py-0.5 text-[10px] text-brand-700">{p.phase}</span>
                        <span className="shrink-0 text-[10px] tabular-nums text-slate-400">{p.progress}%</span>
                      </Link>
                    ))}
                  </div>
                </section>
              )}

              <section className="rounded-lg border border-slate-100 bg-slate-50 p-3">
                <p className="text-xs font-semibold text-slate-500">現在のタスク</p>
                {currentTask ? (
                  <div className="mt-1.5">
                    <Link href={`/tasks/${currentTask.id}`} className="text-sm font-medium text-brand-700 hover:underline">
                      {currentTask.title}
                    </Link>
                    <div className="mt-2 flex items-center gap-2">
                      <ProgressBar value={currentTask.progress} className="flex-1" />
                      <span className="text-xs font-semibold tabular-nums text-slate-600">
                        {currentTask.progress}%
                      </span>
                    </div>
                  </div>
                ) : (
                  <p className="mt-1 text-sm text-slate-400">{agent.statusNote}</p>
                )}
              </section>

              <section className="grid grid-cols-2 gap-2">
                <MiniStat label="今日の処理件数" value={`${num(agent.todayCount)}件`} />
                <MiniStat label="今月の処理件数" value={`${num(agent.monthCount)}件`} />
                <MiniStat label="完了タスク数" value={`${num(doneCount)}件`} />
                <MiniStat label="エラー数" value={`${num(errorCount)}件`} />
                <MiniStat label="使用モデル" value={agent.model} small />
                <MiniStat label="ステータス" value={AGENT_STATUS[agent.status].label} />
                <MiniStat
                  label="利用トークン数"
                  value={`${num(agent.inputTokens + agent.outputTokens)}`}
                  sub={`入力 ${num(agent.inputTokens)} / 出力 ${num(agent.outputTokens)}`}
                />
                <MiniStat label="推定利用料金" value={`${yen(agent.costUsd * usdJpyRate)}`} sub={usd(agent.costUsd)} />
              </section>

              <section>
                <p className="mb-2 text-xs font-semibold text-slate-500">成果(KPI)</p>
                <div className="grid grid-cols-2 gap-2">
                  {agent.kpis.map((k) => (
                    <div key={k.label} className="rounded-lg border border-slate-100 px-2.5 py-2">
                      <p className="truncate text-[10px] text-slate-400">{k.label}</p>
                      <p className="text-sm font-bold tabular-nums text-slate-800">
                        {k.unit === '円' ? yen(k.value) : `${num(k.value)}${k.unit ?? ''}`}
                      </p>
                    </div>
                  ))}
                </div>
              </section>

              {/* 勤務履歴(概算・デモデータと当日イベントから算出) */}
              <section>
                <p className="mb-2 text-xs font-semibold text-slate-500">本日の勤務履歴(概算)</p>
                <WorkHistory agent={agent} doneCount={doneCount} errorCount={errorCount} costJpy={agent.costUsd * usdJpyRate} latestAchievement={latestAchievement?.title ?? null} />
              </section>

              <section>
                <p className="mb-2 text-xs font-semibold text-slate-500">最近の活動ログ</p>
                <ul className="space-y-1.5">
                  {agentLogs.length === 0 && <p className="text-xs text-slate-400">ログはまだありません</p>}
                  {agentLogs.map((l) => (
                    <li key={l.id} className="flex gap-2 text-xs">
                      <span className="shrink-0 tabular-nums text-slate-400">{formatDateTime(l.timestamp)}</span>
                      <span className="text-slate-600">{l.message}</span>
                    </li>
                  ))}
                </ul>
              </section>

              <section className="rounded-lg border border-brand-100 bg-brand-50/50 p-3">
                <p className="text-xs font-semibold text-slate-600">このAI社員へ個別指示</p>
                <div className="mt-2 flex gap-2">
                  <input
                    value={instruction}
                    onChange={(e) => setInstruction(e.target.value)}
                    placeholder="例: 明日までに競合3社を調査して"
                    aria-label="個別指示の入力"
                    className="min-w-0 flex-1 rounded-lg border border-slate-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand-400"
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.nativeEvent.isComposing) sendInstruction();
                    }}
                  />
                  <Button onClick={sendInstruction}>
                    <Send className="h-3.5 w-3.5" />
                  </Button>
                </div>
                {sent && <p className="mt-1.5 text-[11px] text-emerald-600">指示をタスクとして登録しました。</p>}
              </section>

              <div className="flex gap-2">
                {agent.status === 'paused' ? (
                  <Button variant="success" className="flex-1" onClick={() => resumeAgent(agent.id)}>
                    <Play className="h-3.5 w-3.5" /> 再開する
                  </Button>
                ) : (
                  <Button variant="secondary" className="flex-1" onClick={() => pauseAgent(agent.id)}>
                    <Pause className="h-3.5 w-3.5" /> 一時停止
                  </Button>
                )}
                <Link
                  href={`/agents/${agent.id}`}
                  className="flex flex-1 items-center justify-center rounded-lg border border-slate-200 py-2 text-center text-sm font-medium text-slate-600 outline-none hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                >
                  詳細ページを開く
                </Link>
              </div>
            </div>
            </div>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}

// 勤務履歴(概算): 処理件数・疲労度・現在時刻から導出する。稼働と待機を分けて表示
function WorkHistory({
  agent,
  doneCount,
  errorCount,
  costJpy,
  latestAchievement,
}: {
  agent: Agent;
  doneCount: number;
  errorCount: number;
  costJpy: number;
  latestAchievement: string | null;
}) {
  const now = new Date();
  const startHour = 9;
  const elapsedMin = Math.max(0, (now.getHours() - startHour) * 60 + now.getMinutes());
  const workMin = Math.min(elapsedMin, agent.todayCount * 14);
  const meetingMin = agent.status === 'meeting' ? 30 : 15;
  const idleMin = Math.max(0, elapsedMin - workMin - meetingMin);
  const breaks = Math.max(1, Math.floor((agent.fatigue ?? 20) / 30));
  const fmt = (min: number) => (min >= 60 ? `${Math.floor(min / 60)}時間${min % 60}分` : `${min}分`);
  const rows: [string, string][] = [
    ['本日の開始', '09:00(出社)'],
    ['作業時間', fmt(workMin)],
    ['待機時間', fmt(idleMin)],
    ['会議時間', fmt(meetingMin)],
    ['休憩回数', `${breaks}回`],
    ['完了タスク', `${doneCount}件`],
    ['エラー', `${errorCount}件`],
    ['利用料金', yen(costJpy)],
  ];
  return (
    <div>
      <dl className="grid grid-cols-2 gap-x-4 divide-slate-50 rounded-lg border border-slate-100 px-3 py-2 text-[11px]">
        {rows.map(([label, value]) => (
          <div key={label} className="flex items-center justify-between py-1">
            <dt className="text-slate-400">{label}</dt>
            <dd className="font-semibold tabular-nums text-slate-700">{value}</dd>
          </div>
        ))}
      </dl>
      {latestAchievement && (
        <p className="mt-1.5 rounded-lg bg-emerald-50/60 px-2.5 py-1.5 text-[11px] text-emerald-700">
          主な成果: {latestAchievement}
        </p>
      )}
      <p className="mt-1 text-[10px] text-slate-400">※ 稼働と待機を分けた概算値です(デモデータ基準)</p>
    </div>
  );
}

function Meter({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div>
      <div className="flex items-center justify-between">
        <p className="text-[10px] text-slate-400">{label}</p>
        <p className="text-[10px] font-semibold tabular-nums text-slate-600">{Math.round(value)}%</p>
      </div>
      <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-slate-100">
        <div
          className="h-full rounded-full transition-all duration-1000 ease-out"
          style={{ width: `${Math.min(100, Math.max(0, value))}%`, backgroundColor: color }}
        />
      </div>
    </div>
  );
}

function MiniStat({ label, value, sub, small }: { label: string; value: string; sub?: string; small?: boolean }) {
  return (
    <div className="rounded-lg border border-slate-100 px-2.5 py-2">
      <p className="text-[10px] text-slate-400">{label}</p>
      <p className={small ? 'truncate text-xs font-semibold text-slate-700' : 'text-sm font-bold tabular-nums text-slate-800'}>
        {value}
      </p>
      {sub && <p className="text-[10px] text-slate-400">{sub}</p>}
    </div>
  );
}
