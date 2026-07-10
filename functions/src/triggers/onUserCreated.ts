import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import { REGION, paths } from "../shared/core.js";

/**
 * 初期ユーザードキュメント生成(Phase 5 §3.1)。
 * v2 には Auth onCreate トリガーがないため、初回起動時にクライアントが呼ぶ
 * callable として実装(冪等: 既存なら no-op)。
 */
export const initUser = onCall(
  { region: REGION, enforceAppCheck: true },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) return { ok: false };
    const db = getFirestore();
    const ref = db.doc(paths.user(uid));
    const snap = await ref.get();
    if (snap.exists) return { ok: true, data: { created: false } };
    await ref.set({
      displayName: "デザイン見習い",
      level: 1, xp: 0, coins: 0, keys: 0, totalDelivered: 0,
      streak: { current: 0, longest: 0, lastDeliveryDate: null, charms: 0 },
      weeklyGoal: { target: 3, delivered: 0 },
      currentAreaId: "area_01_hajimari",
      areaProgress: {},
      skillPoints: {},
      earnedBadgeIds: [],
      flags: { onboardingDone: false, returnWelcomePending: false },
      createdAt: new Date(), lastActiveAt: new Date(),
    });
    return { ok: true, data: { created: true } };
  },
);
