// ============================================================
// AI CREATIVE OFFICE ドメイン型定義
// Supabase移行時は database.types.ts に置き換える前提で、
// テーブル構造(docs/DATABASE.md)と1:1で対応させている。
// ============================================================

export type DepartmentId =
  | 'executive' // 経営部
  | 'secretary' // 秘書部
  | 'sales' // 営業部
  | 'marketing' // マーケティング部
  | 'production' // 制作部
  | 'admin'; // 管理部

export type AgentStatus =
  | 'idle' // 待機中
  | 'checking' // タスク確認中
  | 'working' // 作業中
  | 'delegating' // 他のAIへ依頼中
  | 'waiting_approval' // 承認待ち
  | 'error' // エラー
  | 'done' // 完了
  | 'paused' // 停止中
  | 'meeting'; // 会議中(オフィス演出用)

export interface AgentKpi {
  label: string;
  value: number;
  unit?: string;
}

/** オフィス内の居場所(ライブオフィス用) */
export type OfficeZone = 'desk' | 'meeting' | 'project' | 'approval' | 'server' | 'break';

export const ZONE_LABELS: Record<OfficeZone, string> = {
  desk: '自席',
  meeting: '会議室',
  project: 'プロジェクトテーブル',
  approval: '承認待ちスペース',
  server: 'サーバールーム',
  break: '休憩スペース',
};

export interface Agent {
  id: string;
  name: string; // 表示名(設定で変更可能)
  role: string; // 役職名(例: リスト作成AI)
  departmentId: DepartmentId;
  description: string;
  responsibilities: string[];
  status: AgentStatus;
  statusNote: string; // オフィスに表示する一言(例: 企業リスト 152/300件)
  currentTaskId: string | null;
  progress: number; // 0-100
  todayCount: number; // 今日の処理件数
  monthCount: number; // 今月の処理件数
  kpis: AgentKpi[];
  model: string; // 使用AIモデル
  provider: 'anthropic' | 'openai' | 'google' | 'mock';
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  avatar: string; // 絵文字アバター
  color: string; // アバター背景色 (tailwindクラスではなくhex)
  enabled: boolean;
  // ---- ライブオフィス用(v2で追加・すべて任意) ----
  zone?: OfficeZone; // 現在の居場所。未指定時はstatusから導出
  nickname?: string; // 人間味のための呼び名(例: 美咲)
  trait?: string; // 特徴(例: 積極的 / 品質重視)
  strengths?: string[]; // 得意業務
  weaknesses?: string[]; // 苦手業務
  signatureStat?: { label: string; value: string }; // 例: 今日の返信率 18%
  doneFlashUntil?: string; // 完了演出の表示期限(ISO)
  focus?: number; // 現在の集中度 0-100(デモで変動)
  fatigue?: number; // 疲労度 0-100(作業で上昇、待機・休憩で回復)
  weeklyHighlight?: string; // 今週の成果(例: 返信率が2.1%→3.4%に改善)
  // ---- 人格・会話(v4で追加・すべて任意) ----
  displayName?: string; // 例: 営業AI「美咲」
  personality?: string; // 性格(例: 積極的、提案型、スピード重視)
  speakingStyle?: string; // 口調(例: 明るく、簡潔で、数字を交えて報告)
  decisionPolicy?: string; // 判断基準(例: 返信率、商談化率、顧客との適合度)
  greeting?: string; // 会話開始時の挨拶
  currentMood?: string; // 現在の気分(集中度・疲労度から更新)
  confidence?: number; // 自信度 0-100
  specialties?: string[]; // 専門領域(strengthsの別名的に使用)
  preferredTaskTypes?: string[]; // 依頼を受けやすいタスク種別
  communicationExamples?: string[]; // 話し方の例
}

export type TaskStatus =
  | 'backlog' // 未着手
  | 'preparing' // 準備中
  | 'queued' // 実行待ち
  | 'running' // 実行中
  | 'waiting_approval' // 承認待ち
  | 'revising' // 修正中
  | 'done' // 完了
  | 'failed' // 失敗
  | 'stopped' // 停止
  | 'cancelled'; // キャンセル

