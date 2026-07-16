'use client';

// AI社員詳細パネル(バーチャルオフィス/AI社員一覧から共用)
import { AGENT_STATUS, DEPARTMENTS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent } from '@/lib/types';
import { formatDateTime, num, usd, yen } from '@/lib/utils';
import { AnimatePresence, motion } from 'framer-motion';
import { Send, X } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { AgentAvatar, AgentStatusBadge, DepartmentBadge } from './agent-bits';
import { Button, ProgressBar } from './ui';

export function AgentDetailPanel({ agent, onClose }: { agent: Agent | null; onClose: () => void }) {
  const tasks = useOffice((s) => s.tasks);
  const logs = useOffice((s) => s.logs);
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);
  const instructAgent = useOffice((s) => s.instructAgent);
  const [instruction, setInstruction] = useState('');
  const [sent, setSent] = useState(false);

  const currentTask = agent?.currentTaskId ? tasks.find((t) => t.id === agent.currentTaskId) : null;
  const agentLogs = agent ? logs.filter((l) => l.agentId === agent.id).slice(0, 8) : [];

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
            initial={{ x: 420, opacity: 0.5 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: 420, opacity: 0 }}
            transition={{ type: 'spring', damping: 28, stiffness: 300 }}
            className="fixed right-0 top-0 z-50 flex h-full w-full max-w-md flex-col overflow-y-auto border-l border-slate-200 bg-white shadow-panel"
          >
            <div className="sticky top-0 z-10 flex items-start justify-between gap-3 border-b border-slate-100 bg-white/95 px-5 py-4 backdrop-blur">
              <div className="flex items-center gap-3">
                <AgentAvatar agent={agent} size="lg" />
                <div>
                  <p className="text-base font-bold text-slate-900">{agent.name}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-1.5">
                    <DepartmentBadge departmentId={agent.departmentId} />
                    <AgentStatusBadge agent={agent} />
                  </div>
                </div>
              </div>
              <button onClick={onClose} className="rounded-lg p-1 hover:bg-slate-100" aria-label="閉じる">
                <X className="h-5 w-5 text-slate-500" />
              </button>
            </div>

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
                <MiniStat label="使用モデル" value={agent.model} small />
                <MiniStat
                  label="利用トークン数"
                  value={`${num(agent.inputTokens + agent.outputTokens)}`}
                />
                <MiniStat label="推定利用料金" value={`${yen(agent.costUsd * usdJpyRate)}`} sub={usd(agent.costUsd)} />
                <MiniStat label="ステータス" value={AGENT_STATUS[agent.status].label} />
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
                    className="min-w-0 flex-1 rounded-lg border border-slate-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand-400"
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && instruction.trim()) {
                        instructAgent(agent.id, instruction.trim());
                        setInstruction('');
                        setSent(true);
                        setTimeout(() => setSent(false), 2500);
                      }
                    }}
                  />
                  <Button
                    onClick={() => {
                      if (!instruction.trim()) return;
                      instructAgent(agent.id, instruction.trim());
                      setInstruction('');
                      setSent(true);
                      setTimeout(() => setSent(false), 2500);
                    }}
                  >
                    <Send className="h-3.5 w-3.5" />
                  </Button>
                </div>
                {sent && <p className="mt-1.5 text-[11px] text-emerald-600">指示をタスクとして登録しました。</p>}
              </section>

              <Link
                href={`/agents/${agent.id}`}
                className="block rounded-lg border border-slate-200 py-2 text-center text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                詳細ページを開く
              </Link>
            </div>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
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
