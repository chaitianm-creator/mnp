'use client';

// ============================================================
// 箱庭型AI会社シミュレーター v3(生きている会社)
// - 2.5頭身のチビキャラ(頭・体・手足・歩行サイクル・待機モーション)
// - 部屋ごとの生活感家具(トロフィー/コピー機/冷蔵庫/ホログラム等)
// - 足跡・キラキラ・メール・拍手・花火などの控えめエフェクト
// - 見た目はゲーム品質、裏側は既存Zustandストアをそのまま使用
//   (このファイルは描画のみ。状態管理ロジックには一切触れない)
// ============================================================
import { agentZone, currentPeriod, type DayPeriod } from '@/lib/office';
import { AGENT_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Agent, OfficeZone } from '@/lib/types';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useEffect, useMemo, useRef, useState } from 'react';

// ---------- レイアウト定義(viewBox 1280x880) ----------

const VB = { w: 1280, h: 880 };

const P = {
  bgOuter: '#f3ede1',
  bgInner: '#faf6ec',
  wall: '#e7d3ae',
  wallStroke: '#cfb488',
  wallLight: '#e0cda6',
  floorWood: '#f3e8d2',
  plank: '#e7d8b8',
  tag: '#6f5b43',
  window: '#cfe8f5',
  windowFrame: '#ffffff',
  night: '#6f6a9e',
  nightPlank: '#635d92',
  skin: '#ffe3c9',
  paper: '#fdfaf3',
  woodDark: '#b89460',
  wood: '#dbbc8d',
  woodLight: '#e8d2ab',
};

interface Room {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  night?: boolean;
  windows?: number;
  floor?: string; // 部屋ごとのパステル床色(未指定はクリーム)
}

const ROOMS: Room[] = [
  { id: 'president', label: '社長室', x: 20, y: 20, w: 280, h: 190, windows: 2, floor: '#f8dfe3' },
  { id: 'ceo', label: 'CEO席(経営部)', x: 320, y: 20, w: 320, h: 190, windows: 2, floor: '#f3e8d2' },
  { id: 'secretary', label: '秘書席', x: 660, y: 20, w: 180, h: 190, windows: 1, floor: '#fcefdc' },
  { id: 'server', label: 'AI研究室(夜勤)', x: 860, y: 20, w: 180, h: 190, night: true },
  { id: 'break', label: '休憩室', x: 1060, y: 20, w: 200, h: 190, windows: 1, floor: '#e6f0d9' },
  { id: 'sales', label: '営業部', x: 20, y: 240, w: 500, h: 280, windows: 3, floor: '#f3e8d2' },
  { id: 'production', label: '制作部', x: 540, y: 240, w: 500, h: 280, windows: 3, floor: '#fbe4e9' },
  { id: 'marketing', label: 'マーケ部', x: 1060, y: 240, w: 200, h: 280, windows: 1, floor: '#ece5f5' },
  { id: 'admin', label: '管理部', x: 20, y: 550, w: 240, h: 240, windows: 1, floor: '#f0ead8' },
  { id: 'meeting', label: '会議室', x: 280, y: 550, w: 380, h: 240, windows: 2, floor: '#f0dfc0' },
  { id: 'project', label: 'プロジェクトテーブル', x: 680, y: 550, w: 320, h: 240, windows: 2, floor: '#e3edf7' },
  { id: 'approval', label: '承認待ちスペース', x: 1020, y: 550, w: 240, h: 240, windows: 1, floor: '#faf0d7' },
];

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

// 椅子のパステルカラー(デスクごとに交互)
const CHAIR_COLORS = ['#f5b8c4', '#a9c8ea', '#a8d8b4', '#f2d488', '#c9b3e0'];

const seatsAround = (cx: number, cy: number, rx: number, ry: number, n: number) =>
  Array.from({ length: n }, (_, i) => {
    const a = (i / n) * Math.PI * 2 - Math.PI / 2;
    return { x: cx + Math.cos(a) * rx, y: cy + Math.sin(a) * ry };
  });

const ZONE_CENTERS: Record<string, { x: number; y: number }> = {
  meeting: { x: 470, y: 675 },
  project: { x: 840, y: 675 },
};

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

// ============================================================
// 家具(SVG・パステル木調)
// ============================================================

function Desk({ x, y, glow, chairColor = '#f5b8c4' }: { x: number; y: number; glow: boolean; chairColor?: string }) {
  return (
    <g>
      {/* デスク下のふんわり丸ラグ */}
      <ellipse cx={x} cy={y - 8} rx={44} ry={23} fill="#ffffff" opacity={0.2} />
      {/* 椅子(社員が離席していても見える) */}
      <ellipse cx={x} cy={y + 10} rx={10} ry={6} fill={chairColor} stroke="#ffffff" strokeWidth={1.8} />
      <ellipse cx={x} cy={y + 8} rx={8} ry={4.5} fill="#ffffff" opacity={0.3} />
      {/* 明るい木のデスク */}
      <rect x={x - 33} y={y - 50} width={66} height={28} rx={9} fill={P.woodLight} stroke={P.wallStroke} strokeWidth={1.8} />
      <rect x={x - 29} y={y - 46} width={58} height={4} rx={2} fill="#ffffff" opacity={0.4} />
      <rect x={x - 13} y={y - 48} width={26} height={16} rx={3.5} fill={glow ? '#d8effc' : '#7d8494'} stroke={glow ? '#a5cfe8' : '#6a7080'} strokeWidth={1.5}>
        {glow && <animate attributeName="fill" values="#d8effc;#b5dcf5;#d8effc" dur="2.4s" repeatCount="indefinite" />}
      </rect>
      <rect x={x - 3} y={y - 32} width={6} height={4} rx={1} fill="#9aa0ad" />
      {glow && <circle cx={x} cy={y - 40} r={17} fill="#8fc5ec" opacity={0.13} />}
      {/* 書類とマグ */}
      <rect x={x + 17} y={y - 44} width={11} height={8} rx={1.5} fill={P.paper} stroke="#e0d4b8" strokeWidth={0.8} transform={`rotate(6 ${x + 22} ${y - 40})`} />
      <circle cx={x - 23} cy={y - 38} r={3.5} fill="#f2b0c1" stroke="#e094ab" strokeWidth={1} />
    </g>
  );
}

function Bookshelf({ x, y, w = 70, trophy }: { x: number; y: number; w?: number; trophy?: boolean }) {
  const colors = ['#e08a8a', '#8ab0e0', '#8ecf9d', '#e6c46b', '#c39ad6'];
  return (
    <g>
      <rect x={x} y={y} width={w} height={34} rx={4} fill="#b98d5c" stroke="#9a7345" strokeWidth={2} />
      {[0, 1].map((row) => (
        <g key={row}>
          {Array.from({ length: Math.floor((w - 12) / 9) }, (_, i) =>
            trophy && row === 0 && i === Math.floor((w - 12) / 18) ? null : (
              <rect key={i} x={x + 6 + i * 9} y={y + 4 + row * 15} width={6} height={11} rx={1} fill={colors[(i + row) % colors.length]} opacity={0.9} />
            ),
          )}
        </g>
      ))}
      {trophy && (
        <text x={x + w / 2} y={y + 13} textAnchor="middle" fontSize={11}>🏆</text>
      )}
    </g>
  );
}

function Clock({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <circle cx={x} cy={y} r={9} fill="#ffffff" stroke="#8a6a4a" strokeWidth={2} />
      <line x1={x} y1={y} x2={x} y2={y - 5} stroke={P.tag} strokeWidth={1.5} strokeLinecap="round" />
      <line x1={x} y1={y} x2={x + 4} y2={y + 1} stroke={P.tag} strokeWidth={1.5} strokeLinecap="round" />
    </g>
  );
}

function Poster({ x, y, color }: { x: number; y: number; color: string }) {
  return (
    <g>
      <rect x={x} y={y} width={26} height={34} rx={3} fill="#ffffff" stroke="#d9c9a8" strokeWidth={1.5} />
      <rect x={x + 4} y={y + 4} width={18} height={14} rx={2} fill={color} opacity={0.55} />
      <line x1={x + 4} y1={y + 23} x2={x + 22} y2={y + 23} stroke="#d9c9a8" strokeWidth={2} strokeLinecap="round" />
      <line x1={x + 4} y1={y + 28} x2={x + 17} y2={y + 28} stroke="#e8ddc8" strokeWidth={2} strokeLinecap="round" />
    </g>
  );
}

function Whiteboard({ x, y, w = 92 }: { x: number; y: number; w?: number }) {
  return (
    <g>
      <rect x={x} y={y} width={w} height={42} rx={5} fill="#ffffff" stroke={P.wall} strokeWidth={2} />
      <line x1={x + 10} y1={y + 13} x2={x + w * 0.75} y2={y + 13} stroke="#8ecf9d" strokeWidth={3} strokeLinecap="round" />
      <line x1={x + 10} y1={y + 24} x2={x + w * 0.6} y2={y + 24} stroke="#d9c9a8" strokeWidth={2.5} strokeLinecap="round" />
      <line x1={x + 10} y1={y + 33} x2={x + w * 0.68} y2={y + 33} stroke="#f2b0c1" strokeWidth={2.5} strokeLinecap="round" />
    </g>
  );
}

function Phone({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x - 8} y={y - 5} width={16} height={10} rx={2.5} fill="#8ab0e0" stroke="#6b93c9" strokeWidth={1.2} />
      <rect x={x - 10} y={y - 9} width={20} height={5} rx={2.5} fill="#6b93c9" />
    </g>
  );
}

function CardRack({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={26} height={14} rx={2} fill={P.woodLight} stroke={P.woodDark} strokeWidth={1.2} />
      {[0, 1, 2].map((i) => (
        <rect key={i} x={x + 3 + i * 8} y={y - 4} width={6} height={9} rx={1} fill={P.paper} stroke="#d9c9a8" strokeWidth={0.7} />
      ))}
    </g>
  );
}

