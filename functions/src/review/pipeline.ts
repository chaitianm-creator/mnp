import { createHash } from "node:crypto";

import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { defineSecret } from "firebase-functions/params";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { REGION, paths } from "../shared/core.js";
import {
  isolateSubmissionText,
  parseModeration,
  parseReviewJson,
  violatesTone,
  type ReviewOutput,
} from "./quality.js";

/**
 * Phase 11: AI添削パイプライン(本稼働版)。
 * review_jobs onCreate →
 *   0. 画像取得 + ハッシュキャッシュ(同一提出はコスト0で再返却)
 *   1. モデレーション(Haiku・fail-closed)
 *   2. プロンプト取得(review_prompts、なければ既定)
 *   3. 添削生成(Sonnet・画像入力・注入隔離) — トーン違反/パース失敗は再生成(最大2回)
 *   4. quest_progress へ反映
 * 失敗経路: review_failed(進行は止めない = US-E3-07)。モデレーションNGは優しい差し戻し。
 */

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const API_URL = "https://api.anthropic.com/v1/messages";
const REVIEW_MODEL = "claude-sonnet-4-6";
const MODERATION_MODEL = "claude-haiku-4-5-20251001";

type ImagePart = { mediaType: string; base64: string };

async function callClaude(
  model: string,
  system: string,
  text: string,
  image?: ImagePart,
  maxTokens = 1024,
): Promise<string | null> {
  const content: unknown[] = [];
  if (image) {
    content.push({
      type: "image",
      source: { type: "base64", media_type: image.mediaType, data: image.base64 },
    });
  }
  content.push({ type: "text", text });

  const res = await fetch(API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY.value(),
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content }],
    }),
    signal: AbortSignal.timeout(45_000),
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { content: Array<{ type: string; text?: string }> };
  return body.content.map((c) => c.text ?? "").join("");
}

const MODERATION_SYSTEM =
  "あなたは教育アプリの提出物モデレーターです。入力(画像またはテキスト)が" +
  "「デザイン課題の提出物として扱ってよいか」だけを判定します。" +
  "性的・暴力的・差別的・その他有害な内容、および明らかに無関係な内容(人物の自撮り等)は safe:false。" +
  "拙くても課題への取り組みであれば safe:true。" +
  'JSONのみで回答: {"safe": true|false, "reason": "短い理由"}';

const DEFAULT_REVIEW_SYSTEM =
  "あなたは「みぽりん先生」。デザイン王国でデザイン初学者(主に女性)を育てる、あたたかい先生です。" +
  "口調: やわらかい提案形(「〜してみよ？」「〜だとどうかな？」)。決めゼリフ:「あなたなら ぜったいできるよ」「一歩ずつでいいの」。" +
  "禁止: 人格否定・命令形・専門用語の言いっぱなし(使う場合は平易に言い換える)。" +
  "改善点は「あなたが悪い」ではなく「お客さんにもっと届く方法」として語る。" +
  "評価6軸(0-5): satisfaction(クライアント満足度) quality(デザイン品質) proposal(提案力) " +
  "deadline(納期※提出があった時点で4以上) hearing(ヒアリング反映) revision(改善力)。" +
  "必ずJSONのみで回答: " +
  '{"goodPoints":["具体的な良い点を1〜3個(必ず1個以上、具体的に)"],' +
  '"improvements":["改善点を最大3個(理由+具体的な直し方)"],' +
  '"nextAdvice":"次への期待を込めた一言",' +
  '"scores":{"satisfaction":n,"quality":n,"proposal":n,"deadline":n,"hearing":n,"revision":n}}';

