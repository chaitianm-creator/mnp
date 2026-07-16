'use client';

// AI実働ランの状況カード(社長指示チャット内)
// 計画確認 → 承認 → 実行状況(タスク・トークン・料金) → 完了
import { executeRun, isRunActive } from '@/lib/agent-runner';
import { useOffice } from '@/lib/store';
import type { AgentRun, RunTask } from '@/lib/types';
import { cn, yen } from '@/lib/utils';
import { AlertTriangle, Check, CircleDashed, Loader2, Play, RotateCcw, X } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { MarkdownView } from './markdown-view';
import { Badge, Button } from './ui';

const TASK_AGENT_LABEL: Record<string, string> = {
  director: 'ディレクターAI',
  writer: 'ライターAI',
  reviewer: 'レビュアーAI',
};

const RUN_STATUS: Record<AgentRun['status'], { label: string; cls: string }> = {
  awaiting_approval: { label: '計画確認待ち', cls: 'bg-amber-50 text-amber-700' },
  running: { label: '実行中', cls: 'bg-emerald-50 text-emerald-700' },
  revising: { label: '修正中', cls: 'bg-orange-50 text-orange-700' },
  awaiting_cost_approval: { label: 'コスト上限で停止中', cls: 'bg-red-50 text-red-700' },
  done: { label: '完了', cls: 'bg-teal-50 text-teal-700' },
  failed: { label: 'エラーで停止', cls: 'bg-red-50 text-red-700' },
  cancelled: { label: 'キャンセル', cls: 'bg-slate-100 text-slate-500' },
};

function TaskRow({ task }: { task: RunTask }) {
  return (
    <div className="flex items-center gap-2 rounded-lg border border-slate-100 px-2.5 py-1.5 text-xs">
      {task.status === 'running' ? (
        <Loader2 className="h-3.5 w-3.5 animate-spin text-emerald-600" />
      ) : task.status === 'done' ? (
        <Check className="h-3.5 w-3.5 text-emerald-600" />
      ) : task.status === 'failed' ? (
        <AlertTriangle className="h-3.5 w-3.5 text-red-500" />
      ) : (
        <CircleDashed className="h-3.5 w-3.5 text-slate-300" />
      )}
      <span className="min-w-0 flex-1 truncate text-slate-700">{task.title}</span>
      <span className="shrink-0 rounded bg-slate-100 px-1.5 py-0.5 text-[10px] text-slate-500">
        {TASK_AGENT_LABEL[task.assignedAgentId] ?? task.assignedAgentId}
      </span>
      {task.actualInputTokens > 0 && (
        <span className="shrink-0 tabular-nums text-[10px] text-slate-400">
          {(task.actualInputTokens + task.actualOutputTokens).toLocaleString()}tok / ¥{task.actualCostJPY.toLocaleString()}
        </span>
      )}
      {task.retryCount > 0 && <span className="text-[10px] text-amber-600">再試行{task.retryCount}</span>}
    </div>
  );
}