function BigMonitor({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x - 24} y={y - 16} width={48} height={28} rx={3.5} fill="#47505e" stroke="#333b47" strokeWidth={2} />
      <rect x={x - 20} y={y - 12} width={40} height={20} rx={2} fill="#a8d2f0">
        <animate attributeName="fill" values="#a8d2f0;#c5e3f7;#a8d2f0" dur="3.2s" repeatCount="indefinite" />
      </rect>
      <rect x={x - 5} y={y + 12} width={10} height={4} fill="#5b6472" />
    </g>
  );
}

function PenTab({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={22} height={15} rx={2.5} fill="#e8e2d4" stroke="#c9bda0" strokeWidth={1.2} />
      <rect x={x + 3} y={y + 3} width={16} height={9} rx={1.5} fill="#ffffff" />
      <line x1={x + 26} y1={y + 2} x2={x + 32} y2={y + 12} stroke="#6f5b43" strokeWidth={2} strokeLinecap="round" />
    </g>
  );
}

function Palette({ x, y }: { x: number; y: number }) {
  const colors = ['#f2a9bd', '#f5d76e', '#8ecf9d', '#8ab0e0'];
  return (
    <g>
      <ellipse cx={x} cy={y} rx={13} ry={10} fill={P.paper} stroke="#d9c9a8" strokeWidth={1.2} />
      {colors.map((c, i) => (
        <circle key={i} cx={x - 6 + (i % 2) * 10} cy={y - 3 + Math.floor(i / 2) * 7} r={2.6} fill={c} />
      ))}
    </g>
  );
}

function Cabinet({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={30} height={46} rx={4} fill="#c9b28a" stroke="#a8905f" strokeWidth={2} />
      {[0, 1, 2].map((i) => (
        <g key={i}>
          <rect x={x + 4} y={y + 5 + i * 14} width={22} height={10} rx={2} fill="#e3d3ae" stroke="#c4ab7d" strokeWidth={1} />
          <rect x={x + 12} y={y + 9 + i * 14} width={6} height={2} rx={1} fill="#8a744c" />
        </g>
      ))}
    </g>
  );
}

function Copier({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={38} height={30} rx={4} fill="#e8e2d4" stroke="#c9bda0" strokeWidth={2} />
      <rect x={x + 4} y={y - 4} width={30} height={7} rx={2} fill="#d4ccba" stroke="#b8ae97" strokeWidth={1} />
      <rect x={x + 8} y={y + 8} width={14} height={4} rx={1} fill="#8ab0e0" />
      <circle cx={x + 31} cy={y + 10} r={2} fill="#8ecf9d">
        <animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite" />
      </circle>
      <rect x={x + 6} y={y + 18} width={26} height={7} rx={1.5} fill={P.paper} stroke="#d9c9a8" strokeWidth={0.8} />
    </g>
  );
}

function Fridge({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={26} height={44} rx={5} fill="#ffffff" stroke="#cfc4ab" strokeWidth={2} />
      <line x1={x + 2} y1={y + 16} x2={x + 24} y2={y + 16} stroke="#cfc4ab" strokeWidth={1.5} />
      <rect x={x + 19} y={y + 6} width={3} height={7} rx={1.5} fill="#b8ae97" />
      <rect x={x + 19} y={y + 20} width={3} height={9} rx={1.5} fill="#b8ae97" />
      <circle cx={x + 8} cy={y + 8} r={2.5} fill="#f2a9bd" />
    </g>
  );
}

function Microwave({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={30} height={18} rx={3} fill="#d8d2c2" stroke="#b8ae97" strokeWidth={1.5} />
      <rect x={x + 3} y={y + 3} width={17} height={12} rx={2} fill="#6f6a5c" />
      <circle cx={x + 25} cy={y + 6} r={1.6} fill="#e08a8a" />
      <circle cx={x + 25} cy={y + 12} r={1.6} fill="#8ecf9d" />
    </g>
  );
}

function Snacks({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={20} height={12} rx={3} fill="#f5d76e" stroke="#dcb845" strokeWidth={1.2} />
      <text x={x + 10} y={y + 9} textAnchor="middle" fontSize={7}>🍪</text>
      <rect x={x + 24} y={y - 2} width={10} height={14} rx={2} fill="#f2a9bd" stroke="#e094ab" strokeWidth={1} />
    </g>
  );
}

function CoffeeMachine({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={20} height={24} rx={3} fill="#8a744c" stroke="#6f5b43" strokeWidth={1.5} />
      <rect x={x + 4} y={y + 4} width={12} height={6} rx={1.5} fill="#e3d3ae" />
      <rect x={x + 7} y={y + 14} width={6} height={6} rx={1} fill="#ffffff" />
      <circle cx={x + 10} cy={y + 12} r={1} fill="#6ee7b7">
        <animate attributeName="opacity" values="1;0.3;1" dur="1.8s" repeatCount="indefinite" />
      </circle>
    </g>
  );
}

function WallScreen({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={64} height={36} rx={4} fill="#47505e" stroke="#333b47" strokeWidth={2} />
      <rect x={x + 4} y={y + 4} width={56} height={28} rx={2.5} fill="#cfe6f7" />
      <rect x={x + 9} y={y + 9} width={22} height={4} rx={2} fill="#8ab0e0" />
      <rect x={x + 9} y={y + 17} width={34} height={3} rx={1.5} fill="#c5d8ea" />
      <rect x={x + 9} y={y + 23} width={28} height={3} rx={1.5} fill="#c5d8ea" />
    </g>
  );
}

function Projector({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={22} height={11} rx={4} fill="#8a8f99" stroke="#6b7280" strokeWidth={1.2} />
      <circle cx={x + 4} cy={y + 5.5} r={3} fill="#fef3c7" opacity={0.9} />
      <polygon points={`${x + 1},${y + 5.5} ${x - 26},${y - 6} ${x - 26},${y + 17}`} fill="#fef3c7" opacity={0.18} />
    </g>
  );
}

function Hologram({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <polygon points={`${x - 4},${y} ${x + 4},${y} ${x + 16},${y - 34} ${x - 16},${y - 34}`} fill="#7dd3fc" opacity={0.16}>
        <animate attributeName="opacity" values="0.1;0.22;0.1" dur="3s" repeatCount="indefinite" />
      </polygon>
      <ellipse cx={x} cy={y - 24} rx={12} ry={3.5} fill="none" stroke="#7dd3fc" strokeWidth={1.2} opacity={0.5}>
        <animate attributeName="cy" values={`${y - 18};${y - 30};${y - 18}`} dur="4s" repeatCount="indefinite" />
      </ellipse>
      <text x={x} y={y - 22} textAnchor="middle" fontSize={10} opacity={0.85}>📊</text>
      <ellipse cx={x} cy={y + 1} rx={7} ry={2.2} fill="#7dd3fc" opacity={0.4} />
    </g>
  );
}

function Tree({ x, y, colors }: { x: number; y: number; colors?: { main: string; left: string; right: string; accent: string } }) {
  const c = colors ?? { main: '#8ecf9d', left: '#6fbf82', right: '#a8dcb2', accent: '#f8c3d0' };
  return (
    <g>
      <ellipse cx={x} cy={y + 22} rx={26} ry={7} fill="#8a6a4a" opacity={0.15} />
      <rect x={x - 4} y={y} width={8} height={22} rx={3} fill="#a87043" />
      <circle cx={x} cy={y - 16} r={22} fill={c.main} />
      <circle cx={x - 16} cy={y - 6} r={14} fill={c.left} />
      <circle cx={x + 16} cy={y - 6} r={14} fill={c.right} />
      <circle cx={x - 6} cy={y - 26} r={3} fill={c.accent} />
      <circle cx={x + 10} cy={y - 18} r={3} fill={c.accent} />
    </g>
  );
}

function Sofa({ x, y, w = 62, color = '#f2b0c1', stroke = '#e094ab' }: { x: number; y: number; w?: number; color?: string; stroke?: string }) {
  return (
    <g>
      <rect x={x} y={y} width={w} height={24} rx={10} fill={color} stroke={stroke} strokeWidth={2} />
      <rect x={x + 5} y={y - 5} width={w - 10} height={9} rx={4.5} fill={color} stroke={stroke} strokeWidth={1.5} />
    </g>
  );
}

function Calendar({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={22} height={24} rx={3} fill="#ffffff" stroke="#d9c9a8" strokeWidth={1.5} />
      <rect x={x} y={y} width={22} height={7} rx={3} fill="#e08a8a" />
      {[0, 1].map((r) =>
        [0, 1, 2].map((c) => <circle key={`${r}${c}`} cx={x + 5 + c * 6} cy={y + 13 + r * 6} r={1.3} fill="#d9c9a8" />),
      )}
    </g>
  );
}

function MeetingTable({ lampOn }: { lampOn: boolean }) {
  return (
    <g>
      <Rug x={470} y={678} rx={128} ry={64} color="#bfe3c5" />
      <ellipse cx={470} cy={679} rx={92} ry={44} fill="#caa06c" stroke={P.woodDark} strokeWidth={2.5} />
      <ellipse cx={470} cy={675} rx={92} ry={44} fill={P.woodLight} stroke="#b08c5f" strokeWidth={2} />
      <ellipse cx={470} cy={675} rx={68} ry={29} fill="#e5c592" />
      {/* 会議資料 */}
      <rect x={448} y={664} width={16} height={11} rx={1.5} fill={P.paper} stroke="#d9c9a8" strokeWidth={0.8} transform="rotate(-8 456 669)" />
      <rect x={472} y={668} width={16} height={11} rx={1.5} fill={P.paper} stroke="#d9c9a8" strokeWidth={0.8} transform="rotate(6 480 673)" />
      <Whiteboard x={344} y={566} />
      <WallScreen x={548} y={560} />
      <Projector x={500} y={690} />
      <Clock x={630} y={575} />
      <PendantLamp x={470} y={600} on={lampOn} />
    </g>
  );
}

