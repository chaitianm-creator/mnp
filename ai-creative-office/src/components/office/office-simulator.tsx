'use client';

// ============================================================
// 箱庭型AI会社シミュレーター(見下ろし型オフィス)
// - 見た目はゲーム品質、裏側は既存のZustandストアをそのまま使用
// - 部屋・家具はSVGで描画(外部画像なし)
// - AI社員は状態(status/zone)に応じて座標間を「歩いて」移動
// - 仕事の受け渡し(officeEvents)/会話吹き出し/時間帯照明/
//   休憩/会議/CEO報告/成果物完成のお祝い演出
// ============================================================
import { agentZone, currentPeriod, type DayPeriod } from '@/lib/office';
import { AGENT_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, OfficeZone } from '@/lib/types';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useEffect, useMemo, useRef, useState } from 'react';

// ---------- レイアウト定義(viewBox 1280x880) ----------

const VB = { w: 1280, h: 880 };

interface Room {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  floor: string; // 床色
  accent: string;
}

const ROOMS: Room[] = [
  { id: 'president', label: '社長室', x: 20, y: 20, w: 280, h: 190, floor: '#efe6d8', accent: '#8b5cf6' },
  { id: 'ceo', label: 'CEO席(経営部)', x: 320, y: 20, w: 320, h: 190, floor: '#e8eaf6', accent: '#6366f1' },
  { id: 'secretary', label: '秘書席', x: 660, y: 20, w: 180, h: 190, floor: '#e3f0f4', accent: '#0ea5e9' },
  { id: 'server', label: 'サーバールーム', x: 860, y: 20, w: 180, h: 190, floor: '#dfe3ea', accent: '#ef4444' },
  { id: 'break', label: '休憩スペース', x: 1060, y: 20, w: 200, h: 190, floor: '#e6f2e6', accent: '#14b8a6' },
  { id: 'sales', label: '営業部', x: 20, y: 240, w: 500, h: 280, floor: '#f3ead9', accent: '#f59e0b' },
  { id: 'production', label: '制作部', x: 540, y: 240, w: 500, h: 280, floor: '#eae6f4', accent: '#8b5cf6' },
  { id: 'marketing', label: 'マーケティング部', x: 1060, y: 240, w: 200, h: 280, floor: '#f6e6ee', accent: '#ec4899' },
  { id: 'admin', label: '管理部', x: 20, y: 550, w: 240, h: 240, floor: '#e4efe9', accent: '#10b981' },
  { id: 'meeting', label: '会議室', x: 280, y: 550, w: 380, h: 240, floor: '#e9e4f4', accent: '#8b5cf6' },
  { id: 'project', label: 'プロジェクトテーブル', x: 680, y: 550, w: 320, h: 240, floor: '#e6ecf6', accent: '#6366f1' },
  { id: 'approval', label: '承認待ちスペース', x: 1020, y: 550, w: 240, h: 240, floor: '#f6efdc', accent: '#f59e0b' },
];

// AI社員の自席(デスク)座標
const DESKS: Record<string, { x: number; y: number }> = {
  ceo: { x: 480, y: 140 },
  secretary: { x: 750, y: 140 },
  list: { x: 110, y: 340 }, form_sales: { x: 270, y: 340 }, email_sales: { x: 430, y: 340 },
  reception: { x: 110, y: 460 }, deal_mgr: { x: 270, y: 460 }, tel: { x: 430, y: 460 },
  director: { x: 630, y: 340 }, writer: { x: 790, y: 340 }, designer: { x: 950, y: 340 },
  coder: { x: 630, y: 460 }, reviewer: { x: 790, y: 460 }, infra: { x: 950, y: 460 },
  sns: { x: 1160, y: 340 }, seo: { x: 1160, y: 460 },
  accountant: { x: 140, y: 630 }, ops_admin: { x: 140, y: 730 },
};

// ゾーンごとの席(会議・プロジェクト・承認待ち・サーバー・休憩)
const seatsAround = (cx: number, cy: number, rx: number, ry: number, n: number) =>
  Array.from({ length: n }, (_, i) => {
    const a = (i / n) * Math.PI * 2 - Math.PI / 2;
    return { x: cx + Math.cos(a) * rx, y: cy + Math.sin(a) * ry };
  });

