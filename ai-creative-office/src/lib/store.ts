'use client';

// ============================================================
// アプリ全体の状態管理(Zustand + localStorage永続化)
// - デモエンジン: tick() が数秒ごとに呼ばれ、AI社員の状態・
//   タスク進捗・活動ログ・利用料金を更新する
// - 将来はここを Supabase Realtime + サーバーAPI に置き換える
//   (コンポーネント側はこのストアのインターフェースのみに依存)
// ============================================================

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import {
  buildAgentContext,
  buildCompanyContext,
  conversationProvider,
  generateAchievementReport,
  generateAssembly,
  generateCEOAlert,
  generateInterAgentConversation,
  generateReaction,
  moodOf,
} from './conversation';
import { currentPeriod } from './office';
import {
  AGENT_PERSONAS,
  emptyAgents,
  mergePersona,
  seedAgents,
  seedDirectChats,
  seedProposals,
  seedTalks,
  seedUnread,
  seedApprovals,
  seedCampaigns,
  seedChat,
  seedDailyStats,
  seedDeals,
  seedErrors,
  seedIntegrations,
  seedInquiries,
  seedLeads,
  seedLogs,
  seedProjects,
  seedReports,
  seedSeoKeywords,
  seedSettings,
  seedSnsPosts,
  seedTasks,
  seedUsage,
} from './mock-data';
import type {
  Achievement,
  ActivityLog,
  Agent,
  AgentRun,
  AgentStatus,
  AgentTalk,
  AiUsageRecord,
  Announcement,
  Approval,
  Campaign,
  CeoAlert,
  CeoProposal,
  CeoUserProfile,
  ChatAction,
  ChatMessage,
  ChatSession,
  CompanySettings,
  DailyStat,
  Deal,
  Deliverable,
  DirectChatMessage,
  ErrorRecord,
  ExecutionPlan,
  Inquiry,
  Integration,
  Lead,
  OfficeEvent,
  OfficeZone,
  Project,
  Report,
  RunTask,
  SeoKeyword,
  SnsPost,
  Task,
  TaskStatus,
} from './types';
import { pickRandom, todayKey, uid } from './utils';

interface OfficeState {
  hydrated: boolean;
  settings: CompanySettings;
  agents: Agent[];
  tasks: Task[];
  approvals: Approval[];
  leads: Lead[];
  campaigns: Campaign[];
  inquiries: Inquiry[];
  deals: Deal[];
  projects: Project[];
  snsPosts: SnsPost[];
  seoKeywords: SeoKeyword[];
  logs: ActivityLog[];
  usage: AiUsageRecord[];
  dailyStats: DailyStat[];
  reports: Report[];
  errors: ErrorRecord[];
  integrations: Integration[];
  chat: ChatMessage[];
  chatSessions: ChatSession[]; // 社長指示チャットの過去セッション
  // ライブオフィス用(永続化しない)
  officeEvents: OfficeEvent[];
  announcements: Announcement[];
  tickCount: number;
  relayQueue: { from: string; to: string; label: string; log: string }[];
  lastChatAt: Record<string, string>; // 「社長と会話中」演出用(永続化しない)
  lastProposalTick: number; // CEO提案のクールダウン(永続化しない)
  alertCooldowns: Record<string, number>; // 同種CEO呼びかけの再通知防止(永続化しない)
  lastTalkTopics: string[]; // 直近の会話トピック(同一パターン連続防止・永続化しない)
  lastAssemblyKey: string; // 朝会/夕会の重複開催防止(永続化しない)
  // AI社員との会話・CEO提案(永続化する)
  directChats: Record<string, DirectChatMessage[]>;
  unread: Record<string, number>;
  proposals: CeoProposal[];
  agentTalks: AgentTalk[];
  achievements: Achievement[]; // 成果イベント(MVP算出に使用)
  ceoAlerts: CeoAlert[]; // CEOから社長への呼びかけ
  agentRuns: AgentRun[]; // AI実働ラン(実際の成果物生成)
  deliverables: Deliverable[]; // AI生成の成果物(バージョン管理付き)
  onboardingDismissed: boolean; // 初回オンボーディングカードを閉じたか
  ceoProfile: CeoUserProfile; // 会話から更新するユーザー(社長)分析

  setHydrated: (v: boolean) => void;
  dismissOnboarding: () => void;
  mergeCeoProfile: (insights: Partial<Omit<CeoUserProfile, 'updatedAt'>>) => void;
  startNewChatSession: () => void; // 現在の会話をアーカイブして新しい会話を始める
  switchChatSession: (sessionId: string) => void; // 過去の会話へ切り替え(現在の会話はアーカイブ)
  setDemoMode: (on: boolean) => void; // Demo Mode切り替え(ダミーデータの表示/非表示)
  tick: () => void;
  pauseAgent: (agentId: string) => void;
  resumeAgent: (agentId: string) => void;
  renameAgent: (agentId: string, name: string) => void;
  openChat: (agentId: string) => void;
  sendDirectMessage: (agentId: string, content: string) => void;
  executeChatAction: (agentId: string, action: ChatAction) => void;
  decideProposal: (proposalId: string, decision: 'adopted' | 'revision' | 'rejected') => void;
  decideAlert: (alertId: string, decision: 'accepted' | 'later' | 'dismissed') => void;
  playAssembly: (kind: 'morning' | 'evening') => void;
  // AI実働ラン
  addAgentRun: (run: AgentRun, chatMessage: string) => void;
  updateAgentRun: (runId: string, patch: Partial<AgentRun>) => void;
  updateRunTask: (runId: string, taskId: string, patch: Partial<RunTask>) => void;
  addDeliverable: (d: Deliverable) => void;
  updateDeliverable: (id: string, patch: Partial<Deliverable>) => void;
  saveDeliverableVersion: (id: string, markdown: string, editedBy: 'ai' | 'human', note: string) => void;
  recordRunUsage: (agentId: string, usage: { provider: string; model: string; inputTokens: number; outputTokens: number; costUSD: number }, taskId: string | null) => void;
  setAgentRunActivity: (agentId: string, note: string, zone: OfficeZone, progress?: number) => void;
  decideApproval: (id: string, decision: 'approved' | 'rejected' | 'revision_requested') => void;
  updateSettings: (patch: Partial<CompanySettings>) => void;
  sendChat: (content: string) => void;
  startPlan: (messageId: string) => void;
  discardPlan: (messageId: string) => void;
  instructAgent: (agentId: string, instruction: string) => void;
  setTaskStatus: (taskId: string, status: TaskStatus) => void;
  resolveError: (id: string) => void;
  toggleIntegration: (id: string) => void;
  resetAll: () => void;
}

// エージェント別の「作業中」表示ノート(デモ演出用)
const WORK_NOTES: Record<string, string[]> = {
  ceo: ['全体進捗を確認中', 'タスクの優先順位を調整中', '週次レポートの構成を検討中'],
  secretary: ['会議候補日を作成中', '議事録を整理中', '未返信案件を確認中'],
  list: ['企業リスト 180 / 300件', '重複チェックを実行中', '対象企業を精査中'],
  form_sales: ['送信文案を個別調整中', 'フォームURLを確認中', '送信結果を記録中'],
  email_sales: ['営業メール本文を作成中', '返信メールを分類中', '件名A/Bパターンを作成中'],
  reception: ['問い合わせを分類中', '一次返信案を作成中', '緊急度を判定中'],
  deal_mgr: ['商談メモを要約中', '次回アクションを設定中', '案件化可能性を判定中'],
  tel: ['トークスクリプトを作成中', '想定Q&Aを整備中'],
  sns: ['投稿文を作成中', '投稿カレンダーを更新中', 'エンゲージメントを分析中'],
  seo: ['競合ページを分析中', '記事構成を作成中', '検索意図を分類中'],
  director: ['要件定義書を更新中', 'サイトマップを作成中', '制作スケジュールを調整中'],
  writer: ['キャッチコピーを作成中', 'サービス紹介文を執筆中', '原稿のトーンを調整中'],
  designer: ['ワイヤーフレームを作成中', '配色パターンを検討中', 'UIパーツを設計中'],
  coder: ['コンポーネントを実装中', 'レスポンシブ対応を実装中', 'フォームを実装中'],
  reviewer: ['表示崩れをチェック中', 'リンク切れを確認中', '修正指示を作成中'],
  infra: ['公開前チェックリストを確認中', 'ビルド状況を監視中'],
  accountant: ['AI利用料を集計中', '案件別原価を計算中', '帳簿を更新中'],
  ops_admin: ['操作ログを監査中', '権限設定を確認中'],
};

// 依頼の飛び先(delegate演出用): 業務フロー上の自然な相手
const DELEGATE_MAP: Record<string, { to: string; label: string }[]> = {
  ceo: [
    { to: 'list', label: '営業リスト作成を依頼' },
    { to: 'director', label: '案件進行の確認を依頼' },
    { to: 'accountant', label: 'コスト集計を依頼' },
  ],
  list: [{ to: 'email_sales', label: 'リスト128社を引き渡し' }, { to: 'form_sales', label: 'フォームURL一覧を共有' }],
  form_sales: [{ to: 'reviewer', label: '送信文チェックを依頼' }],
  email_sales: [{ to: 'reviewer', label: '文面レビューを依頼' }, { to: 'deal_mgr', label: '返信2件を引き継ぎ' }],
  reception: [{ to: 'deal_mgr', label: '新規問い合わせを引き継ぎ' }, { to: 'secretary', label: '日程調整を依頼' }],
  deal_mgr: [{ to: 'secretary', label: '商談候補日の作成を依頼' }],
  secretary: [{ to: 'ceo', label: '本日の予定を報告' }],
  sns: [{ to: 'designer', label: '投稿画像の制作を依頼' }],
  seo: [{ to: 'writer', label: '記事構成を引き渡し' }],
  director: [
    { to: 'writer', label: '原稿作成を依頼' },
    { to: 'designer', label: 'ワイヤー作成を依頼' },
    { to: 'coder', label: '実装を依頼' },
  ],
  writer: [{ to: 'reviewer', label: '原稿チェックを依頼' }, { to: 'designer', label: '原稿を引き渡し' }],
  designer: [{ to: 'coder', label: 'デザイン指示書を引き渡し' }],
  coder: [{ to: 'reviewer', label: 'コードレビューを依頼' }],
  reviewer: [{ to: 'coder', label: '修正指示4件を送付' }, { to: 'infra', label: '公開前チェックを依頼' }],
  infra: [{ to: 'ceo', label: 'ビルド状況を報告' }],
  accountant: [{ to: 'ceo', label: '日次集計を報告' }],
  ops_admin: [{ to: 'ceo', label: '監査結果を報告' }],
  tel: [{ to: 'deal_mgr', label: '架電結果を共有' }],
};

