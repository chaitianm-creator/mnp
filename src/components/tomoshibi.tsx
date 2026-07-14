import { cn } from '@/lib/utils';

/**
 * 案内役「ともしび」— MokuTomoオリジナルの小さなランタンの精。
 * 勉強を始める人の手元をそっと照らす存在、という設定。
 * (参考サービスのキャラクター・人物・文章は一切使用していない)
 */
export function TomoshibiIcon({ className, glow = false }: { className?: string; glow?: boolean }) {
  return (
    <svg
      viewBox="0 0 64 64"
      className={cn('h-12 w-12', glow && 'animate-lantern-glow', className)}
      role="img"
      aria-label="案内役ともしび"
    >
      {/* ランタン本体 */}
      <path d="M24 14 h16 l4 8 v22 a6 6 0 0 1-6 6 H26 a6 6 0 0 1-6-6 V22 z" fill="#316655" />
      <rect x="27" y="10" width="10" height="6" rx="2" fill="#295246" />
      <path d="M24 22 h16 v20 H24 z" fill="#fff4d6" />
      {/* 炎 (顔) */}
      <path d="M32 26 c4 4 5 7 5 9.5 a5 5 0 1 1-10 0 C27 33 28 30 32 26 z" fill="#ffc54a" />
      <circle cx="30.2" cy="35" r="0.9" fill="#7a2c0d" />
      <circle cx="33.8" cy="35" r="0.9" fill="#7a2c0d" />
      <path d="M30.5 37.5 q1.5 1.2 3 0" stroke="#7a2c0d" strokeWidth="0.9" fill="none" strokeLinecap="round" />
      {/* 取っ手 */}
      <path d="M26 10 a6 6 0 0 1 12 0" stroke="#295246" strokeWidth="2.5" fill="none" />
    </svg>
  );
}

export function TomoshibiMessage({
  message,
  className,
  glow,
}: {
  message: string;
  className?: string;
  glow?: boolean;
}) {
  return (
    <div className={cn('flex items-center gap-3', className)}>
      <TomoshibiIcon glow={glow} className="shrink-0" />
      <p className="rounded-2xl rounded-bl-sm bg-lantern-50 px-4 py-2.5 text-sm text-brand-900 shadow-sm dark:bg-brand-800 dark:text-brand-50">
        {message}
      </p>
    </div>
  );
}

/** ロゴ (仮案): ランタン + サービス名 */
export function Logo({ className }: { className?: string }) {
  return (
    <span className={cn('inline-flex items-center gap-1.5 font-bold', className)}>
      <TomoshibiIcon className="h-7 w-7" />
      <span className="text-lg tracking-tight">
        Moku<span className="text-lantern-500">Tomo</span>
      </span>
    </span>
  );
}
