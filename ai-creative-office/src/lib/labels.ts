import type {
  AgentStatus,
  ApprovalStatus,
  ApprovalType,
  DepartmentId,
  InquiryStatus,
  LeadStatus,
  ProposalStatus,
  SnsPostStatus,
  TaskPriority,
  TaskStatus,
} from './types';

export const DEPARTMENTS: Record<DepartmentId, { name: string; color: string }> = {
  executive: { name: '経営部', color: '#6366f1' },
  secretary: { name: '秘書部', color: '#0ea5e9' },
  sales: { name: '営業部', color: '#f59e0b' },
  marketing: { name: 'マーケティング部', color: '#ec4899' },
  production: { name: '制作部', color: '#8b5cf6' },
  admin: { name: '管理部', color: '#10b981' },
};

export const AGENT_STATUS: Record<AgentStatus, { label: string; color: string; bg: string; dot: string }> = {
  idle: { label: '待機中', color: 'text-slate-600', bg: 'bg-slate-100', dot: 'bg-slate-400' },
  checking: { label: 'タスク確認中', color: 'text-sky-700', bg: 'bg-sky-50', dot: 'bg-sky-500' },
  working: { label: '作業中', color: 'text-emerald-700', bg: 'bg-emerald-50', dot: 'bg-emerald-500' },
  delegating: { label: '他のAIへ依頼中', color: 'text-indigo-700', bg: 'bg-indigo-50', dot: 'bg-indigo-500' },
  waiting_approval: { label: '承認待ち', color: 'text-amber-700', bg: 'bg-amber-50', dot: 'bg-amber-500' },
  error: { label: 'エラー', color: 'text-red-700', bg: 'bg-red-50', dot: 'bg-red-500' },
  done: { label: '完了', color: 'text-teal-700', bg: 'bg-teal-50', dot: 'bg-teal-500' },
  paused: { label: '停止中', color: 'text-slate-500', bg: 'bg-slate-100', dot: 'bg-slate-300' },
  meeting: { label: '会議中', color: 'text-violet-700', bg: 'bg-violet-50', dot: 'bg-violet-500' },
};

export const TASK_STATUS: Record<TaskStatus, { label: string; color: string; bg: string }> = {
  backlog: { label: '未着手', color: 'text-slate-600', bg: 'bg-slate-100' },
  preparing: { label: '準備中', color: 'text-sky-700', bg: 'bg-sky-50' },
  queued: { label: '実行待ち', color: 'text-cyan-700', bg: 'bg-cyan-50' },
  running: { label: '実行中', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  waiting_approval: { label: '承認待ち', color: 'text-amber-700', bg: 'bg-amber-50' },
  revising: { label: '修正中', color: 'text-orange-700', bg: 'bg-orange-50' },
  done: { label: '完了', color: 'text-teal-700', bg: 'bg-teal-50' },
  failed: { label: '失敗', color: 'text-red-700', bg: 'bg-red-50' },
  stopped: { label: '停止', color: 'text-slate-500', bg: 'bg-slate-100' },
  cancelled: { label: 'キャンセル', color: 'text-slate-400', bg: 'bg-slate-50' },
};

export const KANBAN_COLUMNS: TaskStatus[] = [
  'backlog',
  'queued',
  'running',
  'waiting_approval',
  'revising',
  'done',
];

export const TASK_PRIORITY: Record<TaskPriority, { label: string; color: string }> = {
  low: { label: '低', color: 'text-slate-500' },
  medium: { label: '中', color: 'text-sky-600' },
  high: { label: '高', color: 'text-amber-600' },
  urgent: { label: '緊急', color: 'text-red-600' },
};

export const APPROVAL_TYPE: Record<ApprovalType, string> = {
  email_send: 'メール送信',
  form_send: 'フォーム送信',
  sns_post: 'SNS投稿',
  customer_reply: '顧客への返信',
  quote_send: '見積書送付',
  publish: '公開作業',
  domain_change: 'ドメイン変更',
  bulk_task: '大量タスク実行',
  high_cost: '高額API利用',
  pii: '個人情報を含む処理',
};

export const APPROVAL_STATUS: Record<ApprovalStatus, { label: string; color: string; bg: string }> = {
  pending: { label: '承認待ち', color: 'text-amber-700', bg: 'bg-amber-50' },
  approved: { label: '承認済み', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  revision_requested: { label: '修正依頼', color: 'text-orange-700', bg: 'bg-orange-50' },
  rejected: { label: '却下', color: 'text-red-700', bg: 'bg-red-50' },
};

export const LEAD_STATUS: Record<LeadStatus, { label: string; color: string; bg: string }> = {
  new: { label: '新規', color: 'text-slate-600', bg: 'bg-slate-100' },
  not_contacted: { label: '連絡前', color: 'text-slate-600', bg: 'bg-slate-100' },
  contacted: { label: '連絡済み', color: 'text-sky-700', bg: 'bg-sky-50' },
  replied: { label: '返信あり', color: 'text-cyan-700', bg: 'bg-cyan-50' },
  scheduling: { label: '日程調整中', color: 'text-indigo-700', bg: 'bg-indigo-50' },
  meeting_set: { label: '商談予定', color: 'text-violet-700', bg: 'bg-violet-50' },
  met: { label: '商談済み', color: 'text-purple-700', bg: 'bg-purple-50' },
  proposing: { label: '提案中', color: 'text-fuchsia-700', bg: 'bg-fuchsia-50' },
  won: { label: '受注', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  on_hold: { label: '保留', color: 'text-amber-700', bg: 'bg-amber-50' },
  lost: { label: '失注', color: 'text-red-700', bg: 'bg-red-50' },
};

export const INQUIRY_STATUS: Record<InquiryStatus, { label: string; color: string; bg: string }> = {
  new: { label: '新規', color: 'text-red-700', bg: 'bg-red-50' },
  triaged: { label: '振り分け済み', color: 'text-sky-700', bg: 'bg-sky-50' },
  replied: { label: '返信済み', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  converted: { label: '商談化', color: 'text-violet-700', bg: 'bg-violet-50' },
  closed: { label: '完了', color: 'text-slate-500', bg: 'bg-slate-100' },
};

export const PROPOSAL_STATUS: Record<ProposalStatus, { label: string; color: string; bg: string }> = {
  new: { label: '新規', color: 'text-brand-700', bg: 'bg-brand-50' },
  reviewing: { label: '確認中', color: 'text-sky-700', bg: 'bg-sky-50' },
  adopted: { label: '採用', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  revision: { label: '修正依頼', color: 'text-orange-700', bg: 'bg-orange-50' },
  rejected: { label: '却下', color: 'text-slate-500', bg: 'bg-slate-100' },
  queued: { label: '実行待ち', color: 'text-cyan-700', bg: 'bg-cyan-50' },
  executing: { label: '実行中', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  done: { label: '完了', color: 'text-teal-700', bg: 'bg-teal-50' },
  failed: { label: '失敗', color: 'text-red-700', bg: 'bg-red-50' },
};

export const SNS_STATUS: Record<SnsPostStatus, { label: string; color: string; bg: string }> = {
  draft: { label: '下書き', color: 'text-slate-600', bg: 'bg-slate-100' },
  waiting_approval: { label: '承認待ち', color: 'text-amber-700', bg: 'bg-amber-50' },
  approved: { label: '承認済み', color: 'text-emerald-700', bg: 'bg-emerald-50' },
  posted: { label: '投稿済み', color: 'text-teal-700', bg: 'bg-teal-50' },
  rejected: { label: '却下', color: 'text-red-700', bg: 'bg-red-50' },
};
