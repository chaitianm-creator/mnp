/**
 * XP・レベル計算。SQL側 (level_for_xp / finish_session) と同一の式。
 * 付与自体はサーバー(RPC)のみが行い、ここは表示用の計算に使う。
 */

/** 完了セッションで付与されるXP (分×2 + 完了ボーナス10) */
export function xpForSession(attendedMinutes: number): number {
  if (attendedMinutes < 0) return 0;
  return Math.floor(attendedMinutes) * 2 + 10;
}

/** XP→レベル: level = floor(sqrt(xp / 50)) + 1 */
export function levelForXp(xp: number): number {
  return Math.floor(Math.sqrt(Math.max(xp, 0) / 50)) + 1;
}

/** そのレベルに到達するのに必要な累計XP */
export function xpForLevel(level: number): number {
  if (level <= 1) return 0;
  return (level - 1) * (level - 1) * 50;
}

/** 次のレベルまでの進捗 (0〜1) */
export function levelProgress(xp: number): {
  level: number;
  current: number;
  needed: number;
  ratio: number;
} {
  const level = levelForXp(xp);
  const base = xpForLevel(level);
  const next = xpForLevel(level + 1);
  const current = xp - base;
  const needed = next - base;
  return { level, current, needed, ratio: needed === 0 ? 1 : Math.min(1, current / needed) };
}