function ProjectTable() {
  return (
    <g>
      <rect x={758} y={638} width={164} height={74} rx={14} fill="#caa06c" stroke={P.woodDark} strokeWidth={2.5} />
      <rect x={760} y={636} width={160} height={70} rx={13} fill={P.woodLight} stroke="#b08c5f" strokeWidth={2} />
      <rect x={775} y={650} width={40} height={26} rx={3} fill={P.paper} stroke="#d9c9a8" />
      <rect x={825} y={656} width={36} height={22} rx={3} fill="#fbeeb8" stroke="#e0c25c" strokeWidth={0.8} />
      <rect x={872} y={648} width={34} height={28} rx={3} fill={P.paper} stroke="#d9c9a8" />
      <Poster x={700} y={586} color="#8ab0e0" />
    </g>
  );
}

function BreakRoom({ lightsOn }: { lightsOn: boolean }) {
  return (
    <g>
      {/* カフェ風の休憩室: ガーランドライト+丸ラグ+メニューボード */}
      <ellipse cx={1160} cy={150} rx={72} ry={38} fill="#bcd9a8" opacity={0.55} />
      <Rug x={1160} y={150} rx={58} ry={28} color="#f4c6cf" />
      <Sofa x={1082} y={98} />
      <Sofa x={1192} y={98} />
      <circle cx={1160} cy={150} r={16} fill={P.woodLight} stroke="#b08c5f" strokeWidth={2} />
      <text x={1160} y={155} textAnchor="middle" fontSize={12}>☕</text>
      <Steam x={1156} y={141} />
      {/* 冷蔵庫・電子レンジ・お菓子・コーヒーマシン */}
      <Fridge x={1228} y={132} />
      <Microwave x={1070} y={178} />
      <Snacks x={1130} y={186} />
      <CoffeeMachine x={1186} y={178} />
      <MenuBoard x={1068} y={92} />
      <HangingPlant x={1246} y={44} />
      <StringLights x1={1072} x2={1250} y={38} on={lightsOn} />
    </g>
  );
}

function ServerRoom({ hasError }: { hasError: boolean }) {
  return (
    <g>
      {/* やさしい紫の夜勤室: 月・星・月夜モニターのミニデスク */}
      <text x={1015} y={52} textAnchor="middle" fontSize={13}>🌙</text>
      {[
        { x: 885, y: 48, r: 1.5 },
        { x: 990, y: 60, r: 1.2 },
        { x: 945, y: 42, r: 1.5 },
        { x: 912, y: 58, r: 1 },
      ].map((s, i) => (
        <circle key={i} cx={s.x} cy={s.y} r={s.r} fill="#fef3c7" opacity={0.85}>
          <animate attributeName="opacity" values="0.85;0.3;0.85" dur={`${2.2 + i * 0.6}s`} repeatCount="indefinite" />
        </circle>
      ))}
      {[0, 1, 2].map((i) => (
        <g key={i}>
          <rect x={878 + i * 50} y={70} width={38} height={52} rx={6} fill="#57518a" stroke="#454070" strokeWidth={1.8} />
          <rect x={883 + i * 50} y={76} width={28} height={18} rx={3} fill="#8d86c9" opacity={0.8} />
          <path d={`M ${901 + i * 50} 83 a 4.5 4.5 0 1 1 -4 -6.8 a 3.6 3.6 0 0 0 4 6.8`} fill="#fdf3c0" />
          {[0, 1].map((j) => (
            <rect key={j} x={883 + i * 50} y={100 + j * 9} width={28} height={5.5} rx={2.5} fill="#6b64a3" />
          ))}
          <circle cx={886 + i * 50} cy={74} r={1.8} fill={hasError && i === 1 ? '#f8a3a3' : '#a3e8c5'}>
            <animate attributeName="opacity" values="1;0.3;1" dur={`${1.4 + i * 0.4}s`} repeatCount="indefinite" />
          </circle>
        </g>
      ))}
      {/* ホログラム風演出 */}
      <Hologram x={945} y={178} />
      <Plant x={880} y={188} />
    </g>
  );
}

function PresidentRoom() {
  return (
    <g>
      <ellipse cx={160} cy={150} rx={80} ry={34} fill="#f4c6cf" opacity={0.5} />
      <rect x={60} y={58} width={120} height={46} rx={8} fill={P.woodDark} stroke="#8a6538" strokeWidth={2.5} />
      <rect x={64} y={62} width={112} height={5} rx={2.5} fill="#ffffff" opacity={0.2} />
      <rect x={95} y={66} width={42} height={22} rx={3} fill="#5b6472" stroke="#47505e" strokeWidth={1.5} />
      <Bookshelf x={200} y={56} w={84} trophy />
      <Sofa x={40} y={160} w={56} color="#f7d9b8" stroke="#e0b98a" />
      <Plant x={276} y={168} />
      <Plant x={40} y={120} />
      <HangingPlant x={160} y={28} />
    </g>
  );
}

function SalesRoom() {
  return (
    <g>
      <Rug x={270} y={405} rx={150} ry={52} color="#bcd9ea" />
      <Whiteboard x={40} y={274} w={80} />
      <Phone x={455} y={318} />
      <CardRack x={150} y={310} />
      {/* 営業資料の山 */}
      <g>
        <rect x={310} y={306} width={16} height={11} rx={1.5} fill={P.paper} stroke="#d9c9a8" strokeWidth={0.8} />
        <rect x={312} y={303} width={16} height={11} rx={1.5} fill={P.paper} stroke="#d9c9a8" strokeWidth={0.8} />
      </g>
      <Plant x={496} y={492} />
      <HangingPlant x={252} y={248} />
    </g>
  );
}

function ProductionRoom() {
  return (
    <g>
      <BigMonitor x={905} y={290} />
      <PenTab x={968} y={306} />
      <Palette x={922} y={318} />
      <Poster x={610} y={258} color="#f2a9bd" />
      <Poster x={642} y={258} color="#8ecf9d" />
      {/* デザインサンプル */}
      <rect x={690} y={300} width={14} height={18} rx={2} fill="#f8e3ec" stroke="#e8c9d8" strokeWidth={1} transform="rotate(-6 697 309)" />
      <rect x={708} y={302} width={14} height={18} rx={2} fill="#e3ecf8" stroke="#c9d8e8" strokeWidth={1} transform="rotate(5 715 311)" />
      <Plant x={1020} y={492} />
      <Rug x={790} y={405} rx={150} ry={52} color="#f4c6cf" />
      <HangingPlant x={772} y={248} />
    </g>
  );
}

function AdminRoom() {
  return (
    <g>
      <Cabinet x={30} y={596} />
      <Copier x={190} y={586} />
      <Bookshelf x={110} y={562} w={76} />
      <Clock x={236} y={572} />
    </g>
  );
}

function SecretaryRoom() {
  return (
    <g>
      <Calendar x={680} y={62} />
      <FlowerVase x={812} y={90} />
    </g>
  );
}

function FlowerVase({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x - 4} y={y} width={8} height={10} rx={2.5} fill="#bcd9ea" stroke="#9cc0d6" strokeWidth={1} />
      <circle cx={x - 3} cy={y - 5} r={3} fill="#f2a9bd" />
      <circle cx={x + 3} cy={y - 6} r={3} fill="#f5d76e" />
      <circle cx={x} cy={y - 9} r={3} fill="#f8c3d0" />
    </g>
  );
}

