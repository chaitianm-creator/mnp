'use client';

// AI社員間の連携イベント(依頼・納品・エラー報告)を
// 社員チップ間を結ぶ「信号」として数秒間だけ描画するレイヤー
import { useOffice } from '@/lib/store';
import type { OfficeEvent } from '@/lib/types';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useLayoutEffect, useState, type RefObject } from 'react';

const EVENT_STYLE: Record<OfficeEvent['kind'], { color: string; icon: string }> = {
  delegate: { color: '#6366f1', icon: '📄' },
  complete: { color: '#10b981', icon: '✅' },
  error: { color: '#ef4444', icon: '⚠️' },
  plan: { color: '#a855f7', icon: '📨' },
};

const EVENT_TTL_MS = 4500;

export function OfficeEventLayer({ containerRef }: { containerRef: RefObject<HTMLDivElement> }) {
  const events = useOffice((s) => s.officeEvents);
  const fresh = events.filter((e) => Date.now() - new Date(e.createdAt).getTime() < EVENT_TTL_MS);

  return (
    <div className="pointer-events-none absolute inset-0 z-20 overflow-hidden" aria-hidden>
      <AnimatePresence>
        {fresh.map((event) => (
          <EventArrow key={event.id} event={event} containerRef={containerRef} />
        ))}
      </AnimatePresence>
    </div>
  );
}

function EventArrow({
  event,
  containerRef,
}: {
  event: OfficeEvent;
  containerRef: RefObject<HTMLDivElement>;
}) {
  const reduced = useReducedMotion();
  const [coords, setCoords] = useState<{ x1: number; y1: number; x2: number; y2: number } | null>(null);

  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const from = container.querySelector(`[data-agent-chip="${event.fromAgentId}"]`);
    const to = container.querySelector(`[data-agent-chip="${event.toAgentId}"]`);
    if (!from || !to) return;
    const cb = container.getBoundingClientRect();
    const fb = from.getBoundingClientRect();
    const tb = to.getBoundingClientRect();
    setCoords({
      x1: fb.left + fb.width / 2 - cb.left,
      y1: fb.top + fb.height / 2 - cb.top,
      x2: tb.left + tb.width / 2 - cb.left,
      y2: tb.top + tb.height / 2 - cb.top,
    });
  }, [event.id]);

  if (!coords) return null;
  const style = EVENT_STYLE[event.kind];
  const midX = (coords.x1 + coords.x2) / 2;
  const midY = (coords.y1 + coords.y2) / 2;

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0">
      {/* 点線 */}
      <svg className="absolute inset-0 h-full w-full">
        <motion.line
          x1={coords.x1}
          y1={coords.y1}
          x2={coords.x2}
          y2={coords.y2}
          stroke={style.color}
          strokeWidth={1.5}
          strokeDasharray="4 5"
          initial={{ opacity: 0 }}
          animate={{ opacity: [0, 0.7, 0.7, 0] }}
          transition={{ duration: EVENT_TTL_MS / 1000, times: [0, 0.15, 0.7, 1] }}
        />
      </svg>
      {/* 移動する書類アイコン */}
      {!reduced && (
        <motion.div
          className="absolute flex h-6 w-6 items-center justify-center rounded-full text-xs shadow-md"
          style={{ backgroundColor: 'white', border: `1.5px solid ${style.color}`, marginLeft: -12, marginTop: -12 }}
          initial={{ left: coords.x1, top: coords.y1, scale: 0.6, opacity: 0 }}
          animate={{ left: coords.x2, top: coords.y2, scale: 1, opacity: [0, 1, 1, 0] }}
          transition={{ duration: 1.6, ease: 'easeInOut', times: [0, 0.15, 0.85, 1] }}
        >
          {style.icon}
        </motion.div>
      )}
      {/* ラベル */}
      <motion.div
        className="absolute -translate-x-1/2 whitespace-nowrap rounded-full bg-white px-2 py-0.5 text-[10px] font-medium shadow-sm"
        style={{ left: midX, top: midY - 18, color: style.color, border: `1px solid ${style.color}44` }}
        initial={{ opacity: 0, y: 4 }}
        animate={{ opacity: [0, 1, 1, 0], y: 0 }}
        transition={{ duration: EVENT_TTL_MS / 1000, times: [0, 0.2, 0.75, 1] }}
      >
        {event.label}
      </motion.div>
    </motion.div>
  );
}