const ZONE_SEATS: Record<Exclude<OfficeZone, 'desk'>, { x: number; y: number }[]> = {
  meeting: seatsAround(470, 675, 130, 70, 8),
  project: seatsAround(840, 675, 100, 60, 6),
  approval: [
    { x: 1080, y: 650 }, { x: 1150, y: 650 }, { x: 1220, y: 650 },
    { x: 1080, y: 730 }, { x: 1150, y: 730 }, { x: 1220, y: 730 },
  ],
  server: [{ x: 910, y: 150 }, { x: 970, y: 165 }, { x: 940, y: 120 }],
  break: [{ x: 1105, y: 120 }, { x: 1215, y: 120 }, { x: 1105, y: 170 }, { x: 1215, y: 170 }],
};

/** 全AI社員の現在座標を解決(ゾーン内は順番に着席・重なり防止) */
function resolvePositions(agents: Agent[]): Map<string, { x: number; y: number }> {
  const map = new Map<string, { x: number; y: number }>();
  const zoneCount: Record<string, number> = {};
  for (const a of agents) {
    const zone = agentZone(a);
    if (zone === 'desk') {
      map.set(a.id, DESKS[a.id] ?? { x: 640, y: 440 });
    } else {
      const seats = ZONE_SEATS[zone];
      const i = zoneCount[zone] ?? 0;
      zoneCount[zone] = i + 1;
      const seat = seats[i % seats.length];
      // 席が足りない場合は少しずらして重なりを防ぐ
      map.set(a.id, { x: seat.x + Math.floor(i / seats.length) * 14, y: seat.y + Math.floor(i / seats.length) * 10 });
    }
  }
  return map;
}

// ---------- 家具(SVG) ----------

function Desk({ x, y, glow }: { x: number; y: number; glow: boolean }) {
  return (
    <g>
      <rect x={x - 34} y={y - 52} width={68} height={30} rx={5} fill="#b58a5a" stroke="#98713f" strokeWidth={1.5} />
      {/* モニター(作業中は点灯) */}
      <rect x={x - 14} y={y - 50} width={28} height={16} rx={2} fill={glow ? '#bfdbfe' : '#334155'} stroke="#1e293b" strokeWidth={1.5}>
        {glow && <animate attributeName="fill" values="#bfdbfe;#93c5fd;#bfdbfe" dur="2.4s" repeatCount="indefinite" />}
      </rect>
      <rect x={x - 3} y={y - 34} width={6} height={4} fill="#475569" />
      {glow && <circle cx={x} cy={y - 42} r={18} fill="#60a5fa" opacity={0.12} />}
      {/* 椅子 */}
      <circle cx={x} cy={y - 6} r={9} fill="#64748b" opacity={0.35} />
    </g>
  );
}

function MeetingTable() {
  return (
    <g>
      <ellipse cx={470} cy={675} rx={92} ry={44} fill="#b58a5a" stroke="#98713f" strokeWidth={2} />
      <ellipse cx={470} cy={675} rx={70} ry={30} fill="#c79b6b" />
      {/* ホワイトボード */}
      <rect x={300} y={562} width={90} height={40} rx={4} fill="#ffffff" stroke="#94a3b8" strokeWidth={1.5} />
      <line x1={310} y1={574} x2={370} y2={574} stroke="#8b5cf6" strokeWidth={2.5} strokeLinecap="round" />
      <line x1={310} y1={584} x2={355} y2={584} stroke="#cbd5e1" strokeWidth={2} strokeLinecap="round" />
      <line x1={310} y1={592} x2={362} y2={592} stroke="#cbd5e1" strokeWidth={2} strokeLinecap="round" />
    </g>
  );
}

function ProjectTable() {
  return (
    <g>
      <rect x={760} y={640} width={160} height={70} rx={10} fill="#8fa8c8" stroke="#6b87ab" strokeWidth={2} />
      <rect x={775} y={652} width={40} height={26} rx={3} fill="#f8fafc" stroke="#cbd5e1" />
      <rect x={825} y={658} width={36} height={22} rx={3} fill="#fef9c3" stroke="#eab308" strokeWidth={0.8} />
      <rect x={872} y={650} width={34} height={28} rx={3} fill="#f8fafc" stroke="#cbd5e1" />
    </g>
  );
}

