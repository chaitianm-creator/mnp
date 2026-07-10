import { describe, expect, it } from "vitest";

import {
  DEFAULT_XP_TABLE,
  dailyStreakCheck,
  levelForXp,
  newBadges,
  rollDrops,
  streakOnDelivery,
} from "./game_logic.js";

describe("levelForXp", () => {
  it("初日クエスト1件(50XP)ではレベル1、2件目(100XP)でレベル2", () => {
    expect(levelForXp(50)).toBe(1);
    expect(levelForXp(100)).toBe(2); // 序盤高速(エンゲージメント設計 §4.1)
  });
  it("テーブル境界値", () => {
    expect(levelForXp(DEFAULT_XP_TABLE[2])).toBe(3);
    expect(levelForXp(DEFAULT_XP_TABLE[2] - 1)).toBe(2);
  });
  it("テーブル超過後は400XPごと", () => {
    const last = DEFAULT_XP_TABLE[DEFAULT_XP_TABLE.length - 1];
    expect(levelForXp(last)).toBe(10);
    expect(levelForXp(last + 400)).toBe(11);
  });
});

describe("streakOnDelivery", () => {
  it("初納品は1", () => {
    expect(streakOnDelivery({ current: 0, lastDeliveryDate: null, today: "2026-07-09" })).toBe(1);
  });
  it("連続日は+1", () => {
    expect(streakOnDelivery({ current: 3, lastDeliveryDate: "2026-07-08", today: "2026-07-09" })).toBe(4);
  });
  it("同日2件目は据え置き", () => {
    expect(streakOnDelivery({ current: 4, lastDeliveryDate: "2026-07-09", today: "2026-07-09" })).toBe(4);
  });
  it("2日空いたら1から(責めずに新章 = US-E5-04)", () => {
    expect(streakOnDelivery({ current: 10, lastDeliveryDate: "2026-07-06", today: "2026-07-09" })).toBe(1);
  });
});

describe("dailyStreakCheck", () => {
  it("前日納品ありなら変化なし", () => {
    expect(dailyStreakCheck(5, 1, true)).toEqual({ streak: 5, charms: 1, charmUsed: false, broke: false });
  });
  it("前日納品なし+お守りあり → お守り消費でストリーク維持", () => {
    expect(dailyStreakCheck(5, 2, false)).toEqual({ streak: 5, charms: 1, charmUsed: true, broke: false });
  });
  it("前日納品なし+お守りなし → リセット+復帰ウェルカム対象", () => {
    expect(dailyStreakCheck(5, 0, false)).toEqual({ streak: 0, charms: 0, charmUsed: false, broke: true });
  });
});

describe("rollDrops", () => {
  it("乱数注入で決定的に検証(30%/15%)", () => {
    expect(rollDrops(() => 0.29, 0.3, 0.15)).toEqual({ key: true, chest: false });
    expect(rollDrops(() => 0.1, 0.3, 0.15)).toEqual({ key: true, chest: true });
    expect(rollDrops(() => 0.31, 0.3, 0.15)).toEqual({ key: false, chest: false });
  });
});

describe("newBadges", () => {
  it("初納品バッジ・獲得済みは再付与しない(冪等)", () => {
    expect(newBadges({ totalDelivered: 1, streak: 1, earned: new Set() }))
      .toEqual(["b_first_delivery"]);
    expect(newBadges({ totalDelivered: 2, streak: 1, earned: new Set(["b_first_delivery"]) }))
      .toEqual([]);
  });
  it("ストリーク7日バッジ", () => {
    expect(newBadges({ totalDelivered: 3, streak: 7, earned: new Set(["b_first_delivery"]) }))
      .toEqual(["b_streak_7"]);
  });
});