function MarketingRoom() {
  return (
    <g>
      <Poster x={1080} y={258} color="#f5d76e" />
      <text x={1226} y={290} textAnchor="middle" fontSize={13}>📣</text>
      <Plant x={1080} y={492} />
      <HangingPlant x={1160} y={248} />
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

// ---------- かわいい暮らしの小物(ラグ・吊り植物・ライト・カフェ) ----------

function Rug({ x, y, rx, ry, color }: { x: number; y: number; rx: number; ry: number; color: string }) {
  return (
    <g pointerEvents="none">
      <ellipse cx={x} cy={y} rx={rx} ry={ry} fill={color} opacity={0.4} />
      <ellipse cx={x} cy={y} rx={rx - 8} ry={ry - 6} fill="none" stroke="#ffffff" strokeWidth={1.5} strokeDasharray="3 5" opacity={0.5} />
    </g>
  );
}

function HangingPlant({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <line x1={x} y1={y - 10} x2={x} y2={y} stroke="#8a744c" strokeWidth={1.2} />
      <path d={`M ${x - 8} ${y} Q ${x} ${y + 5} ${x + 8} ${y} L ${x + 6} ${y + 9} Q ${x} ${y + 13} ${x - 6} ${y + 9} Z`} fill="#d99a63" stroke="#b57f4c" strokeWidth={1} />
      <circle cx={x - 5} cy={y - 1} r={4} fill="#8ecf9d" />
      <circle cx={x + 5} cy={y - 1} r={4} fill="#a8dcb2" />
      <path d={`M ${x - 8} ${y + 3} q -3 8 -1 14`} stroke="#6fbf82" strokeWidth={2} fill="none" strokeLinecap="round" />
      <path d={`M ${x + 8} ${y + 3} q 3 7 1 12`} stroke="#8ecf9d" strokeWidth={2} fill="none" strokeLinecap="round" />
    </g>
  );
}

function StringLights({ x1, x2, y, on }: { x1: number; x2: number; y: number; on: boolean }) {
  const n = Math.max(3, Math.floor((x2 - x1) / 26));
  const colors = ['#f8c3d0', '#fbe3a2', '#bfe3c5', '#bcd9ea'];
  return (
    <g pointerEvents="none">
      <path d={`M ${x1} ${y} Q ${(x1 + x2) / 2} ${y + 14} ${x2} ${y}`} stroke="#8a744c" strokeWidth={1.2} fill="none" opacity={0.7} />
      {Array.from({ length: n }, (_, i) => {
        const t = (i + 0.5) / n;
        const bx = x1 + (x2 - x1) * t;
        const by = y + 14 * 4 * t * (1 - t) * 0.5 + 3;
        return (
          <circle key={i} cx={bx} cy={by} r={2.6} fill={colors[i % colors.length]} opacity={on ? 0.95 : 0.55}>
            {on && <animate attributeName="opacity" values="0.95;0.45;0.95" dur={`${2 + (i % 3) * 0.7}s`} repeatCount="indefinite" />}
          </circle>
        );
      })}
    </g>
  );
}

function PendantLamp({ x, y, on }: { x: number; y: number; on: boolean }) {
  return (
    <g pointerEvents="none">
      <line x1={x} y1={y - 18} x2={x} y2={y} stroke="#8a744c" strokeWidth={1.4} />
      <path d={`M ${x - 9} ${y + 8} Q ${x} ${y - 6} ${x + 9} ${y + 8} Z`} fill="#e8b04b" stroke="#c9963c" strokeWidth={1.2} />
      <circle cx={x} cy={y + 9} r={2.4} fill={on ? '#ffe9ad' : '#fdf6e3'} />
      {on && <ellipse cx={x} cy={y + 26} rx={26} ry={12} fill="#fbbf24" opacity={0.12} />}
    </g>
  );
}

function MenuBoard({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={24} height={30} rx={3} fill="#5f4a36" stroke="#4a3826" strokeWidth={1.5} />
      <rect x={x + 3} y={y + 3} width={18} height={24} rx={2} fill="#3f4a3d" />
      <text x={x + 12} y={y + 12} textAnchor="middle" fontSize={6.5} fill="#fdf6e3">☕ MENU</text>
      <line x1={x + 6} y1={y + 17} x2={x + 18} y2={y + 17} stroke="#e8ddc8" strokeWidth={1} strokeLinecap="round" opacity={0.7} />
      <line x1={x + 6} y1={y + 22} x2={x + 15} y2={y + 22} stroke="#e8ddc8" strokeWidth={1} strokeLinecap="round" opacity={0.5} />
    </g>
  );
}

function Steam({ x, y }: { x: number; y: number }) {
  return (
    <g pointerEvents="none" opacity={0.6}>
      {[0, 1].map((i) => (
        <path key={i} d={`M ${x + i * 5 - 2} ${y} q 2 -4 0 -8 q -2 -4 0 -7`} stroke="#ffffff" strokeWidth={1.4} fill="none" strokeLinecap="round">
          <animate attributeName="opacity" values="0;0.7;0" dur="2.6s" begin={`${i * 0.9}s`} repeatCount="indefinite" />
          <animateTransform attributeName="transform" type="translate" values="0 0; 0 -4" dur="2.6s" begin={`${i * 0.9}s`} repeatCount="indefinite" />
        </path>
      ))}
    </g>
  );
}

// ---------- マスコット(猫・犬) ----------

// 会社猫「もち」: tickに合わせてお気に入りの場所を移動。ソファでは昼寝する
const CAT_SPOTS = [
  { x: 68, y: 168, sleep: true }, // 社長室のソファ
  { x: 1226, y: 116, sleep: true }, // 休憩室のソファ
  { x: 604, y: 792, sleep: false }, // エントランスの木の下
  { x: 906, y: 726, sleep: false }, // プロジェクトテーブルの横
];

function CatMascot({ tickCount, reduced }: { tickCount: number; reduced: boolean }) {
  const spot = CAT_SPOTS[Math.floor(tickCount / 9) % CAT_SPOTS.length];
  return (
    <motion.g
      initial={false}
      animate={{ x: spot.x, y: spot.y }}
      transition={reduced ? { duration: 0 } : { type: 'tween', duration: 2.2, ease: [0.45, 0.05, 0.35, 1] }}
      pointerEvents="none"
      aria-label="会社猫のもち"
      role="img"
    >
      <ellipse cx={0} cy={10} rx={11} ry={3} fill="#8a6a4a" opacity={0.15} />
      {spot.sleep ? (
        <g>
          {/* 丸くなって昼寝 */}
          <ellipse cx={0} cy={3} rx={11} ry={7.5} fill="#f0e3d0" stroke="#d9c5a8" strokeWidth={1.2} />
          <circle cx={-7} cy={-1} r={5.5} fill="#f0e3d0" stroke="#d9c5a8" strokeWidth={1.2} />
          <path d="M -10.5 -5 L -9 -1.5 L -6.5 -4 Z" fill="#e8b0a0" stroke="#d9c5a8" strokeWidth={0.8} />
          <path d="M -4.5 -5.5 L -4.5 -2 L -1.5 -4 Z" fill="#e8b0a0" stroke="#d9c5a8" strokeWidth={0.8} />
          <path d="M -9.5 -1 Q -8.5 0 -7.5 -1" stroke="#9a8468" strokeWidth={0.8} fill="none" />
          <path d="M -6 -1 Q -5 0 -4 -1" stroke="#9a8468" strokeWidth={0.8} fill="none" />
          <path d="M 8 4 Q 14 2 12 -3" stroke="#d9c5a8" strokeWidth={2.5} fill="none" strokeLinecap="round" />
          <text x={9} y={-8} fontSize={7} opacity={0.75}>
            💤
          </text>
        </g>
      ) : (
        <g>
          {/* おすわり */}
          <ellipse cx={0} cy={2} rx={7} ry={8} fill="#f0e3d0" stroke="#d9c5a8" strokeWidth={1.2} />
          <circle cx={0} cy={-9} r={6.5} fill="#f0e3d0" stroke="#d9c5a8" strokeWidth={1.2} />
          <path d="M -6 -13.5 L -4.5 -9 L -1.5 -12.5 Z" fill="#e8b0a0" stroke="#d9c5a8" strokeWidth={0.8} />
          <path d="M 6 -13.5 L 4.5 -9 L 1.5 -12.5 Z" fill="#e8b0a0" stroke="#d9c5a8" strokeWidth={0.8} />
          <circle cx={-2.4} cy={-9.5} r={1} fill="#5c4c38" />
          <circle cx={2.4} cy={-9.5} r={1} fill="#5c4c38" />
          <path d="M -1.2 -6.8 Q 0 -5.8 1.2 -6.8" stroke="#9a8468" strokeWidth={0.8} fill="none" strokeLinecap="round" />
          <ellipse cx={-3} cy={8} rx={2.4} ry={1.6} fill="#e6d5bc" />
          <ellipse cx={3} cy={8} rx={2.4} ry={1.6} fill="#e6d5bc" />
          {/* しっぽ(ゆらゆら) */}
          <g>
            <path d="M 6.5 4 Q 13 3 12.5 -4" stroke="#d9c5a8" strokeWidth={2.5} fill="none" strokeLinecap="round">
              <animateTransform attributeName="transform" type="rotate" values="0 6.5 4; 9 6.5 4; 0 6.5 4" dur="2.4s" repeatCount="indefinite" />
            </path>
          </g>
        </g>
      )}
    </motion.g>
  );
}

// 会社犬「くう」: エントランスでお出迎え。たまにうれしくてしっぽを振る
function DogMascot({ tickCount }: { tickCount: number }) {
  const happy = tickCount % 11 < 4;
  return (
    <g transform="translate(742 806)" pointerEvents="none" aria-label="会社犬のくう" role="img">
      <ellipse cx={0} cy={11} rx={11} ry={3} fill="#8a6a4a" opacity={0.15} />
      <ellipse cx={0} cy={3} rx={7.5} ry={8} fill="#e8c79a" stroke="#cfa878" strokeWidth={1.2} />
      <circle cx={0} cy={-9} r={7} fill="#e8c79a" stroke="#cfa878" strokeWidth={1.2} />
      {/* たれ耳 */}
      <path d="M -6.5 -13 Q -10.5 -9 -8 -3.5 Q -5.5 -6 -5 -11 Z" fill="#c99b66" stroke="#b08549" strokeWidth={0.8} />
      <path d="M 6.5 -13 Q 10.5 -9 8 -3.5 Q 5.5 -6 5 -11 Z" fill="#c99b66" stroke="#b08549" strokeWidth={0.8} />
      <circle cx={-2.6} cy={-10} r={1.1} fill="#5c4c38" />
      <circle cx={2.6} cy={-10} r={1.1} fill="#5c4c38" />
      <ellipse cx={0} cy={-6.5} rx={1.7} ry={1.3} fill="#5c4c38" />
      {/* 舌 */}
      <path d="M -1 -5 Q 0 -2.5 1.6 -4.2" stroke="#e8938a" strokeWidth={1.8} fill="none" strokeLinecap="round" />
      <ellipse cx={-3.4} cy={9} rx={2.5} ry={1.7} fill="#dfba88" />
      <ellipse cx={3.4} cy={9} rx={2.5} ry={1.7} fill="#dfba88" />
      {/* しっぽ(うれしいと速く振る) */}
      <path d="M 7 3 Q 12.5 1 12 -5" stroke="#cfa878" strokeWidth={2.6} fill="none" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="-8 7 3; 14 7 3; -8 7 3" dur={happy ? '0.5s' : '1.6s'} repeatCount="indefinite" />
      </path>
      {happy && (
        <text x={-14} y={-14} fontSize={8} opacity={0.85}>
          ♪
        </text>
      )}
    </g>
  );
}

// ---------- 季節装飾(月に応じて自動で変わる) ----------

type Season = 'spring' | 'summer' | 'autumn' | 'winter';

function currentSeason(): Season {
  const m = new Date().getMonth() + 1;
  if (m >= 3 && m <= 5) return 'spring';
  if (m >= 6 && m <= 8) return 'summer';
  if (m >= 9 && m <= 11) return 'autumn';
  return 'winter';
}

const SEASON_TREE: Record<Season, { main: string; left: string; right: string; accent: string }> = {
  spring: { main: '#f6c9d6', left: '#efb3c6', right: '#fbdce6', accent: '#ffffff' },
  summer: { main: '#8ecf9d', left: '#6fbf82', right: '#a8dcb2', accent: '#f8c3d0' },
  autumn: { main: '#e8a35c', left: '#d98a45', right: '#f2bd7a', accent: '#c96b3f' },
  winter: { main: '#a9c4b5', left: '#93b3a2', right: '#c2d6ca', accent: '#ffffff' },
};

function SeasonalLayer({ season }: { season: Season }) {
  if (season === 'spring') {
    // 桜の花びらがはらはらと舞う
    return (
      <g pointerEvents="none">
        {[0, 1, 2, 3, 4].map((i) => (
          <ellipse key={i} cx={600 + i * 28} cy={730} rx={2.6} ry={1.7} fill="#f8c3d0" opacity={0}>
            <animate attributeName="cy" values={`${726 + i * 4};${846 + i * 3}`} dur={`${4.5 + i * 0.8}s`} begin={`${i * 1.3}s`} repeatCount="indefinite" />
            <animate attributeName="cx" values={`${600 + i * 28};${588 + i * 28};${608 + i * 28}`} dur={`${4.5 + i * 0.8}s`} begin={`${i * 1.3}s`} repeatCount="indefinite" />
            <animate attributeName="opacity" values="0;0.85;0.85;0" dur={`${4.5 + i * 0.8}s`} begin={`${i * 1.3}s`} repeatCount="indefinite" />
          </ellipse>
        ))}
      </g>
    );
  }
  if (season === 'summer') {
    // 風鈴とひまわり
    return (
      <g pointerEvents="none">
        <g>
          <line x1={1078} y1={12} x2={1078} y2={26} stroke="#8a744c" strokeWidth={1} />
          <path d="M 1071 26 Q 1078 18 1085 26 L 1083 34 Q 1078 37 1073 34 Z" fill="#bcd9ea" stroke="#9cc0d6" strokeWidth={1} opacity={0.9} />
          <line x1={1078} y1={34} x2={1078} y2={44} stroke="#9cc0d6" strokeWidth={1} />
          <rect x={1075} y={44} width={6} height={9} rx={1} fill="#f8c3d0" opacity={0.9}>
            <animateTransform attributeName="transform" type="rotate" values="-6 1078 44; 6 1078 44; -6 1078 44" dur="3.2s" repeatCount="indefinite" />
          </rect>
        </g>
        {[532, 772].map((fx) => (
          <g key={fx}>
            <line x1={fx} y1={842} x2={fx} y2={820} stroke="#6fbf82" strokeWidth={2} strokeLinecap="round" />
            {Array.from({ length: 8 }, (_, i) => {
              const a = (i / 8) * Math.PI * 2;
              return <ellipse key={i} cx={fx + Math.cos(a) * 6} cy={814 + Math.sin(a) * 6} rx={3} ry={2} fill="#f5d76e" transform={`rotate(${(a * 180) / Math.PI} ${fx + Math.cos(a) * 6} ${814 + Math.sin(a) * 6})`} />;
            })}
            <circle cx={fx} cy={814} r={3.6} fill="#a87043" />
          </g>
        ))}
      </g>
    );
  }
  if (season === 'autumn') {
    // 紅葉がひらひらと落ちる
    return (
      <g pointerEvents="none">
        {[0, 1, 2, 3].map((i) => (
          <g key={i}>
            <rect x={598 + i * 34} y={730} width={5} height={4} rx={1.5} fill={i % 2 === 0 ? '#d98a45' : '#c96b3f'} opacity={0}>
              <animate attributeName="y" values={`${728 + i * 5};${844 + i * 2}`} dur={`${5 + i * 0.9}s`} begin={`${i * 1.6}s`} repeatCount="indefinite" />
              <animate attributeName="opacity" values="0;0.9;0.9;0" dur={`${5 + i * 0.9}s`} begin={`${i * 1.6}s`} repeatCount="indefinite" />
              <animateTransform attributeName="transform" type="rotate" values={`0 ${600 + i * 34} 780; 260 ${600 + i * 34} 780`} dur={`${5 + i * 0.9}s`} begin={`${i * 1.6}s`} repeatCount="indefinite" />
            </rect>
          </g>
        ))}
        <text x={588} y={838} fontSize={10} opacity={0.8}>🍂</text>
      </g>
    );
  }
  // 冬: 小さな雪だるまと雪
  return (
    <g pointerEvents="none">
      <g transform="translate(586 806)">
        <ellipse cx={0} cy={12} rx={10} ry={3} fill="#8a6a4a" opacity={0.12} />
        <circle cx={0} cy={5} r={7.5} fill="#ffffff" stroke="#dbe3ea" strokeWidth={1.2} />
        <circle cx={0} cy={-6} r={5.5} fill="#ffffff" stroke="#dbe3ea" strokeWidth={1.2} />
        <circle cx={-1.8} cy={-7} r={0.9} fill="#5c4c38" />
        <circle cx={1.8} cy={-7} r={0.9} fill="#5c4c38" />
        <path d="M 0 -5.5 L 3.4 -4.6 L 0 -3.8 Z" fill="#e8963f" />
        <rect x={-6} y={-13.5} width={12} height={3} rx={1.5} fill="#e08a8a" />
        <rect x={-3.5} y={-18} width={7} height={5.5} rx={1} fill="#e08a8a" />
      </g>
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <circle key={i} cx={520 + i * 52} cy={760} r={1.8} fill="#ffffff" opacity={0}>
          <animate attributeName="cy" values={`${752 + (i % 3) * 8};${848}`} dur={`${6 + (i % 3) * 1.2}s`} begin={`${i * 1.1}s`} repeatCount="indefinite" />
          <animate attributeName="opacity" values="0;0.9;0.9;0" dur={`${6 + (i % 3) * 1.2}s`} begin={`${i * 1.1}s`} repeatCount="indefinite" />
        </circle>
      ))}
    </g>
  );
}

