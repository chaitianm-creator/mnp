import { getFirestore } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { dailyStreakCheck, jstDateString } from "../domain/game_logic.js";
import { REGION } from "../shared/core.js";

/**
 * Phase 6 §3.1 日次バッチ(毎日 04:00 JST)。
 * MVP 骨格: ストリーク判定(お守り自動消費 / リセット+復帰フラグ)。
 * todayOffers 生成・週次リセット・手紙送付は Phase 11 マイルストーンで拡張。
 */
export const dailyBatch = onSchedule(
  { schedule: "0 4 * * *", timeZone: "Asia/Tokyo", region: REGION },
  async () => {
    const db = getFirestore();
    const yesterday = jstDateString(new Date(Date.now() - 86_400_000));

    // アクティブユーザー(30日以内)をページングで処理
    const cutoff = new Date(Date.now() - 30 * 86_400_000);
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    for (;;) {
      let q = db.collection("users")
        .where("lastActiveAt", ">=", cutoff)
        .orderBy("lastActiveAt")
        .limit(200);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;

      const batch = db.batch();
      for (const doc of page.docs) {
        const u = doc.data();
        const deliveredYesterday = u.streak?.lastDeliveryDate === yesterday;
        const r = dailyStreakCheck(
          Number(u.streak?.current ?? 0),
          Number(u.streak?.charms ?? 0),
          deliveredYesterday,
        );
        const update: Record<string, unknown> = {
          "streak.current": r.streak,
          "streak.charms": r.charms,
        };
        if (r.broke) update["flags.returnWelcomePending"] = true;
        if (r.charmUsed) {
          // 手紙:「お守りが守ってくれたよ」(letters_templates 経由は Phase 11)
          batch.set(doc.ref.collection("letters").doc(), {
            templateId: "lt_charm_used",
            read: false,
            createdAt: new Date(),
          });
        }
        batch.update(doc.ref, update);
      }
      await batch.commit();
      last = page.docs[page.docs.length - 1];
      if (page.size < 200) break;
    }
  },
);
