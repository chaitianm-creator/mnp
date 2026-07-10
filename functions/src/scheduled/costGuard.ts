import { getFirestore } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { jstDateString } from "../domain/game_logic.js";
import { REGION, paths } from "../shared/core.js";

/**
 * Phase 6 §3.3: AI添削APIのコスト自動防衛(毎時)。
 * 当日の添削ジョブ数(キャッシュヒット除く)を集計し、予算閾値超過で
 * review_daily_limit を自動で絞る + 運営アラート(ops_alerts)。
 */
const ESTIMATED_COST_PER_REVIEW_USD = 0.03; // 画像入力込みの概算。実測で更新

export const costGuard = onSchedule(
  { schedule: "0 * * * *", timeZone: "Asia/Tokyo", region: REGION },
  async () => {
    const db = getFirestore();
    const today = jstDateString(new Date());
    const dayStart = new Date(`${today}T00:00:00+09:00`);

    const jobs = await db
      .collection("review_jobs")
      .where("createdAt", ">=", dayStart)
      .count()
      .get();
    const count = jobs.data().count;
    const estimatedUsd = count * ESTIMATED_COST_PER_REVIEW_USD;

    const configRef = db.doc(paths.opsConfig);
    const config = (await configRef.get()).data() ?? {};
    const budgetUsd = Number(config.dailyReviewBudgetUsd ?? 50);
    const currentLimit = Number(config.reviewDailyLimit ?? 10);

    if (estimatedUsd >= budgetUsd && currentLimit > 3) {
      // 段階的に絞る(最低3回/日は死守 = 学習体験を止めない)
      const newLimit = Math.max(3, Math.floor(currentLimit / 2));
      await configRef.set({ reviewDailyLimit: newLimit }, { merge: true });
      await db.collection("ops_alerts").add({
        type: "cost_guard_triggered",
        estimatedUsd,
        budgetUsd,
        reviewCount: count,
        newLimit,
        createdAt: new Date(),
        // TODO(運用): Slack webhook 通知
      });
    }
  },
);