// 窓の外の空(時間帯で変わる自然光)
const SKY: Record<DayPeriod, string> = {
  morning: '#ffe0b8',
  day: '#bcd9ea',
  evening: '#f8b98a',
  night: '#3a3d66',
};

function WelcomeMat() {
  return (
    <g>
      <rect x={585} y={812} width={130} height={30} rx={14} fill="#f4b8c6" stroke="#e094ab" strokeWidth={2} />
      <rect x={589} y={816} width={122} height={22} rx={11} fill="none" stroke="#ffffff" strokeWidth={1.2} strokeDasharray="3 4" opacity={0.7} />
      <text x={650} y={831} textAnchor="middle" fontSize={12} fill="#9c5b6e" fontWeight={700}>
        ようこそ!🐰
      </text>
    </g>
  );
}

// エントランスの憩い(掲示板・ベンチ・花壇・木の下の丸ラグ)
function Entrance() {
  return (
    <g>
      {/* 木の下のピンクの丸ラグ */}
      <ellipse cx={650} cy={790} rx={78} ry={22} fill="#f6cdd8" opacity={0.55} />
      <ellipse cx={650} cy={790} rx={62} ry={16} fill="none" stroke="#ffffff" strokeWidth={1.4} strokeDasharray="3 5" opacity={0.6} />
      {/* お知らせ掲示板 */}
      <g>
        <rect x={396} y={796} width={60} height={38} rx={5} fill={P.woodLight} stroke={P.wallStroke} strokeWidth={1.8} />
        <rect x={400} y={806} width={52} height={24} rx={3} fill="#f6eed9" />
        <text x={426} y={805} textAnchor="middle" fontSize={7.5} fill={P.tag} fontWeight={700}>お知らせ</text>
        <rect x={404} y={810} width={14} height={16} rx={1.5} fill={P.paper} stroke="#e0d4b8" strokeWidth={0.8} transform="rotate(-3 411 818)" />
        <rect x={422} y={811} width={13} height={14} rx={1.5} fill="#fbeeb8" stroke="#e0c25c" strokeWidth={0.8} transform="rotate(2 428 818)" />
        <rect x={438} y={810} width={12} height={15} rx={1.5} fill="#e3ecf8" stroke="#c9d8e8" strokeWidth={0.8} />
      </g>
      {/* ピンクのベンチ */}
      <g>
        <rect x={872} y={806} width={66} height={11} rx={5.5} fill="#f5b8c4" stroke="#e094ab" strokeWidth={1.6} />
        <rect x={876} y={817} width={5} height={9} rx={2} fill="#c98a9a" />
        <rect x={929} y={817} width={5} height={9} rx={2} fill="#c98a9a" />
        <rect x={872} y={798} width={66} height={5} rx={2.5} fill="#f5b8c4" stroke="#e094ab" strokeWidth={1.2} />
      </g>
      {/* 花壇(左右) */}
      {[120, 1140].map((fx) => (
        <g key={fx}>
          <rect x={fx - 34} y={836} width={68} height={16} rx={7} fill="#e8d2ab" stroke={P.wallStroke} strokeWidth={1.5} />
          <rect x={fx - 30} y={839} width={60} height={10} rx={4} fill="#b98d5c" opacity={0.5} />
          {[-22, -8, 6, 20].map((dx, i) => (
            <g key={dx}>
              <circle cx={fx + dx} cy={836} r={3.4} fill={['#f2a9bd', '#f5d76e', '#f8c3d0', '#c9b3e0'][i]} />
              <circle cx={fx + dx} cy={836} r={1.2} fill="#ffffff" opacity={0.8} />
            </g>
          ))}
          <circle cx={fx - 15} cy={831} r={2.6} fill="#8ecf9d" />
          <circle cx={fx + 13} cy={831} r={2.6} fill="#a8dcb2" />
        </g>
      ))}
    </g>
  );
}

