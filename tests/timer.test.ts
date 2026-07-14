import { describe, expect, it } from 'vitest';
import { computeTimerState, formatSeconds, estimateServerOffset } from '@/lib/timer';

const START = 1_000_000_000_000;
const MIN = 60_000;

describe('computeTimerState (同期タイマー)', () => {
  const startsAt = START;
  const endsAt = START + 25 * MIN;

  it('開始前はcountdownで開始までの秒数を返す', () => {
    const s = computeTimerState(startsAt, endsAt, startsAt - 30_000);
    expect(s.phase).toBe('countdown');
    expect(s.secondsToStart).toBe(30);
    expect(s.progress).toBe(0);
  });

  it('進行中は残り秒数と進捗を返す', () => {
    const s = computeTimerState(startsAt, endsAt, startsAt + 5 * MIN);
    expect(s.phase).toBe('running');
    expect(s.secondsRemaining).toBe(20 * 60);
    expect(s.progress).toBeCloseTo(0.2, 5);
  });

  it('終了後はfinished', () => {
    const s = computeTimerState(startsAt, endsAt, endsAt + 1);
    expect(s.phase).toBe('finished');
    expect(s.secondsRemaining).toBe(0);
    expect(s.progress).toBe(1);
  });

  it('バックグラウンド後のように任意の時刻でも絶対時刻ベースで正しい', () => {
    // 12分34秒経過した地点にいきなり飛んでも正しい残り時間になる
    const jumped = startsAt + 12 * MIN + 34_000;
    const s = computeTimerState(startsAt, endsAt, jumped);
    expect(s.secondsRemaining).toBe(25 * 60 - (12 * 60 + 34));
  });

  it('ちょうど開始時刻はrunning', () => {
    expect(computeTimerState(startsAt, endsAt, startsAt).phase).toBe('running');
  });
});

describe('formatSeconds', () => {
  it('mm:ss形式にする', () => {
    expect(formatSeconds(0)).toBe('00:00');
    expect(formatSeconds(61)).toBe('01:01');
    expect(formatSeconds(25 * 60)).toBe('25:00');
  });
  it('負数は00:00', () => {
    expect(formatSeconds(-5)).toBe('00:00');
  });
});

describe('estimateServerOffset (サーバー時刻同期)', () => {
  it('RTTの中点を基準にオフセットを推定する', () => {
    // 送信=1000, 受信=1200 (RTT200ms) → 中点1100。サーバー時刻=6100 → offset=+5000
    expect(estimateServerOffset(1000, 1200, 6100)).toBe(5000);
  });
  it('クロックが揃っていればオフセットは0', () => {
    expect(estimateServerOffset(1000, 1000, 1000)).toBe(0);
  });
});