function BreakArea() {
  return (
    <g>
      {/* ソファ */}
      <rect x={1085} y={95} width={60} height={22} rx={8} fill="#e8927c" stroke="#d97862" strokeWidth={1.5} />
      <rect x={1195} y={95} width={60} height={22} rx={8} fill="#e8927c" stroke="#d97862" strokeWidth={1.5} />
      {/* コーヒーテーブル */}
      <circle cx={1160} cy={150} r={16} fill="#b58a5a" stroke="#98713f" strokeWidth={1.5} />
      <text x={1160} y={155} textAnchor="middle" fontSize={12}>☕</text>
      {/* 自販機 */}
      <rect x={1230} y={140} width={22} height={36} rx={3} fill="#475569" stroke="#334155" strokeWidth={1.5} />
      <rect x={1234} y={146} width={14} height={12} rx={1} fill="#93c5fd" />
    </g>
  );
}

function ServerRacks({ hasError }: { hasError: boolean }) {
  return (
    <g>
      {[0, 1, 2].map((i) => (
        <g key={i}>
          <rect x={880 + i * 48} y={60} width={34} height={64} rx={3} fill="#1e293b" stroke="#0f172a" strokeWidth={1.5} />
          {[0, 1, 2, 3].map((j) => (
            <rect key={j} x={885 + i * 48} y={66 + j * 14} width={24} height={9} rx={1.5} fill="#334155" />
          ))}
          <circle cx={890 + i * 48} cy={70} r={2} fill={hasError && i === 1 ? '#ef4444' : '#34d399'}>
            <animate attributeName="opacity" values="1;0.3;1" dur={`${1.2 + i * 0.4}s`} repeatCount="indefinite" />
          </circle>
        </g>
      ))}
    </g>
  );
}

function PresidentRoom() {
  return (
    <g>
      <rect x={60} y={60} width={120} height={44} rx={6} fill="#7c5a3a" stroke="#5f4227" strokeWidth={2} />
      <rect x={95} y={66} width={40} height={20} rx={2} fill="#334155" stroke="#1e293b" />
      <ellipse cx={230} cy={160} rx={26} ry={12} fill="#dbc9a8" opacity={0.7} />
      <Plant x={272} y={52} />
    </g>
  );
}

function Plant({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x - 7} y={y + 4} width={14} height={12} rx={2} fill="#b45309" />
      <circle cx={x} cy={y - 4} r={11} fill="#22c55e" opacity={0.85} />
      <circle cx={x - 7} cy={y + 1} r={7} fill="#16a34a" opacity={0.85} />
      <circle cx={x + 7} cy={y + 1} r={7} fill="#4ade80" opacity={0.85} />
    </g>
  );
}

function ApprovalArea({ pending }: { pending: number }) {
  return (
    <g>
      <rect x={1060} y={590} width={160} height={16} rx={6} fill="#d6bc8a" stroke="#b89a63" strokeWidth={1.2} />
      <rect x={1060} y={688} width={160} height={16} rx={6} fill="#d6bc8a" stroke="#b89a63" strokeWidth={1.2} />
      {/* 書類トレイ */}
      <rect x={1226} y={585} width={26} height={20} rx={3} fill="#f8fafc" stroke="#cbd5e1" strokeWidth={1.2} />
      <text x={1239} y={578} textAnchor="middle" fontSize={11} fill="#b45309" fontWeight={700}>
        {pending > 0 ? `${pending}件` : ''}
      </text>
    </g>
  );
}

// ---------- 時間帯照明 ----------

const LIGHTING: Record<DayPeriod, { fill: string; opacity: number; label: string; emoji: string }> = {
  morning: { fill: '#fcd34d', opacity: 0.08, label: '朝会・出社の時間帯', emoji: '🌅' },
  day: { fill: '#ffffff', opacity: 0, label: '通常業務中', emoji: '☀️' },
  evening: { fill: '#fb923c', opacity: 0.12, label: '日報作成の時間帯', emoji: '🌇' },
  night: { fill: '#0f172a', opacity: 0.34, label: '夜間は一部AIのみ稼働中', emoji: '🌙' },
};

// ---------- AI社員スプライト ----------

