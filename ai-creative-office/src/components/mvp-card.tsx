'use client';

// 今日のMVP AI社員(実績データから算出・根拠を確認できる)
import { scoreMVPAgent } from '@/lib/conversation';
import { useOffice } from '@/lib/store';
import { cn, num } from '@/lib/utils';
import { Award, ChevronDown, ChevronUp } from 'lucide-react';
import Link from 'next/link';
import { useMemo, useState } from 'react';
import { AgentAvatar } from './agent-bits';

export function MvpCard() {
  const agents = useOffice((s) => s.agents);
  const tasks = useOffice((s) => s.tasks);
  const logs = useOffice((s) => s.logs);
  const achievements = useOffice((s) => s.achievements);
  const settings = useOffice((s) => s.settings);
  const projects = useOffice((s) => s.projects);
  const approvals = useOffice((s) => s.approvals);
  const errors = useOffice((s) => s.errors);
  const inquiries = useOffice((s) => s.inquiries);
  const leads = useOffice((s) => s.leads);
  const dailyStats = useOffice((s) => s.dailyStats);
  const [showBasis, setShowBasis] = useState(false);

  // 毎tickの再計算を避け、主要データの変化時のみ再算出する
  const mvp = useMemo(
    () => scoreMVPAgent({ agents, tasks, logs, projects, approvals, errors, inquiries, leads, dailyStats, settings }, achievements),
    [tasks.length, achievements.length, logs.length],
  );
  const agent = mvp ? agents.find((a) => a.id === mvp.agentId) : null;

  // 実績がまだない初回状態(スコア0以下は「実績なし」とみなす)
  if (!mvp || !agent || mvp.score <= 0) {
    return (
      <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-card">
        <div className="flex items-center gap-3">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-100 text-slate-400">
            <Award className="h-4 w-4" />
          </span>
          <div>
            <p className="text-[10px] font-semibold tracking-wide text-slate-400">今日のMVP AI社員(実績データから算出)</p>
            <p className="mt-0.5 text-sm text-slate-400">まだデータがありません</p>
          </div>
        </div>
      </div>
    );
  }

  const topAchievement = achievements.find((a) => a.agentId === agent.id);
  const topReasons = [...mvp.reasons].sort((a, b) => b.points - a.points).slice(0, 2);

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-card">
      <div className="flex flex-wrap items-center gap-3">
        <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-amber-100 to-amber-50 text-amber-600">
          <Award className="h-4 w-4" />
        </span>
        <div className="min-w-0">
          <p className="text-[10px] font-semibold tracking-wide text-slate-400">今日のMVP AI社員(実績データから算出)</p>
          <div className="flex items-center gap-2">
            <AgentAvatar agent={agent} size="sm" />
            <p className="text-sm font-bold text-slate-900">{agent.name}</p>
            <span className="text-xs text-slate-400">{agent.role}</span>
          </div>
        </div>
        <div className="ml-auto flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
          <span className="text-slate-500">
            本日 <span className="font-bold tabular-nums text-slate-800">{num(agent.todayCount)}件</span>
          </span>
          {topAchievement && <span className="truncate text-emerald-600">🏆 {topAchievement.title}</span>}
          <Link href={`/agents/${agent.id}`} className="text-brand-600 hover:underline">
            詳細を見る
          </Link>
        </div>
      </div>
      <p className="mt-2 text-[11px] text-slate-500">
        選出理由: {topReasons.map((r) => `${r.label} ${r.value}`).join('、')}を評価しました。
      </p>
      <button
        onClick={() => setShowBasis((v) => !v)}
        aria-expanded={showBasis}
        className="mt-1.5 flex items-center gap-1 text-[10px] font-medium text-brand-600 outline-none hover:underline focus-visible:ring-2 focus-visible:ring-brand-500"
      >
        {showBasis ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
        算出根拠を{showBasis ? '閉じる' : '見る'}
      </button>
      {showBasis && (
        <dl className="mt-2 divide-y divide-slate-50 rounded-lg border border-slate-100 text-[11px]">
          {mvp.reasons.map((r) => (
            <div key={r.label} className="flex items-center justify-between px-3 py-1.5">
              <dt className="text-slate-500">{r.label}</dt>
              <dd className="flex items-center gap-3">
                <span className="tabular-nums text-slate-700">{r.value}</span>
                <span className={cn('w-12 text-right font-semibold tabular-nums', r.points >= 0 ? 'text-emerald-600' : 'text-red-500')}>
                  {r.points >= 0 ? '+' : ''}
                  {r.points}pt
                </span>
              </dd>
            </div>
          ))}
          <div className="flex items-center justify-between bg-slate-50 px-3 py-1.5 font-semibold">
            <dt className="text-slate-600">合計スコア</dt>
            <dd className="tabular-nums text-slate-800">{mvp.score}pt</dd>
          </div>
        </dl>
      )}
    </div>
  );
}
