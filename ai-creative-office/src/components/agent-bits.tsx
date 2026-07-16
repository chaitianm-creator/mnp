'use client';

import { AGENT_STATUS, DEPARTMENTS } from '@/lib/labels';
import type { Agent } from '@/lib/types';
import { cn } from '@/lib/utils';
import { Badge } from './ui';

export function AgentAvatar({ agent, size = 'md' }: { agent: Agent; size?: 'sm' | 'md' | 'lg' }) {
  const sizes = { sm: 'h-8 w-8 text-base', md: 'h-10 w-10 text-lg', lg: 'h-14 w-14 text-2xl' };
  return (
    <div
      className={cn('relative flex shrink-0 items-center justify-center rounded-full', sizes[size])}
      style={{ backgroundColor: `${agent.color}18`, border: `2px solid ${agent.color}55` }}
    >
      <span aria-hidden>{agent.avatar}</span>
      <span
        className={cn(
          'absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-white',
          AGENT_STATUS[agent.status].dot,
          (agent.status === 'working' || agent.status === 'checking' || agent.status === 'delegating') &&
            'animate-pulse',
        )}
      />
    </div>
  );
}

export function AgentStatusBadge({ agent }: { agent: Agent }) {
  const s = AGENT_STATUS[agent.status];
  return <Badge className={cn(s.bg, s.color)}>{s.label}</Badge>;
}

export function DepartmentBadge({ departmentId }: { departmentId: Agent['departmentId'] }) {
  const d = DEPARTMENTS[departmentId];
  return (
    <Badge className="bg-slate-100 text-slate-600">
      <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: d.color }} />
      {d.name}
    </Badge>
  );
}
