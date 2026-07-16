'use client';

// スマホ版 AI社員一覧: 部署別グルーピング + 検索。タップで詳細(会話・プロフィール)
import { AgentAvatar, AgentStatusBadge } from '@/components/agent-bits';
import { ProgressBar } from '@/components/ui';
import { DEPARTMENTS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, DepartmentId } from '@/lib/types';
import { Search } from 'lucide-react';
import { useState } from 'react';

const DEPT_ORDER: DepartmentId[] = ['executive', 'secretary', 'sales', 'marketing', 'production', 'admin'];

export function MobileAgents({ onSelect }: { onSelect: (a: Agent) => void }) {
  const agents = useOffice((s) => s.agents);
  const unread = useOffice((s) => s.unread);
  const [query, setQuery] = useState('');

  const q = query.trim().toLowerCase();
  const filtered = q
    ? agents.filter((a) =>
        [a.name, a.role, a.displayName ?? '', a.nickname ?? '', a.description].join(' ').toLowerCase().includes(q),
      )
    : agents;

  const working = agents.filter((a) => ['working', 'checking', 'delegating', 'meeting'].includes(a.status)).length;

  return (
    <div className="flex h-full flex-col">
      {/* 検索(上部だが頻度低の操作なのでOK) */}
      <div className="shrink-0 border-b border-slate-200 bg-white px-3 pb-2 pt-2.5">
        <div className="flex items-center gap-2 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
          <Search className="h-4 w-4 shrink-0 text-slate-400" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="名前・役職で検索…"
            aria-label="AI社員を検索"
            className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-slate-400"
          />
        </div>
        <p className="mt-1.5 px-1 text-[10.5px] text-slate-400">
          全{agents.length}名 ・ 稼働中{working}名
        </p>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain pb-6">
        {DEPT_ORDER.map((deptId) => {
          const members = filtered.filter((a) => a.departmentId === deptId);
          if (members.length === 0) return null;
          return (
            <section key={deptId}>
              <p className="px-4 pb-1 pt-3 text-[11px] font-semibold text-slate-400">{DEPARTMENTS[deptId].name}</p>
              <div className="divide-y divide-slate-100 bg-white">
                {members.map((agent) => {
                  const count = unread[agent.id] ?? 0;
                  const busy = ['working', 'checking', 'delegating'].includes(agent.status);
                  return (
                    <button
                      key={agent.id}
                      onClick={() => onSelect(agent)}
                      aria-label={`${agent.name}の詳細を開く`}
                      className="flex w-full items-center gap-3 px-4 py-2.5 text-left outline-none active:bg-slate-50 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-500"
                    >
                      <div className="relative shrink-0">
                        <AgentAvatar agent={agent} size="sm" />
                        {count > 0 && (
                          <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand-600 px-1 text-[9px] font-bold text-white">
                            {count}
                          </span>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1.5">
                          <p className="truncate text-[13px] font-bold text-slate-800">{agent.displayName ?? agent.name}</p>
                          <AgentStatusBadge agent={agent} />
                        </div>
                        <p className="mt-0.5 truncate text-[10.5px] text-slate-400">{agent.statusNote}</p>
                        {busy && <ProgressBar value={agent.progress} className="mt-1 h-1" />}
                      </div>
                    </button>
                  );
                })}
              </div>
            </section>
          );
        })}
        {filtered.length === 0 && (
          <p className="px-4 py-12 text-center text-[12px] text-slate-400">「{query}」に一致するAI社員はいません。</p>
        )}
      </div>
    </div>
  );
}
