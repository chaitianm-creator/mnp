import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import { REGION, appError, paths } from "../shared/core.js";

/** Phase 6 §1.9: review_failed 案件の再添削。完了時は processReview が status を更新。 */
export const redeliverReview = onCall(
  { region: REGION, enforceAppCheck: true },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw appError("auth/unauthenticated", "permission-denied");
    const questId = String(req.data?.questId ?? "");
    if (!questId) throw appError("review/invalid-args", "invalid-argument");

    const db = getFirestore();
    const progressRef = db.doc(paths.progress(uid, questId));
    const progress = await progressRef.get();
    if (!progress.exists || progress.data()!.status !== "review_failed") {
      throw appError("review/not-failed");
    }
    // モデレーション差し戻しの再実行は不可(提出し直しが必要)
    if (progress.data()!.failReason === "moderation") {
      throw appError("review/needs-resubmission");
    }

    const imagePath = progress.data()!.submissionImagePath as string | null;
    const jobRef = db.collection("review_jobs").doc();
    await progressRef.update({
      status: "reviewing",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await jobRef.set({
      uid,
      questId,
      submission: imagePath
        ? { type: "image", storagePath: imagePath }
        : { type: "text", text: String(progress.data()!.submissionText ?? "") },
      status: "queued",
      isRedeliver: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { ok: true, data: { reviewJobId: jobRef.id } };
  },
);
