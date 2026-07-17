// ============================================================
// 案件種別の判定と担当部署への振り分け定義
// (クライアント・サーバー共用。CEO AIが依頼文から種別を判定し、
//  Web制作/SNS/デザイン/ドキュメントの各パイプラインへ分岐する)
// ============================================================
import type { DeliverableType } from './types';

export type CaseType =
  | 'instagram_post'
  | 'instagram_reel'
  | 'instagram_carousel'
  | 'threads'
  | 'x_post'
  | 'facebook'
  | 'blog'
  | 'lp'
  | 'website'
  | 'banner'
  | 'flyer'
  | 'logo'
  | 'proposal'
  | 'planning_doc';

export type PipelineKind = 'web' | 'sns' | 'design' | 'docs';

/** パイプラインの1工程(レビューを除く) */
export interface PipelineStep {
  kind: 'director' | 'writer' | 'brief' | 'content' | 'visual' | 'distribution';
  agentId: string; // 担当AI社員のID(オフィス演出・ログにも使用)
  title: string;
  description: string;
  deliverableType: DeliverableType;
  deliverableTitle: string;
  activity: string; // 実行中のステータス表示
}

export interface CaseDef {
  type: CaseType;
  label: string; // 例: Instagram投稿
  departmentLabel: string; // 例: マーケ部(SNSチーム)
  pipeline: PipelineKind;
  steps: PipelineStep[]; // レビュー(reviewer)は全パイプライン共通で最後に実行
  revisionKind: PipelineStep['kind']; // レビュー差し戻し時に修正する工程
  directorAgentId: string; // 会話を引き継ぐ専門ディレクターのAI社員ID
  directorLabel: string; // 例: 📣 SNSディレクター(制作判断の担当として表示)
}

// ---- 工程テンプレート ----

const snsSteps = (label: string): PipelineStep[] => [
  {
    kind: 'brief',
    agentId: 'sns',
    title: `${label}の企画・構成案の作成`,
    description: '目的・ターゲット・キーメッセージ・構成(枚数/尺)・トーンを設計',
    deliverableType: 'brief',
    deliverableTitle: `${label} 企画・構成案`,
    activity: `${label}の企画・構成を設計中`,
  },
  {
    kind: 'content',
    agentId: 'writer',
    title: 'キャプション・本文の執筆',
    description: '構成案に沿ってフック・本文・ハッシュタグ・CTAを執筆',
    deliverableType: 'sns_content',
    deliverableTitle: `${label} キャプション・本文`,
    activity: `${label}の本文とハッシュタグを執筆中`,
  },
  {
    kind: 'visual',
    agentId: 'designer',
    title: 'ビジュアル案の作成',
    description: 'レイアウト・配色・画像ディレクションを設計',
    deliverableType: 'visual',
    deliverableTitle: `${label} ビジュアル案`,
    activity: `${label}のビジュアル案を作成中`,
  },
  {
    kind: 'distribution',
    agentId: 'seo',
    title: '配信戦略の立案',
    description: '投稿タイミング・KPI・ハッシュタグ戦略・改善案を設計',
    deliverableType: 'distribution',
    deliverableTitle: `${label} 配信戦略・KPI設計`,
    activity: `${label}の配信戦略とKPIを設計中`,
  },
];

const webSteps: PipelineStep[] = [
  {
    kind: 'director',
    agentId: 'director',
    title: '要件整理とサイト構成の作成',
    description: 'ターゲット・ペルソナ・サイトマップ・トップページ構成を整理',
    deliverableType: 'requirements',
    deliverableTitle: '要件整理書',
    activity: 'ターゲットとサイト構成を整理中',
  },
  {
    kind: 'writer',
    agentId: 'writer',
    title: 'キャッチコピー・原稿の作成',
    description: '構成に沿ってコピーと本文を執筆',
    deliverableType: 'copy',
    deliverableTitle: 'Web原稿・キャッチコピー',
    activity: 'キャッチコピーと原稿を作成中',
  },
];

const designSteps = (label: string, withCopy: boolean): PipelineStep[] => [
  {
    kind: 'brief',
    agentId: 'director',
    title: `${label}の要件・企画整理`,
    description: '目的・ターゲット・キーメッセージ・制約(サイズ/媒体)を整理',
    deliverableType: 'brief',
    deliverableTitle: `${label} 企画・要件整理`,
    activity: `${label}の要件を整理中`,
  },
  ...(withCopy
    ? [
        {
          kind: 'content' as const,
          agentId: 'writer',
          title: 'キャッチコピー・掲載文の作成',
          description: `${label}に載せるコピー・テキストを執筆`,
          deliverableType: 'sns_content' as DeliverableType,
          deliverableTitle: `${label} コピー・掲載文`,
          activity: `${label}のコピーを作成中`,
        },
      ]
    : []),
  {
    kind: 'visual',
    agentId: 'designer',
    title: `${label}のデザイン案作成`,
    description: 'コンセプト・レイアウト・配色・書体を設計',
    deliverableType: 'visual',
    deliverableTitle: `${label} デザイン案`,
    activity: `${label}のデザイン案を作成中`,
  },
];

const docsSteps = (label: string, briefAgent: string): PipelineStep[] => [
  {
    kind: 'brief',
    agentId: briefAgent,
    title: `${label}の構成案作成`,
    description: '目的・読み手・論理構成・章立てを設計',
    deliverableType: 'brief',
    deliverableTitle: `${label} 構成案`,
    activity: `${label}の構成を設計中`,
  },
  {
    kind: 'content',
    agentId: 'writer',
    title: `${label}の本文執筆`,
    description: '構成案に沿って本文を執筆',
    deliverableType: 'document',
    deliverableTitle: `${label}(本文)`,
    activity: `${label}の本文を執筆中`,
  },
];

