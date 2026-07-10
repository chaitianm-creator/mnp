/**
 * コンテンツ投入(Phase 7 §1): YAML → Firestore(Admin SDK)。
 *   GOOGLE_APPLICATION_CREDENTIALS=sa.json npx tsx scripts/publish.ts [--staging]
 * 進行中クエスト保護: 既存 version と内容が異なる場合のみ version を自動加算
 * (クライアントは questVersion 固定で進行 = Phase 5 §3.2)。
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { globSync } from "glob";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { parse } from "yaml";

initializeApp();
const db = getFirestore();

const collections: Array<[string, string, string]> = [
  ["areas/*.yaml", "areas", "areaId"],
  ["residents/*.yaml", "residents", "residentId"],
  ["quests/**/*.yaml", "quests", "questId"],
  ["review_prompts/*.yaml", "review_prompts", "promptId"],
];

for (const [pattern, collection, idField] of collections) {
  for (const file of globSync(pattern)) {
    const data = parse(readFileSync(file, "utf8"));
    const id = data[idField];
    const ref = db.collection(collection).doc(id);
    const existing = await ref.get();
    const hash = createHash("sha256").update(JSON.stringify(data)).digest("hex");
    if (existing.exists && existing.data()!._contentHash === hash) {
      console.log(`skip (unchanged): ${collection}/${id}`);
      continue;
    }
    const version = existing.exists ? Number(existing.data()!.version ?? 0) + 1 : data.version ?? 1;
    await ref.set({ ...data, version, _contentHash: hash });
    console.log(`published: ${collection}/${id} (v${version})`);
  }
}
