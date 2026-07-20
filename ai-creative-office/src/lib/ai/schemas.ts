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

/** CEOの相談出力(CEO=経営判断の短い一次回答 + ディレクター=制作判断の引き継ぎ) */
export const CeoConsultSchema = z.object({
  shortReply: z.string(), // CEOの一次回答(100〜200字: 依頼の理解+簡単な提案のみ)
  directorComment: z.string(), // 引き継いだ専門ディレクターの一言(制作視点・100〜200字)
  understanding: z.string(), // 依頼内容の理解(詳細)
  objective: z.string(), // 目的の整理(詳細。「詳しく見る」で表示)
  proposal: z.string(), // 成果を出す方法の提案(詳細)
  reasoning: z.string(), // 判断根拠(詳細)
  productionApproach: z.string(), // 最適な制作方法(詳細)
  questions: z
    .array(
      z.object({
        question: z.string(),
        why: z.string(), // なぜ聞くか(成果物の質への影響)
        options: z.array(z.string()), // 選択肢(2〜4個。自由回答でもよい)
      }),
    )
    .max(2), // 追加質問は最大2件。成果物の質に大きく影響する点のみ(ディレクターが質問する)
  readyToProceed: z.boolean(), // trueなら質問なしで制作へ進める
});
export type CeoConsultOutput = z.infer<typeof CeoConsultSchema>;

/** レビュー会議(3人の立場からのコメント。良い点・厳しい指摘を各1つ) */
export const ReviewPanelSchema = z.object({
  investor: z.object({ good: z.string(), harsh: z.string() }), // 疑り深い投資家
  lazyReader: z.object({ good: z.string(), harsh: z.string() }), // 面倒くさがりの読者
  futureSelf: z.object({ good: z.string(), harsh: z.string() }), // 1年後の自分
});
export type ReviewPanelOutput = z.infer<typeof ReviewPanelSchema>;

/** ユーザー分析(会話から見えた特徴。該当がなければ空配列) */
export const UserInsightsSchema = z.object({
  criteria: z.array(z.string()), // 判断基準
  values: z.array(z.string()), // 大切にしている価値観
  phrases: z.array(z.string()), // よく使う言葉
  patterns: z.array(z.string()), // 思考パターン
  strengths: z.array(z.string()), // 得意なこと
  weaknesses: z.array(z.string()), // 苦手なこと
});
export type UserInsightsOutput = z.infer<typeof UserInsightsSchema>;

/** 経営相談モード: ①需要②勝てる理由③最悪のケース④最初の一歩(各3行以内) */
export const CeoAdviceSchema = z.object({
  demand: z.array(z.string()).max(3), // ①需要: 誰が困っているか/どんな場面か/お金を払う人は誰か
  winningReason: z.array(z.string()).max(3), // ②勝てる理由: この人がやる意味/強み/参入障壁
  worstCase: z.array(z.string()).max(3), // ③最悪のケース: 失うもの/リスク/撤退ライン
  firstStep: z.object({
    action: z.string(), // 今日30分以内でできる最小行動(例: Instagramプロフィールを書く)
    breakdown: z.array(z.string()).max(3), // 具体的な手順
  }),
  reviewPanel: ReviewPanelSchema,
  userInsights: UserInsightsSchema,
});
export type CeoAdviceOutput = z.infer<typeof CeoAdviceSchema>;

/** ディープリサーチモード: 判断材料の整理(CEOは結論を出さない) */
export const CeoResearchSchema = z.object({
  facts: z.array(z.string()), // ①今わかっている事実(数字・市場・一次情報)
  pros: z.array(z.object({ point: z.string(), basis: z.string() })), // ②賛成意見+根拠
  cons: z.array(z.object({ point: z.string(), basis: z.string() })), // ③反対意見+根拠
  sources: z.array(z.object({ title: z.string(), type: z.string(), url: z.string() })), // ④一次情報(公式資料・論文・IR・政府資料)
  cautions: z.array(z.string()), // 情報の確度・確認方法の注意
  reviewPanel: ReviewPanelSchema,
});
export type CeoResearchOutput = z.infer<typeof CeoResearchSchema>;

/** 案件ルームのタスクアシスタント(秘書AI): 返信+提案整理+必要なら成果物下書き */
export const TaskWorkSchema = z.object({
  reply: z.string(), // 案件チャットへの返信(簡潔に)
  suggestions: z.object({
    approaches: z.array(z.string()).max(4), // 対応方針の提案
    checkpoints: z.array(z.string()).max(4), // 確認すべきこと
    nextActions: z.array(z.string()).max(4), // 次のアクション
    missingInfo: z.array(z.string()).max(4), // 不足している情報
  }),
  // 返信文・下書きなどの成果物が求められている場合のみ作成(不要ならnull)
  artifact: z.object({ title: z.string(), kind: z.string(), content: z.string() }).nullable(),
});
export type TaskWorkOutput = z.infer<typeof TaskWorkSchema>;

export const RUN_KINDS = ['plan', 'director', 'writer', 'reviewer', 'brief', 'content', 'visual', 'distribution', 'consult', 'advise', 'research', 'taskwork'] as const;
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
  advise: CeoAdviceSchema,
  research: CeoResearchSchema,
  taskwork: TaskWorkSchema,
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
