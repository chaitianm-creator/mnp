import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import {
  jstDateString,
  levelForXp,
  newBadges,
  rollDrops,
  streakOnDelivery,
} from "../domain/game_logic.js";
import { REGION, appError, loadGameConfig, paths } from "../shared/core.js";

/**
 * Phase 6 §1.3: 報酬付与の唯一の入口。
 *  - reviewed → delivered の遷移検証(Phase 4 不変条件のサーバ側担保)
 *  - 冪等キー = {questId}_{retakeCount}: 既納品なら当時の報酬を再返却(安全リトライ)
 *  - XP/レベル/ストリーク/ドロップ/絆/バッジ/daily_log を 1 トランザクションで
 */
export const deliverQuest = onCall(
  { region: REGION, enforceAppCheck: true },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw appError("auth/unauthenticated", "permission-denied");
    const questId = String(req.data?.questId ?? "");
    if (!questId) throw appError("deliver/invalid-args", "invalid-argument");

    const db = getFirestore();
    const config = await loadGameConfig();
    const now = new Date();
    const today = jstDateString(now);

    return db.runTransaction(async (tx) => {
      // ── 読み取りフェーズ ─────────────────────────────
      const progressRef = db.doc(paths.progress(uid, questId));
      const userRef = db.doc(paths.user(uid));
      const questRef = db.doc(paths.quest(questId));
      const [progressSnap, userSnap, questSnap] = await Promise.all([
        tx.get(progressRef),
        tx.get(userRef),
        tx.get(questRef),
      ]);

      if (!progressSnap.exists) throw appError("deliver/no-progress", "not-found");
      if (!questSnap.exists) throw appError("quest/not-found", "not-found");
      if (!userSnap.exists) throw appError("auth/no-user", "not-found");

      const progress = progressSnap.data()!;
      const quest = questSnap.data()!;
      const user = userSnap.data()!;

      // 冪等性: 既納品なら保存済み outcome を再返却(クライアントのリトライ安全)
      const retakeCount = Number(progress.retakeCount ?? 0);
      const deliveryId = `${questId}_${retakeCount}`;
      const deliveryRef = db.doc(paths.delivery(uid, deliveryId));
      const existing = await tx.get(deliveryRef);
      if (existing.exists) {
        return { ok: true, data: existing.data()!.outcome };
      }

      // 遷移検証: reviewed からのみ delivered へ
      if (progress.status !== "reviewed") {
        throw appError("deliver/not-reviewed");
      }

      // ── 計算フェーズ(純関数 = domain/game_logic) ─────────
      const reward = quest.reward ?? { xp: 0, coins: 0, skillPoints: {} };
      const prevXp = Number(user.xp ?? 0);
      const newXp = prevXp + Number(reward.xp ?? 0);
      const prevLevel = levelForXp(prevXp, config.xpTable);
      const newLevel = levelForXp(newXp, config.xpTable);

      const streak = streakOnDelivery({
        current: Number(user.streak?.current ?? 0),
        lastDeliveryDate: (user.streak?.lastDeliveryDate as string) ?? null,
        today,
      });

      const drops = rollDrops(Math.random, config.dropKeyChance, config.dropChestChance);

      const totalDelivered = Number(user.totalDelivered ?? 0) + 1;
      const earnedBadges: Set<string> = new Set(
        (user.earnedBadgeIds as string[] | undefined) ?? [],
      );
      const badges = newBadges({ totalDelivered, streak, earned: earnedBadges });

      const areaId = String(quest.areaId ?? "");
      const areaDelivered =
        Number(user.areaProgress?.[areaId]?.delivered ?? 0) + 1;
      const stage = areaDelivered >= 12 ? 3 : areaDelivered >= 6 ? 2 : 1;

      const outcome = {
        rewards: reward,
        levelUp: newLevel > prevLevel ? { from: prevLevel, to: newLevel } : null,
        drops,
        streak: { current: streak, isNewRecord: streak > Number(user.streak?.longest ?? 0) },
        areaProgress: { areaId, delivered: areaDelivered, stage },
        newBadges: badges,
        nextTeaser: quest.nextTeaser ?? null,
      };

      // ── 書き込みフェーズ ─────────────────────────────
      const skillPoints: Record<string, number> = {};
      for (const [k, v] of Object.entries(reward.skillPoints ?? {})) {
        skillPoints[`skillPoints.${k}`] = FieldValue.increment(Number(v));
      }

      tx.update(userRef, {
        xp: newXp,
        level: newLevel,
        coins: FieldValue.increment(Number(reward.coins ?? 0)),
        keys: FieldValue.increment(drops.key ? 1 : 0),
        totalDelivered,
        earnedBadgeIds: FieldValue.arrayUnion(...(badges.length ? badges : ["__noop__"])),
        "streak.current": streak,
        "streak.longest": Math.max(streak, Number(user.streak?.longest ?? 0)),
        "streak.lastDeliveryDate": today,
        [`areaProgress.${areaId}.delivered`]: areaDelivered,
        [`areaProgress.${areaId}.stage`]: stage,
        ...skillPoints,
      });

      tx.update(progressRef, {
        status: "delivered",
        deliveredAt: FieldValue.serverTimestamp(),
      });

      tx.set(deliveryRef, {
        questId,
        residentId: quest.residentId ?? null,
        areaId,
        review: progress.review ?? null,
        submissionImagePath: progress.submissionImagePath ?? null,
        isRetake: retakeCount > 0,
        outcome, // 冪等リトライ時の再返却用
        deliveredAt: FieldValue.serverTimestamp(),
      });

      for (const badgeId of badges) {
        tx.set(db.doc(paths.badge(uid, badgeId)), {
          earnedAt: FieldValue.serverTimestamp(),
        });
      }

      if (quest.residentId) {
        tx.set(
          db.doc(paths.bond(uid, String(quest.residentId))),
          {
            deliveredCount: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      tx.set(
        db.doc(paths.dailyLog(uid, today)),
        {
          delivered: FieldValue.increment(1),
          xpEarned: FieldValue.increment(Number(reward.xp ?? 0)),
        },
        { merge: true },
      );

      return { ok: true, data: outcome };
    });
  },
);
