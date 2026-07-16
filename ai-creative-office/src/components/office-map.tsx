'use client';

// 2Dバーチャルオフィス
// - 部署ごとのエリアにAI社員のデスクを配置
// - 会議中は会議室へ、停止中は休憩スペースへ移動(framer-motionのlayoutIdで移動アニメーション)
import { AGENT_STATUS, DEPARTMENTS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, DepartmentId } from '@/lib/types';
import { cn } from '@/lib/utils';
import { LayoutGroup, motion } from 'framer-motion';
import { Armchair, Coffee, Crown, Presentation } from 'lucide-react';
import Link from 'next/link';
import { ProgressBar } from './ui';

const AREA_ORDER: { id: DepartmentId; className: string }[] = [
  { id: 'executive', className: '' },
  { id: 'secretary', className: '' },
  { id: 'sales', className: 'sm:col-span-2' },
  { id: 'marketing', className: '' },
  { id: 'production', className: 'sm:col-span-2' },
  { id: 'admin', className: '' },
];

function AgentDesk({ agent, onSelect }: { agent: Agent; onSelect: (a: Agent) => void }) {
  const st = AGENT_STATUS[agent.status];
  const busy = ['working', 'checking', 'delegating'].includes(agent.status);
  return (
    <motion.button
      layoutId={`agent-${agent.id}`}
      layout
      onClick={() => onSelect(agent)}
      whileHover={{ scale: 1.03 }}
      whileTap={{ scale: 0.97 }}
      transition={{ type: 'spring', damping: 25, stiffness: 260 }}
      className={cn(
        'w-full rounded-lg border bg-white px-2.5 py-2 text-left shadow-sm transition-colors',
        agent.status === 'waiting_approval'
          ? 'border-amber-300 ring-2 ring-amber-100'
          : agent.status === 'error'
            ? 'border-red-300 ring-2 ring-red-100'
            : 'border-slate-200 hover:border-brand-300',
      )}
    >
      <div className="flex items-center gap-2">
        <div
          className="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-base"
          style={{ backgroundColor: `${agent.color}18`, border: `1.5px solid ${agent.color}55` }}
        >
          {agent.avatar}
          <span
            className={cn(
              'absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-white',
              st.dot,
              busy && 'animate-pulse',
            )}
          />
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-xs font-bold text-slate-800">{agent.name}</p>
          <p className={cn('truncate text-[10px] font-medium', st.color)}>{st.label}</p>
        </div>
      </div>
      <p className="mt-1.5 truncate text-[10px] text-slate-500">{agent.statusNote}</p>
      {busy && <ProgressBar value={agent.progress} className="mt-1.5 h-1" />}
    </motion.button>
  );
}

export function OfficeMap({ onSelect }: { onSelect: (a: Agent) => void }) {
  const agents = useOffice((s) => s.agents);
  const ceoName = useOffice((s) => s.settings.ceoName);

  const atDesk = (dept: DepartmentId) =>
    agents.filter((a) => a.departmentId === dept && a.status !== 'meeting' && a.status !== 'paused');
  const inMeeting = agents.filter((a) => a.status === 'meeting');
  const onBreak = agents.filter((a) => a.status === 'paused');

  return (
    <LayoutGroup>
      <div className="rounded-2xl border border-slate-200 bg-gradient-to-br from-slate-100 via-indigo-50/50 to-purple-50/60 p-3 sm:p-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {/* 社長室 */}
          <div className="rounded-xl border border-brand-200/70 bg-white/70 p-3 backdrop-blur-sm">
            <AreaLabel icon={<Crown className="h-3.5 w-3.5" />} name="社長室" color="#6366f1" />
            <Link
              href="/chat"
              className="mt-2 flex items-center gap-2 rounded-lg border border-dashed border-brand-300 bg-brand-50/60 px-2.5 py-2 hover:bg-brand-50"
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-brand-300 bg-white text-base">
                🧑‍💼
              </div>
              <div>
                <p className="text-xs font-bold text-slate-800">{ceoName}(あなた)</p>
                <p className="text-[10px] text-brand-600">クリックでCEO AIへ指示</p>
              </div>
            </Link>
          </div>

          {/* 部署エリア */}
          {AREA_ORDER.map(({ id, className }) => {
            const dept = DEPARTMENTS[id];
            const members = atDesk(id);
            return (
              <div key={id} className={cn('rounded-xl border bg-white/70 p-3 backdrop-blur-sm', className)} style={{ borderColor: `${dept.color}44` }}>
                <AreaLabel icon={<Armchair className="h-3.5 w-3.5" />} name={dept.name} color={dept.color} />
                <div
                  className={cn(
                    'mt-2 grid gap-2',
                    className.includes('col-span-2') ? 'grid-cols-1 sm:grid-cols-3' : 'grid-cols-1',
                  )}
                >
                  {members.map((a) => (
                    <AgentDesk key={a.id} agent={a} onSelect={onSelect} />
                  ))}
                  {members.length === 0 && (
                    <p className="rounded-lg border border-dashed border-slate-200 py-3 text-center text-[10px] text-slate-400">
                      全員離席中
                    </p>
                  )}
                </div>
              </div>
            );
          })}

          {/* 会議室 */}
          <div className="rounded-xl border border-violet-200 bg-white/70 p-3 backdrop-blur-sm sm:col-span-2">
            <AreaLabel icon={<Presentation className="h-3.5 w-3.5" />} name="会議室" color="#8b5cf6" />
            <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-3">
              {inMeeting.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} />
              ))}
              {inMeeting.length === 0 && (
                <p className="col-span-full rounded-lg border border-dashed border-slate-200 py-3 text-center text-[10px] text-slate-400">
                  現在会議はありません
                </p>
              )}
            </div>
          </div>

          {/* 休憩スペース */}
          <div className="rounded-xl border border-teal-200 bg-white/70 p-3 backdrop-blur-sm">
            <AreaLabel icon={<Coffee className="h-3.5 w-3.5" />} name="休憩スペース" color="#14b8a6" />
            <div className="mt-2 grid grid-cols-1 gap-2">
              {onBreak.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} />
              ))}
              {onBreak.length === 0 && (
                <p className="rounded-lg border border-dashed border-slate-200 py-3 text-center text-[10px] text-slate-400">
                  休憩中の社員はいません
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </LayoutGroup>
  );
}

function AreaLabel({ icon, name, color }: { icon: React.ReactNode; name: string; color: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className="flex h-5 w-5 items-center justify-center rounded" style={{ backgroundColor: `${color}1c`, color }}>
        {icon}
      </span>
      <p className="text-xs font-bold text-slate-700">{name}</p>
    </div>
  );
}