function ApprovalArea({ pending }: { pending: number }) {
  return (
    <g>
      <rect x={1060} y={590} width={160} height={16} rx={7} fill={P.woodLight} stroke="#b08c5f" strokeWidth={1.5} />
      <rect x={1060} y={688} width={160} height={16} rx={7} fill={P.woodLight} stroke="#b08c5f" strokeWidth={1.5} />
      <rect x={1224} y={585} width={28} height={20} rx={4} fill={P.paper} stroke="#c4a071" strokeWidth={1.5} />
      <rect x={1228} y={581} width={20} height={4} rx={2} fill="#f5d76e" />
      {/* 承認スタンプ */}
      <circle cx={1046} cy={594} r={5} fill="#e08a8a" stroke="#c96b6b" strokeWidth={1.2} />
      <rect x={1043} y={586} width={6} height={5} rx={1.5} fill="#c96b6b" />
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
  night: { fill: '#2a2a4a', opacity: 0.24, label: '夜間は一部AIのみ稼働中', emoji: '🌙' },
};

// ============================================================
// 2.5頭身チビキャラクター
// ============================================================

function ChibiBody({
  agent,
  walking,
  thinking,
  seated,
  cushion,
  coffee,
}: {
  agent: Agent;
  walking: boolean;
  thinking: boolean;
  seated?: boolean; // 座り(足を隠す)。椅子はデスク側にあるのでここでは描かない
  cushion?: boolean; // 会議・プロジェクト用の丸クッションを描く
  coffee?: boolean;
}) {
  const paused = agent.status === 'paused';
  return (
    <g opacity={paused ? 0.55 : 1}>
      {seated && !walking ? (
        cushion ? (
          <ellipse cx={0} cy={14} rx={10} ry={4.5} fill={agent.color} opacity={0.45} stroke="#ffffff" strokeWidth={1.6} />
        ) : null
      ) : (
        <g>
          {/* 足(歩行時は交互に動く) */}
          <ellipse className={walking ? 'walk-foot-l' : undefined} cx={-5} cy={16} rx={4} ry={3} fill="#8a6a4a" />
          <ellipse className={walking ? 'walk-foot-r' : undefined} cx={5} cy={16} rx={4} ry={3} fill="#8a6a4a" />
        </g>
      )}
      {/* 腕 */}
      <g className={walking ? 'walk-arm-l' : undefined} style={{ transformOrigin: '-9px 2px' }}>
        <circle cx={-11} cy={7} r={3.2} fill={P.skin} stroke="#eec9a8" strokeWidth={0.8} />
      </g>
      <g className={walking ? 'walk-arm-r' : undefined} style={{ transformOrigin: '9px 2px' }}>
        <circle cx={11} cy={coffee && !walking ? 3 : 7} r={3.2} fill={P.skin} stroke="#eec9a8" strokeWidth={0.8} />
      </g>
      {/* コーヒー(休憩中はカップを持ってひと息) */}
      {coffee && !walking && (
        <g>
          <g>
            <rect x={12} y={-1} width={7} height={7} rx={2} fill="#fdf6e3" stroke="#d9c5a8" strokeWidth={1} />
            <path d="M 19 1 q 3 1.5 0 3.5" stroke="#d9c5a8" strokeWidth={1.2} fill="none" />
            <animateTransform attributeName="transform" type="translate" values="0 0; 0 -2.5; 0 0" dur="3.4s" repeatCount="indefinite" />
          </g>
          <path d="M 14 -3 q 1.5 -3 0 -6" stroke="#ffffff" strokeWidth={1.1} fill="none" strokeLinecap="round" opacity={0.7}>
            <animate attributeName="opacity" values="0;0.7;0" dur="2.4s" repeatCount="indefinite" />
          </path>
        </g>
      )}
      {/* 体(服=エージェントカラーのパステル) */}
      <rect x={-9} y={0} width={18} height={15} rx={7} fill={agent.color} opacity={0.82} stroke="#00000022" strokeWidth={0.8} />
      <rect x={-9} y={0} width={18} height={6} rx={3} fill="#ffffff" opacity={0.22} />
      {/* 役割バッジ(胸元) */}
      <text y={11} textAnchor="middle" fontSize={8} aria-hidden>
        {agent.avatar}
      </text>
      {/* 頭 */}
      <circle cy={-9} r={10.5} fill={P.skin} stroke="#eec9a8" strokeWidth={1} />
      {/* 髪(エージェントカラー) */}
      <path d="M -10.5 -9 A 10.5 10.5 0 0 1 10.5 -9 L 10.5 -12 A 10.5 8 0 0 0 -10.5 -12 Z" fill={agent.color} opacity={0.9} />
      <path d="M -10.5 -9 Q -10.5 -17 0 -19 Q 10.5 -17 10.5 -9 Q 5 -14.5 0 -14.5 Q -5 -14.5 -10.5 -9 Z" fill={agent.color} />
      {/* 目と口 */}
      <circle cx={-3.6} cy={-8} r={1.3} fill="#4a3b2f" />
      <circle cx={3.6} cy={-8} r={1.3} fill="#4a3b2f" />
      <path d="M -2 -4.5 Q 0 -3 2 -4.5" stroke="#4a3b2f" strokeWidth={0.9} fill="none" strokeLinecap="round" />
      {/* ほっぺ */}
      <circle cx={-6.5} cy={-5} r={1.6} fill="#f8b8c0" opacity={0.55} />
      <circle cx={6.5} cy={-5} r={1.6} fill="#f8b8c0" opacity={0.55} />
      {/* 考え中モーション */}
      {thinking && (
        <g opacity={0.85}>
          <circle cx={13} cy={-20} r={1.6} fill="#b8b3a6" />
          <circle cx={17} cy={-25} r={2.2} fill="#c9c4b6" />
          <text x={24} y={-27} textAnchor="middle" fontSize={9}>💭</text>
        </g>
      )}
    </g>
  );
}

function AgentSprite({
  agent,
  pos,
  onSelect,
  reduced,
  tickCount,
  index,
}: {
  agent: Agent;
  pos: { x: number; y: number };
  onSelect: (a: Agent) => void;
  reduced: boolean;
  tickCount: number;
  index: number;
}) {
  const st = AGENT_STATUS[agent.status];
  const busy = ['working', 'checking', 'delegating'].includes(agent.status);
  const unread = useOffice((s) => s.unread[agent.id] ?? 0);
  const [walking, setWalking] = useState(false);
  const [facing, setFacing] = useState(1);
  const prev = useRef(pos);

  useEffect(() => {
    if (prev.current.x !== pos.x || prev.current.y !== pos.y) {
      // 進行方向を向く
      if (pos.x !== prev.current.x) setFacing(pos.x > prev.current.x ? 1 : -1);
      prev.current = pos;
      setWalking(true);
      const t = setTimeout(() => setWalking(false), 1700);
      return () => clearTimeout(t);
    }
  }, [pos.x, pos.y]);

  // 会議・プロジェクト中はテーブル中心を向く
  const zone = agentZone(agent);
  const zoneCenter = ZONE_CENTERS[zone];
  const seatedFacing = zoneCenter ? (zoneCenter.x >= pos.x ? 1 : -1) : null;

  // 待機モーション(決定的な擬似ランダム: tick+indexで揺らす)
  const idleSeed = (tickCount + index * 5) % 29;
  const thinking = !walking && agent.status === 'idle' && idleSeed < 4;
  const turned = !walking && agent.status === 'idle' && idleSeed >= 14 && idleSeed < 19; // 振り向き
  const effectiveFacing = seatedFacing ?? (turned ? -facing : facing);
  const talking = agent.statusNote.startsWith('💬');

  const showBubble =
    talking ||
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
      {/* 揺れ(idle-sway)は作業完了(done)のキャラだけ。他は歩行ボブのみで静止 */}
      <g className={walking && !reduced ? 'sim-bob' : !reduced && agent.status === 'done' ? 'idle-sway' : undefined}>
        {/* 影 */}
        <ellipse cx={0} cy={17} rx={13} ry={4} fill="#8a6a4a" opacity={0.18} />
        {/* キャラ本体(向きで反転) */}
        <g transform={`scale(${effectiveFacing}, 1)`}>
          <ChibiBody
            agent={agent}
            walking={walking && !reduced}
            thinking={thinking}
            seated={zone === 'desk' || zone === 'meeting' || zone === 'project'}
            cushion={zone === 'meeting' || zone === 'project'}
            coffee={zone === 'break'}
          />
        </g>
        {/* 会話インジケーター */}
        {talking && (
          <g opacity={0.9}>
            <circle cx={-3} cy={-26} r={1.4} fill="#8a6a4a">
              <animate attributeName="opacity" values="0.3;1;0.3" dur="1.2s" begin="0s" repeatCount="indefinite" />
            </circle>
            <circle cx={1} cy={-26} r={1.4} fill="#8a6a4a">
              <animate attributeName="opacity" values="0.3;1;0.3" dur="1.2s" begin="0.2s" repeatCount="indefinite" />
            </circle>
            <circle cx={5} cy={-26} r={1.4} fill="#8a6a4a">
              <animate attributeName="opacity" values="0.3;1;0.3" dur="1.2s" begin="0.4s" repeatCount="indefinite" />
            </circle>
          </g>
        )}
        {/* 状態ドット */}
        <circle cx={12} cy={12} r={4.5} fill={dotColor} stroke="#fff" strokeWidth={1.6}>
          {busy && !reduced && <animate attributeName="opacity" values="1;0.4;1" dur="1.6s" repeatCount="indefinite" />}
        </circle>
        {/* 完了フラッシュ */}
        {agent.status === 'done' && (
          <motion.circle r={17} fill="none" stroke="#10b981" strokeWidth={2.5} initial={{ opacity: 0.9, scale: 1 }} animate={{ opacity: 0, scale: 1.9 }} transition={{ duration: 1.4, repeat: 2 }} />
        )}
        {/* 未読バッジ */}
        {unread > 0 && (
          <g>
            <circle cx={-13} cy={-16} r={6.5} fill="#4f46e5" stroke="#fff" strokeWidth={1.4} />
            <text x={-13} y={-13} textAnchor="middle" fontSize={8.5} fill="#fff" fontWeight={700}>
              {unread}
            </text>
          </g>
        )}
        {/* 名札 */}
        <rect x={-36} y={21} width={72} height={15} rx={7.5} fill="#ffffff" stroke="#e3d7bd" strokeWidth={1.2} />
        <text y={31.5} textAnchor="middle" fontSize={9} fill={P.tag} fontWeight={700}>
          {agent.name.slice(0, 9)}
        </text>
        {/* 進捗ミニバー */}
        {busy && agent.progress > 0 && (
          <g>
            <rect x={-16} y={39} width={32} height={3.5} rx={1.75} fill="#e8ddc8" />
            <rect x={-16} y={39} width={(32 * agent.progress) / 100} height={3.5} rx={1.75} fill={agent.color} />
          </g>
        )}
        {/* 吹き出し */}
        <AnimatePresence>
          {showBubble && bubbleText && (
            <motion.g initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.3 }}>
              <rect x={-bubbleText.length * 4.6 - 8} y={-52} width={bubbleText.length * 9.2 + 16} height={20} rx={10} fill="#ffffff" stroke="#e3d7bd" strokeWidth={1.2} opacity={0.97} />
              <path d="M -4 -33 L 0 -26 L 4 -33 Z" fill="#ffffff" stroke="#e3d7bd" strokeWidth={0.8} />
              <text y={-38.5} textAnchor="middle" fontSize={9.5} fill="#5c4c38">
                {bubbleText}
              </text>
            </motion.g>
          )}
        </AnimatePresence>
      </g>
    </motion.g>
  );
}

