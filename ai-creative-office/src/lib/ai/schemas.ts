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
      assignedAgentRole: z.enum(['director', 'writer', 'reviewer', 'sns', 'designer', 'seo']),
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

// ---- 案件種別別パイプライン用スキーマ(SNS/デザイン/ドキュメント) ----

/** 企画・構成案(SNSディレクター/ディレクター/SEO・AIO) */
export const CreativeBriefSchema = z.object({
  overview: z.string(),
  objective: z.string(),
  target: z.string(),
  keyMessage: z.string(),
  toneOfVoice: z.string(),
  structure: z.array(z.object({ name: z.string(), purpose: z.string() })), // カルーセル枚数/リール尺/章立て等
  constraints: z.array(z.string()),
  referenceIdeas: z.array(z.string()),
  openQuestions: z.array(z.string()),
});
export type CreativeBriefOutput = z.infer<typeof CreativeBriefSchema>;

/** 本文・キャプション(ライター) */
export const ContentDraftSchema = z.object({
  title: z.string(),
  mainText: z.string(),
  variations: z.array(z.string()),
  hashtags: z.array(z.string()),
  cta: z.string(),
  notes: z.array(z.string()),
});
export type ContentDraftOutput = z.infer<typeof ContentDraftSchema>;

/** ビジュアル・デザイン案(デザイナー) */
export const VisualDesignSchema = z.object({
  concept: z.string(),
  layoutIdeas: z.array(z.object({ name: z.string(), description: z.string() })),
  colorPalette: z.array(z.string()),
  typography: z.string(),
  imageDirections: z.array(z.string()),
  sizeVariations: z.array(z.string()),
  notes: z.array(z.string()),
});
export type VisualDesignOutput = z.infer<typeof VisualDesignSchema>;

/** 配信戦略・KPI(マーケティング) */
export const DistributionPlanSchema = z.object({
  bestTiming: z.string(),
  frequency: z.string(),
  kpis: z.array(z.string()),
  hashtagStrategy: z.string(),
  abTestIdeas: z.array(z.string()),
  crossChannelIdeas: z.array(z.string()),
  expectedEffect: z.string(),
  notes: z.array(z.string()),
});
export type DistributionPlanOutput = z.infer<typeof DistributionPlanSchema>;

/** CEOの相談出力(経営者・クリエイティブディレクターとしての一次回答) */
export const CeoConsultSchema = z.object({
  understanding: z.string(), // ①依頼内容の理解
  objective: z.string(), // ②目的の整理(本当のゴール)
  proposal: z.string(), // ③成果を出す方法の提案
  reasoning: z.string(), // 判断根拠
  productionApproach: z.string(), // ⑤最適な制作方法(フロー・チーム)
  questions: z
    .array(
      z.object({
        question: z.string(),
        why: z.string(), // なぜ聞くか(成果物の質への影響)
        options: z.array(z.string()), // 選択肢(2〜4個。自由回答でもよい)
      }),
    )
    .max(2), // ④追加質問は最大2件。成果物の質に大きく影響する点のみ
  readyToProceed: z.boolean(), // trueなら質問なしで制作へ進める
});
export type CeoConsultOutput = z.infer<typeof CeoConsultSchema>;

export const RUN_KINDS = ['plan', 'director', 'writer', 'reviewer', 'brief', 'content', 'visual', 'distribution', 'consult'] as const;
export type RunKind = (typeof RUN_KINDS)[number];

export const SCHEMA_BY_KIND = {
  plan: ExecutionPlanSchema,
  director: DirectorDocSchema,
  writer: WriterCopySchema,
  reviewer: ReviewResultSchema,
  brief: CreativeBriefSchema,
  content: ContentDraftSchema,
  visual: VisualDesignSchema,
  distribution: DistributionPlanSchema,
  consult: CeoConsultSchema,
} as const;

/** /api/agent/run のリクエスト(入力サイズも制限) */
export const RunRequestSchema = z.object({
  kind: z.enum(RUN_KINDS),
  request: z.string().min(1).max(4000), // 社長の依頼文
  context: z.string().max(24000).optional(), // 前工程の成果物など
  revision: z.boolean().optional(), // 修正版の生成か
  revisionNotes: z.string().max(4000).optional(),
  caseLabel: z.string().max(40).optional(), // 案件種別の表示名(例: Instagram投稿)
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
