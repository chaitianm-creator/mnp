'use client';

// ============================================================
// 箱庭型AI会社シミュレーター(見下ろし型オフィス)
// - 参考イメージ準拠: 木の温もり+パステル+丸アバター+こげ茶ルームタグ
// - 見た目はゲーム品質、裏側は既存のZustandストアをそのまま使用
// - 部屋・家具はSVGで描画(外部画像なし)
// - AI社員は状態(status/zone)に応じて座標間を「歩いて」移動
// - 仕事の受け渡し/会話吹き出し/時間帯照明/休憩/会議/CEO報告/
//   成果物完成のお祝い演出
// ============================================================
import { agentZone, currentPeriod, type DayPeriod } from '@/lib/office';
import { AGENT_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, OfficeZone } from '@/lib/types';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useEffect, useMemo, useRef, useState } from 'react';

// ---------- レイアウト定義(viewBox 1280x880) ----------

const VB = { w: 1280, h: 880 };

// 参考イメージのパレット(木・パステル)
const P = {
  bgOuter: '#efe6d4',
  bgInner: '#f6efe0',
  wall: '#a98454',
  wallLight: '#c4a071',
  floorWood: '#eeddbc',
  plank: '#dcc394',
  tag: '#6f5b43',
  window: '#bcd9ea',
  windowFrame: '#ffffff',
  night: '#4b4b73',
  nightPlank: '#3f3f63',
};

interface Room {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  night?: boolean; // サーバールーム=夜勤テーマ
  windows?: number; // 上壁の窓の数
}

const ROOMS: Room[] = [
  { id: 'president', label: '社長室', x: 20, y: 20, w: 280, h: 190, windows: 2 },
  { id: 'ceo', label: 'CEO席(経営部)', x: 320, y: 20, w: 320, h: 190, windows: 2 },
  { id: 'secretary', label: '秘書席', x: 660, y: 20, w: 180, h: 190, windows: 1 },
  { id: 'server', label: 'サーバールーム(夜勤)', x: 860, y: 20, w: 180, h: 190, night: true },
  { id: 'break', label: '休憩室', x: 1060, y: 20, w: 200, h: 190, windows: 1 },
  { id: 'sales', label: '営業部', x: 20, y: 240, w: 500, h: 280, windows: 3 },
  { id: 'production', label: '制作部', x: 540, y: 240, w: 500, h: 280, windows: 3 },
  { id: 'marketing', label: 'マーケ部', x: 1060, y: 240, w: 200, h: 280, windows: 1 },
  { id: 'admin', label: '管理部', x: 20, y: 550, w: 240, h: 240, windows: 1 },
  { id: 'meeting', label: '会議室', x: 280, y: 550, w: 380, h: 240, windows: 2 },
  { id: 'project', label: 'プロジェクトテーブル', x: 680, y: 550, w: 320, h: 240, windows: 2 },
  { id: 'approval', label: '承認待ちスペース', x: 1020, y: 550, w: 240, h: 240, windows: 1 },
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
  server: [{ x: 910, y: 155 }, { x: 970, y: 168 }, { x: 940, y: 125 }],
  break: [{ x: 1105, y: 125 }, { x: 1215, y: 125 }, { x: 1110, y: 172 }, { x: 1210, y: 172 }],
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
      map.set(a.id, { x: seat.x + Math.floor(i / seats.length) * 14, y: seat.y + Math.floor(i / seats.length) * 10 });
    }
  }
  return map;
}

// ---------- 家具(SVG・パステル木調) ----------

function Desk({ x, y, glow }: { x: number; y: number; glow: boolean }) {
  return (
    <g>
      <rect x={x - 34} y={y - 52} width={68} height={30} rx={7} fill="#c89b66" stroke="#a87f4d" strokeWidth={2} />
      <rect x={x - 30} y={y - 48} width={60} height={4} rx={2} fill="#ffffff" opacity={0.25} />
      {/* モニター(作業中は点灯) */}
      <rect x={x - 14} y={y - 50} width={28} height={17} rx={3} fill={glow ? '#cfe6f7' : '#5b6472'} stroke="#47505e" strokeWidth={1.5}>
        {glow && <animate attributeName="fill" values="#cfe6f7;#a8d2f0;#cfe6f7" dur="2.4s" repeatCount="indefinite" />}
      </rect>
      <rect x={x - 3} y={y - 33} width={6} height={4} fill="#8a8f99" />
      {glow && <circle cx={x} cy={y - 42} r={18} fill="#7cb8e8" opacity={0.14} />}
      {/* 椅子 */}
      <circle cx={x} cy={y - 4} r={9} fill="#b9c4a3" stroke="#9dab84" strokeWidth={1.2} opacity={0.8} />
    </g>
  );
}