export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';

export interface Task {
  id: string;
  title: string;
  description: string;
  assigneeId: string; // 担当AI
  requesterId: string | null; // 依頼元AI(nullは社長直轄)
  projectId: string | null;
  customerId: string | null;
  priority: TaskPriority;
  status: TaskStatus;
  progress: number;
  plannedStart: string | null;
  deadline: string | null;
  startedAt: string | null;
  completedAt: string | null;
  needsApproval: boolean;
  approver: string | null;
  dependsOn: string[]; // 依存タスクID
  input: string | null;
  output: string | null;
  model: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  errorMessage: string | null;
  createdAt: string;
}

export type ApprovalType =
  | 'email_send' // メール送信
  | 'form_send' // フォーム送信
  | 'sns_post' // SNS投稿
  | 'customer_reply' // 顧客への返信
  | 'quote_send' // 見積書送付
  | 'publish' // 公開作業
  | 'domain_change' // ドメイン変更
  | 'bulk_task' // 大量タスク実行
  | 'high_cost' // 高額API利用
  | 'pii'; // 個人情報を含む処理

export type ApprovalStatus = 'pending' | 'approved' | 'revision_requested' | 'rejected';

export interface Approval {
  id: string;
  type: ApprovalType;
  title: string;
  requesterId: string; // 申請したAI
  target: string; // 実行対象
  body: string; // 本文または変更内容
  count: number; // 実行件数
  estimatedCostJpy: number;
  risks: string[];
  hasDuplicates: boolean;
  hasOptedOutTargets: boolean;
  status: ApprovalStatus;
  taskId: string | null;
  createdAt: string;
  decidedAt: string | null;
}

// ---------- 営業/CRM ----------

export type LeadStatus =
  | 'new' // 新規
  | 'not_contacted' // 連絡前
  | 'contacted' // 連絡済み
  | 'replied' // 返信あり
  | 'scheduling' // 日程調整中
  | 'meeting_set' // 商談予定
  | 'met' // 商談済み
  | 'proposing' // 提案中
  | 'won' // 受注
  | 'on_hold' // 保留
  | 'lost'; // 失注

export interface Lead {
  id: string;
  companyName: string;
  industry: string;
  region: string;
  employeeSize: string;
  url: string;
  contactFormUrl: string | null;
  email: string | null;
  phone: string | null;
  contactPerson: string | null;
  reason: string; // 営業対象になった理由
  hypothesis: string; // 課題仮説
  proposal: string | null; // 提案内容
  status: LeadStatus;
  lastContactAt: string | null;
  nextActionAt: string | null;
  optedOut: boolean; // 配信停止
  doNotContact: boolean; // 連絡禁止
  memo: string;
  campaignId: string | null;
  createdAt: string;
}

export interface Campaign {
  id: string;
  name: string;
  channel: 'email' | 'form' | 'tel';
  targetCondition: string;
  status: 'draft' | 'active' | 'paused' | 'done';
  totalLeads: number;
  sent: number;
  replied: number;
  meetings: number;
  createdAt: string;
}

export type InquiryUrgency = 'low' | 'medium' | 'high';
export type InquiryStatus = 'new' | 'triaged' | 'replied' | 'converted' | 'closed';

export interface Inquiry {
  id: string;
  fromCompany: string;
  fromName: string;
  email: string;
  subject: string;
  body: string;
  service: string;
  urgency: InquiryUrgency;
  status: InquiryStatus;
  draftReply: string | null;
  assigneeId: string;
  receivedAt: string;
  firstResponseMinutes: number | null;
}

export interface Deal {
  id: string;
  leadId: string | null;
  companyName: string;
  title: string;
  amountJpy: number;
  status: LeadStatus;
  summary: string;
  nextAction: string;
  nextActionAt: string | null;
  lostReason: string | null;
  probability: number; // 案件化可能性 0-100
  createdAt: string;
}