function AgentSprite({
  agent,
  pos,
  onSelect,
  reduced,
}: {
  agent: Agent;
  pos: { x: number; y: number };
  onSelect: (a: Agent) => void;
  reduced: boolean;
}) {
  const st = AGENT_STATUS[agent.status];
  const busy = ['working', 'checking', 'delegating'].includes(agent.status);
  const unread = useOffice((s) => s.unread[agent.id] ?? 0);
  const [walking, setWalking] = useState(false);
  const prev = useRef(pos);

  useEffect(() => {
    if (prev.current.x !== pos.x || prev.current.y !== pos.y) {
      prev.current = pos;
      setWalking(true);
      const t = setTimeout(() => setWalking(false), 1700);
      return () => clearTimeout(t);
    }
  }, [pos.x, pos.y]);

  // 吹き出しを出す条件(騒がしくならないよう限定)
  const showBubble =
    agent.statusNote.startsWith('💬') ||
    ['waiting_approval', 'error', 'done', 'meeting'].includes(agent.status) ||
    (busy && agent.progress > 0);
  const bubbleText = agent.statusNote.replace(/^💬 ?/, '').slice(0, 14) + (agent.statusNote.length > 15 ? '…' : '');
  const dotColor =
    agent.status === 'error' ? '#ef4444' : agent.status === 'waiting_approval' ? '#f59e0b' : agent.status === 'done' ? '#10b981' : busy ? '#22c55e' : '#94a3b8';

  return (
    <motion.g
      data-agent-chip={agent.id}
      initial={false}
      animate={{ x: pos.x, y: pos.y }}
      transition={reduced ? { duration: 0 } : { type: 'tween', duration: 1.5, ease: [0.45, 0.05, 0.35, 1] }}
      onClick={() => onSelect(agent)}
      onKeyDown={(e) => e.key === 'Enter' && onSelect(agent)}
      tabIndex={0}
      role="button"
      aria-label={`${agent.name}(${st.label})の詳細を開く`}
      style={{ cursor: 'pointer', outline: 'none' }}
    >
      <g className={walking && !reduced ? 'sim-bob' : undefined}>
        {/* 影 */}
        <ellipse cx={0} cy={12} rx={13} ry={4.5} fill="#0f172a" opacity={0.14} />
        {/* 体 */}
        <circle r={15} fill="#ffffff" stroke={agent.color} strokeWidth={3} opacity={agent.status === 'paused' ? 0.55 : 1} />
        <text y={5.5} textAnchor="middle" fontSize={15} aria-hidden>
          {agent.avatar}
        </text>
        {/* 状態ドット */}
        <circle cx={11} cy={-10} r={4.2} fill={dotColor} stroke="#fff" strokeWidth={1.4}>
          {busy && !reduced && <animate attributeName="opacity" values="1;0.4;1" dur="1.6s" repeatCount="indefinite" />}
        </circle>
        {/* 完了フラッシュ */}
        {agent.status === 'done' && (
          <motion.circle r={15} fill="none" stroke="#10b981" strokeWidth={2.5} initial={{ opacity: 0.9, scale: 1 }} animate={{ opacity: 0, scale: 1.9 }} transition={{ duration: 1.4, repeat: 2 }} />
        )}
        {/* 未読バッジ */}
        {unread > 0 && (
          <g>
            <circle cx={-12} cy={-11} r={6.5} fill="#4f46e5" stroke="#fff" strokeWidth={1.4} />
            <text x={-12} y={-8} textAnchor="middle" fontSize={8.5} fill="#fff" fontWeight={700}>
              {unread}
            </text>
          </g>
        )}
        {/* 名札 */}
        <rect x={-34} y={17} width={68} height={13} rx={6.5} fill="#ffffff" opacity={0.92} stroke="#e2e8f0" strokeWidth={0.8} />
        <text y={26.5} textAnchor="middle" fontSize={8.5} fill="#334155" fontWeight={700}>
          {agent.name.slice(0, 9)}
        </text>
        {/* 進捗ミニバー */}
        {busy && agent.progress > 0 && (
          <g>
            <rect x={-16} y={32} width={32} height={3.5} rx={1.75} fill="#e2e8f0" />
            <rect x={-16} y={32} width={(32 * agent.progress) / 100} height={3.5} rx={1.75} fill={agent.color} />
          </g>
        )}
        {/* 吹き出し */}
        <AnimatePresence>
          {showBubble && bubbleText && (
            <motion.g initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.3 }}>
              <rect x={-bubbleText.length * 4.6 - 8} y={-46} width={bubbleText.length * 9.2 + 16} height={20} rx={10} fill="#ffffff" stroke="#e2e8f0" strokeWidth={1} opacity={0.97} />
              <path d="M -4 -27 L 0 -20 L 4 -27 Z" fill="#ffffff" stroke="#e2e8f0" strokeWidth={0.8} />
              <text y={-32.5} textAnchor="middle" fontSize={9.5} fill="#334155">
                {bubbleText}
              </text>
            </motion.g>
          )}
        </AnimatePresence>
      </g>
    </motion.g>
  );
}