// CEOアナウンスのテンプレート(数値は実データから埋める)
const ANNOUNCE_POOL: ((counts: { pending: number; running: number; errors: number }) => { message: string; tone: Announcement['tone'] })[] = [
  (c) => ({ message: `本日は営業部を優先稼働しています(実行中タスク ${c.running}件)`, tone: 'info' }),
  (c) => ({ message: `承認待ちが${c.pending}件あります。承認センターのご確認をお願いします`, tone: 'warning' }),
  () => ({ message: '制作部の進捗は順調です。田中製作所様はデザイン工程を進行中です', tone: 'info' }),
  (c) =>
    c.errors > 0
      ? { message: `問題が${c.errors}件発生しています。サーバールームで対応中です`, tone: 'warning' }
      : { message: '現在、未解決の障害はありません。全部署が正常稼働しています', tone: 'success' },
  () => ({ message: '営業部へ応援としてリスト精査の優先度を引き上げました', tone: 'info' }),
  () => ({ message: '夕方に本日の日報を自動作成します。優先事項があればチャットでご指示ください', tone: 'info' }),
];

const TICK_LOGS: [string, string, ActivityLog['status']][] = [
  ['list', '営業リストに新しい企業を3社追加しました(製造業・愛知県)。', 'info'],
  ['list', 'ミナト精密工業様の企業情報を最新化しました。', 'info'],
  ['email_sales', 'ワタナベ税理士法人様がメールを開封しました。', 'info'],
  ['email_sales', 'アーバン不動産様向けの件名をA/Bテスト用に2案作成しました。', 'info'],
  ['form_sales', 'タカハシ電設様の送信文案を業種向けに調整しました。', 'info'],
  ['writer', '佐藤工務店様「お客様の声」原稿の推敲が完了しました。', 'success'],
  ['writer', '採用コピーの表現を3パターン作成しました。', 'info'],
  ['coder', 'ヘッダーコンポーネントの実装が完了しました。', 'success'],
  ['coder', '施工事例ギャラリーのレスポンシブ調整を反映しました。', 'info'],
  ['reviewer', 'トップページの指摘1件(リンク切れ)の修正を確認しました。', 'success'],
  ['reviewer', '田中製作所様サイトのアクセシビリティ検査を実行中です。', 'info'],
  ['seo', '「ホームページ リニューアル 費用」の競合3ページを分析しました。', 'info'],
  ['seo', '「工務店 ホームページ 事例」が7位→5位に上昇しました。', 'success'],
  ['sns', 'Instagram投稿「制作実績紹介」の画像構成を更新しました。', 'info'],
  ['secretary', 'ミナト精密工業様へ商談リマインドの下書きを作成しました。', 'info'],
  ['secretary', '明日の予定2件を各担当AIへ通知しました。', 'info'],
  ['deal_mgr', 'クローバー美容室様の商談メモを要約しました。', 'info'],
  ['deal_mgr', 'ハルカゼ商事様の案件化可能性を68%と判定しました。', 'info'],
  ['designer', 'トップページヒーローセクションの配色案を2点追加しました。', 'info'],
  ['designer', 'デザイナーAIがレビュアーAIへデザイン確認を依頼しました。', 'info'],
  ['accountant', '本日のトークン利用量を集計し、帳簿へ記録しました。', 'info'],
  ['infra', 'ステージング環境のビルドが72秒で成功しました。', 'success'],
  ['ceo', '各部署の進捗を確認し、優先順位を再調整しました。', 'info'],
  ['ops_admin', '操作ログ48件を監査しました。異常はありません。', 'info'],
];

// 会議中のAI社員が交わす会話(吹き出し演出用)
const MEETING_TALK = [
  '💬 進捗は予定どおりです',
  '💬 コピーはB案が良さそうですね',
  '💬 明日までに初稿を出します',
  '💬 返信率が改善しています',
  '💬 リスクは共有済みです',
  '💬 次の工程に進めましょう',
  '💬 顧客確認は木曜が良さそうです',
];

// 仕事のリレー演出: 営業→秘書→CEO→制作 と依頼が流れていく
const RELAY_CHAINS: { from: string; to: string; label: string; log: string }[][] = [
  [
    { from: 'list', to: 'email_sales', label: 'リスト28社を引き渡し', log: 'リスト作成AIがメール営業AIへ新規リスト28社を引き渡しました。' },
    { from: 'email_sales', to: 'secretary', label: '商談日程の調整を依頼', log: 'メール営業AIが秘書AIへ商談日程の調整を依頼しました。' },
    { from: 'secretary', to: 'ceo', label: '商談予定を報告', log: '秘書AIがCEO AIへ来週の商談予定を報告しました。' },
    { from: 'ceo', to: 'director', label: '制作準備を指示', log: 'CEO AIがディレクターAIへ受注見込み案件の制作準備を指示しました。' },
  ],
  [
    { from: 'reception', to: 'deal_mgr', label: '問い合わせを引き継ぎ', log: '受付AIが商談管理AIへ新規問い合わせを引き継ぎました。' },
    { from: 'deal_mgr', to: 'ceo', label: '商談化を報告', log: '商談管理AIがCEO AIへ商談化1件を報告しました。' },
    { from: 'ceo', to: 'writer', label: '提案資料の作成を指示', log: 'CEO AIがライターAIへ提案資料の作成を指示しました。' },
  ],
  [
    { from: 'director', to: 'designer', label: 'ワイヤー作成を依頼', log: 'ディレクターAIがデザイナーAIへワイヤーフレーム作成を依頼しました。' },
    { from: 'designer', to: 'coder', label: 'デザイン指示書を引き渡し', log: 'デザイナーAIがコーダーAIへデザイン指示書を引き渡しました。' },
    { from: 'coder', to: 'reviewer', label: 'レビューを依頼', log: 'コーダーAIがレビュアーAIへ実装レビューを依頼しました。' },
    { from: 'reviewer', to: 'infra', label: '公開前チェックを依頼', log: 'レビュアーAIがインフラAIへ公開前チェックを依頼しました。' },
  ],
];

function nowIso() {
  return new Date().toISOString();
}

function ensureToday(stats: DailyStat[]): DailyStat[] {
  const key = todayKey();
  if (stats.some((s) => s.date === key)) return stats;
  return [
    ...stats,
    {
      date: key,
      tasksCompleted: 0,
      leadsAdded: 0,
      formsSent: 0,
      emailsSent: 0,
      inquiries: 0,
      meetings: 0,
      orders: 0,
      costJpy: 0,
      revenueJpy: 0,
    },
  ].slice(-30);
}

// 社長指示からモック実行プランを生成する(将来はCEO AIのLLM呼び出しに置き換え)
function buildPlan(instruction: string): ExecutionPlan {
  const has = (...words: string[]) => words.some((w) => instruction.includes(w));

  if (has('リスト', '営業先', '企業を調査', '調査して')) {
    return {
      summary: `営業リスト作成プロジェクト: 「${instruction.slice(0, 40)}」`,
      purpose: '条件に合致する営業対象企業を収集し、アプローチ可能な状態に整備する',
      tasks: [
        { title: '対象条件の整理と検索クエリ設計', assigneeId: 'ceo', order: 1, parallel: false, needsApproval: false },
        { title: '企業リストの収集・整理', assigneeId: 'list', order: 2, parallel: false, needsApproval: false },
        { title: '重複・対象外企業の除外', assigneeId: 'list', order: 3, parallel: false, needsApproval: false },
        { title: 'アプローチ文案の下書き作成', assigneeId: 'form_sales', order: 4, parallel: true, needsApproval: true },
        { title: '営業メール下書き作成', assigneeId: 'email_sales', order: 4, parallel: true, needsApproval: true },
      ],
      approvalNotes: ['フォーム送信・メール送信は下書き作成後、承認センターでの承認が必要です'],
      completionCriteria: '有効企業リストが完成し、アプローチ文案が承認待ちになった時点',
      estimatedCostJpy: 1200,
    };
  }
  if (has('返信', '問い合わせ')) {
    return {
      summary: `問い合わせ対応: 「${instruction.slice(0, 40)}」`,
      purpose: '問い合わせへの一次返信案を作成し、商談化につなげる',
      tasks: [
        { title: '問い合わせ内容の分類・緊急度判定', assigneeId: 'reception', order: 1, parallel: false, needsApproval: false },
        { title: '一次返信案の作成', assigneeId: 'reception', order: 2, parallel: false, needsApproval: true },
        { title: '商談ステータスへの登録', assigneeId: 'deal_mgr', order: 3, parallel: false, needsApproval: false },
      ],
      approvalNotes: ['顧客への返信は送信前に承認が必要です'],
      completionCriteria: '返信案が承認され、商談管理に登録された時点',
      estimatedCostJpy: 150,
    };
  }
  if (has('案件', 'ホームページ', 'サイト', 'トップページ', 'LP')) {
    return {
      summary: `Web制作プロジェクト: 「${instruction.slice(0, 40)}」`,
      purpose: '新規Web制作案件を立ち上げ、公開まで進行する',
      tasks: [
        { title: 'ヒアリング内容の整理・要件定義', assigneeId: 'director', order: 1, parallel: false, needsApproval: false },
        { title: 'サイトマップ・ページ構成作成', assigneeId: 'director', order: 2, parallel: false, needsApproval: false },
        { title: '原稿作成', assigneeId: 'writer', order: 3, parallel: true, needsApproval: false },
        { title: 'ワイヤーフレーム作成', assigneeId: 'designer', order: 3, parallel: true, needsApproval: false },
        { title: 'デザイン案作成', assigneeId: 'designer', order: 4, parallel: false, needsApproval: false },
        { title: 'コーディング', assigneeId: 'coder', order: 5, parallel: false, needsApproval: false },
        { title: '品質レビュー', assigneeId: 'reviewer', order: 6, parallel: false, needsApproval: false },
        { title: '公開準備・公開承認申請', assigneeId: 'infra', order: 7, parallel: false, needsApproval: true },
      ],
      approvalNotes: ['公開作業は承認センターでの承認が必要です'],
      completionCriteria: 'レビュー完了後、公開承認が下りてサイトが公開された時点',
      estimatedCostJpy: 4800,
    };
  }
  if (has('まとめ', 'レポート', '週報', '日報', '月報', '稼働状況', '結果')) {
    return {
      summary: `レポート作成: 「${instruction.slice(0, 40)}」`,
      purpose: '実績データを集計し、経営判断に使えるレポートを作成する',
      tasks: [
        { title: '実績データの集計', assigneeId: 'accountant', order: 1, parallel: true, needsApproval: false },
        { title: '営業・商談データの集計', assigneeId: 'deal_mgr', order: 1, parallel: true, needsApproval: false },
        { title: 'レポートの作成・要約', assigneeId: 'ceo', order: 2, parallel: false, needsApproval: false },
      ],
      approvalNotes: [],
      completionCriteria: 'レポートがレポート画面に保存された時点',
      estimatedCostJpy: 300,
    };
  }
  return {
    summary: `新規指示: 「${instruction.slice(0, 40)}」`,
    purpose: '社長指示を分解し、適切なAI社員に割り振って実行する',
    tasks: [
      { title: '指示内容の分解・実行計画の詳細化', assigneeId: 'ceo', order: 1, parallel: false, needsApproval: false },
      { title: '関連情報の調査', assigneeId: 'list', order: 2, parallel: true, needsApproval: false },
      { title: '成果物の作成', assigneeId: 'writer', order: 2, parallel: true, needsApproval: false },
      { title: '品質確認', assigneeId: 'reviewer', order: 3, parallel: false, needsApproval: false },
    ],
    approvalNotes: ['外部送信を伴う場合は実行前に承認が必要です'],
    completionCriteria: '全タスクが完了し、成果物が確認できた時点',
    estimatedCostJpy: 800,
  };
}

