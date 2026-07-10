import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/** Phase 6 §5.2: {domain}/{reason} 形式。クライアントは messageKey → 世界観文言へ変換 */
export function appError(code: string, httpsCode: "failed-precondition" | "not-found" | "permission-denied" | "resource-exhausted" | "invalid-argument" = "failed-precondition"): HttpsError {
  return new HttpsError(httpsCode, code, { messageKey: code });
}

/** Firestore パスの一元管理(Phase 7 §5: ここ以外にパス文字列を書かない) */
export const paths = {
  user: (uid: string) => `users/${uid}`,
  progress: (uid: string, questId: string) => `users/${uid}/quest_progress/${questId}`,
  delivery: (uid: string, id: string) => `users/${uid}/deliveries/${id}`,
  badge: (uid: string, id: string) => `users/${uid}/badges/${id}`,
  bond: (uid: string, residentId: string) => `users/${uid}/bonds/${residentId}`,
  letter: (uid: string, id: string) => `users/${uid}/letters/${id}`,
  dailyLog: (uid: string, date: string) => `users/${uid}/daily_log/${date}`,
  quest: (id: string) => `quests/${id}`,
  reviewPrompt: (id: string) => `review_prompts/${id}`,
  reviewJob: (id: string) => `review_jobs/${id}`,
  opsConfig: "ops_config/game",
} as const;

/** 運営チューニング値(Phase 5 §5)。ops_config/game になければデフォルト。
 *  クライアント側ノブは Remote Config、サーバ側ノブはこのドキュメント — 二重管理を
 *  避けるため、運営は content/scripts/publish.ts から両方へ同期する。 */
export interface GameConfig {
  dropKeyChance: number;
  dropChestChance: number;
  reviewDailyLimit: number;
  xpTable: number[];
}

const DEFAULT_CONFIG: GameConfig = {
  dropKeyChance: 0.3,
  dropChestChance: 0.15,
  reviewDailyLimit: 10,
  xpTable: [0, 60, 150, 280, 450, 660, 910, 1200, 1530, 1900],
};

export async function loadGameConfig(): Promise<GameConfig> {
  try {
    const snap = await getFirestore().doc(paths.opsConfig).get();
    if (!snap.exists) return DEFAULT_CONFIG;
    return { ...DEFAULT_CONFIG, ...(snap.data() as Partial<GameConfig>) };
  } catch {
    return DEFAULT_CONFIG;
  }
}

export const REGION = "asia-northeast1";
