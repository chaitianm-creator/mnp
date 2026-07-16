'use client';

// ライブバーチャルオフィス
// レイアウト: 上=サマリー+CEOアナウンス / 中央=2Dオフィス / 右=ライブフィード / 下=進行中タスク
// モバイル(390px)では「オフィス表示」と「社員リスト表示」を切り替えられる
import { AgentDetailPanel } from '@/components/agent-detail-panel';
import { AgentAvatar, AgentStatusBadge } from '@/components/agent-bits';
import { OfficeMap } from '@/components/office-map';
import {
  CeoAlertBar,
  CeoAnnouncement,
  LiveFeed,
  OfficeSummary,
  RunningTasksBar,
  TalkFeed,
} from '@/components/office/office-widgets';
import { SystemMonitor } from '@/components/office/system-monitor';
import { ProgressBar } from '@/components/ui';
import { agentZoneLabel } from '@/lib/office';
import { useOffice } from '@/lib/store';
import type { Agent } from '@/lib/types';
import { cn } from '@/lib/utils';
import { Building2, ChevronDown, ChevronUp, List } from 'lucide-react';
import { useState } from 'react';

const STATUS_ORDER: Agent['status'][] = [
  'error',
  'waiting_approval',
  'working',
  'delegating',
  'checking',
  'meeting',
  'done',
  'idle',
  'paused',
];

export default function OfficePage() {
  const agents = useOffice((s) => s.agents);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [mobileView, setMobileView] = useState<'office' | 'list'>('office');
  const [feedOpen, setFeedOpen] = useState(true);
  const selected = agents.find((a) => a.id === selectedId) ?? null;

  const sortedAgents = [...agents].sort(
    (a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status),
  );

  return (
    <div className="space-y-3">
      {/* 上部: サマリー + システムモニター + CEOアナウンス + CEO呼びかけ */}
      <OfficeSummary />
      <SystemMonitor />
      <CeoAnnouncement />
      <CeoAlertBar />

      {/* モバイル: 表示切り替え */}
      <div className="flex rounded-lg border border-slate-200 bg-white p-0.5 lg:hidden">
        <button
          onClick={() => setMobileView('office')}
          className={cn(
            'flex flex-1 items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition',
            mobileView === 'office'
              ? 'bg-gradient-to-r from-brand-600 to-accent-600 text-white'
              : 'text-slate-500',
          )}
        >
          <Building2 className="h-3.5 w-3.5" /> オフィス表示
        </button>
        <button
          onClick={() => setMobileView('list')}
          className={cn(
            'flex flex-1 items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition',
            mobileView === 'list'
              ? 'bg-gradient-to-r from-brand-600 to-accent-600 text-white'
              : 'text-slate-500',
          )}
        >
          <List className="h-3.5 w-3.5" /> 社員リスト表示
        </button>
      </div>

      {/* 中央 + 右 */}
      <div className="grid gap-3 xl:grid-cols-[minmax(0,1fr)_320px]">
        <div className="min-w-0 space-y-3">
          {/* デスクトップは常にオフィス。モバイルは切り替え */}
          <div className={cn(mobileView === 'list' && 'hidden lg:block')}>
            <OfficeMap onSelect={(a) => setSelectedId(a.id)} />
          </div>

          {/* モバイル用: 社員リスト表示 */}
          <div className={cn('space-y-2 lg:hidden', mobileView === 'office' && 'hidden')}>
            {sortedAgents.map((agent) => (
              <button
                key={agent.id}
                onClick={() => setSelectedId(agent.id)}
                aria-label={`${agent.name}の詳細を開く`}
                className="flex w-full items-center gap-3 rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-left outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
              >
                <AgentAvatar agent={agent} size="sm" />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="truncate text-xs font-bold text-slate-800">{agent.name}</p>
                    <AgentStatusBadge agent={agent} />
                  </div>
                  <p className="mt-0.5 truncate text-[10px] text-slate-500">
                    📍{agentZoneLabel(agent)} — {agent.statusNote}
                  </p>
                  {['working', 'checking', 'delegating'].includes(agent.status) && (
                    <ProgressBar value={agent.progress} className="mt-1 h-1" />
                  )}
                </div>
              </button>
            ))}
          </div>

          <RunningTasksBar />
        </div>

        {/* 右: ライブフィード(1024px前後では折りたたみ可能) */}
        <div className="min-w-0">
          <button
            onClick={() => setFeedOpen((v) => !v)}
            className="mb-2 flex w-full items-center justify-between rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500 xl:hidden"
            aria-expanded={feedOpen}
          >
            社内ライブフィード
            {feedOpen ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
          </button>
          <div className={cn('space-y-3', !feedOpen && 'hidden xl:block')}>
            <LiveFeed
              onSelectAgent={(id) => setSelectedId(id)}
              className="max-h-[380px] xl:max-h-[calc(100vh-480px)] xl:min-h-[320px]"
            />
            <TalkFeed onSelectAgent={(id) => setSelectedId(id)} />
          </div>
        </div>
      </div>

      <AgentDetailPanel agent={selected} onClose={() => setSelectedId(null)} />
    </div>
  );
}
