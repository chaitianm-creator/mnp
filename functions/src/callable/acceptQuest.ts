import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import { REGION, appError, paths } from "../shared/core.js";

/** Phase 6 §1.1: 受注。解放条件・同時InProgress 1件制約(ボス戦例外)を検証。 */
export const acceptQuest = onCall(
  { region: REGION, enforceAppCheck: true },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw appError("auth/unauthenticated", "permission-denied");
    const questId = String(req.data?.questId ?? "");
    if (!questId) throw appError("quest/invalid-args", "invalid-argument");

    const db = getFirestore();
    const questSnap = await db.doc(paths.quest(questId)).get();
    if (!questSnap.exists || questSnap.data()!.isPublished !== true) {
      throw appError("quest/not-found", "not-found");
    }
    const quest = questSnap.data()!;

    // 同時 InProgress 1 件制約(ボス戦は例外 = Phase 4 §5)
    if (quest.type !== "boss") {
      const inProgress = await db
        .collection(`users/${uid}/quest_progress`)
        .where("status", "in", ["accepted", "in_progress", "paused"])
        .limit(5)
        .get();
      const blocking = inProgress.docs.some((d) => d.id !== questId);
      if (blocking) throw appError("quest/already-in-progress");
    }

    await db.doc(paths.progress(uid, questId)).set(
      {
        status: "accepted",
        questVersion: quest.version ?? 1,
        currentStepId: null,
        stepAnswers: {},
        retakeCount: 0,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    // 予約消化(1件制約)
    await db.doc(paths.user(uid)).update({
      reservedQuestId: FieldValue.delete(),
    }).catch(() => {});

    return { ok: true, data: { progressId: questId, questVersion: quest.version ?? 1 } };
  },
);