function Bookshelf({ x, y, w = 70 }: { x: number; y: number; w?: number }) {
  const colors = ['#e08a8a', '#8ab0e0', '#8ecf9d', '#e6c46b', '#c39ad6'];
  return (
    <g>
      <rect x={x} y={y} width={w} height={34} rx={4} fill="#b98d5c" stroke="#9a7345" strokeWidth={2} />
      {[0, 1].map((row) => (
        <g key={row}>
          {Array.from({ length: Math.floor((w - 12) / 9) }, (_, i) => (
            <rect key={i} x={x + 6 + i * 9} y={y + 4 + row * 15} width={6} height={11} rx={1} fill={colors[(i + row) % colors.length]} opacity={0.9} />
          ))}
        </g>
      ))}
    </g>
  );
}

function Clock({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <circle cx={x} cy={y} r={9} fill="#ffffff" stroke="#8a6a4a" strokeWidth={2} />
      <line x1={x} y1={y} x2={x} y2={y - 5} stroke="#6f5b43" strokeWidth={1.5} strokeLinecap="round" />
      <line x1={x} y1={y} x2={x + 4} y2={y + 1} stroke="#6f5b43" strokeWidth={1.5} strokeLinecap="round" />
    </g>
  );
}

function MeetingTable() {
  return (
    <g>
      <ellipse cx={470} cy={679} rx={92} ry={44} fill="#caa06c" stroke="#a87f4d" strokeWidth={2.5} />
      <ellipse cx={470} cy={675} rx={92} ry={44} fill="#d9b27e" stroke="#b08c5f" strokeWidth={2} />
      <ellipse cx={470} cy={675} rx={68} ry={29} fill="#e5c592" />
      {/* ホワイトボード */}
      <rect x={300} y={562} width={92} height={42} rx={5} fill="#ffffff" stroke="#a98454" strokeWidth={2} />
      <line x1={310} y1={575} x2={372} y2={575} stroke="#8ecf9d" strokeWidth={3} strokeLinecap="round" />
      <line x1={310} y1={586} x2={356} y2={586} stroke="#d9c9a8" strokeWidth={2.5} strokeLinecap="round" />
      <line x1={310} y1={595} x2={364} y2={595} stroke="#d9c9a8" strokeWidth={2.5} strokeLinecap="round" />
      <Clock x={630} y={575} />
    </g>
  );
}

function ProjectTable() {
  return (
    <g>
      <rect x={758} y={638} width={164} height={74} rx={14} fill="#caa06c" stroke="#a87f4d" strokeWidth={2.5} />
      <rect x={760} y={636} width={160} height={70} rx={13} fill="#d9b27e" stroke="#b08c5f" strokeWidth={2} />
      <rect x={775} y={650} width={40} height={26} rx={3} fill="#fdfaf3" stroke="#d9c9a8" />
      <rect x={825} y={656} width={36} height={22} rx={3} fill="#fbeeb8" stroke="#e0c25c" strokeWidth={0.8} />
      <rect x={872} y={648} width={34} height={28} rx={3} fill="#fdfaf3" stroke="#d9c9a8" />
    </g>
  );
}

function BreakArea() {
  return (
    <g>
      {/* 緑のラグ */}
      <ellipse cx={1160} cy={150} rx={72} ry={38} fill="#bcd9a8" opacity={0.55} />
      {/* ソファ(ピンク) */}
      <rect x={1082} y={98} width={62} height={24} rx={10} fill="#f2b0c1" stroke="#e094ab" strokeWidth={2} />
      <rect x={1192} y={98} width={62} height={24} rx={10} fill="#f2b0c1" stroke="#e094ab" strokeWidth={2} />
      {/* コーヒーテーブル */}
      <circle cx={1160} cy={150} r={16} fill="#d9b27e" stroke="#b08c5f" strokeWidth={2} />
      <text x={1160} y={155} textAnchor="middle" fontSize={12}>☕</text>
      {/* 自販機(ピンク) */}
      <rect x={1230} y={138} width={24} height={40} rx={4} fill="#f4a9bd" stroke="#e094ab" strokeWidth={2} />
      <rect x={1234} y={144} width={16} height={14} rx={2} fill="#fdf1f4" />
      <rect x={1234} y={162} width={16} height={4} rx={1.5} fill="#fdf1f4" opacity={0.8} />
    </g>
  );
}

