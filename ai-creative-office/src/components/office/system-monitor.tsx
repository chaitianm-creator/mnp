'use client';

// AIカンパニーらしいシステムモニター(演出)
// 稼働AI数 / 並列処理数 / 処理待ちキュー / GPU使用率風メーター / Token使用量 / TPS
// 実データ(タスク・利用量)から導出し、ノイズだけクライアント側で付与する
import { useOffice } from '@/lib/store';
import { cn, todayKey } from '@/lib/utils';
import { Cpu } from 'lucide-react';
import { useEffect, useState } from 'react';

export function SystemMonitor() {
  const agents = useOffice((s) => s.agents);
  const tasks = useOffice((s) => s.tasks);
  const usage = useOffice((s) => s.usage);
  const demoMode = useOffice((s) => s.settings.demoMode);

  const active = agents.filter((a) => ['working', 'checking', 'delegating'].includes(a.status)).length;
  const parallel = tasks.filter((t) => t.status === 'running').length;
  const queued = tasks.filter((t) => t.status === 'queued' || t.status === 'preparing').length;
  const todayTokens = usage
    .filter((u) => u.executedAt.slice(0, 10) === todayKey())
    .reduce((acc, u) => acc + u.inputTokens + u.outputTokens, 0);

  // GPU使用率風の値: 稼働状況ベース + ゆらぎ(マウント後のみ動かしてSSR不一致を防ぐ)
  const base = Math.min(94, 18 + active * 6 + parallel * 2);
  const [noise, setNoise] = useState(0);
  const [tps, setTps] = useState(0);
  useEffect(() => {
    if (!demoMode) return;
    const id = setInterval(() => {
      setNoise(Math.round((Math.random() - 0.5) * 8));
      setTps(active > 0 ? 24 + Math.round(Math.random() * 30) : 0);
    }, 1800);
    return () => clearInterval(id);
  }, [demoMode, active]);
  const gpu = Math.max(4, Math.min(98, base + noise));

  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 rounded-xl border border-slate-200 bg-slate-900 px-3.5 py-2 font-mono text-[10px] text-slate-300">
      <span className="flex items-center gap-1.5 text-slate-400">
        <Cpu className="h-3 w-3" />
        SYSTEM
      </span>
      <Metric label="稼働AI" value={`${active}/${agents.length}`} />
      <Metric label="並列処理" value={String(parallel)} highlight={parallel > 6} />
      <Metric label="待機キュー" value={String(queued)} />
      <span className="flex items-center gap-1.5">
        <span className="text-slate-500">GPU</span>
        <span className="relative h-1.5 w-16 overflow-hidden rounded-full bg-slate-700">
          <span
            className={cn(
              'absolute inset-y-0 left-0 rounded-full transition-all duration-1000 ease-out',
              gpu > 80 ? 'bg-amber-400' : 'bg-emerald-400',
            )}
            style={{ width: `${gpu}%` }}
          />
        </span>
        <span className="tabular-nums text-slate-200">{gpu}%</span>
      </span>
      <Metric label="Tokens(今日)" value={todayTokens > 1000 ? `${(todayTokens / 1000).toFixed(1)}k` : String(todayTokens)} />
      <Metric label="TPS" value={String(tps)} />
      <span className={cn('ml-auto flex items-center gap-1', demoMode ? 'text-emerald-400' : 'text-slate-500')}>
        <span className={cn('h-1.5 w-1.5 rounded-full', demoMode ? 'bg-emerald-400 motion-safe:animate-pulse' : 'bg-slate-500')} />
        {demoMode ? 'LIVE' : 'PAUSED'}
      </span>
    </div>
  );
}

function Metric({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <span className="flex items-center gap-1.5">
      <span className="text-slate-500">{label}</span>
      <span className={cn('tabular-nums', highlight ? 'text-amber-300' : 'text-slate-200')}>{value}</span>
    </span>
  );
}
