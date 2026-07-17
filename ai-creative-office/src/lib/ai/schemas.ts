// ============================================================
// AI構造化出力のZodスキーマ(サーバー・クライアント共用)
// ============================================================
import { z } from 'zod';

export const ExecutionPlanSchema = z.object({
  summary: z.string(),
  goal: z.string(),
  assumptions: z.array(z.string()),
  missingInformation: z.array(z.string()),
  deliverables: z.array(z.string()),
  tasks: z.array(
    z.object({
      title: z.string(),
      description: z.string(),
      assignedAgentRole: z.enum(['director', 'writer', 'reviewer']),
      dependsOn: z.array(z.number()),
      canRunInParallel: z.boolean(),
      requiresApproval: z.boolean(),
      estimatedTokens: z.number(),
      estimatedCostJPY: z.number(),
    }),
  ),
  risks: z.array(z.string()),
  completionCriteria: z.array(z.string()),
});
export type ExecutionPlanOutput = z.infer<typeof ExecutionPlanSchema>;

export const DirectorDocSchema = z.object({
  overview: z.string(),
  customerIssues: z.array(z.string()),
  purpose: z.string(),
  businessGoals: z.array(z.string()),
  target: z.string(),
  persona: z.string(),
  userPains: z.array(z.string()),
  valueProposition: z.array(z.string()),
  differentiation: z.array(z.string()),
  conversion: z.string(),
  kpis: z.array(z.string()),
  sitemap: z.array(z.string()),
  pages: z.array(z.string()),
  topPageSections: z.array(z.object({ name: z.string(), purpose: z.string() })),
  requiredAssets: z.array(z.string()),
  schedule: z.array(z.string()),
  openQuestions: z.array(z.string()),
  clientConfirmations: z.array(z.string()),
});
export type DirectorDocOutput = z.infer<typeof DirectorDocSchema>;

export const WriterCopySchema = z.object({
  mainCatch: z.string(),
  subCopy: z.string(),
  cta: z.string(),
  sections: z.array(z.object({ heading: z.string(), body: z.string(), role: z.string() })),
  faq: z.array(z.object({ q: z.string(), a: z.string() })),
  companyIntro: z.string(),
  recruitMessage: z.string(),
  seoTitle: z.string(),
  metaDescription: z.string(),
});
export type WriterCopyOutput = z.infer<typeof WriterCopySchema>;

export const ReviewResultSchema = z.object({
  overall: z.string(), // 総合評価(短評)
  goodPoints: z.array(z.string()),
  criticalIssues: z.array(z.string()),
  minorIssues: z.array(z.string()),
  suggestions: z.array(z.string()),
  clientConfirmations: z.array(z.string()),
  approve: z.boolean(), // 承認可否(falseなら修正差し戻し)
});
export type ReviewResultOutput = z.infer<typeof ReviewResultSchema>;

export const RUN_KINDS = ['plan', 'director', 'writer', 'reviewer'] as const;
export type RunKind = (typeof RUN_KINDS)[number];

export const SCHEMA_BY_KIND = {
  plan: ExecutionPlanSchema,
  director: DirectorDocSchema,
  writer: WriterCopySchema,
  reviewer: ReviewResultSchema,
} as const;

/** /api/agent/run のリクエスト(入力サイズも制限) */
export const RunRequestSchema = z.object({
  kind: z.enum(RUN_KINDS),
  request: z.string().min(1).max(4000), // 社長の依頼文
  context: z.string().max(24000).optional(), // 前工程の成果物など
  revision: z.boolean().optional(), // 修正版の生成か
  revisionNotes: z.string().max(4000).optional(),
});
export type RunRequest = z.infer<typeof RunRequestSchema>;

export interface RunUsage {
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  costUSD: number;
  isMock: boolean;
  estimated: boolean; // トークン数が推定値か(実値が返らない場合のみtrue)
  durationMs: number;
}

export interface RunResponse {
  ok: boolean;
  data?: unknown;
  usage?: RunUsage;
  error?: string;
}
