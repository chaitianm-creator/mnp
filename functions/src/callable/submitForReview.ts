import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import { jstDateString } from "../domain/game_logic.js";
import { REGION, appError, loadGameConfig, paths } from "../shared/core.js";

/** Phase 6 §1.2: 提出 → 添削ジョブ作成(非同期)。日次上限でコスト防衛。 */
export const submitForReview = onCall(
  { region: REGION, enforceAppCheck: true },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw appError("auth/unauthenticated", "permission-denied");
    const questId = String(req.data?.questId ?? "");
    const submission = req.data?.submission as
      | { type: "image"; storagePath: string }
      | { type: "text"; text: string }
      | undefined;
    if (!questId || !submission) throw appError("review/invalid-args", "invalid-argument");

    // 本人領域外の Storage パスを拒否
    if (submission.type === "image" &&
        !submission.storagePath.startsWith(`users/${uid}/submissions/`)) {
      throw appError("review/invalid-path", "permission-denied");
    }

    const db = getFirestore();
    const config = await loadGameConfig();
    const today = jstDateString(new Date());

    // 日次添削上限(review_daily_limit)
    const logSnap = await db.doc(paths.dailyLog(uid, today)).get();
    const used = Number(logSnap.data()?.reviews ?? 0);
    if (used >= config.reviewDailyLimit) {
      // みぽりん先生「今日はたくさん頑張ったね！続きは明日見せて」
      throw appError("review/daily-limit", "resource-exhausted");
    }

    const jobRef = db.collection("review_jobs").doc();
    await db.runTransaction(async (tx) => {
      const progressRef = db.doc(paths.progress(uid, questId));
      const progress = await tx.get(progressRef);
      if (!progress.exists || progress.data()!.status !== "in_progress") {
        throw appError("review/not-in-progress");
      }
      tx.update(progressRef, {
        status: "reviewing",
        submissionImagePath: submission.type === "image" ? submission.storagePath : null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(jobRef, {
        uid,
        questId,
        submission,
        status: "queued",
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.doc(paths.dailyLog(uid, today)),
        { reviews: FieldValue.increment(1) }, { merge: true });
    });

    return { ok: true, data: { reviewJobId: jobRef.id, estimatedSec: 30 } };
  },
);
