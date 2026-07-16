'use client';

// 数値が変化したとき、静かにカウントアップ/ダウンして表示するコンポーネント
// (派手なフラッシュではなく、Linear/Stripe風の落ち着いた遷移)
import { useEffect, useRef, useState } from 'react';

export function useAnimatedNumber(value: number, duration = 700): number {
  const [display, setDisplay] = useState(value);
  const prevRef = useRef(value);
  const rafRef = useRef<number>();

  useEffect(() => {
    const from = prevRef.current;
    prevRef.current = value;
    if (from === value) return;
    if (typeof window === 'undefined') {
      setDisplay(value);
      return;
    }
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) {
      setDisplay(value);
      return;
    }
    const start = performance.now();
    const step = (t: number) => {
      const p = Math.min(1, (t - start) / duration);
      const eased = 1 - Math.pow(1 - p, 3); // easeOutCubic
      setDisplay(from + (value - from) * eased);
      if (p < 1) rafRef.current = requestAnimationFrame(step);
    };
    rafRef.current = requestAnimationFrame(step);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [value, duration]);

  return display;
}

export function AnimatedNumber({
  value,
  format,
  className,
}: {
  value: number;
  format?: (v: number) => string;
  className?: string;
}) {
  const display = useAnimatedNumber(value);
  const text = format ? format(display) : Math.round(display).toLocaleString('ja-JP');
  return (
    <span className={className} style={{ fontVariantNumeric: 'tabular-nums' }}>
      {text}
    </span>
  );
}

/** 前日比などの増減バッジ */
export function DeltaBadge({ current, previous, invert }: { current: number; previous: number; invert?: boolean }) {
  if (previous === 0 && current === 0) return null;
  const diff = current - previous;
  const pct = previous === 0 ? 100 : (diff / Math.abs(previous)) * 100;
  if (Math.abs(pct) < 0.05) {
    return <span className="text-[10px] font-medium text-slate-400">±0%</span>;
  }
  const up = diff > 0;
  // invert=true はコストなど「増加が悪い」指標
  const good = invert ? !up : up;
  return (
    <span
      className={`inline-flex items-center gap-0.5 rounded-full px-1.5 py-0.5 text-[10px] font-semibold tabular-nums ${
        good ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-500'
      }`}
    >
      {up ? '▲' : '▼'} {Math.abs(pct) >= 100 ? Math.round(Math.abs(pct)) : Math.abs(pct).toFixed(1)}%
      <span className="font-normal text-slate-400">前日比</span>
    </span>
  );
}