// デモモード用のダミーデータ一式(削除せず保持。Demo Mode ONでいつでも表示できる)
const demoData = {
  agents: seedAgents,
  tasks: seedTasks,
  approvals: seedApprovals,
  leads: seedLeads,
  campaigns: seedCampaigns,
  inquiries: seedInquiries,
  deals: seedDeals,
  projects: seedProjects,
  snsPosts: seedSnsPosts,
  seoKeywords: seedSeoKeywords,
  logs: seedLogs,
  usage: seedUsage,
  dailyStats: seedDailyStats,
  reports: seedReports,
  errors: seedErrors,
  chat: seedChat,
  directChats: seedDirectChats,
  unread: seedUnread,
  proposals: seedProposals,
  agentTalks: seedTalks,
};

// 通常モード(初回利用者)の初期値: 実績ゼロ・全員待機中
const emptyData = {
  agents: emptyAgents,
  tasks: [] as Task[],
  approvals: [] as Approval[],
  leads: [] as Lead[],
  campaigns: [] as Campaign[],
  inquiries: [] as Inquiry[],
  deals: [] as Deal[],
  projects: [] as Project[],
  snsPosts: [] as SnsPost[],
  seoKeywords: [] as SeoKeyword[],
  logs: [] as ActivityLog[],
  usage: [] as AiUsageRecord[],
  dailyStats: [] as DailyStat[],
  reports: [] as Report[],
  errors: [] as ErrorRecord[],
  chat: [] as ChatMessage[],
  directChats: {} as Record<string, DirectChatMessage[]>,
  unread: {} as Record<string, number>,
  proposals: [] as CeoProposal[],
  agentTalks: [] as AgentTalk[],
};

const initialData = {
  settings: { ...seedSettings, demoMode: false },
  ...emptyData,
  integrations: seedIntegrations,
};


/** 現在のチャットをセッション履歴へアーカイブ(空なら何もしない・最大20件) */
function archiveChat(chat: ChatMessage[], sessions: ChatSession[]): ChatSession[] {
  if (chat.length === 0) return sessions;
  const firstUser = chat.find((m) => m.role === 'ceo_user');
  const raw = (firstUser?.content ?? chat[0].content).replace(/\s+/g, ' ').trim();
  const title = raw.slice(0, 24) + (raw.length > 24 ? '…' : '');
  return [
    { id: uid('sess'), title: title || '会話', messages: chat, createdAt: chat[0].timestamp, archivedAt: nowIso() },
    ...sessions,
  ].slice(0, 20);
}