function ServerRacks({ hasError }: { hasError: boolean }) {
  return (
    <g>
      {/* 月と星(夜勤テーマ) */}
      <text x={1015} y={48} textAnchor="middle" fontSize={14}>🌙</text>
      <circle cx={885} cy={45} r={1.5} fill="#fef3c7" opacity={0.9} />
      <circle cx={990} cy={58} r={1.2} fill="#fef3c7" opacity={0.8} />
      <circle cx={945} cy={40} r={1.5} fill="#fef3c7" opacity={0.7} />
      {[0, 1, 2].map((i) => (
        <g key={i}>
          <rect x={880 + i * 48} y={62} width={34} height={62} rx={4} fill="#33334f" stroke="#26263d" strokeWidth={2} />
          {[0, 1, 2, 3].map((j) => (
            <rect key={j} x={885 + i * 48} y={68 + j * 13} width={24} height={8} rx={2} fill="#454568" />
          ))}
          <circle cx={890 + i * 48} cy={72} r={2} fill={hasError && i === 1 ? '#f87171' : '#6ee7b7'}>
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
      {/* ピンクのラグ */}
      <ellipse cx={160} cy={150} rx={80} ry={34} fill="#f4c6cf" opacity={0.5} />
      {/* 社長デスク */}
      <rect x={60} y={58} width={120} height={46} rx={8} fill="#a87f4d" stroke="#8a6538" strokeWidth={2.5} />
      <rect x={64} y={62} width={112} height={5} rx={2.5} fill="#ffffff" opacity={0.2} />
      <rect x={95} y={66} width={42} height={22} rx={3} fill="#5b6472" stroke="#47505e" strokeWidth={1.5} />
      <Bookshelf x={200} y={56} w={84} />
      <Plant x={276} y={168} />
    </g>
  );
}

function Plant({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x - 8} y={y + 4} width={16} height={13} rx={3} fill="#c98a54" stroke="#a87043" strokeWidth={1.2} />
      <circle cx={x} cy={y - 5} r={11} fill="#8ecf9d" />
      <circle cx={x - 8} cy={y + 1} r={7} fill="#6fbf82" />
      <circle cx={x + 8} cy={y + 1} r={7} fill="#a8dcb2" />
    </g>
  );
}

function FlowerPot({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x - 9} y={y} width={18} height={10} rx={3} fill="#d99a63" stroke="#b57f4c" strokeWidth={1.2} />
      <circle cx={x - 4} cy={y - 4} r={3.5} fill="#f2a9bd" />
      <circle cx={x + 4} cy={y - 4} r={3.5} fill="#f5d76e" />
      <circle cx={x} cy={y - 8} r={3.5} fill="#f8c3d0" />
    </g>
  );
}

function WelcomeMat() {
  return (
    <g>
      <rect x={585} y={812} width={130} height={30} rx={14} fill="#f4b8c6" stroke="#e094ab" strokeWidth={2} />
      <text x={650} y={831} textAnchor="middle" fontSize={12} fill="#9c5b6e" fontWeight={700}>
        ようこそ!🐰
      </text>
    </g>
  );
}

function ApprovalArea({ pending }: { pending: number }) {
  return (
    <g>
      <rect x={1060} y={590} width={160} height={16} rx={7} fill="#d9b27e" stroke="#b08c5f" strokeWidth={1.5} />
      <rect x={1060} y={688} width={160} height={16} rx={7} fill="#d9b27e" stroke="#b08c5f" strokeWidth={1.5} />
      {/* 書類トレイ */}
      <rect x={1224} y={585} width={28} height={20} rx={4} fill="#fdfaf3" stroke="#c4a071" strokeWidth={1.5} />
      <rect x={1228} y={581} width={20} height={4} rx={2} fill="#f5d76e" />
      <text x={1238} y={576} textAnchor="middle" fontSize={11} fill="#b45309" fontWeight={700}>
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
  night: { fill: '#2a2a4a', opacity: 0.32, label: '夜間は一部AIのみ稼働中', emoji: '🌙' },
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

  const showBubble =
    agent.statusNote.startsWith('💬') ||
    ['waiting_approval', 'error', 'done', 'meeting'].includes(agent.status) ||
    (busy && agent.progress > 0);
  const bubbleText = agent.statusNote.replace(/^💬 ?/, '').slice(0, 14) + (agent.statusNote.length > 15 ? '…' : '');
  const dotColor =
    agent.status === 'error' ? '#ef4444' : agent.status === 'waiting_approval' ? '#f59e0b' : agent.status === 'done' ? '#10b981' : busy ? '#34c759' : '#b8b3a6';

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
        <ellipse cx={0} cy={13} rx={14} ry={4.5} fill="#8a6a4a" opacity={0.18} />
        {/* 体(白丸+カラーリング — 参考イメージの丸アバター) */}
        <circle r={16.5} fill="#ffffff" stroke="#e8ddc8" strokeWidth={1} opacity={agent.status === 'paused' ? 0.6 : 1} />
        <circle r={16.5} fill="none" stroke={agent.color} strokeWidth={2.6} opacity={agent.status === 'paused' ? 0.4 : 0.9} />
        <text y={6} textAnchor="middle" fontSize={16} aria-hidden>
          {agent.avatar}
        </text>
        {/* 状態ドット(右下・参考イメージ準拠) */}
        <circle cx={11.5} cy={11.5} r={4.5} fill={dotColor} stroke="#fff" strokeWidth={1.6}>
          {busy && !reduced && <animate attributeName="opacity" values="1;0.4;1" dur="1.6s" repeatCount="indefinite" />}
        </circle>
        {/* 完了フラッシュ */}
        {agent.status === 'done' && (
          <motion.circle r={16.5} fill="none" stroke="#10b981" strokeWidth={2.5} initial={{ opacity: 0.9, scale: 1 }} animate={{ opacity: 0, scale: 1.9 }} transition={{ duration: 1.4, repeat: 2 }} />
        )}
        {/* 未読バッジ */}
        {unread > 0 && (
          <g>
            <circle cx={-12} cy={-12} r={6.5} fill="#4f46e5" stroke="#fff" strokeWidth={1.4} />
            <text x={-12} y={-9} textAnchor="middle" fontSize={8.5} fill="#fff" fontWeight={700}>
              {unread}
            </text>
          </g>
        )}
        {/* 名札(白ピル・参考イメージ準拠) */}
        <rect x={-36} y={19} width={72} height={15} rx={7.5} fill="#ffffff" stroke="#e3d7bd" strokeWidth={1.2} />
        <text y={29.5} textAnchor="middle" fontSize={9} fill="#6f5b43" fontWeight={700}>
          {agent.name.slice(0, 9)}
        </text>
        {/* 進捗ミニバー */}
        {busy && agent.progress > 0 && (
          <g>
            <rect x={-16} y={37} width={32} height={3.5} rx={1.75} fill="#e8ddc8" />
            <rect x={-16} y={37} width={(32 * agent.progress) / 100} height={3.5} rx={1.75} fill={agent.color} />
          </g>
        )}
        {/* 吹き出し */}
        <AnimatePresence>
          {showBubble && bubbleText && (
            <motion.g initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.3 }}>
              <rect x={-bubbleText.length * 4.6 - 8} y={-48} width={bubbleText.length * 9.2 + 16} height={20} rx={10} fill="#ffffff" stroke="#e3d7bd" strokeWidth={1.2} opacity={0.97} />
              <path d="M -4 -29 L 0 -22 L 4 -29 Z" fill="#ffffff" stroke="#e3d7bd" strokeWidth={0.8} />
              <text y={-34.5} textAnchor="middle" fontSize={9.5} fill="#5c4c38">
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

  useEffect(() => {
    const latest = achievements[0];
    if (!latest || seenAch.current === latest.id) return;
    const isFirst = seenAch.current === null;
    seenAch.current = latest.id;
    if (isFirst) return;
    const pos = positions.get(latest.agentId);
    if (pos) setBursts((b) => [...b.slice(-3), { id: latest.id, x: pos.x, y: pos.y, big: false }]);
  }, [achievements, positions]);

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
              const colors = ['#f2a9bd', '#f5d76e', '#8ecf9d', '#8ab0e0', '#c39ad6'];
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
    <div className="relative overflow-hidden rounded-2xl border border-[#dccbaa] bg-[#efe6d4] shadow-card">
      <p className="absolute right-3 top-2 z-10 rounded-full bg-white/90 px-2.5 py-0.5 text-[10px] font-medium text-[#6f5b43] shadow-sm">
        {light.emoji} {light.label}
      </p>
      <div className="overflow-x-auto">
        <svg
          viewBox={`0 0 ${VB.w} ${VB.h}`}
          className="block h-auto w-full min-w-[820px]"
          role="img"
          aria-label="バーチャルオフィスの見取り図。AI社員をクリックすると詳細を開けます"
        >
          <defs>
            {/* 木の床(縦板) */}
            <pattern id="planks" width={26} height={26} patternUnits="userSpaceOnUse">
              <rect width={26} height={26} fill="none" />
              <line x1={0} y1={0} x2={0} y2={26} stroke={P.plank} strokeOpacity={0.5} strokeWidth={1.4} />
              <line x1={13} y1={0} x2={13} y2={26} stroke={P.plank} strokeOpacity={0.25} strokeWidth={1} />
            </pattern>
            <pattern id="planksNight" width={26} height={26} patternUnits="userSpaceOnUse">
              <rect width={26} height={26} fill="none" />
              <line x1={0} y1={0} x2={0} y2={26} stroke={P.nightPlank} strokeOpacity={0.7} strokeWidth={1.4} />
            </pattern>
          </defs>

          {/* 建物の外枠と廊下 */}
          <rect x={0} y={0} width={VB.w} height={VB.h} rx={22} fill={P.bgOuter} />
          <rect x={8} y={8} width={VB.w - 16} height={VB.h - 16} rx={18} fill={P.bgInner} />

          {/* 部屋 */}
          {ROOMS.map((room) => (
            <g key={room.id}>
              {/* 壁(木枠)と床 */}
              <rect x={room.x - 4} y={room.y - 4} width={room.w + 8} height={room.h + 8} rx={16} fill={P.wall} />
              <rect x={room.x} y={room.y} width={room.w} height={room.h} rx={12} fill={room.night ? P.night : P.floorWood} />
              <rect x={room.x} y={room.y} width={room.w} height={room.h} rx={12} fill={`url(#${room.night ? 'planksNight' : 'planks'})`} />
              {/* 窓(上壁・青) */}
              {!room.night &&
                Array.from({ length: room.windows ?? 0 }, (_, i) => {
                  const wx = room.x + room.w - 34 - i * 42;
                  return (
                    <g key={i}>
                      <rect x={wx} y={room.y - 3} width={28} height={12} rx={3} fill={P.window} stroke={P.windowFrame} strokeWidth={2} />
                      <line x1={wx + 14} y1={room.y - 3} x2={wx + 14} y2={room.y + 9} stroke={P.windowFrame} strokeWidth={1.5} />
                    </g>
                  );
                })}
              {/* ドア(下壁) */}
              <rect x={room.x + room.w / 2 - 16} y={room.y + room.h - 4} width={32} height={8} rx={4} fill={P.bgInner} stroke={P.wallLight} strokeWidth={1} />
              {/* 部屋ラベル(こげ茶タグ・参考イメージ準拠) */}
              <rect x={room.x + 6} y={room.y + 6} width={room.label.length * 11 + 16} height={20} rx={6} fill={P.tag} opacity={0.95} />
              <text x={room.x + 14} y={room.y + 20} fontSize={11} fill="#fdfaf3" fontWeight={700}>
                {room.label}
              </text>
              {/* 会議室の使用中ランプ */}
              {room.id === 'meeting' && (
                <g>
                  <circle cx={room.x + room.w - 22} cy={room.y + 16} r={4} fill={meetingInUse ? '#ef4444' : '#34c759'}>
                    {meetingInUse && <animate attributeName="opacity" values="1;0.4;1" dur="1.8s" repeatCount="indefinite" />}
                  </circle>
                  <text x={room.x + room.w - 30} y={room.y + 20} textAnchor="end" fontSize={9} fill={meetingInUse ? '#b91c1c' : '#2e7d4f'}>
                    {meetingInUse ? '使用中' : '空室'}
                  </text>
                </g>
              )}
            </g>
          ))}

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
          <Bookshelf x={130} y={560} w={100} />
          <Clock x={60} y={600} />
          <Plant x={40} y={226} />
          <Plant x={1240} y={534} />
          <Plant x={648} y={226} />
          <FlowerPot x={550} y={824} />
          <FlowerPot x={750} y={824} />
          <WelcomeMat />

          {/* 社長(あなた) */}
          <g role="img" aria-label={`${ceoName}(あなた)の席`}>
            <ellipse cx={120} cy={144} rx={14} ry={4.5} fill="#8a6a4a" opacity={0.18} />
            <circle cx={120} cy={130} r={16.5} fill="#fff" stroke="#e8ddc8" strokeWidth={1} />
            <circle cx={120} cy={130} r={16.5} fill="none" stroke="#6366f1" strokeWidth={2.6} opacity={0.9} />
            <text x={120} y={136} textAnchor="middle" fontSize={16}>🧑‍💼</text>
            <rect x={84} y={149} width={72} height={15} rx={7.5} fill="#ffffff" stroke="#e3d7bd" strokeWidth={1.2} />
            <text x={120} y={159.5} textAnchor="middle" fontSize={9} fill="#6f5b43" fontWeight={700}>
              {ceoName}(社長)
            </text>
          </g>

          {/* 時間帯の照明オーバーレイ */}
          {light.opacity > 0 && <rect x={0} y={0} width={VB.w} height={VB.h} rx={22} fill={light.fill} opacity={light.opacity} pointerEvents="none" />}
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