// ---- 案件種別定義 ----

const sns = (type: CaseType, label: string): CaseDef => ({
  type,
  label,
  departmentLabel: 'マーケ部(SNSディレクター)',
  pipeline: 'sns',
  steps: snsSteps(label),
  revisionKind: 'content',
  directorAgentId: 'sns',
  directorLabel: '📣 SNSディレクター',
});

export const CASE_DEFS: Record<CaseType, CaseDef> = {
  instagram_post: sns('instagram_post', 'Instagram投稿'),
  instagram_reel: sns('instagram_reel', 'Instagramリール'),
  instagram_carousel: sns('instagram_carousel', 'Instagramカルーセル'),
  threads: sns('threads', 'Threads投稿'),
  x_post: sns('x_post', 'X投稿'),
  facebook: sns('facebook', 'Facebook投稿'),
  blog: {
    type: 'blog',
    label: 'ブログ記事',
    departmentLabel: 'マーケ部(SEO・AIOチーム)',
    pipeline: 'docs',
    steps: docsSteps('ブログ記事', 'seo'),
    revisionKind: 'content',
    directorAgentId: 'seo',
    directorLabel: '📝 編集ディレクター',
  },
  lp: {
    type: 'lp',
    label: 'LP制作',
    departmentLabel: '制作部(Web制作チーム)',
    pipeline: 'web',
    steps: webSteps,
    revisionKind: 'writer',
    directorAgentId: 'director',
    directorLabel: '🗂 Webディレクター',
  },
  website: {
    type: 'website',
    label: 'ホームページ制作',
    departmentLabel: '制作部(Web制作チーム)',
    pipeline: 'web',
    steps: webSteps,
    revisionKind: 'writer',
    directorAgentId: 'director',
    directorLabel: '🗂 Webディレクター',
  },
  banner: {
    type: 'banner',
    label: 'バナー制作',
    departmentLabel: '制作部(デザインチーム)',
    pipeline: 'design',
    steps: designSteps('バナー', true),
    revisionKind: 'visual',
    directorAgentId: 'designer',
    directorLabel: '🎨 アートディレクター',
  },
  flyer: {
    type: 'flyer',
    label: 'チラシ制作',
    departmentLabel: '制作部(デザインチーム)',
    pipeline: 'design',
    steps: designSteps('チラシ', true),
    revisionKind: 'visual',
    directorAgentId: 'designer',
    directorLabel: '🎨 アートディレクター',
  },
  logo: {
    type: 'logo',
    label: 'ロゴ制作',
    departmentLabel: '制作部(デザインチーム)',
    pipeline: 'design',
    steps: designSteps('ロゴ', false),
    revisionKind: 'visual',
    directorAgentId: 'designer',
    directorLabel: '🎨 アートディレクター',
  },
  proposal: {
    type: 'proposal',
    label: '提案書作成',
    departmentLabel: '経営部・制作部(ドキュメントチーム)',
    pipeline: 'docs',
    steps: docsSteps('提案書', 'director'),
    revisionKind: 'content',
    directorAgentId: 'director',
    directorLabel: '🗂 ディレクター',
  },
  planning_doc: {
    type: 'planning_doc',
    label: '企画書作成',
    departmentLabel: '経営部・制作部(ドキュメントチーム)',
    pipeline: 'docs',
    steps: docsSteps('企画書', 'director'),
    revisionKind: 'content',
    directorAgentId: 'director',
    directorLabel: '🗂 ディレクター',
  },
};

/**
 * 依頼文から案件種別を判定する(決定的なキーワード判定)
 * 具体的な種別(カルーセル等)を先に判定し、最後に汎用種別へフォールバックする
 */
export function classifyRequest(request: string): CaseType {
  const t = request.toLowerCase();
  const has = (...words: string[]) => words.some((w) => t.includes(w.toLowerCase()));

  // Instagram系(具体的な形式を先に判定)
  const isInstagram = has('instagram', 'インスタ');
  if (has('カルーセル', 'carousel')) return 'instagram_carousel';
  if (has('リール', 'reel')) return 'instagram_reel';
  if (isInstagram) return 'instagram_post';

  // その他SNS
  if (has('threads', 'スレッズ')) return 'threads';
  if (has('facebook', 'フェイスブック')) return 'facebook';
  if (has('ツイート', 'twitter') || (/(^|[^a-z])x([^a-z]|$)/.test(t) && has('投稿', 'ポスト'))) return 'x_post';
  if (has('sns') && has('投稿')) return 'instagram_post';

  // ドキュメント
  if (has('提案書')) return 'proposal';
  if (has('企画書')) return 'planning_doc';

  // デザイン
  if (has('バナー')) return 'banner';
  if (has('チラシ', 'フライヤー')) return 'flyer';
  if (has('ロゴ')) return 'logo';

  // 記事
  if (has('ブログ', '記事', 'コラム')) return 'blog';

  // Web制作
  if (has('lp', 'ランディングページ')) return 'lp';
  if (has('ホームページ', 'コーポレートサイト', 'webサイト', 'サイト')) return 'website';

  // 不明な依頼はWeb制作フロー(従来動作)へ
  return 'website';
}