// ---------- 足跡レイヤー ----------

interface Trail {
  id: string;
  from: { x: number; y: number };
  to: { x: number; y: number };
}

function TrailLayer({ trails }: { trails: Trail[] }) {
  return (
    <g pointerEvents="none">
      <AnimatePresence>
        {trails.map((trail) => (
          <motion.g key={trail.id} initial={{ opacity: 0.5 }} animate={{ opacity: 0 }} exit={{ opacity: 0 }} transition={{ duration: 2 }}>
            {[0.25, 0.45, 0.65, 0.85].map((t, i) => (
              <ellipse
                key={i}
                cx={trail.from.x + (trail.to.x - trail.from.x) * t + (i % 2 === 0 ? -3 : 3)}
                cy={trail.from.y + (trail.to.y - trail.from.y) * t + 14}
                rx={2.5}
                ry={1.4}
                fill="#8a6a4a"
                opacity={0.4}
              />
            ))}
          </motion.g>
        ))}
      </AnimatePresence>
    </g>
  );
}

// ---------- 受け渡し演出 ----------

function eventIcon(label: string, kind: string): string {
  if (label.includes('メール') || label.includes('送信')) return '✉️';
  if (label.includes('レビュー') || label.includes('チェック') || label.includes('確認')) return '🔍';
  if (kind === 'complete' || label.includes('納品')) return '✅';
  if (kind === 'error') return '⚠️';
  if (label.includes('報告')) return '📈';
  return '📄';
}

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
          const color = e.kind === 'complete' ? '#6cbf95' : e.kind === 'error' ? '#e39a9a' : e.kind === 'plan' ? '#b9a0d9' : '#9aa8dc';
          const midX = (from.x + to.x) / 2;
          const midY = (from.y + to.y) / 2 - 24;
          return (
            <motion.g key={e.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              <line x1={from.x} y1={from.y} x2={to.x} y2={to.y} stroke={color} strokeWidth={1.2} strokeDasharray="4 7" opacity={0.35} strokeLinecap="round" />
              {!reduced && (
                <motion.g initial={{ x: from.x, y: from.y, scale: 0.6, rotate: -8 }} animate={{ x: to.x, y: to.y, scale: 1, rotate: 8 }} transition={{ duration: 1.5, ease: 'easeInOut' }}>
                  <circle r={10} fill="#ffffff" stroke={color} strokeWidth={1.8} />
                  <text y={4} textAnchor="middle" fontSize={10}>
                    {eventIcon(e.label, e.kind)}
                  </text>
                </motion.g>
              )}
              <g>
                <rect x={midX - e.label.length * 4.2 - 6} y={midY - 8} width={e.label.length * 8.4 + 12} height={15} rx={7.5} fill="#ffffff" opacity={0.92} stroke={color} strokeWidth={0.8} />
                <text x={midX} y={midY + 3} textAnchor="middle" fontSize={8} fill="#8a7660" fontWeight={600}>
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

// ---------- お祝い演出(キラキラ・紙吹雪・拍手・花火) ----------

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
    const t = setTimeout(() => setBursts((b) => b.slice(1)), 2800);
    return () => clearTimeout(t);
  }, [bursts]);

  if (reduced) return null;
  const confetti = ['#f2a9bd', '#f5d76e', '#8ecf9d', '#8ab0e0', '#c39ad6'];
  return (
    <g pointerEvents="none">
      <AnimatePresence>
        {bursts.map((burst) => (
          <motion.g key={burst.id} initial={{ opacity: 1 }} exit={{ opacity: 0 }}>
            {/* 紙吹雪(大)/キラキラ(小) */}
            {Array.from({ length: burst.big ? 14 : 6 }, (_, i) => {
              const a = (i / (burst.big ? 14 : 6)) * Math.PI * 2;
              const dist = burst.big ? 52 : 30;
              return burst.big && i % 2 === 0 ? (
                <motion.rect
                  key={i}
                  initial={{ x: burst.x, y: burst.y, opacity: 1, rotate: 0 }}
                  animate={{ x: burst.x + Math.cos(a) * dist, y: burst.y + Math.sin(a) * dist + 16, opacity: 0, rotate: 200 }}
                  transition={{ duration: 1.9, ease: 'easeOut' }}
                  width={5}
                  height={3}
                  rx={1}
                  fill={confetti[i % confetti.length]}
                />
              ) : (
                <motion.circle
                  key={i}
                  initial={{ cx: burst.x, cy: burst.y, r: burst.big ? 4 : 3, opacity: 1 }}
                  animate={{ cx: burst.x + Math.cos(a) * dist, cy: burst.y + Math.sin(a) * dist - 12, r: 0.6, opacity: 0 }}
                  transition={{ duration: 1.5, ease: 'easeOut' }}
                  fill={confetti[i % confetti.length]}
                />
              );
            })}
            {/* 花火(大のみ・上空に控えめ) */}
            {burst.big &&
              [0, 1].map((f) => (
                <g key={f}>
                  {Array.from({ length: 8 }, (_, i) => {
                    const a = (i / 8) * Math.PI * 2;
                    const fx = burst.x + (f === 0 ? -70 : 70);
                    const fy = burst.y - 60;
                    return (
                      <motion.line
                        key={i}
                        initial={{ x1: fx, y1: fy, x2: fx, y2: fy, opacity: 0.9 }}
                        animate={{ x2: fx + Math.cos(a) * 20, y2: fy + Math.sin(a) * 20, opacity: 0 }}
                        transition={{ duration: 1.1, delay: 0.3 + f * 0.35, ease: 'easeOut' }}
                        stroke={confetti[(i + f) % confetti.length]}
                        strokeWidth={1.6}
                        strokeLinecap="round"
                      />
                    );
                  })}
                </g>
              ))}
            <motion.text
              initial={{ x: burst.x, y: burst.y - 20, opacity: 0, scale: 0.6 }}
              animate={{ y: burst.y - (burst.big ? 56 : 42), opacity: [0, 1, 1, 0], scale: 1 }}
              transition={{ duration: 2.2 }}
              textAnchor="middle"
              fontSize={burst.big ? 22 : 15}
            >
              {burst.big ? '🎉' : '✨'}
            </motion.text>
            {burst.big && (
              <motion.g initial={{ opacity: 0, y: 6 }} animate={{ opacity: [0, 1, 1, 0] }} transition={{ duration: 2.6 }}>
                <rect x={burst.x - 62} y={burst.y - 96} width={124} height={20} rx={10} fill="#10b981" opacity={0.95} />
                <text x={burst.x} y={burst.y - 82} textAnchor="middle" fontSize={10.5} fill="#fff" fontWeight={700}>
                  成果物が完成しました!
                </text>
                {/* 拍手 */}
                <motion.text initial={{ opacity: 0 }} animate={{ opacity: [0, 1, 0] }} transition={{ duration: 2, delay: 0.4 }} x={burst.x - 82} y={burst.y - 82} fontSize={13}>
                  👏
                </motion.text>
                <motion.text initial={{ opacity: 0 }} animate={{ opacity: [0, 1, 0] }} transition={{ duration: 2, delay: 0.7 }} x={burst.x + 70} y={burst.y - 82} fontSize={13}>
                  👏
                </motion.text>
              </motion.g>
            )}
          </motion.g>
        ))}
      </AnimatePresence>
    </g>
  );
}

// ============================================================
// 本体
// ============================================================

