'use client';

// バーチャルオフィス
import { AgentDetailPanel } from '@/components/agent-detail-panel';
import { OfficeMap } from '@/components/office-map';
import { Badge, PageHeader } from '@/components/ui';
import { AGENT_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, AgentStatus } from '@/lib/types';
import { cn, formatDateTime } from '@/lib/utils';
import { useState } from 'react';

export default function OfficePage() {
  const agents = useOffice((s) => s.agents);
  const logs = useOffice((s) => s.logs);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = agents.find((a) => a.id === selectedId) ?? null;
  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;

  const counts = agents.reduce<Record<string, number>>((acc, a) => {
    acc[a.status] = (acc[a.status] ?? 0) + 1;
    return acc;
  }, {});

  return (
    <div>
      <PageHeader
        title="バーチャルオフィス"
        sub="AI社員をクリックすると詳細と個別指示ができます"
        action={
          <div className="flex flex-wrap gap-1.5">
            {(Object.keys(AGENT_STATUS) as AgentStatus[])
              .filter((k) => counts[k])
              .map((k) => (
                <Badge key={k} className={cn(AGENT_STATUS[k].bg, AGENT_STATUS[k].color)}>
                  {AGENT_STATUS[k].label} {counts[k]}
                </Badge>
              ))}
          </div>
        }
      />

      <div className="grid gap-4 xl:grid-cols-[1fr_320px]">
        <OfficeMap onSelect={(a: Agent) => setSelectedId(a.id)} />

        {/* サイド: 社内タイムライン */}
        <div className="rounded-2xl border border-slate-200 bg-white">
          <div className="border-b border-slate-100 px-4 py-3">
            <p className="text-sm font-semibold text-slate-800">社内タイムライン</p>
            <p className="text-xs text-slate-400">AI社員の最新の動き</p>
          </div>
          <ul className="max-h-[560px] space-y-2.5 overflow-y-auto px-4 py-3 xl:max-h-[calc(100vh-220px)]">
            {logs.slice(0, 40).map((log) => (
              <li key={log.id} className="text-xs">
                <div className="flex items-center gap-1.5">
                  <span
                    className={cn(
                      'h-1.5 w-1.5 shrink-0 rounded-full',
                      log.status === 'success' && 'bg-emerald-500',
                      log.status === 'info' && 'bg-sky-400',
                      log.status === 'warning' && 'bg-amber-500',
                      log.status === 'error' && 'bg-red-500',
                    )}
                  />
                  <span className="font-semibold text-slate-700">{agentName(log.agentId)}</span>
                  <span className="ml-auto tabular-nums text-slate-400">{formatDateTime(log.timestamp)}</span>
                </div>
                <p className="mt-0.5 pl-3 text-slate-600">{log.message}</p>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <AgentDetailPanel agent={selected} onClose={() => setSelectedId(null)} />
    </div>
  );
}
