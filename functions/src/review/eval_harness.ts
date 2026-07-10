/**
 * Phase 11 §3: 添削品質の評価ハーネス(ローカル実行)。
 *   ANTHROPIC_API_KEY=... npx tsx src/review/eval_harness.ts --prompt rp_pop_basic
 * ゴールデンセット(content/review_prompts/golden/*.json)を実行し、
 * L1(形式)/L2(トーン)を自動判定、L3用のMarkdownレポートを出力する。
 * ※ Firestoreに依存しない(YAMLプロンプトを直接読む)。
 */
import { readFileSync, writeFileSync } from "node:fs";
import { globSync } from "glob";
import { parse } from "yaml";

import { parseReviewJson, violatesTone } from "./quality.js";

const promptId = process.argv[process.argv.indexOf("--prompt") + 1] ?? "rp_pop_basic";
const promptYaml = parse(
  readFileSync(`../content/review_prompts/${promptId}.yaml`, "utf8"),
) as { systemPrompt: string; version: number };

interface GoldenCase {
  id: string;
  submissionText: string;
  expected: {
    mustMentionKeywords?: string[];
    scoreRange?: Record<string, [number, number]>;
  };
}

const cases: GoldenCase[] = globSync("../content/review_prompts/golden/*.json").map(
  (p) => JSON.parse(readFileSync(p, "utf8")),
);
if (cases.length === 0) {
  console.log("golden/ が空です。docs/phase11_review_quality.md §2 のセットを整備してください。");
  process.exit(0);
}

const RUNS = 3; // ばらつき計測
const results: string[] = [`# 添削評価レポート: ${promptId} v${promptYaml.version}\n`];
let l1Pass = 0, l2Pass = 0, total = 0;

for (const c of cases) {
  for (let run = 0; run < RUNS; run++) {
    total++;
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY ?? "",
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        system: promptYaml.systemPrompt,
        messages: [{ role: "user", content: c.submissionText }],
      }),
    });
    const body = (await res.json()) as { content: Array<{ text?: string }> };
    const text = body.content?.map((x) => x.text ?? "").join("") ?? "";
    const review = parseReviewJson(text);

    const l1 = review !== null;
    const l2 = l1 && !violatesTone(review);
    if (l1) l1Pass++;
    if (l2) l2Pass++;

    const mentions = (c.expected.mustMentionKeywords ?? []).map((k) => {
      const hit = JSON.stringify(review ?? {}).includes(k);
      return `${hit ? "✅" : "❌"} ${k}`;
    });
    results.push(
      `## ${c.id} (run ${run + 1})\n` +
        `- L1形式: ${l1 ? "PASS" : "FAIL"} / L2トーン: ${l2 ? "PASS" : "FAIL"}\n` +
        (mentions.length ? `- 観点言及: ${mentions.join(" / ")}\n` : "") +
        "```json\n" + JSON.stringify(review, null, 2) + "\n```\n",
    );
  }
}

results.unshift(
  `**L1: ${l1Pass}/${total} / L2: ${l2Pass}/${total}** (リリースゲート: 両方100%)\n`,
);
writeFileSync(`eval_report_${promptId}.md`, results.join("\n"));
console.log(`L1 ${l1Pass}/${total}, L2 ${l2Pass}/${total} → eval_report_${promptId}.md`);
if (l1Pass < total || l2Pass < total) process.exit(1);