export const processReview = onDocumentCreated(
  {
    document: "review_jobs/{jobId}",
    region: REGION,
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const job = snap.data() as {
      uid: string;
      questId: string;
      submission: { type: "image"; storagePath: string } | { type: "text"; text: string };
    };
    const db = getFirestore();
    const progressRef = db.doc(paths.progress(job.uid, job.questId));

    const fail = async (reason: string) => {
      await progressRef
        .update({ status: "review_failed", failReason: reason, updatedAt: FieldValue.serverTimestamp() })
        .catch(() => {});
      await snap.ref.update({ status: "failed", error: reason }).catch(() => {});
    };

    try {
      // ── 0. 提出物の取得 + キャッシュ ─────────────────────
      let image: ImagePart | undefined;
      let submissionText = "";
      let contentHash: string;

      if (job.submission.type === "image") {
        const file = getStorage().bucket().file(job.submission.storagePath);
        const [buf] = await file.download();
        const ext = job.submission.storagePath.split(".").pop()?.toLowerCase();
        const mediaType = ext === "png" ? "image/png" : ext === "webp" ? "image/webp" : "image/jpeg";
        image = { mediaType, base64: buf.toString("base64") };
        contentHash = createHash("sha256").update(buf).digest("hex");
        submissionText = "添付画像がユーザーの提出物です。";
      } else {
        submissionText = isolateSubmissionText(job.submission.text);
        contentHash = createHash("sha256").update(job.submission.text).digest("hex");
      }

      // 同一提出のキャッシュ(Phase 6 §4: コスト0で再返却)
      const cacheRef = db.doc(`review_cache/${job.uid}_${job.questId}_${contentHash}`);
      const cached = await cacheRef.get();
      if (cached.exists) {
        await progressRef.update({
          status: "reviewed",
          review: cached.data()!.review,
          updatedAt: FieldValue.serverTimestamp(),
        });
        await snap.ref.update({ status: "done", cached: true });
        return;
      }

      // ── 1. モデレーション(fail-closed) ────────────────────
      const modText = await callClaude(
        MODERATION_MODEL,
        MODERATION_SYSTEM,
        job.submission.type === "text" ? submissionText : "添付画像を判定してください。",
        image,
        200,
      );
      const verdict = parseModeration(modText ?? "");
      if (!verdict.safe) {
        // 優しい差し戻し(US-E3-08): 罰ではなく「別のものを見せて」
        await progressRef.update({
          status: "review_failed",
          failReason: "moderation",
          updatedAt: FieldValue.serverTimestamp(),
        });
        await snap.ref.update({ status: "rejected", reason: verdict.reason });
        return;
      }

      // ── 2. プロンプト取得 ────────────────────────────────
      const questSnap = await db.doc(paths.quest(job.questId)).get();
      const quest = questSnap.data();
      const steps = (quest?.steps ?? []) as Array<{ reviewPromptId?: string }>;
      const promptId = steps.at(-1)?.reviewPromptId ?? "rp_default";
      const promptSnap = await db.doc(paths.reviewPrompt(promptId)).get();
      const systemPrompt = (promptSnap.data()?.systemPrompt as string) ?? DEFAULT_REVIEW_SYSTEM;
      const promptVersion = Number(promptSnap.data()?.version ?? 0);

      // クエスト文脈(ヒアリング回答を評価に反映 = hearing 軸)
      const progressSnap = await progressRef.get();
      const stepAnswers = JSON.stringify(progressSnap.data()?.stepAnswers ?? {});
      const context =
        `クエスト: ${quest?.title ?? ""}\n依頼内容: ${quest?.brief ?? ""}\n` +
        `ユーザーのヒアリング回答(参考データ): ${stepAnswers}\n\n${submissionText}`;

      // ── 3. 添削生成(トーン違反・パース失敗は再生成、最大2回) ──
      let review: ReviewOutput | null = null;
      for (let attempt = 0; attempt < 2 && !review; attempt++) {
        const text = await callClaude(REVIEW_MODEL, systemPrompt, context, image);
        if (!text) continue;
        const parsed = parseReviewJson(text);
        if (parsed && !violatesTone(parsed)) review = parsed;
      }
      if (!review) return await fail("generation-failed");

      // ── 4. 反映 ─────────────────────────────────────────
      await progressRef.update({
        status: "reviewed",
        review,
        updatedAt: FieldValue.serverTimestamp(),
      });
      await cacheRef.set({ review, createdAt: FieldValue.serverTimestamp() });
      await snap.ref.update({ status: "done", promptId, promptVersion });
    } catch (e) {
      await fail(String(e));
    }
  },
);
