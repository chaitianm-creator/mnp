import { describe, expect, it } from 'vitest';
import {
  dailyMinutes,
  localDateKey,
  sumWeekMinutes,
  weekDateKeys,
  completedCount,
  leftEarlyCount,
  weekdayTrend,
  formatMinutes,
  type SessionRow,
} from '@/lib/history';

const TZ = 'Asia/Tokyo';

function session(partial: Partial<SessionRow>): SessionRow {
  return {
    id: Math.random().toString(36),
    topic: 'テスト',
    planned_minutes: 25,
    started_at: '2026-07-13T01:00:00Z', // JST 10:00
    ended_at: '2026-07-13T01:25:00Z',
    attended_seconds: 1500,
    status: 'completed',
    rating: null,
    is_trial: false,
    ...partial,
  };
}

describe('localDateKey (タイムゾーン対応)', () => {
  it('UTC深夜はJSTでは翌日になる', () => {
    expect(localDateKey('2026-07-13T16:00:00Z', TZ)).toBe('2026-07-14'); // JST 01:00
    expect(localDateKey('2026-07-13T14:00:00Z', TZ)).toBe('2026-07-13'); // JST 23:00
  });
  it('別タイムゾーンでは日付が変わる', () => {
    expect(localDateKey('2026-07-13T16:00:00Z', 'America/New_York')).toBe('2026-07-13');
  });
});

describe('dailyMinutes', () => {
  it('完了と途中退出の実参加時間を日別に合算する', () => {
    const sessions = [
      session({ attended_seconds: 1500 }),
      session({ attended_seconds: 600, status: 'left_early' }),
      session({ attended_seconds: 3000, started_at: '2026-07-12T01:00:00Z' }),
    ];
    const daily = dailyMinutes(sessions, TZ);
    expect(daily.get('2026-07-13')).toBe(35); // 25 + 10
    expect(daily.get('2026-07-12')).toBe(50);
  });

  it('体験セッションと中断は集計しない', () => {
    const sessions = [
      session({ is_trial: true }),
      session({ status: 'abandoned' }),
      session({ status: 'active' }),
    ];
    expect(dailyMinutes(sessions, TZ).size).toBe(0);
  });
});

describe('weekDateKeys / sumWeekMinutes', () => {
  it('週は月曜はじまりで7日分', () => {
    const wed = new Date('2026-07-15T03:00:00Z'); // JST水曜
    const keys = weekDateKeys(wed, TZ);
    expect(keys).toHaveLength(7);
    expect(keys[0]).toBe('2026-07-13'); // 月曜
    expect(keys[6]).toBe('2026-07-19'); // 日曜
  });

  it('今週分だけ合算する', () => {
    const now = new Date('2026-07-15T03:00:00Z');
    const sessions = [
      session({ started_at: '2026-07-13T01:00:00Z', attended_seconds: 1500 }), // 今週月曜
      session({ started_at: '2026-07-05T01:00:00Z', attended_seconds: 1500 }), // 先週
    ];
    expect(sumWeekMinutes(sessions, now, TZ)).toBe(25);
  });
});

describe('completedCount / leftEarlyCount', () => {
  it('完了・途中退出をそれぞれ数える', () => {
    const sessions = [
      session({}),
      session({}),
      session({ status: 'left_early' }),
      session({ is_trial: true }), // 体験は除外
    ];
    expect(completedCount(sessions)).toBe(2);
    expect(leftEarlyCount(sessions)).toBe(1);
  });
});

describe('weekdayTrend', () => {
  it('曜日別に分を集計する (JST基準)', () => {
    const sessions = [session({ started_at: '2026-07-13T01:00:00Z' })]; // JST月曜
    const trend = weekdayTrend(sessions, TZ);
    expect(trend[1]).toBe(25); // 月曜=index1
    expect(trend.reduce((a, b) => a + b, 0)).toBe(25);
  });
});

describe('formatMinutes', () => {
  it('時間と分を読みやすく整形する', () => {
    expect(formatMinutes(0)).toBe('0分');
    expect(formatMinutes(59)).toBe('59分');
    expect(formatMinutes(60)).toBe('1時間');
    expect(formatMinutes(95)).toBe('1時間35分');
  });
});
