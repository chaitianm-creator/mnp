'use client';

// AI社員一覧(部署一覧を兼ねる)
import { AgentDetailPanel } from '@/components/agent-detail-panel';
import { AgentAvatar, AgentStatusBadge } from '@/components/agent-bits';
import { Card, PageHeader, ProgressBar } from '@/components/ui';
import { DEPARTMENTS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { DepartmentId } from '@/lib/types';
import { num, yen } from '@/lib/utils';
import { useState } from 'react';

export default function AgentsPage() {
  const agents = useOffice((s) => s.agents);
  const unread = useOffice((s) => s.unread);
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = agents.find((a) => a.id === selectedId) ?? null;

  return (
    <div>
      <PageHeader title="AI社員一覧" sub={`全${agents.length}名 / 6部署`} />
      <div className="space-y-6">
        {(Object.keys(DEPARTMENTS) as DepartmentId[]).map((deptId) => {
          const dept = DEPARTMENTS[deptId];
          const members = agents.filter((a) => a.departmentId === deptId);
          if (members.length === 0) return null;
          return (
            <section key={deptId}>
              <div className="mb-2 flex items-center gap-2">
                <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: dept.color }} />
                <h2 className="text-sm font-bold text-slate-700">{dept.name}</h2>
                <span className="text-xs text-slate-400">{members.length}名</span>
              </div>
              <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                {members.map((agent) => (
                  <Card key={agent.id} className="relative cursor-pointer p-4 transition hover:border-brand-300">
                    {(unread[agent.id] ?? 0) > 0 && (
                      <span
                        className="absolute -left-1.5 -top-1.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-brand-600 px-1.5 text-[10px] font-bold text-white shadow"
                        aria-label={`未読メッセージ ${unread[agent.id]}件`}
                      >
                        {unread[agent.id]}
                      </span>
                    )}
                    <button className="w-full text-left" onClick={() => setSelectedId(agent.id)}>
                      <div className="flex items-center gap-3">
                        <AgentAvatar agent={agent} />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-bold text-slate-900">{agent.name}</p>
                          <p className="truncate text-xs text-slate-400">{agent.trait ?? agent.role}</p>
                        </div>
                        <AgentStatusBadge agent={agent} />
                      </div>
                      <p className="mt-2 truncate text-xs text-slate-500">{agent.statusNote}</p>
                      <ProgressBar value={agent.progress} className="mt-2" />
                      <div className="mt-3 grid grid-cols-3 gap-2 border-t border-slate-100 pt-2 text-center">
                        <div>
                          <p className="text-[10px] text-slate-400">今日</p>
                          <p className="text-xs font-bold tabular-nums">{num(agent.todayCount)}件</p>
                        </div>
                        <div>
                          <p className="text-[10px] text-slate-400">今月</p>
                          <p className="text-xs font-bold tabular-nums">{num(agent.monthCount)}件</p>
                        </div>
                        <div>
                          <p className="text-[10px] text-slate-400">利用料</p>
                          <p className="text-xs font-bold tabular-nums">{yen(agent.costUsd * usdJpyRate)}</p>
                        </div>
                      </div>
                    </button>
                  </Card>
                ))}
              </div>
            </section>
          );
        })}
      </div>
      <AgentDetailPanel agent={selected} onClose={() => setSelectedId(null)} />
    </div>
  );
}
