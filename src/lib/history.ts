/**
 * 学習履歴の集計ロジック (クライアント側表示用)。
 * セッション行はRLSにより本人の分しか取得できない。
 */

export interface SessionRow {
  id: string;
  topic: string;
  planned_minutes: number;
  started_at: string;
  ended_at: string | null;
  attended_seconds: number;
  status: 'active' | 'completed' | 'left_early' | 'abandoned';
  rating: string | null;
  is_trial: boolean;
}

/** タイムゾーンにおけるローカル日付キー YYYY-MM-DD */
export function localDateKey(iso: string | Date, timeZone: string): string {
  const d = typeof iso === 'string' ? new Date(iso) : iso;
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return fmt.format(d); // en-CA は YYYY-MM-DD 形式
}

export function localHour(iso: string, timeZone: string): number {
  const fmt = new Intl.DateTimeFormat('en-US', { timeZone, hour: 'numeric', hour12: false });
  return parseInt(fmt.format(new Date(iso)), 10) % 24;
}

export function localWeekday(iso: string | Date, timeZone: string): number {
  const d = typeof iso === 'string' ? new Date(iso) : iso;
  const fmt = new Intl.DateTimeFormat('en-US', { timeZone, weekday: 'short' });
  const map: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return map[fmt.format(d)] ?? 0;
}

export function minutesOf(s: SessionRow): number {
  return Math.floor(s.attended_seconds / 60);
}

/** 日別の合計集中分 (完了+途中退出の実参加時間) */
export function dailyMinutes(sessions: SessionRow[], timeZone: string): Map<string, number> {
  const map = new Map<string, number>();
  for (const s of sessions) {
    if (s.status !== 'completed' && s.status !== 'left_early') continue;
    if (s.is_trial) continue;
    const key = localDateKey(s.started_at, timeZone);
    map.set(key, (map.get(key) ?? 0) + minutesOf(s));
  }
  return map;
}

/** 指定日の合計分 */
export function minutesOnDate(sessions: SessionRow[], dateKey: string, timeZone: string): number {
  return dailyMinutes(sessions, timeZone).get(dateKey) ?? 0;
}

/** 週の開始(月曜)からの日付キー配列 */
export function weekDateKeys(now: Date, timeZone: string): string[] {
  const todayKey = localDateKey(now, timeZone);
  const weekday = localWeekday(now, timeZone); // 0=日
  const mondayOffset = weekday === 0 ? 6 : weekday - 1;
  const keys: string[] = [];
  const base = new Date(now);
  for (let i = 0; i < 7; i++) {
    const d = new Date(base.getTime() - (mondayOffset - i) * 86400000);
    keys.push(localDateKey(d, timeZone));
  }
  // now が週の中にあることを保証
  if (!keys.includes(todayKey)) keys[mondayOffset] = todayKey;
  return keys;
}

export function sumWeekMinutes(sessions: SessionRow[], now: Date, timeZone: string): number {
  const daily = dailyMinutes(sessions, timeZone);
  return weekDateKeys(now, timeZone).reduce((acc, k) => acc + (daily.get(k) ?? 0), 0);
}

export function completedCount(sessions: SessionRow[], keys?: Set<string>, timeZone?: string): number {
  return sessions.filter(
    (s) =>
      s.status === 'completed' &&
      !s.is_trial &&
      (!keys || !timeZone || keys.has(localDateKey(s.started_at, timeZone)))
  ).length;
}

export function leftEarlyCount(sessions: SessionRow[]): number {
  return sessions.filter((s) => s.status === 'left_early' && !s.is_trial).length;
}

/** 曜日別合計分 (0=日〜6=土) */
export function weekdayTrend(sessions: SessionRow[], timeZone: string): number[] {
  const arr = new Array(7).fill(0);
  for (const s of sessions) {
    if ((s.status !== 'completed' && s.status !== 'left_early') || s.is_trial) continue;
    arr[localWeekday(s.started_at, timeZone)] += minutesOf(s);
  }
  return arr;
}

/** 時間帯別合計分 (4時間区切り × 6) */
export function hourBandTrend(sessions: SessionRow[], timeZone: string): number[] {
  const arr = new Array(6).fill(0);
  for (const s of sessions) {
    if ((s.status !== 'completed' && s.status !== 'left_early') || s.is_trial) continue;
    arr[Math.floor(localHour(s.started_at, timeZone) / 4)] += minutesOf(s);
  }
  return arr;
}

export function formatMinutes(total: number): string {
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h === 0) return `${m}分`;
  if (m === 0) return `${h}時間`;
  return `${h}時間${m}分`;
}
