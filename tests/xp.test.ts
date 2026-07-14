import { describe, expect, it } from 'vitest';
import { xpForSession, levelForXp, xpForLevel, levelProgress } from '@/lib/xp';

describe('xpForSession (SQL側 finish_session と同一式)', () => {
  it('25分完了 = 25*2+10 = 60XP', () => {
    expect(xpForSession(25)).toBe(60);
  });
  it('0分でも完了ボーナス10XP', () => {
    expect(xpForSession(0)).toBe(10);
  });
  it('負の値は0', () => {
    expect(xpForSession(-10)).toBe(0);
  });
});

describe('levelForXp (SQL側 level_for_xp と同一式)', () => {
  it('0XPはレベル1', () => {
    expect(levelForXp(0)).toBe(1);
  });
  it('50XPでレベル2', () => {
    expect(levelForXp(49)).toBe(1);
    expect(levelForXp(50)).toBe(2);
  });
  it('200XPでレベル3', () => {
    expect(levelForXp(199)).toBe(2);
    expect(levelForXp(200)).toBe(3);
  });
  it('レベル境界とxpForLevelが一致する', () => {
    for (let level = 1; level <= 20; level++) {
      const xp = xpForLevel(level);
      expect(levelForXp(xp)).toBe(level);
      if (xp > 0) expect(levelForXp(xp - 1)).toBe(level - 1);
    }
  });
});

describe('levelProgress', () => {
  it('進捗率が0〜1に収まる', () => {
    for (const xp of [0, 10, 50, 120, 555, 10000]) {
      const p = levelProgress(xp);
      expect(p.ratio).toBeGreaterThanOrEqual(0);
      expect(p.ratio).toBeLessThanOrEqual(1);
    }
  });
});