export const useOffice = create<OfficeState>()(
  persist(
    (set, get) => ({
      hydrated: false,
      ...initialData,
      chatSessions: [],
      officeEvents: [],
      announcements: [],
      tickCount: 0,
      relayQueue: [],
      lastChatAt: {},
      lastProposalTick: 0,
      alertCooldowns: {},
      lastTalkTopics: [],
      lastAssemblyKey: '',
      achievements: [],
      ceoAlerts: [],
      agentRuns: [],
      deliverables: [],
      onboardingDismissed: false,
      ceoProfile: { criteria: [], values: [], phrases: [], patterns: [], strengths: [], weaknesses: [], updatedAt: null },

      setHydrated: (v) => set({ hydrated: v }),

      dismissOnboarding: () => set({ onboardingDismissed: true }),

      // ユーザー分析: 会話から見えた特徴をマージ(重複除去・各カテゴリ最大8件)
      mergeCeoProfile: (insights) =>
        set((s) => {
          const merge = (cur: string[], add?: string[]) =>
            Array.from(new Set([...(cur ?? []), ...(add ?? [])])).slice(-8);
          const p = s.ceoProfile;
          return {
            ceoProfile: {
              criteria: merge(p.criteria, insights.criteria),
              values: merge(p.values, insights.values),
              phrases: merge(p.phrases, insights.phrases),
              patterns: merge(p.patterns, insights.patterns),
              strengths: merge(p.strengths, insights.strengths),
              weaknesses: merge(p.weaknesses, insights.weaknesses),
              updatedAt: nowIso(),
            },
          };
        }),

      // 新しい会話: 現在の会話を履歴へ保存してまっさらに(見やすさのためのリセット)
      startNewChatSession: () =>
        set((s) => ({ chatSessions: archiveChat(s.chat, s.chatSessions), chat: [] })),

      // 過去の会話へ切り替え(現在の会話は履歴へ保存)
      switchChatSession: (sessionId) =>
        set((s) => {
          const target = s.chatSessions.find((c) => c.id === sessionId);
          if (!target) return {};
          const rest = s.chatSessions.filter((c) => c.id !== sessionId);
          return { chat: target.messages, chatSessions: archiveChat(s.chat, rest) };
        }),

      // Demo Mode切り替え: ONでダミーデータ表示+自動デモ演出、OFFで初期値0の実運用モード
      // (どちらの場合も、あなたが作成した成果物・AI実行履歴・設定は保持される)
      setDemoMode: (on) =>
        set((s) => ({
          settings: { ...s.settings, demoMode: on },
          ...(on ? demoData : emptyData),
          chatSessions: archiveChat(s.chat, s.chatSessions), // 現在の会話は履歴へ退避
          officeEvents: [],
          announcements: [],
          tickCount: 0,
          relayQueue: [],
          lastChatAt: {},
          lastProposalTick: 0,
          alertCooldowns: {},
          lastTalkTopics: [],
          lastAssemblyKey: '',
          achievements: [],
          ceoAlerts: [],
          onboardingDismissed: on ? true : s.onboardingDismissed,
        })),

      // ---------- AI実働ラン ----------
      addAgentRun: (run, chatMessage) =>
        set((s) => ({
          agentRuns: [run, ...s.agentRuns].slice(0, 10),
          chat: [
            ...s.chat,
            { id: uid('chat'), role: 'ceo_ai' as const, content: chatMessage, runId: run.id, timestamp: nowIso() },
          ],
        })),

      updateAgentRun: (runId, patch) =>
        set((s) => ({
          agentRuns: s.agentRuns.map((r) => (r.id === runId ? { ...r, ...patch } : r)),
        })),

      updateRunTask: (runId, taskId, patch) =>
        set((s) => ({
          agentRuns: s.agentRuns.map((r) =>
            r.id === runId ? { ...r, tasks: r.tasks.map((t) => (t.id === taskId ? { ...t, ...patch } : t)) } : r,
          ),
        })),

      addDeliverable: (d) =>
        set((s) => ({
          deliverables: [d, ...s.deliverables].slice(0, 40),
          agentRuns: s.agentRuns.map((r) =>
            r.id === d.runId ? { ...r, deliverableIds: [...r.deliverableIds, d.id] } : r,
          ),
        })),

      updateDeliverable: (id, patch) =>
        set((s) => ({
          deliverables: s.deliverables.map((d) => (d.id === id ? { ...d, ...patch, updatedAt: nowIso() } : d)),
        })),

      // 新バージョンとして保存(AIによる自動上書きはせず、人間の編集も別バージョンで保持)
      saveDeliverableVersion: (id, markdown, editedBy, note) =>
        set((s) => ({
          deliverables: s.deliverables.map((d) => {
            if (d.id !== id) return d;
            const version = d.version + 1;
            return {
              ...d,
              version,
              markdown,
              status: editedBy === 'human' ? d.status : ('draft' as const),
              versions: [...d.versions, { version, markdown, editedBy, note, createdAt: nowIso() }].slice(-10),
              updatedAt: nowIso(),
            };
          }),
        })),

      // AI呼び出しごとの利用量を記録(実値/推定の区別はusage側のestimatedで管理)
      recordRunUsage: (agentId, usage, taskId) =>
        set((s) => ({
          usage: [
            {
              id: uid('usage'),
              provider: usage.provider,
              model: usage.model,
              inputTokens: usage.inputTokens,
              outputTokens: usage.outputTokens,
              cachedTokens: 0,
              usdRateInput: 0,
              usdRateOutput: 0,
              costUsd: usage.costUSD,
              executedAt: nowIso(),
              agentId,
              taskId,
              projectId: null,
            },
            ...s.usage,
          ].slice(0, 300),
          agents: s.agents.map((a) =>
            a.id === agentId
              ? {
                  ...a,
                  inputTokens: a.inputTokens + usage.inputTokens,
                  outputTokens: a.outputTokens + usage.outputTokens,
                  costUsd: a.costUsd + usage.costUSD,
                  todayCount: a.todayCount + 1,
                  monthCount: a.monthCount + 1,
                }
              : a,
          ),
        })),

      // 実行中AIのオフィス表示(移動・吹き出し・進捗)
      setAgentRunActivity: (agentId, note, zone, progress) =>
        set((s) => ({
          agents: s.agents.map((a) =>
            a.id === agentId
              ? {
                  ...a,
                  status: (zone === 'desk' && note === '' ? 'idle' : 'working') as AgentStatus,
                  zone,
                  statusNote: note || '次の指示を待っています',
                  progress: progress ?? a.progress,
                }
              : a,
          ),
        })),

      // ---------- CEO呼びかけへの対応(押されるまで実行しない) ----------
      decideAlert: (alertId, decision) => {
        const s = get();
        const alert = s.ceoAlerts.find((a) => a.id === alertId);
        if (!alert || (alert.status !== 'new' && alert.status !== 'later')) return;
        if (decision === 'accepted') {
          const newTasks: Task[] = alert.actions.map((item, i) => ({
            id: uid('task'),
            title: item.title,
            description: `CEO呼びかけ「${alert.conclusion}」より`,
            assigneeId: item.assigneeId,
            requesterId: 'ceo',
            projectId: null,
            customerId: null,
            priority: 'high',
            status: i === 0 ? 'running' : 'queued',
            progress: 0,
            plannedStart: null,
            deadline: null,
            startedAt: i === 0 ? nowIso() : null,
            completedAt: null,
            needsApproval: false,
            approver: null,
            dependsOn: [],
            input: alert.recommendation,
            output: null,
            model: 'claude-sonnet-5',
            inputTokens: 0,
            outputTokens: 0,
            costUsd: 0,
            errorMessage: null,
            createdAt: nowIso(),
          }));
          set({
            ceoAlerts: s.ceoAlerts.map((a) => (a.id === alertId ? { ...a, status: 'accepted' as const, decidedAt: nowIso() } : a)),
            tasks: [...newTasks, ...s.tasks],
            officeEvents: [
              ...alert.actions.map((item) => ({
                id: uid('evt'),
                kind: 'plan' as const,
                fromAgentId: 'ceo',
                toAgentId: item.assigneeId,
                label: '承認済み・実行を指示',
                createdAt: nowIso(),
              })),
              ...s.officeEvents,
            ].slice(0, 10),
            logs: [
              { id: uid('log'), timestamp: nowIso(), agentId: 'ceo', message: `社長の承認により対応を開始します: ${alert.recommendation}`, taskId: newTasks[0]?.id ?? null, projectId: null, status: 'success' as const },
              ...s.logs,
            ].slice(0, 400),
          });
          return;
        }
        set({
          ceoAlerts: s.ceoAlerts.map((a) =>
            a.id === alertId ? { ...a, status: decision === 'later' ? ('later' as const) : ('dismissed' as const), decidedAt: nowIso() } : a,
          ),
          // 却下・後で確認は同種の再通知を長めに抑制する
          alertCooldowns: { ...s.alertCooldowns, [alert.kind]: s.tickCount + (decision === 'dismissed' ? 200 : 100) },
        });
      },

      // ---------- 朝会・夕会の再生(手動再生はデモモードOFFでも可能) ----------
      playAssembly: (kind) => {
        const s = get();
        const assembly = generateAssembly(kind, s, buildCompanyContext(s));
        set({
          announcements: [
            { id: uid('ann'), message: assembly.announcement, tone: 'info' as const, createdAt: nowIso() },
            ...s.announcements,
          ].slice(0, 6),
          agentTalks: [...assembly.talks, ...s.agentTalks].slice(0, 20),
          logs: [
            { id: uid('log'), timestamp: nowIso(), agentId: 'ceo', message: kind === 'morning' ? '朝会を開催しました。本日の重点方針を共有しています。' : '夕会を開催しました。本日の成果と翌日の優先事項をまとめています。', taskId: null, projectId: null, status: 'info' as const },
            ...s.logs,
          ].slice(0, 400),
        });
      },

      // ---------- AI社員との個別会話 ----------
      openChat: (agentId) => {
        const s = get();
        const agent = s.agents.find((a) => a.id === agentId);
        if (!agent) return;
        const history = s.directChats[agentId] ?? [];
        // 初回は人格の挨拶+現在の状況で会話を開始する
        const withGreeting =
          history.length === 0
            ? [
                {
                  id: uid('dm'),
                  role: 'agent' as const,
                  content: `${agent.greeting ?? 'お疲れさまです。'}\n現在は「${agent.statusNote}」の状態です。ご質問やご依頼があればどうぞ。`,
                  timestamp: nowIso(),
                },
              ]
            : history;
        set({
          directChats: { ...s.directChats, [agentId]: withGreeting },
          unread: { ...s.unread, [agentId]: 0 }, // 開いた時点で既読
        });
      },

      sendDirectMessage: (agentId, content) => {
        const s = get();
        const agent = s.agents.find((a) => a.id === agentId);
        if (!agent || !content.trim()) return;
        const userMsg: DirectChatMessage = { id: uid('dm'), role: 'user', content: content.trim(), timestamp: nowIso() };
        // 会話生成はProvider経由(将来Claude APIなどへ差し替え可能)
        const reply = conversationProvider.generateAgentReply(
          content.trim(),
          buildAgentContext(s, agentId),
          buildCompanyContext(s),
        );
        const agentMsg: DirectChatMessage = {
          id: uid('dm'),
          role: 'agent',
          content: reply.content,
          actions: reply.actions,
          timestamp: nowIso(),
        };
        const history = [...(s.directChats[agentId] ?? []), userMsg, agentMsg].slice(-100);
        set({
          directChats: { ...s.directChats, [agentId]: history },
          unread: { ...s.unread, [agentId]: 0 },
          lastChatAt: { ...s.lastChatAt, [agentId]: nowIso() },
          agents: s.agents.map((a) =>
            a.id === agentId && a.status !== 'paused' && a.status !== 'error'
              ? { ...a, statusNote: '社長と会話中', currentMood: moodOf(a) }
              : a,
          ),
        });
      },

      // 会話内アクションの実行(ユーザーがボタンを押した時のみ)
      executeChatAction: (agentId, action) => {
        const s = get();
        const agent = s.agents.find((a) => a.id === agentId);
        if (!agent) return;
        const pushAgentMsg = (content: string) => {
          const msg: DirectChatMessage = { id: uid('dm'), role: 'agent', content, timestamp: nowIso() };
          return { ...s.directChats, [agentId]: [...(s.directChats[agentId] ?? []), msg].slice(-100) };
        };

        if (action.kind === 'create_task') {
          const title = (action.payload ?? '社長からの依頼').slice(0, 60);
          const task: Task = {
            id: uid('task'),
            title,
            description: `会話からの依頼: ${action.payload ?? ''}`,
            assigneeId: agentId,
            requesterId: null,
            projectId: null,
            customerId: null,
            priority: 'high',
            status: 'running',
            progress: 0,
            plannedStart: null,
            deadline: null,
            startedAt: nowIso(),
            completedAt: null,
            needsApproval: false,
            approver: null,
            dependsOn: [],
            input: action.payload ?? null,
            output: null,
            model: agent.model,
            inputTokens: 0,
            outputTokens: 0,
            costUsd: 0,
            errorMessage: null,
            createdAt: nowIso(),
          };
          set({
            tasks: [task, ...s.tasks],
            directChats: pushAgentMsg(`承知しました。「${title}」をタスクとして登録し、着手します。進捗はオフィスとタスク管理でご確認いただけます。`),
            agents: s.agents.map((a) =>
              a.id === agentId && a.status !== 'paused' ? { ...a, status: 'checking' as AgentStatus, statusNote: '依頼内容を確認中' } : a,
            ),
            logs: [
              { id: uid('log'), timestamp: nowIso(), agentId, message: `社長との会話から新しいタスク「${title}」を受領しました。`, taskId: task.id, projectId: null, status: 'info' as const },
              ...s.logs,
            ].slice(0, 400),
          });
          return;
        }

        if (action.kind === 'consult') {
          const targetId = action.payload ?? 'ceo';
          const target = s.agents.find((a) => a.id === targetId);
          set({
            directChats: pushAgentMsg(`${target?.name ?? targetId}へ確認を依頼しました。回答が届き次第、ご報告します。`),
            officeEvents: [
              { id: uid('evt'), kind: 'delegate' as const, fromAgentId: agentId, toAgentId: targetId, label: '確認を依頼', createdAt: nowIso() },
              ...s.officeEvents,
            ].slice(0, 10),
            agentTalks: [
              {
                id: uid('talk'),
                lines: [
                  { agentId, text: `${target?.name ?? targetId}さん、社長からのご相談の件、確認をお願いできますか?` },
                  { agentId: targetId, text: '確認しました。内容を見て今日中に回答します。' },
                ],
                taskId: agent.currentTaskId,
                projectId: null,
                timestamp: nowIso(),
              },
              ...s.agentTalks,
            ].slice(0, 20),
            logs: [
              { id: uid('log'), timestamp: nowIso(), agentId, message: `${target?.name ?? targetId}へ確認を依頼しました。`, taskId: null, projectId: null, status: 'info' as const },
              ...s.logs,
            ].slice(0, 400),
          });
          return;
        }

        if (action.kind === 'call_meeting') {
          const attendees = (action.payload ?? 'director,designer').split(',');
          set({
            directChats: pushAgentMsg('会議を招集しました。対象メンバーが会議室へ移動します。'),
            agents: s.agents.map((a) =>
              [agentId, ...attendees].includes(a.id) && a.status !== 'paused' && a.status !== 'error'
                ? { ...a, status: 'meeting' as AgentStatus, zone: 'meeting' as OfficeZone, statusNote: '💬 社長招集の会議に参加中' }
                : a,
            ),
            logs: [
              { id: uid('log'), timestamp: nowIso(), agentId, message: '社長の承認により会議を招集しました。', taskId: null, projectId: null, status: 'info' as const },
              ...s.logs,
            ].slice(0, 400),
          });
          return;
        }

        if (action.kind === 'pause_agent') {
          get().pauseAgent(agentId);
          set({ directChats: pushAgentMsg('承知しました。作業を一時停止し、休憩スペースへ移動します。再開のご指示をお待ちします。') });
          return;
        }
        if (action.kind === 'resume_agent') {
          get().resumeAgent(agentId);
          set({ directChats: pushAgentMsg('作業を再開します。次のタスクから順に進めます。') });
          return;
        }

        if (action.kind === 'report') {
          const ctx = buildAgentContext(s, agentId);
          const lines = [
            `【詳細レポート】${agent.name}(${nowIso().slice(0, 10)})`,
            `状態: ${agent.statusNote} / 居場所: ${ctx.zoneLabel}`,
            `本日${agent.todayCount}件 / 今月${agent.monthCount}件を処理`,
            ctx.currentTask ? `進行中: 「${ctx.currentTask.title}」(${ctx.currentTask.progress}%)` : '進行中のタスクなし',
            `待機タスク: ${ctx.queuedTasks.length}件`,
            `担当案件: ${ctx.assignedProjects.map((p) => `${p.name}(${p.progress}%)`).join(' / ') || 'なし'}`,
            `集中度${agent.focus ?? 75}% / 疲労度${agent.fatigue ?? 20}% / 推定利用料 ${Math.round(ctx.ownCostJpy).toLocaleString()}円`,
          ];
          set({ directChats: pushAgentMsg(lines.join('\n')) });
          return;
        }
        // kind === 'link' はUI側で遷移のみ(ストア変更なし)
      },

      // ---------- CEO提案の採用・修正・却下 ----------
      decideProposal: (proposalId, decision) => {
        const s = get();
        const proposal = s.proposals.find((p) => p.id === proposalId);
        if (!proposal || !['new', 'reviewing', 'revision'].includes(proposal.status)) return;

        if (decision === 'adopted') {
          // 採用: 提案内容をタスクへ変換し、担当AIへ割り振る
          const newTasks: Task[] = proposal.actions.map((item, i) => ({
            id: uid('task'),
            title: item.title,
            description: `CEO提案「${proposal.title}」より`,
            assigneeId: item.assigneeId,
            requesterId: 'ceo',
            projectId: null,
            customerId: null,
            priority: 'high',
            status: i === 0 ? 'running' : 'queued',
            progress: 0,
            plannedStart: null,
            deadline: null,
            startedAt: i === 0 ? nowIso() : null,
            completedAt: null,
            needsApproval: false,
            approver: null,
            dependsOn: [],
            input: proposal.summary,
            output: null,
            model: 'claude-sonnet-5',
            inputTokens: 0,
            outputTokens: 0,
            costUsd: 0,
            errorMessage: null,
            createdAt: nowIso(),
          }));
          const events: OfficeEvent[] = proposal.targetAgentIds.map((toAgentId) => ({
            id: uid('evt'),
            kind: 'plan' as const,
            fromAgentId: 'ceo',
            toAgentId,
            label: '提案採用・実行開始',
            createdAt: nowIso(),
          }));
          set({
            proposals: s.proposals.map((p) =>
              p.id === proposalId ? { ...p, status: 'executing' as const, decidedAt: nowIso(), taskIds: newTasks.map((t) => t.id) } : p,
            ),
            tasks: [...newTasks, ...s.tasks],
            officeEvents: [...events, ...s.officeEvents].slice(0, 10),
            announcements: [
              { id: uid('ann'), message: `社長が提案「${proposal.title}」を採用しました。実行を開始します`, tone: 'success' as const, createdAt: nowIso() },
              ...s.announcements,
            ].slice(0, 6),
            agents: s.agents.map((a) =>
              proposal.targetAgentIds.includes(a.id) && a.status !== 'paused' && a.status !== 'error'
                ? { ...a, status: 'checking' as AgentStatus, statusNote: '提案タスクを確認中' }
                : a,
            ),
            logs: [
              { id: uid('log'), timestamp: nowIso(), agentId: 'ceo', message: `提案「${proposal.title}」が採用されました。タスク${newTasks.length}件を作成し、実行を開始します。`, taskId: newTasks[0]?.id ?? null, projectId: null, status: 'success' as const },
              ...s.logs,
            ].slice(0, 400),
          });
          return;
        }

        const status = decision === 'revision' ? ('revision' as const) : ('rejected' as const);
        set({
          proposals: s.proposals.map((p) => (p.id === proposalId ? { ...p, status, decidedAt: nowIso() } : p)),
          logs: [
            {
              id: uid('log'),
              timestamp: nowIso(),
              agentId: 'ceo',
              message:
                decision === 'revision'
                  ? `提案「${proposal.title}」に修正依頼を受けました。前提を見直して再提案します。`
                  : `提案「${proposal.title}」は見送りとなりました。判断を記録します。`,
              taskId: null,
              projectId: null,
              status: 'warning' as const,
            },
            ...s.logs,
          ].slice(0, 400),
        });
      },

      // ---------- デモエンジン ----------
      // 小さな変化は毎tick(約3秒)、大きなイベントは6tickごと(約18秒)に発生させる
      tick: () => {
        const s = get();
        if (!s.settings.demoMode) return;

        const usdJpy = s.settings.usdJpyRate;
        const tickCount = s.tickCount + 1;
        let dailyStats = ensureToday(s.dailyStats);
        const todayIdx = dailyStats.findIndex((d) => d.date === todayKey());
        const today = { ...dailyStats[todayIdx] };
        const newLogs: ActivityLog[] = [];
        const newEvents: OfficeEvent[] = [];
        let announcements = s.announcements;
        const completedAssignees = new Set<string>();
        let tasks = [...s.tasks];
        let approvals = s.approvals;

        // 集中度・疲労度のゆらぎ(0-100にクランプしつつ目標値へ緩やかに寄せる)
        const drift = (v: number | undefined, target: number, spread: number) => {
          const cur = v ?? target;
          return Math.round(Math.max(5, Math.min(100, cur + (target - cur) * 0.15 + (Math.random() - 0.5) * spread)));
        };

        // 仕事のリレー演出: キューに積まれた依頼を2tickごとに1本ずつ流す
        let relayQueue = s.relayQueue;
        const newTalks: AgentTalk[] = [];
        if (relayQueue.length > 0 && tickCount % 2 === 0) {
          const [step, ...rest] = relayQueue;
          relayQueue = rest;
          newEvents.push({
            id: uid('evt'),
            kind: 'delegate',
            fromAgentId: step.from,
            toAgentId: step.to,
            label: step.label,
            createdAt: nowIso(),
          });
          newLogs.push({
            id: uid('log'),
            timestamp: nowIso(),
            agentId: step.from,
            message: step.log,
            taskId: null,
            projectId: null,
            status: 'info',
          });
          // 社内会話としても記録(重要イベントのみ)
          newTalks.push({
            id: uid('talk'),
            lines: [
              { agentId: step.from, text: `${step.label}します。確認をお願いします。` },
              { agentId: step.to, text: pickRandom(['確認しました。すぐ対応します。', '受け取りました。優先で進めます。', '承知しました。今日中に対応します。']) },
            ],
            taskId: null,
            projectId: null,
            timestamp: nowIso(),
          });
        }

        // 1) 実行中タスクの進捗を進める
        tasks = tasks.map((task) => {
          if (task.status !== 'running') return task;
          if (Math.random() < 0.25) return task; // たまに停滞
          const inc = 2 + Math.floor(Math.random() * 8);
          const progress = Math.min(100, task.progress + inc);
          const addIn = 400 + Math.floor(Math.random() * 2200);
          const addOut = 150 + Math.floor(Math.random() * 900);
          const addCost = (addIn / 1e6) * 3 + (addOut / 1e6) * 15;
          if (progress >= 100) {
            const agent = s.agents.find((a) => a.id === task.assigneeId);
            if (task.needsApproval) {
              // 承認が必要なタスクは承認待ちへ
              const approval: Approval = {
                id: uid('apr'),
                type: 'bulk_task',
                title: `${task.title}(実行承認)`,
                requesterId: task.assigneeId,
                target: task.title,
                body: task.description,
                count: 1,
                estimatedCostJpy: Math.round(task.costUsd * usdJpy),
                risks: ['実行内容を確認してください'],
                hasDuplicates: false,
                hasOptedOutTargets: false,
                status: 'pending',
                taskId: task.id,
                createdAt: nowIso(),
                decidedAt: null,
              };
              approvals = [approval, ...approvals];
              newLogs.push({
                id: uid('log'),
                timestamp: nowIso(),
                agentId: task.assigneeId,
                message: `「${task.title}」の準備が完了しました。承認待ちです。`,
                taskId: task.id,
                projectId: task.projectId,
                status: 'warning',
              });
              return {
                ...task,
                progress: 100,
                status: 'waiting_approval' as TaskStatus,
                inputTokens: task.inputTokens + addIn,
                outputTokens: task.outputTokens + addOut,
                costUsd: task.costUsd + addCost,
              };
            }
            today.tasksCompleted += 1;
            completedAssignees.add(task.assigneeId);
            newLogs.push({
              id: uid('log'),
              timestamp: nowIso(),
              agentId: task.assigneeId,
              message: `「${task.title}」が完了しました。`,
              taskId: task.id,
              projectId: task.projectId,
              status: 'success',
            });
            if (task.requesterId && task.requesterId !== task.assigneeId) {
              newEvents.push({
                id: uid('evt'),
                kind: 'complete',
                fromAgentId: task.assigneeId,
                toAgentId: task.requesterId,
                label: '成果物を納品',
                createdAt: nowIso(),
              });
            }
            if (agent?.id === 'list') today.leadsAdded += 3;
            return {
              ...task,
              progress: 100,
              status: 'done' as TaskStatus,
              completedAt: nowIso(),
              output: '完了成果物あり(活動ログ参照)',
              inputTokens: task.inputTokens + addIn,
              outputTokens: task.outputTokens + addOut,
              costUsd: task.costUsd + addCost,
            };
          }
          return {
            ...task,
            progress,
            inputTokens: task.inputTokens + addIn,
            outputTokens: task.outputTokens + addOut,
            costUsd: task.costUsd + addCost,
          };
        });

        // 2) 待機中エージェントにキュー済みタスクを割り当てる
        const runningIds = new Set(tasks.filter((x) => x.status === 'running').map((x) => x.assigneeId));
        const queued = tasks.filter(
          (x) =>
            x.status === 'queued' &&
            !runningIds.has(x.assigneeId) &&
            x.dependsOn.every((depId) => tasks.find((d) => d.id === depId)?.status === 'done'),
        );
        if (queued.length > 0 && Math.random() < 0.5) {
          const next = queued[0];
          tasks = tasks.map((x) =>
            x.id === next.id ? { ...x, status: 'running' as TaskStatus, startedAt: nowIso() } : x,
          );
          runningIds.add(next.assigneeId);
          newLogs.push({
            id: uid('log'),
            timestamp: nowIso(),
            agentId: next.assigneeId,
            message: `「${next.title}」を開始しました。`,
            taskId: next.id,
            projectId: next.projectId,
            status: 'info',
          });
        }

        // 3) エージェント状態・居場所(zone)を同期・演出
        let agents: Agent[] = s.agents.map((agent) => {
          // 停止中: 休憩スペースでグレーアウト(疲労が回復していく)
          if (agent.status === 'paused')
            return {
              ...agent,
              zone: 'break' as OfficeZone,
              fatigue: drift(agent.fatigue, 5, 2),
              focus: drift(agent.focus, 60, 3),
            };
          // エラー中: サーバールームで復旧作業。確率で自然復旧する
          if (agent.status === 'error') {
            if (Math.random() < 0.18) {
              newLogs.push({
                id: uid('log'),
                timestamp: nowIso(),
                agentId: agent.id,
                message: '復旧しました。通常業務に戻ります。',
                taskId: null,
                projectId: null,
                status: 'success',
              });
              return { ...agent, status: 'idle' as AgentStatus, zone: 'desk' as OfficeZone, statusNote: '復旧完了。次のタスク待ち', progress: 0 };
            }
            return { ...agent, zone: 'server' as OfficeZone };
          }

          const running = tasks.find((x) => x.assigneeId === agent.id && x.status === 'running');
          const waiting = tasks.find((x) => x.assigneeId === agent.id && x.status === 'waiting_approval');
          const addIn = running ? 300 + Math.floor(Math.random() * 1500) : 0;
          const addOut = running ? 100 + Math.floor(Math.random() * 600) : 0;
          const addCost = (addIn / 1e6) * 3 + (addOut / 1e6) * 15;

          if (running) {
            const notes = WORK_NOTES[agent.id] ?? ['作業中'];
            const statusPool: AgentStatus[] = ['working', 'working', 'working', 'checking', 'delegating'];
            const nextStatus = pickRandom(statusPool);
            // 「他のAIへ依頼中」になった瞬間、連携イベント(信号)を飛ばす
            if (nextStatus === 'delegating' && agent.status !== 'delegating') {
              const targets = DELEGATE_MAP[agent.id];
              if (targets && targets.length > 0 && Math.random() < 0.7) {
                const t = pickRandom(targets);
                newEvents.push({
                  id: uid('evt'),
                  kind: 'delegate',
                  fromAgentId: agent.id,
                  toAgentId: t.to,
                  label: t.label,
                  createdAt: nowIso(),
                });
              }
            }
            const note =
              Math.random() < 0.35 ? pickRandom(notes) : `${running.title.slice(0, 18)} ${running.progress}%`;
            return {
              ...agent,
              status: nextStatus,
              zone: 'desk' as OfficeZone,
              statusNote: note,
              currentTaskId: running.id,
              progress: running.progress,
              todayCount: agent.todayCount + (Math.random() < 0.3 ? 1 : 0),
              monthCount: agent.monthCount + (Math.random() < 0.3 ? 1 : 0),
              inputTokens: agent.inputTokens + addIn,
              outputTokens: agent.outputTokens + addOut,
              costUsd: agent.costUsd + addCost,
              doneFlashUntil: undefined,
              focus: drift(agent.focus, 92, 8),
              fatigue: drift(agent.fatigue, 70, 6),
            };
          }

          // 承認待ち: 承認待ちスペースへ移動
          if (waiting) {
            return {
              ...agent,
              status: 'waiting_approval' as AgentStatus,
              zone: 'approval' as OfficeZone,
              statusNote: '社長の承認を待っています',
              currentTaskId: waiting.id,
              progress: 100,
            };
          }

          // 直前にタスクが完了: 完了フラッシュ演出
          if (completedAssignees.has(agent.id)) {
            return {
              ...agent,
              status: 'done' as AgentStatus,
              zone: 'desk' as OfficeZone,
              statusNote: 'タスク完了!',
              currentTaskId: null,
              progress: 100,
              doneFlashUntil: new Date(Date.now() + 5000).toISOString(),
            };
          }
          // 完了フラッシュの終了 → 待機へ
          if (agent.status === 'done') {
            if (!agent.doneFlashUntil || agent.doneFlashUntil < nowIso()) {
              return { ...agent, status: 'idle' as AgentStatus, zone: 'desk' as OfficeZone, statusNote: '次の指示を待っています', progress: 0, doneFlashUntil: undefined };
            }
            return agent;
          }

          // 会議演出: 会話の吹き出しを交わし、しばらくして席へ戻る
          if (agent.status === 'meeting') {
            if (Math.random() < 0.3) {
              return { ...agent, status: 'idle' as AgentStatus, zone: 'desk' as OfficeZone, statusNote: '次の指示を待っています', currentTaskId: null, progress: 0 };
            }
            return {
              ...agent,
              statusNote: Math.random() < 0.45 ? pickRandom(MEETING_TALK) : agent.statusNote,
              focus: drift(agent.focus, 75, 5),
            };
          }

          // 休憩演出: 疲労が溜まった待機中の社員はときどき休憩スペースへ行き、回復して戻る
          if (agent.zone === 'break' && agent.status === 'idle') {
            if (Math.random() < 0.3 && (agent.fatigue ?? 0) < 25) {
              return { ...agent, zone: 'desk' as OfficeZone, statusNote: '休憩から戻りました', fatigue: drift(agent.fatigue, 10, 3), focus: drift(agent.focus, 75, 4) };
            }
            return { ...agent, statusNote: '☕ 休憩中', fatigue: drift(agent.fatigue, 5, 3), focus: drift(agent.focus, 70, 3) };
          }
          if ((agent.fatigue ?? 0) >= 45 && Math.random() < 0.06) {
            return {
              ...agent,
              status: 'idle' as AgentStatus,
              zone: 'break' as OfficeZone,
              statusNote: '☕ 休憩中',
              currentTaskId: null,
              progress: 0,
            };
          }
          return {
            ...agent,
            status: 'idle' as AgentStatus,
            zone: 'desk' as OfficeZone,
            statusNote: '次の指示を待っています',
            currentTaskId: null,
            progress: 0,
            focus: drift(agent.focus, 68, 5),
            fatigue: drift(agent.fatigue, 15, 4),
          };
        });

        // 4) ときどき活動ログを追加
        if (Math.random() < 0.65) {
          const [agentId, message, status] = pickRandom(TICK_LOGS);
          newLogs.push({
            id: uid('log'),
            timestamp: nowIso(),
            agentId,
            message,
            taskId: null,
            projectId: null,
            status,
          });
          if (agentId === 'email_sales' && Math.random() < 0.4) today.emailsSent += 1;
          if (agentId === 'list') today.leadsAdded += 1;
        }

        // 5) 利用料金レコードを追加(たまに)
        let usage = s.usage;
        if (Math.random() < 0.4) {
          const workingAgents = agents.filter((a) => a.status === 'working');
          if (workingAgents.length > 0) {
            const agent = pickRandom(workingAgents);
            const inputTokens = 2000 + Math.floor(Math.random() * 20000);
            const outputTokens = 800 + Math.floor(Math.random() * 8000);
            const costUsd = (inputTokens / 1e6) * 3 + (outputTokens / 1e6) * 15;
            usage = [
              {
                id: uid('usage'),
                provider: 'anthropic',
                model: agent.model,
                inputTokens,
                outputTokens,
                cachedTokens: Math.floor(inputTokens * 0.3),
                usdRateInput: 3,
                usdRateOutput: 15,
                costUsd,
                executedAt: nowIso(),
                agentId: agent.id,
                taskId: agent.currentTaskId,
                projectId: null,
              },
              ...usage,
            ].slice(0, 300);
            today.costJpy += Math.round(costUsd * usdJpy);
          }
        }

        // 初回tick: 稼働開始アナウンス(初期表示が静止画に見えないようにする)
        if (tickCount === 1 && announcements.length === 0) {
          announcements = [
            {
              id: uid('ann'),
              message: '全AI社員が稼働を開始しました。本日もよろしくお願いします',
              tone: 'info' as const,
              createdAt: nowIso(),
            },
          ];
        }

        // 6) 大イベント(約18秒ごとに1種類だけ発生させ、画面が騒がしくなりすぎないようにする)
        if (tickCount % 6 === 0) {
          const bigEventKind = ['announce', 'relay', 'meeting', 'announce', 'relay', 'error'][
            (tickCount / 6 - 1) % 6
          ];

          if (bigEventKind === 'relay' && relayQueue.length === 0) {
            // 営業→秘書→CEO→制作 のように仕事が流れるリレーを開始
            relayQueue = [...RELAY_CHAINS[Math.floor(tickCount / 6) % RELAY_CHAINS.length]];
          }

          if (bigEventKind === 'announce') {
            const counts = {
              pending: approvals.filter((a) => a.status === 'pending').length,
              running: tasks.filter((t) => t.status === 'running').length,
              errors: agents.filter((a) => a.status === 'error').length + s.errors.filter((e) => !e.resolved).length,
            };
            const template = ANNOUNCE_POOL[Math.floor(tickCount / 6) % ANNOUNCE_POOL.length](counts);
            announcements = [
              { id: uid('ann'), message: template.message, tone: template.tone, createdAt: nowIso() },
              ...announcements,
            ].slice(0, 6);
            newLogs.push({
              id: uid('log'),
              timestamp: nowIso(),
              agentId: 'ceo',
              message: template.message,
              taskId: null,
              projectId: null,
              status: template.tone === 'warning' ? 'warning' : 'info',
            });
          }

          if (bigEventKind === 'meeting') {
            // 待機中の2〜3名が会議室 or プロジェクトテーブルに集まる
            const candidates = agents.filter((a) => a.status === 'idle');
            if (candidates.length >= 2) {
              const zone: OfficeZone = tickCount % 12 === 0 ? 'project' : 'meeting';
              const attendees = candidates.slice(0, 2 + (tickCount % 2)).map((a) => a.id);
              agents = agents.map((a) =>
                attendees.includes(a.id)
                  ? {
                      ...a,
                      status: 'meeting' as AgentStatus,
                      zone,
                      statusNote: zone === 'project' ? '案件キックオフに参加中' : '定例ミーティングに参加中',
                    }
                  : a,
              );
              newLogs.push({
                id: uid('log'),
                timestamp: nowIso(),
                agentId: attendees[0],
                message: zone === 'project' ? 'プロジェクトテーブルでキックオフを開始しました。' : '会議室で定例ミーティングを開始しました。',
                taskId: null,
                projectId: null,
                status: 'info',
              });
            }
          }

          if (bigEventKind === 'error') {
            // 待機中の1名にエラーを発生させる(次以降のtickで自然復旧する)
            const candidates = agents.filter((a) => a.status === 'idle' && a.id !== 'ceo');
            if (candidates.length > 0 && Math.random() < 0.7) {
              const victim = pickRandom(candidates);
              agents = agents.map((a) =>
                a.id === victim.id
                  ? { ...a, status: 'error' as AgentStatus, zone: 'server' as OfficeZone, statusNote: '処理に失敗しました。復旧作業中' }
                  : a,
              );
              newEvents.push({
                id: uid('evt'),
                kind: 'error',
                fromAgentId: victim.id,
                toAgentId: 'ops_admin',
                label: 'エラーを報告',
                createdAt: nowIso(),
              });
              newLogs.push({
                id: uid('log'),
                timestamp: nowIso(),
                agentId: victim.id,
                message: '処理に失敗しました。サーバールームで復旧作業を開始します。',
                taskId: null,
                projectId: null,
                status: 'error',
              });
            }
          }
        }

        // 7) 「社長と会話中」の吹き出しを一定時間維持 + 気分の更新
        const chatCutoff = Date.now() - 12000;
        agents = agents.map((a) => {
          const t = s.lastChatAt[a.id];
          const talking = t && new Date(t).getTime() > chatCutoff;
          return {
            ...a,
            currentMood: moodOf(a),
            statusNote: talking ? '💬 社長と会話中' : a.statusNote,
          };
        });

        // 8) AI社員からの自発報告(タスク完了時に確率で。未読が溜まりすぎないよう抑制)
        let directChats = s.directChats;
        let unread = s.unread;
        const reporter = Array.from(completedAssignees).find((id) => (s.unread[id] ?? 0) < 2);
        if (reporter && Math.random() < 0.5) {
          const agent = agents.find((a) => a.id === reporter);
          const doneTask = tasks.find((t) => t.assigneeId === reporter && t.status === 'done' && t.completedAt);
          if (agent && doneTask) {
            const msg: DirectChatMessage = {
              id: uid('dm'),
              role: 'agent',
              content: `ご報告です。「${doneTask.title}」が完了しました。本日はこれで${agent.todayCount}件目です。続けて次のタスクへ進みます。`,
              timestamp: nowIso(),
            };
            directChats = { ...directChats, [reporter]: [...(directChats[reporter] ?? []), msg].slice(-100) };
            unread = { ...unread, [reporter]: (unread[reporter] ?? 0) + 1 };
          }
        }

        // 9) CEO AIの自発提案(約60秒周期で状況を分析。未処理の提案がある間は出さない)
        let proposals = s.proposals;
        let lastProposalTick = s.lastProposalTick;
        if (
          tickCount % 20 === 0 &&
          tickCount - lastProposalTick >= 20 &&
          !proposals.some((p) => p.status === 'new' || p.status === 'reviewing')
        ) {
          const draft = conversationProvider.generateCEOProposal(buildCompanyContext({ ...s, agents, tasks, approvals }), agents);
          if (draft) {
            lastProposalTick = tickCount;
            proposals = [draft, ...proposals].slice(0, 20);
            unread = { ...unread, ceo: (unread.ceo ?? 0) + 1 };
            const ceoMsg: DirectChatMessage = {
              id: uid('dm'),
              role: 'agent',
              content: `新しい経営提案があります。\n「${draft.title}」\n${draft.summary}\n詳細は提案センターでご確認ください。`,
              timestamp: nowIso(),
            };
            directChats = { ...directChats, ceo: [...(directChats.ceo ?? []), ceoMsg].slice(-100) };
            announcements = [
              { id: uid('ann'), message: `新しい経営提案「${draft.title}」を作成しました。提案センターをご確認ください`, tone: 'info' as const, createdAt: nowIso() },
              ...announcements,
            ].slice(0, 6);
            newLogs.push({
              id: uid('log'),
              timestamp: nowIso(),
              agentId: 'ceo',
              message: `経営提案「${draft.title}」を作成しました。`,
              taskId: null,
              projectId: null,
              status: 'info',
            });
          }
        }

        // 10) AI社員同士の自発会話(約15秒に1回。直近と同じ話題は避ける)
        let lastTalkTopics = s.lastTalkTopics;
        if (tickCount % 5 === 0) {
          const talk = generateInterAgentConversation({ ...s, agents, tasks, approvals }, lastTalkTopics);
          if (talk) {
            newTalks.push(talk);
            lastTalkTopics = [talk.topic ?? '', ...lastTalkTopics].slice(0, 3);
            newLogs.push({
              id: uid('log'),
              timestamp: nowIso(),
              agentId: talk.lines[0].agentId,
              message: talk.lines[0].text,
              taskId: talk.taskId,
              projectId: talk.projectId,
              status: 'info',
            });
          }
        }

        // 11) 成果イベント(自発報告。約24秒に1回、対象AIを変えながら)
        let achievements = s.achievements;
        if (tickCount % 8 === 0) {
          const candidates = agents.filter((a) => !['paused', 'error'].includes(a.status));
          const reporterAgent = candidates[(tickCount / 8) % candidates.length];
          const achievement = reporterAgent ? generateAchievementReport(reporterAgent, { ...s, agents, tasks, approvals }) : null;
          if (achievement) {
            achievements = [achievement, ...achievements].slice(0, 50);
            newLogs.push({
              id: uid('log'),
              timestamp: nowIso(),
              agentId: achievement.agentId,
              message: `【成果】${achievement.title} — ${achievement.detail}`,
              taskId: null,
              projectId: null,
              status: 'success',
            });
            // 控えめな社内リアクション(最大2件)
            if (Math.random() < 0.6) {
              const reactors = ['ceo', achievement.agentId === 'deal_mgr' ? 'secretary' : 'deal_mgr'].filter((r) => r !== achievement.agentId).slice(0, 2);
              newTalks.push({
                id: uid('talk'),
                lines: [
                  { agentId: achievement.agentId, text: `${achievement.title}です。${achievement.detail}` },
                  ...reactors.slice(0, 2).map((r) => ({ agentId: r, text: generateReaction(r), isReaction: true })),
                ],
                taskId: null,
                projectId: null,
                timestamp: nowIso(),
                topic: 'achievement',
              });
            }
            // 本人からの直接報告(未読は1社員2件まで)
            if ((unread[achievement.agentId] ?? 0) < 2 && Math.random() < 0.4) {
              const msg: DirectChatMessage = {
                id: uid('dm'),
                role: 'agent',
                content: `ご報告です。${achievement.title}しました。${achievement.detail}`,
                timestamp: nowIso(),
              };
              directChats = { ...directChats, [achievement.agentId]: [...(directChats[achievement.agentId] ?? []), msg].slice(-100) };
              unread = { ...unread, [achievement.agentId]: (unread[achievement.agentId] ?? 0) + 1 };
            }
          }
        }

        // 12) CEOから社長への能動的な呼びかけ(約45秒周期・同種はクールダウン・最大2件まで)
        let ceoAlerts = s.ceoAlerts;
        let alertCooldowns = s.alertCooldowns;
        if (tickCount % 15 === 0) {
          const activeAlerts = ceoAlerts.filter((a) => a.status === 'new');
          if (activeAlerts.length < 2) {
            const excluded = [
              ...Object.entries(alertCooldowns)
                .filter(([, until]) => tickCount < until)
                .map(([kind]) => kind),
              ...ceoAlerts.filter((a) => a.status === 'new' || a.status === 'later').map((a) => a.kind),
            ];
            const alert = generateCEOAlert(
              { ...s, agents, tasks, approvals },
              buildCompanyContext({ ...s, agents, tasks, approvals }),
              excluded,
            );
            if (alert) {
              ceoAlerts = [alert, ...ceoAlerts].slice(0, 12);
              alertCooldowns = { ...alertCooldowns, [alert.kind]: tickCount + 100 };
              unread = { ...unread, ceo: (unread.ceo ?? 0) + 1 };
              newLogs.push({
                id: uid('log'),
                timestamp: nowIso(),
                agentId: 'ceo',
                message: alert.conclusion,
                taskId: null,
                projectId: null,
                status: alert.severity === 'high' ? 'warning' : 'info',
              });
            }
          }
        }

        // 13) 朝会・夕会の自動開催(時間帯が切り替わったとき1回だけ)
        let lastAssemblyKey = s.lastAssemblyKey;
        if (s.settings.timeEffects !== false) {
          const period =
            (s.settings.clockMode ?? 'real') === 'demo'
              ? (['morning', 'day', 'evening', 'night'] as const)[Math.floor(tickCount / 40) % 4]
              : currentPeriod();
          const key = `${todayKey()}-${period}`;
          if ((period === 'morning' || period === 'evening') && key !== lastAssemblyKey) {
            lastAssemblyKey = key;
            const assembly = generateAssembly(period, { ...s, agents, tasks, approvals }, buildCompanyContext({ ...s, agents, tasks, approvals }));
            announcements = [
              { id: uid('ann'), message: assembly.announcement, tone: 'info' as const, createdAt: nowIso() },
              ...announcements,
            ].slice(0, 6);
            newTalks.push(...assembly.talks);
          }
        }

        dailyStats = dailyStats.map((d, i) => (i === todayIdx ? today : d));

        set({
          tasks,
          agents,
          approvals,
          usage,
          dailyStats,
          announcements,
          tickCount,
          relayQueue,
          directChats,
          unread,
          proposals,
          lastProposalTick,
          achievements,
          ceoAlerts,
          alertCooldowns,
          lastTalkTopics,
          lastAssemblyKey,
          agentTalks: [...newTalks, ...s.agentTalks].slice(0, 20),
          officeEvents: [...newEvents, ...s.officeEvents].slice(0, 10),
          logs: [...newLogs.reverse(), ...s.logs].slice(0, 400),
        });
      },

      pauseAgent: (agentId) =>
        set((s) => ({
          agents: s.agents.map((a) =>
            a.id === agentId
              ? { ...a, status: 'paused' as AgentStatus, zone: 'break' as OfficeZone, statusNote: '停止中(社長指示)', progress: 0 }
              : a,
          ),
        })),

      resumeAgent: (agentId) =>
        set((s) => ({
          agents: s.agents.map((a) =>
            a.id === agentId
              ? { ...a, status: 'idle' as AgentStatus, zone: 'desk' as OfficeZone, statusNote: '次の指示を待っています' }
              : a,
          ),
        })),

      renameAgent: (agentId, name) =>
        set((s) => ({
          agents: s.agents.map((a) => (a.id === agentId ? { ...a, name: name || a.name } : a)),
        })),

      // ---------- 承認フロー ----------
      decideApproval: (id, decision) => {
        const s = get();
        const approval = s.approvals.find((a) => a.id === id);
        if (!approval) return;
        const approvals = s.approvals.map((a) =>
          a.id === id ? { ...a, status: decision, decidedAt: nowIso() } : a,
        );
        let tasks = s.tasks;
        if (approval.taskId) {
          const nextStatus: TaskStatus =
            decision === 'approved' ? 'running' : decision === 'revision_requested' ? 'revising' : 'cancelled';
          tasks = s.tasks.map((task) =>
            task.id === approval.taskId
              ? { ...task, status: nextStatus, progress: decision === 'approved' ? Math.min(task.progress, 90) : task.progress }
              : task,
          );
        }
        const decisionLabel =
          decision === 'approved' ? '承認されました。実行を開始します' : decision === 'revision_requested' ? 'に修正依頼が届きました。修正します' : 'は却下されました';
        const decisionLogs: ActivityLog[] = [
          {
            id: uid('log'),
            timestamp: nowIso(),
            agentId: approval.requesterId,
            message: `「${approval.title}」${decisionLabel}。`,
            taskId: approval.taskId,
            projectId: null,
            status: decision === 'approved' ? ('success' as const) : ('warning' as const),
          },
        ];
        if (decision === 'approved') {
          decisionLogs.unshift({
            id: uid('log'),
            timestamp: nowIso(),
            agentId: 'ceo',
            message: `社長承認「${approval.title}」を確認しました。担当AIへ実行を指示します。`,
            taskId: approval.taskId,
            projectId: null,
            status: 'info',
          });
        }
        set({
          approvals,
          tasks,
          officeEvents:
            decision === 'approved'
              ? [
                  {
                    id: uid('evt'),
                    kind: 'plan' as const,
                    fromAgentId: 'ceo',
                    toAgentId: approval.requesterId,
                    label: '承認済み・実行を指示',
                    createdAt: nowIso(),
                  },
                  ...s.officeEvents,
                ].slice(0, 10)
              : s.officeEvents,
          logs: [...decisionLogs, ...s.logs].slice(0, 400),
        });
      },

      updateSettings: (patch) => set((s) => ({ settings: { ...s.settings, ...patch } })),

      // ---------- 社長チャット ----------
      sendChat: (content) => {
        const s = get();
        const userMsg: ChatMessage = {
          id: uid('chat'),
          role: 'ceo_user',
          content,
          timestamp: nowIso(),
        };
        const plan = buildPlan(content);
        const aiMsg: ChatMessage = {
          id: uid('chat'),
          role: 'ceo_ai',
          content: 'ご指示を分析しました。以下の実行プランでよろしければ「この内容で開始する」を押してください。開始まで処理は実行しません。',
          plan,
          planStatus: 'proposed',
          timestamp: nowIso(),
        };
        set({ chat: [...s.chat, userMsg, aiMsg] });
      },

      startPlan: (messageId) => {
        const s = get();
        const msg = s.chat.find((m) => m.id === messageId);
        if (!msg?.plan || msg.planStatus !== 'proposed') return;
        const plan = msg.plan;
        const createdIds: string[] = [];
        const newTasks: Task[] = plan.tasks.map((planned, i) => {
          const id = uid('task');
          createdIds.push(id);
          const dependsOn =
            planned.order > 1
              ? plan.tasks
                  .map((p, j) => ({ p, id: createdIds[j] }))
                  .filter(({ p }) => p.order === planned.order - 1 && p !== planned)
                  .map(({ id: depId }) => depId)
                  .filter(Boolean)
              : [];
          return {
            id,
            title: planned.title,
            description: `${plan.summary} のサブタスク`,
            assigneeId: planned.assigneeId,
            requesterId: 'ceo',
            projectId: null,
            customerId: null,
            priority: 'high',
            status: i === 0 ? 'running' : 'queued',
            progress: 0,
            plannedStart: null,
            deadline: null,
            startedAt: i === 0 ? nowIso() : null,
            completedAt: null,
            needsApproval: planned.needsApproval,
            approver: planned.needsApproval ? '社長' : null,
            dependsOn,
            input: null,
            output: null,
            model: 'claude-sonnet-5',
            inputTokens: 0,
            outputTokens: 0,
            costUsd: 0,
            errorMessage: null,
            createdAt: nowIso(),
          };
        });
        // オフィス連動: CEO AIから担当AIへタスク信号を飛ばし、担当AIを「タスク確認中」にする
        const assigneeIds = Array.from(new Set(plan.tasks.map((t) => t.assigneeId))).filter((id) => id !== 'ceo');
        const planEvents: OfficeEvent[] = assigneeIds.map((toAgentId) => ({
          id: uid('evt'),
          kind: 'plan',
          fromAgentId: 'ceo',
          toAgentId,
          label: 'タスクを割り当て',
          createdAt: nowIso(),
        }));
        set({
          tasks: [...newTasks, ...s.tasks],
          chat: s.chat.map((m) => (m.id === messageId ? { ...m, planStatus: 'started' } : m)),
          agents: s.agents.map((a) =>
            assigneeIds.includes(a.id) && a.status !== 'paused' && a.status !== 'error'
              ? { ...a, status: 'checking' as AgentStatus, zone: 'desk' as OfficeZone, statusNote: '依頼内容を確認中' }
              : a,
          ),
          officeEvents: [...planEvents, ...s.officeEvents].slice(0, 10),
          announcements: [
            {
              id: uid('ann'),
              message: `社長指示により「${plan.summary.slice(0, 30)}」を開始しました`,
              tone: 'success' as const,
              createdAt: nowIso(),
            },
            ...s.announcements,
          ].slice(0, 6),
          logs: [
            {
              id: uid('log'),
              timestamp: nowIso(),
              agentId: 'ceo',
              message: `実行プラン「${plan.summary}」を開始しました(タスク${newTasks.length}件を作成)。`,
              taskId: newTasks[0]?.id ?? null,
              projectId: null,
              status: 'success' as const,
            },
            ...s.logs,
          ].slice(0, 400),
        });
      },

      discardPlan: (messageId) =>
        set((s) => ({
          chat: s.chat.map((m) => (m.id === messageId ? { ...m, planStatus: 'discarded' } : m)),
        })),

      instructAgent: (agentId, instruction) => {
        const s = get();
        const task: Task = {
          id: uid('task'),
          title: instruction.slice(0, 60),
          description: `社長からの個別指示: ${instruction}`,
          assigneeId: agentId,
          requesterId: null,
          projectId: null,
          customerId: null,
          priority: 'high',
          status: 'running',
          progress: 0,
          plannedStart: null,
          deadline: null,
          startedAt: nowIso(),
          completedAt: null,
          needsApproval: false,
          approver: null,
          dependsOn: [],
          input: instruction,
          output: null,
          model: 'claude-sonnet-5',
          inputTokens: 0,
          outputTokens: 0,
          costUsd: 0,
          errorMessage: null,
          createdAt: nowIso(),
        };
        set({
          tasks: [task, ...s.tasks],
          logs: [
            {
              id: uid('log'),
              timestamp: nowIso(),
              agentId,
              message: `社長から個別指示を受領しました: 「${instruction.slice(0, 40)}」`,
              taskId: task.id,
              projectId: null,
              status: 'info' as const,
            },
            ...s.logs,
          ].slice(0, 400),
        });
      },

      setTaskStatus: (taskId, status) =>
        set((s) => ({
          tasks: s.tasks.map((t) =>
            t.id === taskId
              ? {
                  ...t,
                  status,
                  startedAt: status === 'running' && !t.startedAt ? nowIso() : t.startedAt,
                  completedAt: status === 'done' ? nowIso() : null,
                  progress: status === 'done' ? 100 : t.progress,
                }
              : t,
          ),
        })),

      resolveError: (id) =>
        set((s) => ({
          errors: s.errors.map((e) => (e.id === id ? { ...e, resolved: true } : e)),
        })),

      toggleIntegration: (id) =>
        set((s) => ({
          integrations: s.integrations.map((i) =>
            i.id === id
              ? { ...i, status: i.status === 'disabled' ? 'not_connected' : 'disabled' }
              : i,
          ),
        })),

      resetAll: () =>
        // 初回利用者と同じ空状態(実績ゼロ・通常モード)へ戻す
        set({
          ...initialData,
          officeEvents: [],
          announcements: [],
          tickCount: 0,
          relayQueue: [],
          lastChatAt: {},
          lastProposalTick: 0,
          alertCooldowns: {},
          lastTalkTopics: [],
          lastAssemblyKey: '',
          achievements: [],
          ceoAlerts: [],
          agentRuns: [],
          deliverables: [],
          chatSessions: [],
          onboardingDismissed: false,
          ceoProfile: { criteria: [], values: [], phrases: [], patterns: [], strengths: [], weaknesses: [], updatedAt: null },
        }),
    }),
    {
      name: 'aco-store-v1',
      version: 7,
      onRehydrateStorage: () => (state) => {
        state?.setHydrated(true);
      },
      // 旧バージョンの永続化データに新フィールドを補完する
      migrate: (persisted, version) => {
        const state = persisted as Partial<OfficeState>;
        if (version < 3 && state) {
          if (state.settings && state.settings.timeEffects === undefined) {
            state.settings = { ...state.settings, timeEffects: true };
          }
        }
        if (version < 4 && state) {
          // v4: 人格・会話フィールドの補完(既存の動的値は保持)
          if (Array.isArray(state.agents)) {
            state.agents = state.agents.map((a) => mergePersona({ ...a, ...AGENT_PERSONAS[a.id] } as Agent));
          }
          if (!state.directChats) state.directChats = seedDirectChats;
          if (!state.unread) state.unread = seedUnread;
          if (!state.proposals) state.proposals = seedProposals;
          if (!state.agentTalks) state.agentTalks = seedTalks;
        }
        if (version < 5 && state) {
          // v5: 成果イベント・CEO呼びかけの初期化
          if (!state.achievements) state.achievements = [];
          if (!state.ceoAlerts) state.ceoAlerts = [];
        }
        if (version < 6 && state) {
          // v6: AI実働ラン・成果物の初期化
          if (!state.agentRuns) state.agentRuns = [];
          if (!state.deliverables) state.deliverables = [];
        }
        if (version < 7 && state) {
          // v7: 初回オンボーディング。既存利用者(デモデータで利用中)には表示しない
          if (state.onboardingDismissed === undefined) state.onboardingDismissed = true;
        }
        return state as OfficeState & Record<string, unknown>;
      },
      partialize: (s) => {
        // hydratedと演出用の一時データは永続化しない
        // (会話履歴 directChats / 未読 unread / 提案 proposals / 社内会話 agentTalks は永続化する)
        const {
          hydrated,
          officeEvents,
          announcements,
          tickCount,
          relayQueue,
          lastChatAt,
          lastProposalTick,
          alertCooldowns,
          lastTalkTopics,
          lastAssemblyKey,
          ...rest
        } = s as OfficeState & Record<string, unknown>;
        return rest;
      },
    },
  ),
);

