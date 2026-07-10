/**
 * コンテンツ検証(Phase 7 §1): スキーマ + 参照整合性。
 * CI(PR時)で実行: 誤字・参照切れをマージ前に機械検証する。
 *   npx tsx scripts/validate.ts
 * 検証内容:
 *  1. quest.schema.json への適合(ajv)
 *  2. クエストは isDeliveryStep を持つステップを1つ以上含む(Phase 5 §2.3)
 *  3. hearing ステップを1つ以上含む(US-E2-04: 仕事の型)… boss/3分ミニは免除
 *  4. residentId / areaId の参照先 YAML が存在する
 */
import Ajv from "ajv";
import { globSync } from "glob";
import { readFileSync } from "node:fs";
import { parse } from "yaml";

const ajv = new Ajv({ allErrors: true });
const schema = JSON.parse(readFileSync("schema/quest.schema.json", "utf8"));
const validateQuest = ajv.compile(schema);

const errors: string[] = [];
const areaIds = new Set(globSync("areas/*.yaml").map((p) => parse(readFileSync(p, "utf8")).areaId));
const residentIds = new Set(globSync("residents/*.yaml").map((p) => parse(readFileSync(p, "utf8")).residentId));

for (const file of globSync("quests/**/*.yaml")) {
  const q = parse(readFileSync(file, "utf8"));
  if (!validateQuest(q)) {
    errors.push(`${file}: ${ajv.errorsText(validateQuest.errors)}`);
    continue;
  }
  const steps: Array<{ kind: string; isDeliveryStep?: boolean }> = q.steps;
  if (!steps.some((s) => s.isDeliveryStep)) {
    errors.push(`${file}: isDeliveryStep を持つステップがありません`);
  }
  if (q.sizeMinutes !== 3 && !steps.some((s) => s.kind === "hearing")) {
    errors.push(`${file}: hearing ステップがありません(3分ミニ以外は必須)`);
  }
  if (areaIds.size && !areaIds.has(q.areaId)) errors.push(`${file}: 未定義の areaId ${q.areaId}`);
  if (residentIds.size && !residentIds.has(q.residentId)) errors.push(`${file}: 未定義の residentId ${q.residentId}`);
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}
console.log("content validation: OK");