// ---------- 制作 ----------

export const PROJECT_PHASES = [
  '問い合わせ',
  'ヒアリング',
  '要件整理',
  '見積もり',
  '受注',
  'サイト設計',
  '原稿作成',
  'ワイヤーフレーム',
  'デザイン',
  'コーディング',
  '品質確認',
  '顧客確認',
  '修正',
  '公開準備',
  '公開',
  '運用',
] as const;

export type ProjectPhase = (typeof PROJECT_PHASES)[number];

export type ProjectStatus = 'active' | 'on_hold' | 'done' | 'maintenance';

export interface ProjectPage {
  id: string;
  name: string;
  status: 'planned' | 'writing' | 'wireframe' | 'design' | 'coding' | 'review' | 'done';
}

export interface Project {
  id: string;
  name: string;
  customerName: string;
  serviceType: string;
  orderAmountJpy: number;
  productionCostJpy: number;
  aiCostJpy: number;
  outsourcingCostJpy: number;
  directorId: string;
  memberIds: string[];
  startDate: string;
  deadline: string;
  status: ProjectStatus;
  phase: ProjectPhase;
  progress: number;
  requirements: string;
  purpose: string;
  target: string;
  persona: string;
  sitemap: string[];
  pages: ProjectPage[];
  assets: string[];
  revisions: { date: string; content: string }[];
  publishedUrl: string | null;
  createdAt: string;
}

// ---------- マーケティング ----------

export type SnsPlatform = 'Instagram' | 'X' | 'Threads' | 'LinkedIn' | 'Facebook';
export type SnsPostStatus = 'draft' | 'waiting_approval' | 'approved' | 'posted' | 'rejected';

export interface SnsPost {
  id: string;
  platform: SnsPlatform;
  title: string;
  body: string;
  scheduledAt: string;
  status: SnsPostStatus;
  impressions: number;
  clicks: number;
}

export interface SeoKeyword {
  id: string;
  keyword: string;
  intent: '情報収集' | '比較検討' | '購入直前' | '指名';
  volume: number;
  difficulty: number;
  rank: number | null;
  articleStatus: 'none' | 'outline' | 'writing' | 'published';
}

// ---------- ログ/コスト/レポート ----------

export interface ActivityLog {
  id: string;
  timestamp: string;
  agentId: string;
  message: string;
  taskId: string | null;
  projectId: string | null;
  status: 'info' | 'success' | 'warning' | 'error';
}

export interface AiUsageRecord {
  id: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  cachedTokens: number;
  usdRateInput: number; // $ / 1M tokens
  usdRateOutput: number;
  costUsd: number;
  executedAt: string;
  agentId: string;
  taskId: string | null;
  projectId: string | null;
}

export interface DailyStat {
  date: string; // YYYY-MM-DD
  tasksCompleted: number;
  leadsAdded: number;
  formsSent: number;
  emailsSent: number;
  inquiries: number;
  meetings: number;
  orders: number;
  costJpy: number;
  revenueJpy: number;
}

export interface Report {
  id: string;
  type: 'daily' | 'weekly' | 'monthly';
  periodLabel: string;
  createdAt: string;
  body: string; // Markdown
}

export interface ErrorRecord {
  id: string;
  timestamp: string;
  agentId: string;
  taskId: string | null;
  message: string;
  detail: string;
  resolved: boolean;
}

export interface ChatMessage {
  id: string;
  role: 'ceo_user' | 'ceo_ai';
  content: string;
  plan?: ExecutionPlan;
  planStatus?: 'proposed' | 'started' | 'discarded';
  timestamp: string;
}

export interface PlannedTask {
  title: string;
  assigneeId: string;
  order: number;
  parallel: boolean;
  needsApproval: boolean;
}

export interface ExecutionPlan {
  summary: string;
  purpose: string;
  tasks: PlannedTask[];
  approvalNotes: string[];
  completionCriteria: string;
  estimatedCostJpy: number;
}

