/**
 * サーバー時刻同期タイマー。
 * setIntervalのドリフトに依存せず、常に「サーバー基準の絶対時刻」から残り時間を計算する。
 * バックグラウンドタブ・リロード後も正しい残り時間になる。
 */

export interface TimerState {
  phase: 'countdown' | 'running' | 'finished';
  /** 開始までの残り秒 (countdown時) */
  secondsToStart: number;
  /** 終了までの残り秒 (running時) */
  secondsRemaining: number;
  /** 経過割合 0〜1 (running時) */
  progress: number;
}

/**
 * @param startsAtMs 部屋の開始時刻 (サーバー基準 epoch ms)
 * @param endsAtMs   部屋の終了時刻 (サーバー基準 epoch ms)
 * @param nowMs      現在時刻 (クライアント時刻 + サーバーオフセット補正済み)
 */
export function computeTimerState(startsAtMs: number, endsAtMs: number, nowMs: number): TimerState {
  if (nowMs < startsAtMs) {
    return {
      phase: 'countdown',
      secondsToStart: Math.ceil((startsAtMs - nowMs) / 1000),
      secondsRemaining: Math.round((endsAtMs - startsAtMs) / 1000),
      progress: 0,
    };
  }
  if (nowMs >= endsAtMs) {
    return { phase: 'finished', secondsToStart: 0, secondsRemaining: 0, progress: 1 };
  }
  const total = endsAtMs - startsAtMs;
  return {
    phase: 'running',
    secondsToStart: 0,
    secondsRemaining: Math.ceil((endsAtMs - nowMs) / 1000),
    progress: total <= 0 ? 1 : (nowMs - startsAtMs) / total,
  };
}

export function formatSeconds(totalSeconds: number): string {
  const s = Math.max(0, totalSeconds);
  const m = Math.floor(s / 60);
  const sec = s % 60;
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
}

/**
 * サーバー時刻とのオフセット(ms)を推定する。
 * offset = serverTime - (送信時刻 + RTT/2)
 */
export function estimateServerOffset(
  requestSentAtMs: number,
  responseReceivedAtMs: number,
  serverTimeMs: number
): number {
  const rtt = responseReceivedAtMs - requestSentAtMs;
  const midpoint = requestSentAtMs + rtt / 2;
  return serverTimeMs - midpoint;
}
