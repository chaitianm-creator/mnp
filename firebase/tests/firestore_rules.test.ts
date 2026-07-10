/**
 * Phase 12: Firestoreセキュリティルールのテスト。
 * 前提: firebase emulators:start --only firestore を起動した状態で
 *   cd firebase/tests && npm install && npm test
 * 検証: Phase 5 §6「進行と設定はクライアント、報酬と実績はFunctionsのみ」
 */
import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

let env: RulesTestEnvironment;
const UID = "user_misaki";

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "design-kingdom-test",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
  });
});
afterAll(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${UID}`).set({
      displayName: "みさき", xp: 100, level: 2, coins: 50,
      streak: { current: 3 }, flags: { onboardingDone: true },
    });
    await db.doc(`users/${UID}/quest_progress/q_marco_01`).set({
      status: "in_progress", stepAnswers: {},
    });
    await db.doc("quests/q_marco_01").set({ title: "POP", isPublished: true });
    await db.doc("quests/q_draft").set({ title: "下書き", isPublished: false });
    await db.doc("review_prompts/rp_pop_basic").set({ systemPrompt: "秘密" });
  });
});

const me = () => env.authenticatedContext(UID).firestore();
const stranger = () => env.authenticatedContext("someone_else").firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe("コンテンツ", () => {
  it("公開クエストは認証ユーザーが読める / 未公開・未認証は読めない", async () => {
    await assertSucceeds(me().doc("quests/q_marco_01").get());
    await assertFails(me().doc("quests/q_draft").get());
    await assertFails(anon().doc("quests/q_marco_01").get());
  });
  it("クエストへの書き込みは常に拒否(運営はAdmin SDK)", async () => {
    await assertFails(me().doc("quests/q_marco_01").set({ title: "改ざん" }));
  });
  it("添削プロンプトは誰も読めない(流出防止)", async () => {
    await assertFails(me().doc("review_prompts/rp_pop_basic").get());
  });
});

describe("ユーザードキュメント(報酬フィールドの防衛)", () => {
  it("本人は読める / 他人・未認証は読めない", async () => {
    await assertSucceeds(me().doc(`users/${UID}`).get());
    await assertFails(stranger().doc(`users/${UID}`).get());
  });
  it("設定系フィールド(displayName等)は本人が更新できる", async () => {
    await assertSucceeds(
      me().doc(`users/${UID}`).update({ displayName: "みさき⭐" }),
    );
  });
  it("XP/コイン/ストリークの直接改ざんは拒否(チート防止の核)", async () => {
    await assertFails(me().doc(`users/${UID}`).update({ xp: 99999 }));
    await assertFails(me().doc(`users/${UID}`).update({ coins: 99999 }));
    await assertFails(
      me().doc(`users/${UID}`).update({ "streak.current": 365 }),
    );
    // 設定と報酬の混在更新も拒否(hasOnlyの検証)
    await assertFails(
      me().doc(`users/${UID}`).update({ displayName: "x", xp: 99999 }),
    );
  });
});

describe("quest_progress(状態機械のサーバ側防衛)", () => {
  it("in_progress への更新は本人が可能", async () => {
    await assertSucceeds(
      me().doc(`users/${UID}/quest_progress/q_marco_01`).update({
        status: "paused",
      }),
    );
  });
  it("delivered / reviewed への直接遷移は拒否(Functions専用)", async () => {
    await assertFails(
      me().doc(`users/${UID}/quest_progress/q_marco_01`).update({
        status: "delivered",
      }),
    );
    await assertFails(
      me().doc(`users/${UID}/quest_progress/q_marco_01`).update({
        status: "reviewed",
        review: { scores: { quality: 5 } }, // 自作添削の注入も不可
      }),
    );
  });
});

describe("実績(deliveries/badges)", () => {
  it("本人でも書き込み不可(付与はdeliverQuestのみ)", async () => {
    await assertFails(
      me().doc(`users/${UID}/deliveries/fake`).set({ questId: "q_marco_01" }),
    );
    await assertFails(
      me().doc(`users/${UID}/badges/b_streak_7`).set({ earnedAt: new Date() }),
    );
  });
});
