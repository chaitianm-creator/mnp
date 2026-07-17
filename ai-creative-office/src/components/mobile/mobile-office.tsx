'use client';

// スマホ版オフィス: 箱庭シミュレーターをドラッグ移動・ピンチズームで眺める
// 1本指=移動 / 2本指=ズーム / ダブルタップ=拡大⇔全体表示 / 右下ボタンでも操作可
import { OfficeSimulator } from '@/components/office/office-simulator';
import type { Agent } from '@/lib/types';
import { Maximize2, Minus, Plus } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

// シミュレーターの描画幅(この幅を基準にfitスケールを計算する)
const BASE_W = 960;
const BASE_H = 680; // 960 * (880/1280) ≒ 660 + 余白

const MIN_SCALE_FACTOR = 0.9; // fitに対する最小倍率
const MAX_SCALE = 3;

export function MobileOffice({ onSelect }: { onSelect: (a: Agent) => void }) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const [view, setView] = useState({ x: 0, y: 0, scale: 0.4 });
  const [fitScale, setFitScale] = useState(0.4);
  const [hintVisible, setHintVisible] = useState(true);

  // ジェスチャー管理(再レンダー不要のためref)
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const gesture = useRef({ startDist: 0, startScale: 1, dragged: false, lastTap: 0 });
  const viewRef = useRef(view);
  viewRef.current = view;
  const fitRef = useRef(fitScale);
  fitRef.current = fitScale;

  const clamp = (v: { x: number; y: number; scale: number }) => {
    const el = viewportRef.current;
    if (!el) return v;
    const scale = Math.min(MAX_SCALE, Math.max(fitRef.current * MIN_SCALE_FACTOR, v.scale));
    const w = BASE_W * scale;
    const h = BASE_H * scale;
    const vw = el.clientWidth;
    const vh = el.clientHeight;
    // マップが画面より小さい軸は中央寄せ、大きい軸は端まででクランプ
    const x = w <= vw ? (vw - w) / 2 : Math.min(0, Math.max(vw - w, v.x));
    const y = h <= vh ? (vh - h) / 2 : Math.min(0, Math.max(vh - h, v.y));
    return { x, y, scale };
  };

  // 初期表示: 画面幅に合わせて全体が見えるスケールに
  useEffect(() => {
    const el = viewportRef.current;
    if (!el) return;
    const apply = () => {
      const fit = Math.min(el.clientWidth / BASE_W, el.clientHeight / BASE_H);
      setFitScale(fit);
      setView(() => {
        const w = BASE_W * fit;
        const h = BASE_H * fit;
        return { x: (el.clientWidth - w) / 2, y: (el.clientHeight - h) / 2, scale: fit };
      });
    };
    apply();
    const ro = new ResizeObserver(apply);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const t = setTimeout(() => setHintVisible(false), 4000);
    return () => clearTimeout(t);
  }, []);

  const zoomAt = (px: number, py: number, nextScale: number) => {
    const v = viewRef.current;
    const scale = Math.min(MAX_SCALE, Math.max(fitRef.current * MIN_SCALE_FACTOR, nextScale));
    // 画面上の点(px,py)の下にあるマップ座標を固定したままスケールする
    const x = px - ((px - v.x) * scale) / v.scale;
    const y = py - ((py - v.y) * scale) / v.scale;
    setView(clamp({ x, y, scale }));
  };

  const onPointerDown = (e: React.PointerEvent) => {
    // ここではキャプチャしない(即キャプチャするとボタン・社員タップのclickが発火しなくなる)
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    gesture.current.dragged = false;
    if (pointers.current.size === 2) {
      const [a, b] = Array.from(pointers.current.values());
      gesture.current.startDist = Math.hypot(a.x - b.x, a.y - b.y);
      gesture.current.startScale = viewRef.current.scale;
    }
  };

  const onPointerMove = (e: React.PointerEvent) => {
    const prev = pointers.current.get(e.pointerId);
    if (!prev) return;
    const cur = { x: e.clientX, y: e.clientY };
    pointers.current.set(e.pointerId, cur);

    if (pointers.current.size === 1) {
      // 1本指: ドラッグ移動
      const dx = cur.x - prev.x;
      const dy = cur.y - prev.y;
      if (!gesture.current.dragged && Math.abs(dx) + Math.abs(dy) > 3) {
        // ドラッグ開始が確定してからキャプチャ(タップはそのまま子要素へ届く)
        gesture.current.dragged = true;
        viewportRef.current?.setPointerCapture(e.pointerId);
      }
      const v = viewRef.current;
      setView(clamp({ x: v.x + dx, y: v.y + dy, scale: v.scale }));
    } else if (pointers.current.size === 2) {
      // 2本指: ピンチズーム(中点を基準に)
      if (!gesture.current.dragged) {
        gesture.current.dragged = true;
        viewportRef.current?.setPointerCapture(e.pointerId);
      }
      const [a, b] = Array.from(pointers.current.values());
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      if (gesture.current.startDist > 0) {
        const rect = viewportRef.current!.getBoundingClientRect();
        const mid = { x: (a.x + b.x) / 2 - rect.left, y: (a.y + b.y) / 2 - rect.top };
        zoomAt(mid.x, mid.y, gesture.current.startScale * (dist / gesture.current.startDist));
      }
    }
  };

  const onPointerUp = (e: React.PointerEvent) => {
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) gesture.current.startDist = 0;
    // ダブルタップ: 拡大⇔全体表示
    if (!gesture.current.dragged && pointers.current.size === 0) {
      const now = Date.now();
      if (now - gesture.current.lastTap < 320) {
        const rect = viewportRef.current!.getBoundingClientRect();
        const v = viewRef.current;
        const target = v.scale > fitRef.current * 1.3 ? fitRef.current : fitRef.current * 2.2;
        zoomAt(e.clientX - rect.left, e.clientY - rect.top, target);
        gesture.current.lastTap = 0;
      } else {
        gesture.current.lastTap = now;
      }
    }
  };

  const center = () => {
    const el = viewportRef.current;
    return el ? { x: el.clientWidth / 2, y: el.clientHeight / 2 } : { x: 0, y: 0 };
  };

  return (
    <div className="flex h-full flex-col">
      <div
        ref={viewportRef}
        className="relative min-h-0 flex-1 overflow-hidden bg-[#efe6d4]"
        style={{ touchAction: 'none' }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onClickCapture={(e) => {
          // ドラッグ直後のクリックは誤タップとして無効化
          if (gesture.current.dragged) {
            e.stopPropagation();
            e.preventDefault();
          }
        }}
        role="application"
        aria-label="バーチャルオフィス。ドラッグで移動、ピンチで拡大できます"
      >
        <div
          style={{
            width: BASE_W,
            transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})`,
            transformOrigin: '0 0',
            willChange: 'transform',
          }}
        >
          <OfficeSimulator onSelect={onSelect} />
        </div>

        {/* 操作ヒント(数秒で消える) */}
        {hintVisible && (
          <p className="pointer-events-none absolute left-1/2 top-3 -translate-x-1/2 rounded-full bg-slate-900/70 px-3 py-1.5 text-[11px] font-medium text-white">
            ドラッグで移動 / ピンチで拡大 / 社員をタップで詳細
          </p>
        )}

        {/* ズーム操作(右下=親指の届く位置) */}
        <div className="absolute bottom-3 right-3 flex flex-col gap-1.5">
          <ZoomBtn
            label="拡大"
            onClick={() => {
              const c = center();
              zoomAt(c.x, c.y, viewRef.current.scale * 1.4);
            }}
          >
            <Plus className="h-4 w-4" />
          </ZoomBtn>
          <ZoomBtn
            label="縮小"
            onClick={() => {
              const c = center();
              zoomAt(c.x, c.y, viewRef.current.scale / 1.4);
            }}
          >
            <Minus className="h-4 w-4" />
          </ZoomBtn>
          <ZoomBtn
            label="全体表示"
            onClick={() => {
              const el = viewportRef.current;
              if (!el) return;
              const w = BASE_W * fitScale;
              const h = BASE_H * fitScale;
              setView({ x: (el.clientWidth - w) / 2, y: (el.clientHeight - h) / 2, scale: fitScale });
            }}
          >
            <Maximize2 className="h-4 w-4" />
          </ZoomBtn>
        </div>
      </div>
    </div>
  );
}

function ZoomBtn({ children, onClick, label }: { children: React.ReactNode; onClick: () => void; label: string }) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      className="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-600 shadow-card outline-none active:scale-95 focus-visible:ring-2 focus-visible:ring-brand-500"
    >
      {children}
    </button>
  );
}