// ---------- セレクタ(集計) ----------
export function selectDashboardStats(s: OfficeState) {
  const usdJpy = s.settings.usdJpyRate;
  const activeAgents = s.agents.filter((a) => ['working', 'checking', 'delegating', 'meeting'].includes(a.status)).length;
  const idleAgents = s.agents.filter((a) => a.status === 'idle' || a.status === 'paused').length;
  const errorCount = s.errors.filter((e) => !e.resolved).length;
  const pendingApprovals = s.approvals.filter((a) => a.status === 'pending').length;
  const todayStat = s.dailyStats.find((d) => d.date === todayKey());
  const monthTasksDone = s.dailyStats.reduce((acc, d) => acc + d.tasksCompleted, 0);
  const totalCostUsd = s.agents.reduce((acc, a) => acc + a.costUsd, 0);
  // 固定のダミー実績はデモモードのみ加算(通常モードは実データのみ=初期値0)
  const demo = s.settings.demoMode;
  const revenue = s.deals.filter((d) => d.status === 'won').reduce((acc, d) => acc + d.amountJpy, 0) + (demo ? 850000 : 0); // デモ時のみ過去受注分含む
  const aiCostJpy = Math.round(totalCostUsd * usdJpy);
  const productionCost = s.projects.reduce((acc, p) => acc + p.productionCostJpy + p.outsourcingCostJpy, 0);
  const grossProfit = revenue - aiCostJpy - productionCost;
  return {
    activeAgents,
    idleAgents,
    errorCount,
    pendingApprovals,
    todayTasksDone: todayStat?.tasksCompleted ?? 0,
    monthTasksDone,
    leadsTotal: s.leads.length,
    formDrafts: s.tasks.filter((t) => t.assigneeId === 'form_sales' && ['waiting_approval', 'running'].includes(t.status)).length + (demo ? 16 : 0),
    formsSent: demo ? 214 : 0,
    emailDrafts: demo ? 36 : 0,
    emailsSent: demo ? 306 : 0,
    inquiries: s.inquiries.length,
    deals: s.deals.length,
    meetings: s.deals.filter((d) => ['meeting_set', 'met', 'proposing'].includes(d.status)).length,
    orders: s.deals.filter((d) => d.status === 'won').length,
    activeProjects: s.projects.filter((p) => p.status === 'active').length,
    doneProjects: demo ? 7 : 0,
    revenue,
    aiCostJpy,
    grossProfit,
    grossMargin: revenue > 0 ? (grossProfit / revenue) * 100 : 0,
  };
}