/** AI社員間の連携イベント(オフィス演出用・永続化しない) */
export interface OfficeEvent {
  id: string;
  kind: 'delegate' | 'complete' | 'error' | 'plan';
  fromAgentId: string;
  toAgentId: string;
  label: string;
  createdAt: string;
}

/** CEO AIの全社アナウンス */
export interface Announcement {
  id: string;
  message: string;
  tone: 'info' | 'success' | 'warning';
  createdAt: string;
}

// ---------- AI社員との個別会話 ----------

/** 会話内のアクションボタン(ユーザーが押すまで実行しない) */
export interface ChatAction {
  id: string;
  label: string;
  kind:
    | 'link' // 画面遷移(承認センター等)
    | 'create_task' // タスク作成(承認=クリック)
    | 'consult' // 他AIへ相談・確認依頼(信号+ログ)
    | 'pause_agent'
    | 'resume_agent'
    | 'call_meeting' // 会議招集
    | 'report'; // 詳細レポートを会話に追加
  href?: string; // kind=link用
  payload?: string; // タスク内容・相談先AIidなど
}

export interface DirectChatMessage {
  id: string;
  role: 'user' | 'agent';
  content: string;
  actions?: ChatAction[];
  timestamp: string;
}

// ---------- CEO AIの経営提案 ----------

export type ProposalStatus =
  | 'new' // 新規
  | 'reviewing' // 確認中
  | 'adopted' // 採用
  | 'revision' // 修正依頼
  | 'rejected' // 却下
  | 'queued' // 実行待ち
  | 'executing' // 実行中
  | 'done' // 完了
  | 'failed'; // 失敗

export interface CeoProposal {
  id: string;
  title: string;
  summary: string; // CEO AIの要約
  issue: string; // 課題
  evidence: string[]; // 根拠となる数字
  hypothesis: string; // 原因仮説
  actions: { title: string; assigneeId: string }[]; // 提案内容(採用時にタスク化)
  expectedEffect: string; // 想定効果
  risks: string[]; // 想定リスク
  estimatedCostJpy: number; // 想定コスト
  approvalNote: string; // 承認が必要な処理
  targetDepartment: string;
  targetAgentIds: string[];
  status: ProposalStatus;
  createdAt: string;
  decidedAt: string | null;
  taskIds: string[]; // 採用時に作成したタスク
}

/** AI社員同士の短い社内会話(重要イベント時のみ) */
export interface AgentTalk {
  id: string;
  lines: { agentId: string; text: string }[];
  taskId: string | null;
  projectId: string | null;
  timestamp: string;
}

export interface Integration {
  id: string;
  name: string;
  category: string;
  description: string;
  status: 'not_connected' | 'connected' | 'disabled';
  requiredEnv: string[];
}

export interface CompanySettings {
  companyName: string;
  subCopy: string;
  ceoName: string;
  business: string;
  services: string[];
  targetCustomer: string;
  salesRegions: string[];
  salesIndustries: string[];
  prohibitedTargets: string;
  tone: string;
  brandColor: string;
  monthlyAiBudgetJpy: number;
  approvalRequired: ApprovalType[];
  timezone: string;
  currency: 'JPY' | 'USD';
  usdJpyRate: number;
  demoMode: boolean;
  setupCompleted: boolean;
  timeEffects?: boolean; // 時間帯演出(v2で追加。未定義はtrue扱い)
  investorMode?: boolean; // ダッシュボードの投資家向け表示(未定義はfalse=経営者向け)
  simulation?: SimulationAssumptions; // 投資家モードの算出条件(未定義はDEFAULT_SIMULATION)
}

/** 投資家モードのシミュレーション算出条件(設定画面から変更可能) */
export interface SimulationAssumptions {
  salaryPerHeadJpy: number; // 1人あたりの想定人件費(月額・円)
  minutesPerTask: number; // タスク1件あたりの人間換算作業時間(分)
  workHoursPerMonth: number; // 1人あたりの月間想定労働時間(時間)
}
