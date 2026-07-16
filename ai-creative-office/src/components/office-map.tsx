'use client';

// ============================================================
// ライブバーチャルオフィス(2D)
// - 12エリア(社長室/CEO席/秘書席/4部署/会議室/プロジェクトテーブル/
//   承認待ちスペース/サーバールーム/休憩スペース)
// - AI社員は status/zone に応じてエリア間を移動する
//   (framer-motion の layoutId により自然な移動アニメーション)
// - 家具・装飾は CSS/絵文字で軽量に表現(外部画像なし)
// ============================================================
import { agentZone, currentPeriod, PERIOD_META } from '@/lib/office';
import { AGENT_STATUS, DEPARTMENTS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, DepartmentId, OfficeZone } from '@/lib/types';
import { cn } from '@/lib/utils';
import { LayoutGroup, motion, useReducedMotion } from 'framer-motion';
import {
  AlertTriangle,
  Armchair,
  CheckCircle2,
  Coffee,
  Crown,
  FileCheck2,
  Presentation,
  Server,
  Users,
} from 'lucide-react';
import Link from 'next/link';
import { memo, useEffect, useRef, useState } from 'react';
import { OfficeEventLayer } from './office/event-layer';
import { ProgressBar } from './ui';

// ---------- AI社員チップ(デスク) ----------

const AgentDesk = memo(function AgentDesk({
  agent,
  onSelect,
  compact,
}: {
  agent: Agent;
  onSelect: (a: Agent) => void;
  compact?: boolean;
}) {
  const reduced = useReducedMotion();
  const unreadCount = useOffice((s) => s.unread[agent.id] ?? 0);
  const st = AGENT_STATUS[agent.status];
  const busy = ['working', 'checking', 'delegating'].includes(agent.status);
  const isDone = agent.status === 'done';
  const isError = agent.status === 'error';
  const isWaiting = agent.status === 'waiting_approval';
  const isPaused = agent.status === 'paused';

  return (
    <motion.button
      layoutId={`agent-${agent.id}`}
      layout
      data-agent-chip={agent.id}
      onClick={() => onSelect(agent)}
      whileHover={reduced ? undefined : { scale: 1.02 }}
      whileTap={reduced ? undefined : { scale: 0.98 }}
      transition={{
        // 移動(layout)は歩くようにゆっくり、ホバーは即座に反応させる
        layout: reduced ? { duration: 0 } : { type: 'tween', duration: 1.2, ease: [0.22, 1, 0.36, 1] },
        scale: { type: 'spring', stiffness: 420, damping: 32 },
      }}
      aria-label={`${agent.name}(${st.label})の詳細を開く`}
      className={cn(
        'relative w-full rounded-lg border bg-white px-2.5 py-2 text-left shadow-sm outline-none transition-colors',
        'focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-1',
        isWaiting && 'border-amber-300 ring-2 ring-amber-100',
        isError && 'border-red-300 ring-2 ring-red-100',
        isDone && 'border-emerald-300 ring-2 ring-emerald-100',
        isPaused && 'opacity-55 grayscale',
        !isWaiting && !isError && !isDone && 'border-slate-200 hover:border-brand-300',
        busy && !reduced && 'motion-safe:shadow-[0_0_14px_rgba(99,102,241,0.22)]',
      )}
    >
      {unreadCount > 0 && (
        <span
          className="absolute -left-1.5 -top-1.5 z-10 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand-600 px-1 text-[9px] font-bold text-white shadow"
          aria-label={`未読メッセージ ${unreadCount}件`}
        >
          {unreadCount}
        </span>
      )}
      <div className="flex items-center gap-2">
        <div
          className={cn(
            'relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-base',
            agent.status === 'idle' && !reduced && 'motion-safe:animate-[pulse_3.2s_ease-in-out_infinite]',
          )}
          style={{ backgroundColor: `${agent.color}18`, border: `1.5px solid ${agent.color}55` }}
        >
          {agent.avatar}
          <span
            className={cn(
              'absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-white',
              st.dot,
              busy && 'motion-safe:animate-pulse',
            )}
          />
          {isDone && (
            <motion.span
              initial={reduced ? false : { scale: 0 }}
              animate={{ scale: 1 }}
              className="absolute -right-1.5 -top-1.5 flex h-4 w-4 items-center justify-center rounded-full bg-emerald-500 text-[9px] text-white shadow"
            >
              ✓
            </motion.span>
          )}
          {isError && (
            <span className="absolute -right-1.5 -top-1.5 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[9px] text-white shadow">
              !
            </span>
          )}
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[11px] font-bold tracking-tight text-slate-800">{agent.name}</p>
          <p className={cn('flex items-center gap-1 truncate text-[10px] font-medium', st.color)}>
            {st.label}
            {busy && (
              <span className="inline-flex gap-0.5" aria-hidden>
                <span className="think-dot h-0.5 w-0.5 rounded-full bg-current" />
                <span className="think-dot h-0.5 w-0.5 rounded-full bg-current" style={{ animationDelay: '0.2s' }} />
                <span className="think-dot h-0.5 w-0.5 rounded-full bg-current" style={{ animationDelay: '0.4s' }} />
              </span>
            )}
          </p>
        </div>
      </div>
      {/* 吹き出し(状態メモ) */}
      <p
        className={cn(
          'mt-1.5 truncate rounded-md px-1.5 py-0.5 text-[10px]',
          isWaiting
            ? 'bg-amber-50 text-amber-700'
            : isError
              ? 'bg-red-50 text-red-600'
              : isDone
                ? 'bg-emerald-50 text-emerald-700'
                : 'bg-slate-50 text-slate-500',
        )}
      >
        {agent.statusNote}
      </p>
      {busy && !compact && <ProgressBar value={agent.progress} className="mt-1.5 h-1" />}
      {/* デスク(家具表現) */}
      <div className="mx-auto mt-1.5 h-1 w-3/4 rounded-full bg-slate-200/80" aria-hidden />
    </motion.button>
  );
});

