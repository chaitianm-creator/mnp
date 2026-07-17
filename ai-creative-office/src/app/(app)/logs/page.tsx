'use client';

// 活動ログ(AI社員同士の会話・処理ログ)
import { PageHeader } from '@/components/ui';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime } from '@/lib/utils';
import { motion } from 'framer-motion';
import Link from 'next/link';
import { useState } from 'react';

export default function LogsPage() {
  const logs = useOffice((s) => s.logs);
  const agents = useOffice((s) => s.agents);
  const [agentFilter, setAgentFilter] = useState('all');

  const filtered = agentFilter === 'all' ? logs : logs.filter((l) => l.agentId === agentFilter);

  return (
    <div>
      <PageHeader
        title="活動ログ"
        sub="AI社員たちの会話と処理の記録がリアルタイムで流れます"
        action={
          <select
            value={agentFilter}
            onChange={(e) => setAgentFilter(e.target.value)}
            className="rounded-lg border border-slate-200 bg-white px-2 py-1.5 text-xs outline-none"
          >
            <option value="all">すべてのAI社員</option>
            {agents.map((a) => (
              <option key={a.id} value={a.id}>{a.name}</option>
            ))}
          </select>
        }
      />

      {filtered.length === 0 && (
        <div className="rounded-xl border border-dashed border-slate-200 py-16 text-center text-sm text-slate-400">
          まだ活動履歴がありません。AI社員が働き始めると、ここに記録が流れます。
        </div>
      )}
      <div className={filtered.length === 0 ? 'hidden' : 'rounded-xl border border-slate-200 bg-white'}>
        <ul className="divide-y divide-slate-50">
          {filtered.slice(0, 100).map((log, i) => {
            const agent = agents.find((a) => a.id === log.agentId);
            return (
              <motion.li
                key={log.id}
                initial={i < 3 ? { opacity: 0, y: -6 } : false}
                animate={{ opacity: 1, y: 0 }}
                className="flex gap-3 px-4 py-3"
              >
                <div
                  className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-base"
                  style={{ backgroundColor: `${agent?.color ?? '#94a3b8'}18`, border: `1.5px solid ${agent?.color ?? '#94a3b8'}55` }}
                >
                  {agent?.avatar ?? '🤖'}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-xs font-bold text-slate-800">{agent?.name ?? log.agentId}</span>
                    <span
                      className={cn(
                        'rounded-full px-1.5 py-0.5 text-[9px] font-medium',
                        log.status === 'success' && 'bg-emerald-50 text-emerald-700',
                        log.status === 'info' && 'bg-sky-50 text-sky-600',
                        log.status === 'warning' && 'bg-amber-50 text-amber-700',
                        log.status === 'error' && 'bg-red-50 text-red-700',
                      )}
                    >
                      {log.status === 'success' ? '完了' : log.status === 'warning' ? '要確認' : log.status === 'error' ? 'エラー' : '情報'}
                    </span>
                    <span className="ml-auto text-[11px] tabular-nums text-slate-400">{formatDateTime(log.timestamp)}</span>
                  </div>
                  <p className="mt-0.5 text-sm text-slate-600">{log.message}</p>
                  <div className="mt-1 flex gap-3 text-[11px]">
                    {log.taskId && (
                      <Link href={`/tasks/${log.taskId}`} className="text-brand-600 hover:underline">関連タスク →</Link>
                    )}
                    {log.projectId && (
                      <Link href={`/projects/${log.projectId}`} className="text-brand-600 hover:underline">関連案件 →</Link>
                    )}
                  </div>
                </div>
              </motion.li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
