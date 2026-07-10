/**
 * ドメインロジック(Phase 7 §5: domain/ は単体テスト必須)。
 * すべて純関数 — Firestore に依存しない。時刻・乱数は引数で受ける(テスト容易性)。
 */

// ── レベル計算 ────────────────────────────────────────────
// xpTable[i] = レベル i+1 に到達するのに必要な累計XP。
// 序盤は高速(初日15〜20分で初レベルアップ = エンゲージメント設計 §4.1)。
export const DEFAULT_XP_TABLE = [0, 60, 150, 280, 450, 660, 910, 1200, 1530, 1900];

export function levelForXp(totalXp: number, xpTable: number[] = DEFAULT_XP_TABLE): number {
  let level = 1;
  for (let i = 1; i < xpTable.length; i++) {
    if (totalXp >= xpTable[i]) level = i + 1;
  }
  // テーブル超過後は 400XP ごとに 1 レベル(緩やかな終盤)
  if (totalXp >= xpTable[xpTable.length - 1]) {
    level = xpTable.length + Math.floor((totalXp - xpTable[xpTable.length - 1]) / 400);
  }
  return level;
}

// ── ストリーク判定 ─────────────────────────────────────────
// JST の日付文字列(YYYY-MM-DD)で比較。クライアント時計に依存しない(Phase 6 §3.1)。
export function jstDateString(d: Date): string {
  const jst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return jst.toISOString().slice(0, 10);
}

export interface StreakInput {
  current: number;
  lastDeliveryDate: string | null; // YYYY-MM-DD (JST)
  today: string; // YYYY-MM-DD (JST)
}

/** 納品時のストリーク更新。同日2件目は据え置き、連続日は+1、間が空いたら1から。 */
export function streakOnDelivery({ current, lastDeliveryDate, today }: StreakInput): number {
  if (lastDeliveryDate === today) return Math.max(current, 1); // 同日
  if (lastDeliveryDate === null) return 1; // 初納品
  const last = new Date(`${lastDeliveryDate}T00:00:00Z`).getTime();
  const now = new Date(`${today}T00:00:00Z`).getTime();
  const diffDays = Math.round((now - last) / 86_400_000);
  if (diffDays === 1) return current + 1; // 連続
  return 1; // 途切れ(お守り消費は dailyBatch 側で処理済みの前提)
}

/** 日次バッチのストリーク判定: 前日納品なし → お守り消費 or リセット。 */
export interface DailyStreakResult {
  streak: number;
  charms: number;
  charmUsed: boolean;
  broke: boolean; // 復帰ウェルカム(returnWelcomePending)対象
}

export function dailyStreakCheck(
  streak: number,
  charms: number,
  deliveredYesterday: boolean,
): DailyStreakResult {
  if (deliveredYesterday || streak === 0) {
    return { streak, charms, charmUsed: false, broke: false };
  }
  if (charms > 0) {
    // お守りが守ってくれた(手紙で報告 = Phase 6 §3.1)
    return { streak, charms: charms - 1, charmUsed: true, broke: false };
  }
  return { streak: 0, charms: 0, charmUsed: false, broke: true };
}

// ── ドロップ抽選(可変報酬・Phase 5 §5 Remote 変数) ─────────
export interface DropResult {
  key: boolean;
  chest: boolean;
}

export function rollDrops(
  random: () => number, // 0-1。テストでは固定値を注入
  keyChance: number,
  chestChance: number,
): DropResult {
  return { key: random() < keyChance, chest: random() < chestChance };
}

// ── バッジ判定(MVP: 代表2種) ──────────────────────────────
export interface BadgeContext {
  totalDelivered: number;
  streak: number;
  earned: Set<string>;
}

export function newBadges(ctx: BadgeContext): string[] {
  const result: string[] = [];
  const check = (id: string, cond: boolean) => {
    if (cond && !ctx.earned.has(id)) result.push(id);
  };
  check("b_first_delivery", ctx.totalDelivered >= 1);
  check("b_delivered_10", ctx.totalDelivered >= 10);
  check("b_streak_7", ctx.streak >= 7);
  return result;
}
