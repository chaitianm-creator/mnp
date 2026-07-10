/**
 * Phase 12: deliverQuest 結合テスト(Firestoreエミュレータ)。
 * 前提: firebase emulators:start --only firestore を起動した状態で
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx vitest run test/deliverQuest.test.ts
 *
 * firebase-functions-test の wrap で v2 callable を直接呼ぶ(App Checkはバイパスされる)。
 */
import { getFirestore } from "firebase-admin/firestore";
import firebaseFunctionsTest from "firebase-functions-test";
import { afterAll, beforeEach, describe, expect, it } from "vitest";

const fft = firebaseFunctionsTest({ projectId: "design-kingdom-test" });
const { deliverQuest } = await import("../src/index.js");
const wrapped = fft.wrap(deliverQuest);

const UID = "user_test";
const QUEST = "q_marco_01";
const db = getFirestore();

async function seed(progressStatus: string) {
  await db.doc(`quests/${QUEST}`).set({
    areaId: "area_01_hajimari",
    residentId: "res_marco",
    isPublished: true,
    reward: { xp: 50, coins: 10, skillPoints: { craft: 2 } },
    nextTeaser: { residentId: "res_marco", text: "次の相談が…" },
    version: 1,
  });
  await db.doc(`users/${UID}`).set({
    xp: 60, // = ちょうどレベル2(DEFAULT_XP_TABLE[1])
    level: 2,
    coins: 0,
    keys: 0,
    totalDelivered: 0,
    earnedBadgeIds: [],
    streak: { current: 2, longest: 2, lastDeliveryDate: null },
    areaProgress: {},
    skillPoints: {},
  });
  await db.doc(`users/${UID}/quest_progress/${QUEST}`).set({
    status: progressStatus,
    retakeCount: 0,
    review: { goodPoints: ["良い"], improvements: [], nextAdvice: "", scores: {} },
  });
}

async function cleanup() {
  const collections = await db.listCollections();
  for (const c of collections) {
    const docs = await c.listDocuments();
    await Promise.all(docs.map((d) => db.recursiveDelete(d)));
  }
}

beforeEach(cleanup);
afterAll(() => fft.cleanup());

describe("deliverQuest", () => {
  it("reviewed から納品: 報酬・実績・進捗がすべて更新される", async () => {
    await seed("reviewed");
    const res = (await wrapped({ data: { questId: QUEST }, auth: { uid: UID } })) as {
      ok: boolean;
      data: Record<string, any>;
    };
    expect(res.ok).toBe(true);
    expect(res.data.rewards.xp).toBe(50);
    expect(res.data.newBadges).toContain("b_first_delivery");
    expect(res.data.streak.current).toBe(1); // lastDeliveryDate=null → 初納品

    const user = (await db.doc(`users/${UID}`).get()).data()!;
    expect(user.xp).toBe(110);
    expect(user.coins).toBe(10);
    expect(user.totalDelivered).toBe(1);
    expect(user.areaProgress.area_01_hajimari.delivered).toBe(1);
    expect(user.skillPoints.craft).toBe(2);

    const progress = (
      await db.doc(`users/${UID}/quest_progress/${QUEST}`).get()
    ).data()!;
    expect(progress.status).toBe("delivered");

    const delivery = await db.doc(`users/${UID}/deliveries/${QUEST}_0`).get();
    expect(delivery.exists).toBe(true);
  });

  it("冪等性: 2回目の呼び出しは保存済みoutcomeを再返却し、報酬は増えない", async () => {
    await seed("reviewed");
    const first = (await wrapped({ data: { questId: QUEST }, auth: { uid: UID } })) as any;
    const second = (await wrapped({ data: { questId: QUEST }, auth: { uid: UID } })) as any;
    expect(second.data.rewards.xp).toBe(first.data.rewards.xp);

    const user = (await db.doc(`users/${UID}`).get()).data()!;
    expect(user.xp).toBe(110); // 二重付与されていない
    expect(user.totalDelivered).toBe(1);
  });

  it("reviewed 以外(in_progress)からの納品は deliver/not-reviewed", async () => {
    await seed("in_progress");
    await expect(
      wrapped({ data: { questId: QUEST }, auth: { uid: UID } }),
    ).rejects.toThrow(/deliver\/not-reviewed/);
    const user = (await db.doc(`users/${UID}`).get()).data()!;
    expect(user.xp).toBe(60); // 変化なし
  });

  it("未認証は拒否", async () => {
    await seed("reviewed");
    await expect(wrapped({ data: { questId: QUEST } })).rejects.toThrow();
  });
});