// ---------- 受け渡し演出(書類が飛ぶ) ----------

function HandoffLayer({ positions }: { positions: Map<string, { x: number; y: number }> }) {
  const events = useOffice((s) => s.officeEvents);
  const reduced = useReducedMotion();
  const fresh = events.filter((e) => Date.now() - new Date(e.createdAt).getTime() < 4500);
  return (
    <g pointerEvents="none">
      <AnimatePresence>
        {fresh.map((e) => {
          const from = positions.get(e.fromAgentId);
          const to = positions.get(e.toAgentId);
          if (!from || !to) return null;
          const color = e.kind === 'complete' ? '#10b981' : e.kind === 'error' ? '#ef4444' : e.kind === 'plan' ? '#a855f7' : '#6366f1';
          const midX = (from.x + to.x) / 2;
          const midY = (from.y + to.y) / 2 - 24;
          return (
            <motion.g key={e.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              <line x1={from.x} y1={from.y} x2={to.x} y2={to.y} stroke={color} strokeWidth={1.5} strokeDasharray="5 6" opacity={0.5} />
              {!reduced && (
                <motion.g initial={{ x: from.x, y: from.y, scale: 0.6 }} animate={{ x: to.x, y: to.y, scale: 1 }} transition={{ duration: 1.5, ease: 'easeInOut' }}>
                  <circle r={10} fill="#ffffff" stroke={color} strokeWidth={1.8} />
                  <text y={4} textAnchor="middle" fontSize={10}>
                    {e.kind === 'complete' ? '✅' : e.kind === 'error' ? '⚠️' : '📄'}
                  </text>
                </motion.g>
              )}
              <g>
                <rect x={midX - e.label.length * 4.5 - 6} y={midY - 9} width={e.label.length * 9 + 12} height={16} rx={8} fill="#ffffff" opacity={0.95} stroke={color} strokeWidth={0.8} />
                <text x={midX} y={midY + 3} textAnchor="middle" fontSize={8.5} fill={color} fontWeight={600}>
                  {e.label}
                </text>
              </g>
            </motion.g>
          );
        })}
      </AnimatePresence>
    </g>
  );
}

// ---------- 成果物完成のお祝い演出 ----------

function CelebrationLayer({ positions }: { positions: Map<string, { x: number; y: number }> }) {
  const achievements = useOffice((s) => s.achievements);
  const runs = useOffice((s) => s.agentRuns);
  const reduced = useReducedMotion();
  const [bursts, setBursts] = useState<{ id: string; x: number; y: number; big: boolean }[]>([]);
  const seenAch = useRef<string | null>(null);
  const seenRuns = useRef<Record<string, string>>({});

  // 成果イベント → 小さなお祝い
  useEffect(() => {
    const latest = achievements[0];
    if (!latest || seenAch.current === latest.id) return;
    const isFirst = seenAch.current === null;
    seenAch.current = latest.id;
    if (isFirst) return; // 初期表示時は発火しない
    const pos = positions.get(latest.agentId);
    if (pos) setBursts((b) => [...b.slice(-3), { id: latest.id, x: pos.x, y: pos.y, big: false }]);
  }, [achievements, positions]);

  // AI実働ランの完了 → 大きなお祝い(CEO席で発火)
  useEffect(() => {
    for (const run of runs) {
      const prevStatus = seenRuns.current[run.id];
      seenRuns.current[run.id] = run.status;
      if (prevStatus && prevStatus !== 'done' && run.status === 'done') {
        const pos = positions.get('ceo') ?? { x: 480, y: 140 };
        setBursts((b) => [...b.slice(-3), { id: `run-${run.id}-${Date.now()}`, x: pos.x, y: pos.y - 20, big: true }]);
      }
    }
  }, [runs, positions]);

  useEffect(() => {
    if (bursts.length === 0) return;
    const t = setTimeout(() => setBursts((b) => b.slice(1)), 2600);
    return () => clearTimeout(t);
  }, [bursts]);

  if (reduced) return null;
  return (
    <g pointerEvents="none">
      <AnimatePresence>
        {bursts.map((burst) => (
          <motion.g key={burst.id} initial={{ opacity: 1 }} exit={{ opacity: 0 }}>
            {Array.from({ length: burst.big ? 10 : 6 }, (_, i) => {
              const a = (i / (burst.big ? 10 : 6)) * Math.PI * 2;
              const dist = burst.big ? 46 : 30;
              const colors = ['#6366f1', '#f59e0b', '#10b981', '#ec4899', '#38bdf8'];
              return (
                <motion.circle
                  key={i}
                  initial={{ cx: burst.x, cy: burst.y, r: burst.big ? 4 : 3, opacity: 1 }}
                  animate={{ cx: burst.x + Math.cos(a) * dist, cy: burst.y + Math.sin(a) * dist - 12, r: 0.6, opacity: 0 }}
                  transition={{ duration: 1.5, ease: 'easeOut' }}
                  fill={colors[i % colors.length]}
                />
              );
            })}
            <motion.text
              initial={{ x: burst.x, y: burst.y - 20, opacity: 0, scale: 0.6 }}
              animate={{ y: burst.y - (burst.big ? 52 : 40), opacity: [0, 1, 1, 0], scale: 1 }}
              transition={{ duration: 2.2 }}
              textAnchor="middle"
              fontSize={burst.big ? 22 : 15}
            >
              {burst.big ? '🎉' : '✨'}
            </motion.text>
            {burst.big && (
              <motion.g initial={{ opacity: 0, y: 6 }} animate={{ opacity: [0, 1, 1, 0] }} transition={{ duration: 2.4 }}>
                <rect x={burst.x - 62} y={burst.y - 92} width={124} height={20} rx={10} fill="#10b981" opacity={0.95} />
                <text x={burst.x} y={burst.y - 78} textAnchor="middle" fontSize={10.5} fill="#fff" fontWeight={700}>
                  成果物が完成しました!
                </text>
              </motion.g>
            )}
          </motion.g>
        ))}
      </AnimatePresence>
    </g>
  );
}

// ---------- 本体 ----------

export function OfficeSimulator({ onSelect }: { onSelect: (a: Agent) => void }) {
  const agents = useOffice((s) => s.agents);
  const ceoName = useOffice((s) => s.settings.ceoName);
  const pending = useOffice((s) => s.approvals.filter((a) => a.status === 'pending').length);
  const timeEffects = useOffice((s) => s.settings.timeEffects ?? true);
  const clockMode = useOffice((s) => s.settings.clockMode ?? 'real');
  const tickCount = useOffice((s) => s.tickCount);
  const reduced = useReducedMotion() ?? false;
  const [realPeriod, setRealPeriod] = useState<DayPeriod>(() => currentPeriod());

  useEffect(() => {
    const id = setInterval(() => setRealPeriod(currentPeriod()), 60_000);
    return () => clearInterval(id);
  }, []);

  const period: DayPeriod = !timeEffects
    ? 'day'
    : clockMode === 'demo'
      ? (['morning', 'day', 'evening', 'night'] as const)[Math.floor(tickCount / 40) % 4]
      : realPeriod;
  const light = LIGHTING[period];

  const positions = useMemo(() => resolvePositions(agents), [agents]);
  const meetingInUse = agents.some((a) => agentZone(a) === 'meeting');
  const hasError = agents.some((a) => a.status === 'error');
  const workingIds = new Set(agents.filter((a) => ['working', 'checking', 'delegating'].includes(a.status) && agentZone(a) === 'desk').map((a) => a.id));

  return (
    <div className="relative overflow-hidden rounded-2xl border border-slate-300 bg-slate-200 shadow-card">
      {/* 時間帯ラベル */}
      <p className="absolute right-3 top-2 z-10 rounded-full bg-white/85 px-2.5 py-0.5 text-[10px] font-medium text-slate-600 shadow-sm">
        {light.emoji} {light.label}
      </p>
      <div className="overflow-x-auto">
        <svg
          viewBox={`0 0 ${VB.w} ${VB.h}`}
          className="block h-auto w-full min-w-[820px]"
          role="img"
          aria-label="バーチャルオフィスの見取り図。AI社員をクリックすると詳細を開けます"
        >
          {/* 建物の床(廊下) */}
          <rect x={0} y={0} width={VB.w} height={VB.h} rx={18} fill="#cbd5e1" />
          <rect x={8} y={8} width={VB.w - 16} height={VB.h - 16} rx={14} fill="#dde3ec" />

          {/* 部屋 */}
          {ROOMS.map((room) => (
            <g key={room.id}>
              <rect x={room.x} y={room.y} width={room.w} height={room.h} rx={10} fill={room.floor} stroke="#94a3b8" strokeWidth={2.5} />
              <rect x={room.x} y={room.y} width={room.w} height={room.h} rx={10} fill="url(#floorTexture)" opacity={0.5} />
              {/* ドア */}
              <rect x={room.x + room.w / 2 - 16} y={room.y + room.h - 3} width={32} height={6} rx={3} fill="#dde3ec" />
              {/* 部屋ラベル */}
              <rect x={room.x + 8} y={room.y + 8} width={room.label.length * 10.5 + 18} height={18} rx={9} fill="#ffffff" opacity={0.9} />
              <circle cx={room.x + 18} cy={room.y + 17} r={3.5} fill={room.accent} />
              <text x={room.x + 27} y={room.y + 21} fontSize={10.5} fill="#334155" fontWeight={700}>
                {room.label}
              </text>
              {/* 会議室の使用中ランプ */}
              {room.id === 'meeting' && (
                <g>
                  <circle cx={room.x + room.w - 22} cy={room.y + 17} r={4} fill={meetingInUse ? '#ef4444' : '#34d399'}>
                    {meetingInUse && <animate attributeName="opacity" values="1;0.4;1" dur="1.8s" repeatCount="indefinite" />}
                  </circle>
                  <text x={room.x + room.w - 30} y={room.y + 21} textAnchor="end" fontSize={9} fill={meetingInUse ? '#b91c1c' : '#047857'}>
                    {meetingInUse ? '使用中' : '空室'}
                  </text>
                </g>
              )}
            </g>
          ))}

          <defs>
            <pattern id="floorTexture" width={26} height={26} patternUnits="userSpaceOnUse">
              <rect width={26} height={26} fill="none" />
              <path d="M 26 0 L 0 0 0 26" fill="none" stroke="#0f172a" strokeOpacity={0.035} strokeWidth={1} />
            </pattern>
          </defs>

          {/* 家具 */}
          <PresidentRoom />
          {Object.entries(DESKS).map(([id, d]) => (
            <Desk key={id} x={d.x} y={d.y} glow={workingIds.has(id)} />
          ))}
          <MeetingTable />
          <ProjectTable />
          <BreakArea />
          <ServerRacks hasError={hasError} />
          <ApprovalArea pending={pending} />
          <Plant x={40} y={228} />
          <Plant x={1240} y={532} />
          <Plant x={648} y={228} />

          {/* 社長(あなた) */}
          <g role="img" aria-label={`${ceoName}(あなた)の席`}>
            <ellipse cx={120} cy={142} rx={13} ry={4.5} fill="#0f172a" opacity={0.14} />
            <circle cx={120} cy={130} r={15} fill="#fff" stroke="#6366f1" strokeWidth={3} />
            <text x={120} y={136} textAnchor="middle" fontSize={15}>🧑‍💼</text>
            <rect x={86} y={147} width={68} height={13} rx={6.5} fill="#ffffff" opacity={0.92} stroke="#e2e8f0" strokeWidth={0.8} />
            <text x={120} y={156.5} textAnchor="middle" fontSize={8.5} fill="#334155" fontWeight={700}>
              {ceoName}(社長)
            </text>
          </g>

          {/* 時間帯の照明オーバーレイ(社員より下・床より上) */}
          {light.opacity > 0 && <rect x={0} y={0} width={VB.w} height={VB.h} rx={18} fill={light.fill} opacity={light.opacity} pointerEvents="none" />}
          {/* 夜はデスクライトが灯る */}
          {period === 'night' &&
            Object.entries(DESKS).map(([id, d]) =>
              workingIds.has(id) ? <circle key={id} cx={d.x} cy={d.y - 42} r={30} fill="#fbbf24" opacity={0.16} pointerEvents="none" /> : null,
            )}

          {/* 受け渡し演出 */}
          <HandoffLayer positions={positions} />

          {/* AI社員 */}
          {agents.map((agent) => {
            const pos = positions.get(agent.id)!;
            return <AgentSprite key={agent.id} agent={agent} pos={pos} onSelect={onSelect} reduced={reduced} />;
          })}

          {/* お祝い演出 */}
          <CelebrationLayer positions={positions} />
        </svg>
      </div>
    </div>
  );
}