// ---------- エリア枠 ----------

function Area({
  name,
  icon,
  color,
  className,
  children,
  deco,
}: {
  name: string;
  icon: React.ReactNode;
  color: string;
  className?: string;
  children: React.ReactNode;
  deco?: React.ReactNode;
}) {
  return (
    <div
      className={cn('relative rounded-xl border bg-white/70 p-3 backdrop-blur-sm', className)}
      style={{ borderColor: `${color}44` }}
    >
      <div className="flex items-center gap-1.5">
        <span className="flex h-5 w-5 items-center justify-center rounded" style={{ backgroundColor: `${color}1c`, color }}>
          {icon}
        </span>
        <p className="text-xs font-bold text-slate-700">{name}</p>
        {deco && <span className="ml-auto text-sm opacity-70" aria-hidden>{deco}</span>}
      </div>
      {children}
    </div>
  );
}

function EmptySpot({ label }: { label: string }) {
  return (
    <p className="col-span-full rounded-lg border border-dashed border-slate-200 py-3 text-center text-[10px] text-slate-400">
      {label}
    </p>
  );
}

// ---------- CEO席(司令塔スポットライト) ----------

function CeoSpot({ onSelect }: { onSelect: (a: Agent) => void }) {
  const ceo = useOffice((s) => s.agents.find((a) => a.id === 'ceo'));
  const pending = useOffice((s) => s.approvals.filter((a) => a.status === 'pending').length);
  const running = useOffice((s) => s.tasks.filter((t) => t.status === 'running').length);
  const errors = useOffice((s) => s.agents.filter((a) => a.status === 'error').length);
  const latest = useOffice((s) => s.announcements[0]);
  const openProposals = useOffice(
    (s) => s.proposals.filter((p) => ['new', 'reviewing', 'revision'].includes(p.status)).length,
  );
  if (!ceo) return null;
  return (
    <div className="mt-2 grid gap-2 sm:grid-cols-[minmax(0,180px)_1fr]">
      <AgentDesk agent={ceo} onSelect={onSelect} />
      <div className="grid grid-cols-2 gap-1.5 text-[10px]">
        <div className="rounded-lg border border-slate-100 bg-white px-2 py-1.5">
          <p className="text-slate-400">承認待ち</p>
          <p className={cn('text-sm font-bold tabular-nums', pending > 0 ? 'text-amber-600' : 'text-slate-700')}>{pending}件</p>
        </div>
        <div className="rounded-lg border border-slate-100 bg-white px-2 py-1.5">
          <p className="text-slate-400">実行中タスク</p>
          <p className="text-sm font-bold tabular-nums text-slate-700">{running}件</p>
        </div>
        <div className="rounded-lg border border-slate-100 bg-white px-2 py-1.5">
          <p className="text-slate-400">問題発生</p>
          <p className={cn('text-sm font-bold tabular-nums', errors > 0 ? 'text-red-600' : 'text-emerald-600')}>{errors}件</p>
        </div>
        <div className="rounded-lg border border-slate-100 bg-white px-2 py-1.5">
          <p className="text-slate-400">遅延案件</p>
          <p className="text-sm font-bold tabular-nums text-emerald-600">0件</p>
        </div>
        <p className="col-span-2 truncate rounded-lg bg-brand-50/70 px-2 py-1 text-[10px] text-brand-700">
          🎯 {latest?.message ?? '本日の重点方針を策定中です'}
        </p>
        {openProposals > 0 && (
          <Link
            href="/proposals"
            className="col-span-2 flex items-center gap-1 rounded-lg bg-amber-50 px-2 py-1 text-[10px] font-semibold text-amber-700 outline-none hover:bg-amber-100 focus-visible:ring-2 focus-visible:ring-amber-500"
          >
            💡 新しい経営提案が{openProposals}件あります → 提案センターへ
          </Link>
        )}
      </div>
    </div>
  );
}