export function RunCard({ runId, onModify }: { runId: string; onModify: (request: string) => void }) {
  const run = useOffice((s) => s.agentRuns.find((r) => r.id === runId));
  const updateAgentRun = useOffice((s) => s.updateAgentRun);
  const [showPlan, setShowPlan] = useState(false);
  const [busy, setBusy] = useState(false);
  if (!run) return null;
  const st = RUN_STATUS[run.status];
  const doneTasks = run.tasks.filter((t) => t.status === 'done').length;
  const progress = run.tasks.length > 0 ? Math.round((doneTasks / run.tasks.length) * 100) : 0;

  const start = async (ignoreCap = false) => {
    setBusy(true);
    try {
      await executeRun(run.id, { ignoreCap });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mt-3 rounded-xl border border-slate-200 bg-white p-3.5 text-slate-700">
      <div className="flex flex-wrap items-center gap-1.5">
        <p className="text-sm font-bold text-slate-900">🤖 AI実働ラン</p>
        <Badge className={st.cls}>{st.label}</Badge>
        <Badge className={run.isMock ? 'bg-slate-100 text-slate-500' : 'bg-brand-50 text-brand-700'}>
          {run.isMock ? 'デモ生成(モックAI)' : '実AI生成'}
        </Badge>
        <span className="ml-auto text-[10px] tabular-nums text-slate-400">
          {(run.totalInputTokens + run.totalOutputTokens).toLocaleString()} tokens / {yen(run.totalCostJpy)}
        </span>
      </div>

      <p className="mt-1.5 text-xs text-slate-500">{run.currentActivity}</p>
      {run.error && <p className="mt-1 rounded-lg bg-red-50 px-2.5 py-1.5 text-xs text-red-600">⚠️ {run.error}</p>}

      {/* 計画の確認 */}
      <button
        onClick={() => setShowPlan((v) => !v)}
        className="mt-2 text-[11px] font-medium text-brand-600 outline-none hover:underline focus-visible:ring-2 focus-visible:ring-brand-500"
        aria-expanded={showPlan}
      >
        {showPlan ? '実行計画を閉じる' : 'CEO AIの実行計画を確認する'}
      </button>
      {showPlan && (
        <div className="mt-2 max-h-72 overflow-y-auto rounded-lg border border-slate-100 bg-slate-50/60 p-3">
          <MarkdownView markdown={run.planMarkdown} />
        </div>
      )}

      {/* タスク一覧(依存順) */}
      <div className="mt-2.5 space-y-1.5">
        {run.tasks.map((t) => (
          <TaskRow key={t.id} task={t} />
        ))}
      </div>

      {/* 進捗 */}
      {run.status !== 'awaiting_approval' && (
        <div className="mt-2 flex items-center gap-2">
          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-slate-100">
            <div className="h-full rounded-full bg-gradient-to-r from-brand-500 to-accent-500 transition-all duration-700" style={{ width: `${progress}%` }} />
          </div>
          <span className="text-[10px] font-semibold tabular-nums text-slate-500">{progress}%</span>
        </div>
      )}

      {/* アクション */}
      <div className="mt-3 flex flex-wrap gap-2">
        {run.status === 'awaiting_approval' && (
          <>
            <Button onClick={() => start()} disabled={busy}>
              <Play className="h-3.5 w-3.5" /> この内容で開始
            </Button>
            <Button variant="secondary" onClick={() => onModify(run.request)} disabled={busy}>
              内容を修正
            </Button>
            <Button variant="secondary" onClick={() => onModify(`${run.request}\n\n【追加情報】\n(CEO AIの質問への回答をここに記入してください)`)} disabled={busy}>
              質問に回答する
            </Button>
            <Button variant="ghost" onClick={() => updateAgentRun(run.id, { status: 'cancelled', currentActivity: 'キャンセルされました' })} disabled={busy}>
              <X className="h-3.5 w-3.5" /> キャンセル
            </Button>
          </>
        )}
        {run.status === 'awaiting_cost_approval' && (
          <>
            <Button onClick={() => start(true)} disabled={busy}>
              追加コストを承認して続行
            </Button>
            <Button variant="ghost" onClick={() => updateAgentRun(run.id, { status: 'cancelled', currentActivity: 'キャンセルされました' })}>
              キャンセル
            </Button>
          </>
        )}
        {run.status === 'failed' && (
          <Button onClick={() => start()} disabled={busy}>
            <RotateCcw className="h-3.5 w-3.5" /> 再実行(続きから)
          </Button>
        )}
        {(run.status === 'running' || run.status === 'revising') && (
          <>
            {/* ページ再読み込みで中断されたラン(孤児ラン)は続きから再開できる */}
            {!isRunActive(run.id) && (
              <Button onClick={() => start()} disabled={busy}>
                <RotateCcw className="h-3.5 w-3.5" /> 中断地点から再開
              </Button>
            )}
            <Button
              variant="secondary"
              onClick={() => updateAgentRun(run.id, { status: 'cancelled', currentActivity: 'キャンセルされました(次の工程から停止)' })}
            >
              <X className="h-3.5 w-3.5" /> キャンセル
            </Button>
          </>
        )}
        {run.deliverableIds.length > 0 && (
          <Link
            href="/deliverables"
            className="inline-flex items-center gap-1 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-sm font-medium text-emerald-700 outline-none hover:bg-emerald-100 focus-visible:ring-2 focus-visible:ring-emerald-500"
          >
            成果物を確認({run.deliverableIds.length}件)
          </Link>
        )}
      </div>
    </div>
  );
}
