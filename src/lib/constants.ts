export const APP_NAME = 'MokuTomo';
export const APP_TAGLINE = '黙々、でもひとりじゃない。';

/** 選択できる集中時間(分)。標準は25分 */
export const DURATIONS = [5, 15, 25, 50] as const;
export const DEFAULT_DURATION = 25;

export const MAX_ROOM_SIZE = 6;

export const FREE_DAILY_SESSIONS = 2;
export const FREE_MAX_RESERVATIONS = 3;

export const STUDY_PURPOSES = [
  { value: 'exam', label: '受験勉強' },
  { value: 'certification', label: '資格試験' },
  { value: 'school', label: '学校の勉強・課題' },
  { value: 'work', label: '仕事・スキルアップ' },
  { value: 'habit', label: '学習習慣づくり' },
  { value: 'other', label: 'その他' },
] as const;

export const REPORT_CATEGORIES = [
  { value: 'inappropriate_behavior', label: '不適切な行動' },
  { value: 'camera_misuse', label: 'カメラの不正利用' },
  { value: 'impersonation', label: 'なりすまし' },
  { value: 'harassment', label: '迷惑行為' },
  { value: 'other', label: 'その他' },
] as const;

export const RATINGS = [
  { value: 'focused', label: '集中できた', emoji: '🔥' },
  { value: 'normal', label: 'ふつう', emoji: '🙂' },
  { value: 'distracted', label: '集中できなかった', emoji: '😮‍💨' },
] as const;

export const WEEKDAYS_JA = ['日', '月', '火', '水', '木', '金', '土'] as const;

export const TIMEZONES = [
  'Asia/Tokyo',
  'Asia/Seoul',
  'Asia/Shanghai',
  'Asia/Singapore',
  'Australia/Sydney',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'Pacific/Honolulu',
] as const;

/** RPCが返すエラーメッセージ → ユーザー向け文言 */
export const RPC_ERROR_MESSAGES: Record<string, string> = {
  account_suspended: 'このアカウントは現在利用停止中です。お問い合わせよりご連絡ください。',
  free_plan_daily_limit:
    '無料プランで利用できるのは1日2コマまでです。明日また利用するか、プレミアムプランをご検討ください。',
  free_plan_reservation_limit: '無料プランで登録できる予約は3件までです。',
  premium_required: 'この機能はプレミアムプラン専用です。',
  session_not_found: 'セッションが見つかりませんでした。',
  session_not_finished_yet: 'まだ集中時間が終わっていません。',
  session_already_finished: 'このセッションはすでに終了しています。',
  report_rate_limited: '通報の回数が上限に達しました。時間をおいてお試しください。',
  invite_rate_limited: '招待の回数が上限に達しました。明日以降にお試しください。',
  invalid_or_used_token: 'このリンクは無効か、すでに使用されています。',
  cannot_report_self: '自分自身を通報することはできません。',
  not_a_room_member: 'この部屋のメンバーではありません。',
};

export function rpcErrorToMessage(error: { message?: string } | null): string {
  if (!error?.message) return '不明なエラーが発生しました。';
  for (const key of Object.keys(RPC_ERROR_MESSAGES)) {
    if (error.message.includes(key)) return RPC_ERROR_MESSAGES[key];
  }
  return 'エラーが発生しました。時間をおいてもう一度お試しください。';
}