// ---------- オフィスマップ本体 ----------

const DEPT_AREAS: { id: DepartmentId; className: string; cols: string }[] = [
  { id: 'sales', className: 'sm:col-span-2', cols: 'grid-cols-2 lg:grid-cols-3' },
  { id: 'marketing', className: '', cols: 'grid-cols-1' },
  { id: 'admin', className: '', cols: 'grid-cols-1' },
  { id: 'production', className: 'sm:col-span-2', cols: 'grid-cols-2 lg:grid-cols-3' },
];

export function OfficeMap({ onSelect }: { onSelect: (a: Agent) => void }) {
  const agents = useOffice((s) => s.agents);
  const ceoName = useOffice((s) => s.settings.ceoName);
  const timeEffects = useOffice((s) => s.settings.timeEffects ?? true);
  const containerRef = useRef<HTMLDivElement>(null);
  const [period, setPeriod] = useState(() => currentPeriod());

  useEffect(() => {
    const id = setInterval(() => setPeriod(currentPeriod()), 60_000);
    return () => clearInterval(id);
  }, []);

  const meta = PERIOD_META[timeEffects ? period : 'day'];
  const inZone = (zone: OfficeZone, dept?: DepartmentId) =>
    agents.filter(
      (a) => agentZone(a) === zone && (dept ? a.departmentId === dept : true) && a.id !== 'ceo',
    );
  const deskAgents = (dept: DepartmentId) => inZone('desk', dept).filter((a) => a.status !== 'paused');
  const meeting = agents.filter((a) => agentZone(a) === 'meeting');
  const project = agents.filter((a) => agentZone(a) === 'project');
  const approval = agents.filter((a) => agentZone(a) === 'approval');
  const server = agents.filter((a) => agentZone(a) === 'server');
  const onBreak = agents.filter((a) => agentZone(a) === 'break');
  const ceoAway = agents.some((a) => a.id === 'ceo' && agentZone(a) !== 'desk');

  return (
    <LayoutGroup>
      <div
        ref={containerRef}
        className={cn('relative rounded-2xl border border-slate-200 bg-gradient-to-br p-3 sm:p-4', meta.officeBg)}
      >
        {timeEffects && (
          <p className="absolute right-3 top-2 z-10 rounded-full bg-white/80 px-2 py-0.5 text-[10px] text-slate-500 shadow-sm">
            {meta.emoji} {meta.label}
          </p>
        )}

        <div className="grid grid-cols-1 gap-3 pt-4 sm:grid-cols-2 lg:grid-cols-4">
          {/* 社長室 */}
          <Area name="社長室" icon={<Crown className="h-3.5 w-3.5" />} color="#6366f1" deco="🪴">
            <Link
              href="/chat"
              className="mt-2 flex items-center gap-2 rounded-lg border border-dashed border-brand-300 bg-brand-50/60 px-2.5 py-2 outline-none hover:bg-brand-50 focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-brand-300 bg-white text-base">
                🧑‍💼
              </div>
              <div>
                <p className="text-xs font-bold text-slate-800">{ceoName}(あなた)</p>
                <p className="text-[10px] text-brand-600">クリックでCEO AIへ指示</p>
              </div>
            </Link>
          </Area>

          {/* CEO AI席 */}
          <Area name="CEO AI席(経営部)" icon={<Users className="h-3.5 w-3.5" />} color="#6366f1" className="sm:col-span-2" deco="🗂️">
            {ceoAway ? <EmptySpot label="CEO AIは離席中" /> : <CeoSpot onSelect={onSelect} />}
          </Area>

          {/* 秘書席 */}
          <Area name="秘書席" icon={<Armchair className="h-3.5 w-3.5" />} color="#0ea5e9" deco="🪴">
            <div className="mt-2 grid grid-cols-1 gap-2">
              {deskAgents('secretary').map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} />
              ))}
              {deskAgents('secretary').length === 0 && <EmptySpot label="離席中" />}
            </div>
          </Area>

          {/* 部署エリア */}
          {DEPT_AREAS.map(({ id, className, cols }) => {
            const dept = DEPARTMENTS[id];
            const members = deskAgents(id);
            return (
              <Area
                key={id}
                name={dept.name}
                icon={<Armchair className="h-3.5 w-3.5" />}
                color={dept.color}
                className={className}
                deco={id === 'admin' ? '📚' : id === 'marketing' ? '🪴' : undefined}
              >
                <div className={cn('mt-2 grid gap-2', cols)}>
                  {members.map((a) => (
                    <AgentDesk key={a.id} agent={a} onSelect={onSelect} />
                  ))}
                  {members.length === 0 && <EmptySpot label="全員離席中" />}
                </div>
              </Area>
            );
          })}

          {/* 会議室 */}
          <Area name="会議室" icon={<Presentation className="h-3.5 w-3.5" />} color="#8b5cf6" className="sm:col-span-2" deco="🖥️">
            {/* ホワイトボード(装飾) */}
            <div className="mt-2 rounded-md border border-slate-200 bg-white/90 px-2 py-1" aria-hidden>
              <div className="h-0.5 w-2/3 rounded bg-violet-200" />
              <div className="mt-0.5 h-0.5 w-1/2 rounded bg-slate-200" />
              <div className="mt-0.5 h-0.5 w-1/3 rounded bg-slate-200" />
            </div>
            <div className="mt-2 grid grid-cols-2 gap-2 lg:grid-cols-3">
              {meeting.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} compact />
              ))}
              {meeting.length === 0 && <EmptySpot label="現在会議はありません" />}
            </div>
          </Area>

          {/* プロジェクトテーブル */}
          <Area name="プロジェクトテーブル" icon={<Users className="h-3.5 w-3.5" />} color="#6366f1" deco="📋">
            <div className="mt-2 grid grid-cols-1 gap-2">
              {project.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} compact />
              ))}
              {project.length === 0 && <EmptySpot label="進行中のキックオフなし" />}
            </div>
          </Area>

          {/* 承認待ちスペース */}
          <Area name="承認待ちスペース" icon={<FileCheck2 className="h-3.5 w-3.5" />} color="#f59e0b">
            <div className="mt-2 grid grid-cols-1 gap-2">
              {approval.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} compact />
              ))}
              {approval.length === 0 && <EmptySpot label="承認待ちなし" />}
              {approval.length > 0 && (
                <Link
                  href="/approvals"
                  className="rounded-lg bg-amber-100 py-1.5 text-center text-[10px] font-bold text-amber-700 outline-none hover:bg-amber-200 focus-visible:ring-2 focus-visible:ring-amber-500"
                >
                  承認センターを開く →
                </Link>
              )}
            </div>
          </Area>

          {/* サーバールーム */}
          <Area name="サーバールーム" icon={<Server className="h-3.5 w-3.5" />} color="#ef4444">
            {/* サーバーラック(装飾) */}
            <div className="mt-2 flex gap-1" aria-hidden>
              {[0, 1, 2].map((i) => (
                <div key={i} className="flex h-8 w-5 flex-col items-center justify-center gap-1 rounded-sm bg-slate-700">
                  <span className={cn('h-1 w-1 rounded-full', i === 1 ? 'bg-emerald-400' : 'bg-emerald-500/70', 'motion-safe:animate-pulse')} />
                  <span className="h-1 w-1 rounded-full bg-sky-400/70" />
                </div>
              ))}
            </div>
            <div className="mt-2 grid grid-cols-1 gap-2">
              {server.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} compact />
              ))}
              {server.length === 0 && (
                <p className="flex items-center justify-center gap-1 rounded-lg border border-dashed border-slate-200 py-3 text-center text-[10px] text-emerald-600">
                  <CheckCircle2 className="h-3 w-3" /> 全システム正常
                </p>
              )}
            </div>
          </Area>

          {/* 休憩スペース */}
          <Area name="休憩スペース" icon={<Coffee className="h-3.5 w-3.5" />} color="#14b8a6" deco="☕">
            <div className="mt-2 grid grid-cols-1 gap-2">
              {onBreak.map((a) => (
                <AgentDesk key={a.id} agent={a} onSelect={onSelect} compact />
              ))}
              {onBreak.length === 0 && <EmptySpot label="休憩中の社員はいません" />}
            </div>
          </Area>
        </div>

        {/* AI社員間の連携イベント表示レイヤー */}
        <OfficeEventLayer containerRef={containerRef} />

        {/* エラー時の注意書き */}
        {server.length > 0 && (
          <p className="mt-2 flex items-center gap-1 text-[10px] text-red-600">
            <AlertTriangle className="h-3 w-3" /> {server.length}名がエラー対応中です(自動復旧を試行しています)
          </p>
        )}
      </div>
    </LayoutGroup>
  );
}
