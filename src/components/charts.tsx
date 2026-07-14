import { cn } from '@/lib/utils';

/** 依存ライブラリなしの軽量SVG棒グラフ (サーバーコンポーネントで描画可能) */
export function BarChart({
  data,
  height = 160,
  unit = '分',
  className,
}: {
  data: Array<{ label: string; value: number }>;
  height?: number;
  unit?: string;
  className?: string;
}) {
  const max = Math.max(1, ...data.map((d) => d.value));
  const barW = 100 / data.length;
  return (
    <div className={cn('w-full', className)}>
      <svg
        viewBox={`0 0 100 ${height}`}
        preserveAspectRatio="none"
        className="h-40 w-full"
        role="img"
        aria-label={`棒グラフ: ${data.map((d) => `${d.label} ${d.value}${unit}`).join('、')}`}
      >
        {data.map((d, i) => {
          const h = (d.value / max) * (height - 20);
          return (
            <rect
              key={i}
              x={i * barW + barW * 0.15}
              y={height - h}
              width={barW * 0.7}
              height={Math.max(h, d.value > 0 ? 2 : 0)}
              rx={1.5}
              className="fill-brand-400 dark:fill-brand-500"
            />
          );
        })}
      </svg>
      <div className="flex text-[10px] text-brand-500" aria-hidden>
        {data.map((d, i) => (
          <span key={i} className="flex-1 truncate text-center">
            {d.label}
          </span>
        ))}
      </div>
    </div>
  );
}

/** 1か月のカレンダーヒートマップ */
export function CalendarHeatmap({
  year,
  month, // 1-12
  values, // dateKey(YYYY-MM-DD) -> minutes
  className,
}: {
  year: number;
  month: number;
  values: Map<string, number>;
  className?: string;
}) {
  const first = new Date(Date.UTC(year, month - 1, 1));
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const startWeekday = first.getUTCDay();
  const cells: Array<{ day: number; minutes: number } | null> = [];
  for (let i = 0; i < startWeekday; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) {
    const key = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    cells.push({ day: d, minutes: values.get(key) ?? 0 });
  }
  const level = (m: number) =>
    m === 0
      ? 'bg-brand-100 dark:bg-brand-800/60'
      : m < 30
        ? 'bg-brand-300'
        : m < 60
          ? 'bg-brand-400'
          : m < 120
            ? 'bg-brand-500'
            : 'bg-brand-600';

  return (
    <div className={className}>
      <div className="grid grid-cols-7 gap-1 text-center text-[10px] text-brand-500">
        {['日', '月', '火', '水', '木', '金', '土'].map((w) => (
          <span key={w}>{w}</span>
        ))}
      </div>
      <div className="mt-1 grid grid-cols-7 gap-1">
        {cells.map((c, i) =>
          c === null ? (
            <div key={i} />
          ) : (
            <div
              key={i}
              title={`${month}/${c.day}: ${c.minutes}分`}
              className={cn(
                'flex aspect-square items-center justify-center rounded-md text-[10px]',
                level(c.minutes),
                c.minutes >= 30 ? 'text-white' : 'text-brand-700 dark:text-brand-200'
              )}
            >
              {c.day}
            </div>
          )
        )}
      </div>
    </div>
  );
}
