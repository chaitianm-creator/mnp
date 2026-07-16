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
  seedAgents,
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
  ActivityLog,
  Agent,
  AgentStatus,
  AiUsageRecord,
  Approval,
  Campaign,
  ChatMessage,
  CompanySettings,
  DailyStat,
  Deal,
  ErrorRecord,
  ExecutionPlan,
  Inquiry,
  Integration,
  Lead,
  Project,
  Report,
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

  setHydrated: (v: boolean) => void;
  tick: () => void;
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

const TICK_LOGS: [string, string, ActivityLog['status']][] = [
  ['list', '営業リストに新しい企業を追加しました。', 'info'],
  ['email_sales', '営業メールの開封を確認しました。', 'info'],
  ['writer', '原稿の推敲が1本完了しました。', 'success'],
  ['coder', 'コンポーネント1件の実装が完了しました。', 'success'],
  ['reviewer', 'レビュー指摘1件の修正を確認しました。', 'success'],
  ['seo', 'キーワード順位の変動を記録しました。', 'info'],
  ['sns', '投稿下書きを1本更新しました。', 'info'],
  ['secretary', 'リマインドを1件送信しました。', 'info'],
  ['deal_mgr', '商談ステータスを更新しました。', 'info'],
  ['designer', 'ワイヤーフレームのセクションを追加しました。', 'info'],
  ['accountant', 'トークン利用量を記録しました。', 'info'],
  ['ceo', '各部署の進捗を確認しました。', 'info'],
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

const initialData = {
  settings: seedSettings,
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
  integrations: seedIntegrations,
  chat: seedChat,
};

export const useOffice = create<OfficeState>()(
  persist(
    (set, get) => ({
      hydrated: false,
      ...initialData,

      setHydrated: (v) => set({ hydrated: v }),

      // ---------- デモエンジン ----------
      tick: () => {
        const s = get();
        if (!s.settings.demoMode) return;

        const usdJpy = s.settings.usdJpyRate;
        let dailyStats = ensureToday(s.dailyStats);
        const todayIdx = dailyStats.findIndex((d) => d.date === todayKey());
        const today = { ...dailyStats[todayIdx] };
        const newLogs: ActivityLog[] = [];
        let tasks = [...s.tasks];
        let approvals = s.approvals;

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
            newLogs.push({
              id: uid('log'),
              timestamp: nowIso(),
              agentId: task.assigneeId,
              message: `「${task.title}」が完了しました。`,
              taskId: task.id,
              projectId: task.projectId,
              status: 'success',
            });
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

        // 3) エージェント状態を同期・演出
        const agents = s.agents.map((agent) => {
          const running = tasks.find((x) => x.assigneeId === agent.id && x.status === 'running');
          const waiting = tasks.find((x) => x.assigneeId === agent.id && x.status === 'waiting_approval');
          const addIn = running ? 300 + Math.floor(Math.random() * 1500) : 0;
          const addOut = running ? 100 + Math.floor(Math.random() * 600) : 0;
          const addCost = (addIn / 1e6) * 3 + (addOut / 1e6) * 15;
          if (running) {
            const notes = WORK_NOTES[agent.id] ?? ['作業中'];
            const statusPool: AgentStatus[] = ['working', 'working', 'working', 'checking', 'delegating'];
            const note =
              Math.random() < 0.35 ? pickRandom(notes) : `${running.title.slice(0, 18)} ${running.progress}%`;
            return {
              ...agent,
              status: agent.status === 'paused' ? agent.status : pickRandom(statusPool),
              statusNote: note,
              currentTaskId: running.id,
              progress: running.progress,
              todayCount: agent.todayCount + (Math.random() < 0.3 ? 1 : 0),
              monthCount: agent.monthCount + (Math.random() < 0.3 ? 1 : 0),
              inputTokens: agent.inputTokens + addIn,
              outputTokens: agent.outputTokens + addOut,
              costUsd: agent.costUsd + addCost,
            };
          }
          if (waiting) {
            return {
              ...agent,
              status: 'waiting_approval' as AgentStatus,
              statusNote: `承認待ち: ${waiting.title.slice(0, 16)}`,
              currentTaskId: waiting.id,
              progress: 100,
            };
          }
          if (agent.status === 'paused' || agent.status === 'error') return agent;
          // 会議演出: たまに会議室へ移動し、しばらくして席へ戻る
          if (agent.status === 'meeting') {
            if (Math.random() < 0.35) {
              return { ...agent, status: 'idle' as AgentStatus, statusNote: '次のタスク待ち', currentTaskId: null, progress: 0 };
            }
            return agent;
          }
          if (Math.random() < 0.05) {
            return {
              ...agent,
              status: 'meeting' as AgentStatus,
              statusNote: '定例ミーティングに参加中',
              currentTaskId: null,
              progress: 0,
            };
          }
          return {
            ...agent,
            status: 'idle' as AgentStatus,
            statusNote: '次のタスク待ち',
            currentTaskId: null,
            progress: 0,
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

        dailyStats = dailyStats.map((d, i) => (i === todayIdx ? today : d));

        set({
          tasks,
          agents,
          approvals,
          usage,
          dailyStats,
          logs: [...newLogs.reverse(), ...s.logs].slice(0, 400),
        });
      },

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
        set({
          approvals,
          tasks,
          logs: [
            {
              id: uid('log'),
              timestamp: nowIso(),
              agentId: approval.requesterId,
              message: `「${approval.title}」${decisionLabel}。`,
              taskId: approval.taskId,
              projectId: null,
              status: decision === 'approved' ? ('success' as const) : ('warning' as const),
            },
            ...s.logs,
          ].slice(0, 400),
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
        set({
          tasks: [...newTasks, ...s.tasks],
          chat: s.chat.map((m) => (m.id === messageId ? { ...m, planStatus: 'started' } : m)),
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

      resetAll: () => set({ ...initialData }),
    }),
    {
      name: 'aco-store-v1',
      onRehydrateStorage: () => (state) => {
        state?.setHydrated(true);
      },
      partialize: (s) => {
        const { hydrated, ...rest } = s as OfficeState & Record<string, unknown>;
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
  const revenue = s.deals.filter((d) => d.status === 'won').reduce((acc, d) => acc + d.amountJpy, 0) + 850000; // 過去受注分含む
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
    formDrafts: s.tasks.filter((t) => t.assigneeId === 'form_sales' && ['waiting_approval', 'running'].includes(t.status)).length + 16,
    formsSent: 214,
    emailDrafts: 36,
    emailsSent: 306,
    inquiries: s.inquiries.length,
    deals: s.deals.length,
    meetings: s.deals.filter((d) => ['meeting_set', 'met', 'proposing'].includes(d.status)).length,
    orders: s.deals.filter((d) => d.status === 'won').length,
    activeProjects: s.projects.filter((p) => p.status === 'active').length,
    doneProjects: 7,
    revenue,
    aiCostJpy,
    grossProfit,
    grossMargin: revenue > 0 ? (grossProfit / revenue) * 100 : 0,
  };
}
