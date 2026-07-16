import type { Agent, OfficeZone } from './types';
import { ZONE_LABELS } from './types';

/** エージェントの現在の居場所を導出する(zone未設定の旧データにも対応) */
export function agentZone(agent: Agent): OfficeZone {
  if (agent.zone) return agent.zone;
  switch (agent.status) {
    case 'waiting_approval':
      return 'approval';
    case 'error':
      return 'server';
    case 'meeting':
      return 'meeting';
    case 'paused':
      return 'break';
    default:
      return 'desk';
  }
}

export function agentZoneLabel(agent: Agent): string {
  return ZONE_LABELS[agentZone(agent)];
}

export type DayPeriod = 'morning' | 'day' | 'evening' | 'night';

/** 現在時刻から時間帯を判定(時間帯演出用) */
export function currentPeriod(date = new Date()): DayPeriod {
  const h = date.getHours();
  if (h >= 5 && h < 10) return 'morning';
  if (h >= 10 && h < 17) return 'day';
  if (h >= 17 && h < 21) return 'evening';
  return 'night';
}

export const PERIOD_META: Record<DayPeriod, { label: string; emoji: string; officeBg: string }> = {
  morning: {
    label: '朝会・出社の時間帯',
    emoji: '🌅',
    officeBg: 'from-amber-50/80 via-indigo-50/50 to-purple-50/60',
  },
  day: {
    label: '通常業務中',
    emoji: '☀️',
    officeBg: 'from-slate-100 via-indigo-50/50 to-purple-50/60',
  },
  evening: {
    label: '日報作成の時間帯',
    emoji: '🌇',
    officeBg: 'from-orange-50/80 via-indigo-50/60 to-purple-100/60',
  },
  night: {
    label: '夜間は一部AIのみ稼働中',
    emoji: '🌙',
    officeBg: 'from-slate-200/90 via-indigo-100/70 to-slate-200/80',
  },
};