export function OfficeSimulator({ onSelect }: { onSelect: (a: Agent) => void }) {
  const agents = useOffice((s) => s.agents);
  const ceoName = useOffice((s) => s.settings.ceoName);
  const pending = useOffice((s) => s.approvals.filter((a) => a.status === 'pending').length);
  const timeEffects = useOffice((s) => s.settings.timeEffects ?? true);
  const clockMode = useOffice((s) => s.settings.clockMode ?? 'real');
  const tickCount = useOffice((s) => s.tickCount);
  const reduced = useReducedMotion() ?? false;
  const [realPeriod, setRealPeriod] = useState<DayPeriod>(() => currentPeriod());
  const [trails, setTrails] = useState<Trail[]>([]);
  const prevPositions = useRef<Map<string, { x: number; y: number }>>(new Map());

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
  const season = useMemo(() => currentSeason(), []);

  // 足跡: 座標が変わった社員の移動経路を記録(2秒でフェード)
  useEffect(() => {
    const newTrails: Trail[] = [];
    positions.forEach((pos, id) => {
      const prev = prevPositions.current.get(id);
      if (prev && (prev.x !== pos.x || prev.y !== pos.y)) {
        newTrails.push({ id: `${id}-${Date.now()}`, from: prev, to: pos });
      }
    });
    prevPositions.current = positions;
    if (newTrails.length > 0 && !reduced) {
      setTrails((t) => [...t.slice(-6), ...newTrails]);
      const timer = setTimeout(() => setTrails((t) => t.slice(newTrails.length)), 2200);
      return () => clearTimeout(timer);
    }
  }, [positions, reduced]);

  const meetingInUse = agents.some((a) => agentZone(a) === 'meeting');
  const hasError = agents.some((a) => a.status === 'error');
  const workingIds = new Set(agents.filter((a) => ['working', 'checking', 'delegating'].includes(a.status) && agentZone(a) === 'desk').map((a) => a.id));

  return (
    <div className="relative overflow-hidden rounded-2xl border border-[#e6d8ba] bg-[#f3ede1] shadow-card">
      {/* 時間帯ラベル: 右上は休憩室タグと重なるため、部屋のない右下の余白に表示 */}
      <p className="absolute bottom-2 right-3 z-10 rounded-full bg-white/90 px-2.5 py-0.5 text-[10px] font-medium text-[#6f5b43] shadow-sm">
        {light.emoji} {light.label}
      </p>
      <div className="overflow-x-auto">
        <svg
          viewBox={`0 0 ${VB.w} ${VB.h}`}
          className="block h-auto w-full min-w-[820px]"
          role="img"
          aria-label="バーチャルオフィスの見取り図。AI社員をクリックすると詳細を開けます"
        >
          <rect x={0} y={0} width={VB.w} height={VB.h} rx={22} fill={P.bgOuter} />
          <rect x={8} y={8} width={VB.w - 16} height={VB.h - 16} rx={18} fill={P.bgInner} />

          {ROOMS.map((room) => (
            <g key={room.id}>
              {/* 柔らかい影 + 薄茶の細い壁 + パステルの床 */}
              <rect x={room.x - 3} y={room.y + 2} width={room.w + 8} height={room.h + 8} rx={18} fill="#dcc9a4" opacity={0.35} />
              <rect x={room.x - 4} y={room.y - 4} width={room.w + 8} height={room.h + 8} rx={17} fill={P.wall} stroke={P.wallStroke} strokeWidth={1.5} />
              <rect x={room.x} y={room.y} width={room.w} height={room.h} rx={13} fill={room.night ? P.night : (room.floor ?? P.floorWood)} />
              <rect x={room.x + 3} y={room.y + 3} width={room.w - 6} height={room.h - 6} rx={11} fill="none" stroke="#ffffff" strokeWidth={2} opacity={room.night ? 0.12 : 0.45} />
              {Array.from({ length: room.windows ?? (room.night ? 1 : 0) }, (_, i) => {
                const wx = room.x + room.w - 42 - i * 48;
                return (
                  <g key={i}>
                    <rect x={wx} y={room.y - 7} width={34} height={17} rx={5} fill={room.night ? '#3a3d66' : SKY[period]} stroke={P.windowFrame} strokeWidth={2.5} />
                    <line x1={wx + 17} y1={room.y - 7} x2={wx + 17} y2={room.y + 10} stroke={P.windowFrame} strokeWidth={2} />
                    {(period === 'night' || room.night) && <circle cx={wx + 8} cy={room.y - 1} r={1.2} fill="#fef3c7" opacity={0.9} />}
                    {period === 'day' && !room.night && <circle cx={wx + 25} cy={room.y - 2} r={3} fill="#ffffff" opacity={0.55} />}
                  </g>
                );
              })}
              <rect x={room.x + room.w / 2 - 16} y={room.y + room.h - 4} width={32} height={8} rx={4} fill={P.bgInner} stroke={P.wallLight} strokeWidth={1} />
              {/* 部屋名: 白い丸ピル */}
              <rect x={room.x + 7} y={room.y + 7} width={room.label.length * 10.5 + 18} height={20} rx={10} fill="#ffffff" opacity={0.95} stroke="#eadfc6" strokeWidth={1.2} />
              <circle cx={room.x + 17} cy={room.y + 17} r={3} fill={room.night ? '#8d86c9' : room.floor === '#f3e8d2' || !room.floor ? '#e8c46b' : room.floor} stroke="#ffffff" strokeWidth={0} opacity={0.9} />
              <text x={room.x + 24} y={room.y + 21} fontSize={10.5} fill={P.tag} fontWeight={700}>
                {room.label}
              </text>
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

          {/* 家具(部屋ごとの生活感) */}
          <PresidentRoom />
          <SecretaryRoom />
          <SalesRoom />
          <ProductionRoom />
          <MarketingRoom />
          <AdminRoom />
          {Object.entries(DESKS).map(([id, d], i) => (
            <Desk key={id} x={d.x} y={d.y} glow={workingIds.has(id)} chairColor={CHAIR_COLORS[i % CHAIR_COLORS.length]} />
          ))}
          <MeetingTable lampOn={period === 'evening' || period === 'night'} />
          <ProjectTable />
          <BreakRoom lightsOn={period === 'evening' || period === 'night'} />
          <ServerRoom hasError={hasError} />
          <ApprovalArea pending={pending} />
          <Plant x={40} y={226} />
          <Plant x={1240} y={534} />
          <Plant x={648} y={226} />
          <Entrance />
          <Tree x={650} y={770} colors={SEASON_TREE[season]} />
          <FlowerPot x={550} y={824} />
          <FlowerPot x={750} y={824} />
          <WelcomeMat />
          {/* 季節装飾(月に応じて自動で変わる) */}
          <SeasonalLayer season={season} />
          {/* マスコット: 会社猫「もち」と会社犬「くう」 */}
          <CatMascot tickCount={tickCount} reduced={reduced} />
          <DogMascot tickCount={tickCount} />

          {/* 社長(あなた) */}
          <g role="img" aria-label={`${ceoName}(あなた)の席`}>
            <ellipse cx={120} cy={147} rx={13} ry={4} fill="#8a6a4a" opacity={0.18} />
            <g transform="translate(120 130)">
              <ellipse cx={-5} cy={16} rx={4} ry={3} fill="#8a6a4a" />
              <ellipse cx={5} cy={16} rx={4} ry={3} fill="#8a6a4a" />
              <circle cx={-11} cy={7} r={3.2} fill={P.skin} stroke="#eec9a8" strokeWidth={0.8} />
              <circle cx={11} cy={7} r={3.2} fill={P.skin} stroke="#eec9a8" strokeWidth={0.8} />
              <rect x={-9} y={0} width={18} height={15} rx={7} fill="#6f5b43" opacity={0.9} />
              <rect x={-3} y={2} width={6} height={9} rx={2} fill="#e08a8a" />
              <circle cy={-9} r={10.5} fill={P.skin} stroke="#eec9a8" strokeWidth={1} />
              <path d="M -10.5 -9 Q -10.5 -17 0 -19 Q 10.5 -17 10.5 -9 Q 5 -14.5 0 -14.5 Q -5 -14.5 -10.5 -9 Z" fill="#5c4c38" />
              <circle cx={-3.6} cy={-8} r={1.3} fill="#4a3b2f" />
              <circle cx={3.6} cy={-8} r={1.3} fill="#4a3b2f" />
              <path d="M -2 -4.5 Q 0 -3 2 -4.5" stroke="#4a3b2f" strokeWidth={0.9} fill="none" strokeLinecap="round" />
            </g>
            <rect x={84} y={152} width={72} height={15} rx={7.5} fill="#ffffff" stroke="#e3d7bd" strokeWidth={1.2} />
            <text x={120} y={162.5} textAnchor="middle" fontSize={9} fill={P.tag} fontWeight={700}>
              {ceoName}(社長)
            </text>
          </g>

          {light.opacity > 0 && <rect x={0} y={0} width={VB.w} height={VB.h} rx={22} fill={light.fill} opacity={light.opacity} pointerEvents="none" />}
          {period === 'night' &&
            Object.entries(DESKS).map(([id, d]) =>
              workingIds.has(id) ? <circle key={id} cx={d.x} cy={d.y - 42} r={30} fill="#fbbf24" opacity={0.16} pointerEvents="none" /> : null,
            )}

          {/* 足跡 */}
          <TrailLayer trails={trails} />

          {/* 受け渡し演出 */}
          <HandoffLayer positions={positions} />

          {/* AI社員(チビキャラ) */}
          {agents.map((agent, index) => {
            const pos = positions.get(agent.id)!;
            return (
              <AgentSprite key={agent.id} agent={agent} pos={pos} onSelect={onSelect} reduced={reduced} tickCount={tickCount} index={index} />
            );
          })}

          {/* お祝い演出 */}
          <CelebrationLayer positions={positions} />
        </svg>
      </div>
    </div>
  );
}
