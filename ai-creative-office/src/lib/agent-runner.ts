'use client';

// ============================================================
// AI実働ランのオーケストレーター(クライアント側)
// 社長の依頼 → CEO計画 → [承認] → ディレクター → ライター →
// レビュー → (差し戻しなら修正×1回) → 最終成果物
// - API呼び出しは /api/agent/run(サーバー)経由。キーは露出しない
// - 承認前は実行しない / コスト上限で停止して承認を求める
// - 依存タスク完了まで後続を開始しない(本チェーンは直列)
// ============================================================
import {
  briefToMarkdown,
  contentToMarkdown,
  directorToMarkdown,
  distributionToMarkdown,
  planToMarkdown,
  reviewToMarkdown,
  visualToMarkdown,
  writerToMarkdown,
} from './ai/markdown';
import type {
  CeoConsultOutput,
  ContentDraftOutput,
  CreativeBriefOutput,
  DirectorDocOutput,
  DistributionPlanOutput,
  ExecutionPlanOutput,
  ReviewResultOutput,
  RunKind,
  RunResponse,
  RunUsage,
  VisualDesignOutput,
  WriterCopyOutput,
} from './ai/schemas';
import { CASE_DEFS, classifyRequest, type CaseDef, type PipelineStep } from './case-types';
import { useOffice } from './store';
import type { CeoAdviceOutput, CeoResearchOutput, ReviewPanelOutput, TaskWorkOutput } from './ai/schemas';
import type { AgentRun, CeoConsultMeta, ChatMessage, Deliverable, DeliverableType, RunTask, Task, TaskRoom } from './types';
import { uid } from './utils';

const nowIso = () => new Date().toISOString();

async function callAgent(kind: RunKind, request: string, context?: string, revisionNotes?: string, caseLabel?: string) {
  const res = await fetch('/api/agent/run', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ kind, request, context, revisionNotes, caseLabel }),
  });
  const json = (await res.json()) as RunResponse;
  if (!json.ok || !json.data || !json.usage) throw new Error(json.error ?? 'AI実行に失敗しました');
  return { data: json.data, usage: json.usage };
}

/** 工程種別ごとの構造化出力→Markdown変換 */
function stepToMarkdown(step: PipelineStep, data: unknown): string {
  switch (step.kind) {
    case 'brief':
      return briefToMarkdown(data as CreativeBriefOutput, step.deliverableTitle);
    case 'content':
      return contentToMarkdown(data as ContentDraftOutput, step.deliverableTitle);
    case 'visual':
      return visualToMarkdown(data as VisualDesignOutput, step.deliverableTitle);
    case 'distribution':
      return distributionToMarkdown(data as DistributionPlanOutput, step.deliverableTitle);
    case 'director':
      return directorToMarkdown(data as DirectorDocOutput);
    case 'writer':
      return writerToMarkdown(data as WriterCopyOutput);
  }
}

function usageToJpy(usage: RunUsage): number {
  const rate = useOffice.getState().settings.usdJpyRate;
  return usage.costUSD * rate;
}

function pushLog(agentId: string, message: string, status: 'info' | 'success' | 'warning' | 'error' = 'info') {
  useOffice.setState((s) => ({
    logs: [
      { id: uid('log'), timestamp: nowIso(), agentId, message, taskId: null, projectId: null, status },
      ...s.logs,
    ].slice(0, 400),
  }));
}

function pushSignal(from: string, to: string, label: string) {
  useOffice.setState((s) => ({
    officeEvents: [
      { id: uid('evt'), kind: 'delegate' as const, fromAgentId: from, toAgentId: to, label, createdAt: nowIso() },
      ...s.officeEvents,
    ].slice(0, 10),
  }));
}

function makeDeliverable(
  runId: string,
  taskId: string | null,
  title: string,
  type: DeliverableType,
  agentId: string,
  markdown: string,
  json: unknown,
  sourceRequest: string,
  usage: RunUsage,
): Deliverable {
  return {
    id: uid('dlv'),
    runId,
    taskId,
    title,
    type,
    agentId,
    status: 'draft',
    version: 1,
    versions: [{ version: 1, markdown, editedBy: 'ai', note: usage.isMock ? 'デモ生成(初版)' : 'AI生成(初版)', createdAt: nowIso() }],
    markdown,
    json: JSON.stringify(json, null, 2),
    sourceRequest,
    model: usage.model,
    provider: usage.provider,
    isMock: usage.isMock,
    inputTokens: usage.inputTokens,
    outputTokens: usage.outputTokens,
    costJpy: usageToJpy(usage),
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };
}

// ============================================================
// ⓪ CEO相談フェーズ: 依頼理解 → 目的整理 → 提案 → (必要なら質問1〜2件) → 計画へ
//   CEOは「言われた仕事を流す人」ではなく「成果を出す方法を考える人」
// ============================================================

/** 「詳しく見る」で展開する詳細(目的整理・提案・判断根拠・制作方法) */
function consultDetail(c: CeoConsultOutput): string {
  return [
    `■ ご依頼の理解\n${c.understanding}`,
    `\n■ 目的の整理\n${c.objective}`,
    `\n■ 成果を出すための提案\n${c.proposal}`,
    `\n■ 判断根拠\n${c.reasoning}`,
    `\n■ 制作の進め方\n${c.productionApproach}`,
  ].join('\n');
}

/** 回答待ちのCEO相談メッセージを取得(あれば次の入力は回答として扱う) */
export function getPendingConsult(): { messageId: string; request: string } | null {
  const chat = useOffice.getState().chat;
  for (let i = chat.length - 1; i >= 0; i--) {
    const m = chat[i];
    if (m.role === 'ceo_user') continue; // 直前の社長メッセージは読み飛ばす
    if (m.consult && !m.consult.answered && m.consult.questions.length > 0) {
      return { messageId: m.id, request: m.consult.request };
    }
    return null; // 直近のCEOメッセージが回答待ちの相談でなければ、通常の新規依頼として扱う
  }
  return null;
}

function markConsultAnswered(messageId: string) {
  useOffice.setState((s) => ({
    chat: s.chat.map((m) =>
      m.id === messageId && m.consult ? { ...m, consult: { ...m.consult, answered: true } } : m,
    ),
  }));
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ============================================================
// CEOのモード判定: 経営相談 / ディープリサーチ / 制作依頼
// CEOは「考える材料を整理する人」。制作が必要なときだけディレクターへ引き継ぐ
// ============================================================

export type CeoMode = 'advice' | 'research' | 'production' | 'tasks';

// 制作依頼と判定するのは「作って/書いて/考えて」等の明確な依頼動詞がある場合のみ
const MAKE_HINTS = /作って|作成して|作成せよ|書いて|考えて|制作して|作りたい|作ってください|デザインして|リニューアルして|構成案を|原稿を書|台本を作/;
const CONSULT_HINTS = /相談|どう思|すべきか|べきです?か|悩んで|迷って|意見|アドバイス|考えを|戦略を|方針|分析して|教えて|判断/;

/**
 * 箇条書き入力の解析。箇条書き(・- * 1. など)が含まれる入力は
 * 100%タスク候補として扱う(AI秘書=社長の仕事整理)
 */
export function parseBulletTasks(text: string): string[] | null {
  const bulletRe = /^([・\-*•●○◦▪]|[0-9０-９]+[.)、.)])\s*/;
  const lines = text
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  // 「・A ・B ・C」のように1行へまとめられた箇条書きにも対応
  // (行頭が「・」で始まり、行内に複数の「・」がある場合のみ分割。文中の「企画・構成」等は誤分割しない)
  if (lines.length === 1 && /^[・•●]/.test(lines[0]) && (lines[0].match(/[・•●]/g) ?? []).length >= 2) {
    const items = lines[0]
      .split(/[・•●]/)
      .map((t) => t.trim())
      .filter(Boolean);
    return items.length >= 2 ? items : null;
  }
  const bulletLines = lines.filter((l) => bulletRe.test(l));
  if (bulletLines.length === 0) return null;
  const items = bulletLines.map((l) => l.replace(bulletRe, '').trim()).filter(Boolean);
  return items.length > 0 ? items : null;
}

/** 「Facebook投稿」「Threads日記」のような動詞なしの短い名詞句(=やること)か */
function isBareTodo(text: string): boolean {
  const t = text.trim();
  if (t.length === 0 || t.length > 30) return false;
  if (t.includes('?') || t.includes('?')) return false;
  if (MAKE_HINTS.test(t) || CONSULT_HINTS.test(t)) return false;
  // 依頼・相談の文末表現がなければ名詞句とみなす
  return !/(ください|して$|したい|します|ですか|でしょうか|お願い)/.test(t);
}

export function detectCeoMode(text: string): CeoMode {
  const t = text.trim();
  if (parseBulletTasks(t)) return 'tasks'; // 箇条書きは100%タスク候補
  if (/^テーマ[::]/.test(t)) return 'research'; // ディープリサーチモード
  if (MAKE_HINTS.test(t)) return 'production'; // 明確な制作依頼のみ制作へ
  if (CONSULT_HINTS.test(t)) return 'advice';
  if (isBareTodo(t)) return 'tasks'; // 名詞句だけの入力は「やること」として登録
  return 'advice';
}

// ---------- AI秘書: タスクの自動分類 ----------

interface TaskClassification {
  category: string;
  assigneeId: string;
  priority: 'low' | 'medium' | 'high' | 'urgent';
}

/** タスク名からカテゴリ・担当AI候補・優先度を自動設定 */
export function classifyTask(title: string): TaskClassification {
  const t = title.toLowerCase();
  const priority: TaskClassification['priority'] = /至急|今すぐ|急ぎ|本日中|今日中/.test(title)
    ? 'urgent'
    : /早め|明日|今週/.test(title)
      ? 'high'
      : 'medium';
  const has = (re: RegExp) => re.test(t) || re.test(title);

  if (has(/返信|返事|メール対応|問い合わせ|連絡|返答/)) return { category: '返信', assigneeId: 'reception', priority };
  if (has(/facebook|threads|スレッズ|instagram|インスタ|リール|カルーセル|x投稿|ツイート|sns|投稿|日記/)) return { category: 'SNS', assigneeId: 'sns', priority };
  if (has(/バナー|チラシ|ロゴ|デザイン|画像/)) return { category: 'デザイン', assigneeId: 'designer', priority };
  if (has(/ブログ|記事|原稿|ライティング|コラム/)) return { category: '記事', assigneeId: 'writer', priority };
  if (has(/hp|ホームページ|サイト|lp|ランディング|web|修正|ページ/)) return { category: '制作', assigneeId: 'director', priority };
  if (has(/提案書|企画書|資料|見積/)) return { category: '資料', assigneeId: 'director', priority };
  if (has(/請求|経理|支払|振込|入金/)) return { category: '管理', assigneeId: 'accountant', priority };
  return { category: 'その他', assigneeId: 'secretary', priority };
}

/** 「〇〇の返事の文を考えて欲しい」等から、タスク名に不要な依頼表現を取り除く */
export function cleanTaskTitle(raw: string): string {
  let t = raw.trim().replace(/[。.]+$/, '');
  t = t
    .replace(/(を|の)?(文章?|文面|返信文|下書き)?を?(考えて|作って|書いて|作成して)(ほしい|欲しい|ください)?$/, '')
    .replace(/(して)?(ほしい|欲しい|ください|お願いします|お願い)$/, '')
    .replace(/[のをはが]$/, '')
    .trim();
  return t || raw.trim();
}

/** 依頼文が「返信文・下書きを考えてほしい」内容か(案件ルームでの自動下書き対象) */
export const wantsDraft = (text: string): boolean => /返信|返事|文を考え|文面|下書き|ドラフト/.test(text);

/**
 * AI秘書モード: 入力をタスク候補として/tasksへ登録する。
 * 各タスクには元の入力文(全文)を保存し、専用の案件ルームを同時に作成する。
 * AI社員への依頼・制作ランは一切行わない(社長の頭の中を整理する場所)
 */
export function registerTasksFromChat(items: string[], sourceText?: string): number {
  const source = (sourceText ?? items.join('\n')).trim();
  const tasks: Task[] = items.map((item) => {
    const c = classifyTask(item);
    return {
      id: uid('task'),
      title: cleanTaskTitle(item),
      description: `社長指示チャット(AI秘書)から登録 — カテゴリ: ${c.category}`,
      category: c.category,
      assigneeId: c.assigneeId,
      requesterId: null,
      projectId: null,
      customerId: null,
      priority: c.priority,
      status: 'backlog' as const,
      progress: 0,
      plannedStart: null,
      deadline: null,
      startedAt: null,
      completedAt: null,
      needsApproval: false,
      approver: null,
      dependsOn: [],
      // 元の指示・依頼内容(このタスクの行 + 全文)を省略なしで保存する
      input: items.length > 1 ? `${item}\n\n【社長指示チャットの元の入力(全文)】\n${source}` : source,
      output: null,
      model: 'なし(未実行)',
      inputTokens: 0,
      outputTokens: 0,
      costUsd: 0,
      errorMessage: null,
      createdAt: nowIso(),
    };
  });
  // 1タスク=1案件ルームを同時に作成(会話・成果物は案件ごとに分離)
  const rooms: Record<string, TaskRoom> = {};
  for (const t of tasks) {
    rooms[t.id] = {
      taskId: t.id,
      sourceRequest: t.input ?? '',
      messages: [],
      artifacts: [],
      activities: [{ id: uid('act'), message: '社長指示チャットからタスクを登録し、案件ルームを作成しました', timestamp: nowIso() }],
      suggestions: null,
      autoDrafted: false,
      unreadCount: 0,
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
  }
  useOffice.setState((s) => ({
    tasks: [...tasks, ...s.tasks],
    taskRooms: { ...s.taskRooms, ...rooms },
    chat: [
      ...s.chat,
      { id: uid('chat'), role: 'ceo_ai' as const, content: `${tasks.length}件のタスクを登録しました。`, timestamp: nowIso() },
    ],
  }));
  pushLog('secretary', `AI秘書: 社長のタスク${tasks.length}件を整理して登録しました(${Array.from(new Set(tasks.map((t) => t.category ?? 'その他'))).join('・')})。`, 'success');
  return tasks.length;
}

// ============================================================
// 案件ルーム: タスク専用チャット・AI提案・成果物の生成
// (この会話はルーム内に閉じる。SNSディレクター等への発注は行わない)
// ============================================================

/** タスク内容から担当AIの候補を返す(自動実行はせず、選択肢の提示のみ) */
export function assigneeCandidates(task: Task): { agentId: string; reason: string }[] {
  const text = `${task.title} ${task.category ?? ''}`;
  if (/返信|返事|問い合わせ|連絡/.test(text)) {
    return [
      { agentId: 'reception', reason: '問い合わせ対応・一次返信が担当領域' },
      { agentId: 'secretary', reason: '日程調整・丁寧な事務連絡が得意' },
      { agentId: 'writer', reason: '文面のトーン調整・推敲が得意' },
    ];
  }
  if (/sns|インスタ|instagram|threads|facebook|x投稿|リール|投稿|日記/i.test(text)) {
    return [
      { agentId: 'sns', reason: 'SNS企画・投稿設計が担当領域' },
      { agentId: 'writer', reason: 'キャプション・本文の執筆が得意' },
    ];
  }
  if (/バナー|チラシ|ロゴ|デザイン|画像/.test(text)) {
    return [
      { agentId: 'designer', reason: 'デザイン制作が担当領域' },
      { agentId: 'director', reason: '要件整理からの進行が得意' },
    ];
  }
  if (/ブログ|記事|原稿|コラム|ライティング/.test(text)) {
    return [
      { agentId: 'writer', reason: '記事・原稿の執筆が担当領域' },
      { agentId: 'seo', reason: '検索意図・構成設計が得意' },
    ];
  }
  if (/hp|ホームページ|サイト|lp|web|修正|ページ/i.test(text)) {
    return [
      { agentId: 'director', reason: 'Web制作の要件整理・進行が担当領域' },
      { agentId: 'coder', reason: '実装・修正作業が得意' },
    ];
  }
  if (/提案書|企画書|資料|見積/.test(text)) {
    return [
      { agentId: 'director', reason: '資料の構成設計が担当領域' },
      { agentId: 'writer', reason: '本文の執筆が得意' },
    ];
  }
  if (/請求|経理|支払|振込|入金/.test(text)) {
    return [{ agentId: 'accountant', reason: '経理・支払管理が担当領域' }];
  }
  return [
    { agentId: 'secretary', reason: '仕事の整理・段取りが担当領域' },
    { agentId: 'writer', reason: '文章化・下書き作成が得意' },
  ];
}

/**
 * ルームのAI呼び出し用コンテキスト(会話型AIのシステム情報)。
 * タスク情報(名前・カテゴリ・優先度・期限・担当)+元依頼全文+会話履歴+最新成果物を渡すため、
 * ユーザーは自然な日本語だけで「もっと丁寧に」「別案を3つ」などの続きの指示ができる
 */
function buildRoomContext(taskId: string): string {
  const s = useOffice.getState();
  const task = s.tasks.find((t) => t.id === taskId);
  const room = s.taskRooms[taskId];
  const parts: string[] = [];
  if (task) {
    const assignee = s.agents.find((a) => a.id === task.assigneeId);
    parts.push(
      `【タスク情報】タスク名: ${task.title} / カテゴリ: ${task.category ?? '未分類'} / 優先度: ${task.priority} / 期限: ${task.deadline ? task.deadline.slice(0, 10) : '未設定'} / 担当AI: ${assignee?.name ?? '未設定'}`,
    );
  }
  if (room?.sourceRequest) parts.push(`【元の指示・依頼内容(全文)】\n${room.sourceRequest}`);
  const recent = (room?.messages ?? []).slice(-12);
  if (recent.length > 0) parts.push(`【この案件のこれまでの会話】\n${recent.map((m) => `${m.role === 'user' ? '社長' : 'AI'}: ${m.content}`).join('\n')}`);
  const latest = room?.artifacts.find((a) => a.isLatest);
  if (latest) parts.push(`【現在の最新版成果物(${latest.kind}): ${latest.title}】\n${latest.content}`);
  return parts.join('\n\n').slice(0, 20000);
}

/** taskworkの結果をルームへ反映(回答はチャットへ。提案・成果物は返されたときだけ更新) */
function applyTaskWork(taskId: string, out: TaskWorkOutput, agentId: string) {
  const s = useOffice.getState();
  if (out.suggestions) s.setRoomSuggestions(taskId, out.suggestions);
  if (out.artifact) s.addRoomArtifact(taskId, out.artifact);
  s.addRoomMessage(taskId, { role: 'ai', content: out.reply, agentId });
}

// 実行中ルームの二重送信防止
const busyRooms = new Set<string>();
export const isRoomBusy = (taskId: string) => busyRooms.has(taskId);

/**
 * 案件専用チャットへの送信。会話はこのタスクのルーム内にのみ保存され、
 * 他の案件・社長指示チャットとは混ざらない。SNSディレクター等への発注も行わない。
 */
export async function sendTaskRoomMessage(taskId: string, text: string): Promise<void> {
  const trimmed = text.trim();
  if (!trimmed || busyRooms.has(taskId)) return;
  busyRooms.add(taskId);
  try {
    const s = useOffice.getState();
    s.ensureTaskRoom(taskId);
    const task = s.tasks.find((t) => t.id === taskId);
    const agentId = task?.assigneeId ?? 'secretary';
    useOffice.getState().addRoomMessage(taskId, { role: 'user', content: trimmed });
    const { data, usage } = await callAgent('taskwork', trimmed, buildRoomContext(taskId));
    useOffice.getState().recordRunUsage(agentId, usage, taskId);
    applyTaskWork(taskId, data as TaskWorkOutput, agentId);
  } catch (e) {
    const message = e instanceof Error ? e.message : 'AI実行に失敗しました';
    useOffice.getState().addRoomMessage(taskId, { role: 'ai', content: `申し訳ありません、処理に失敗しました(${message})。少し待ってからもう一度お試しください。` });
  } finally {
    busyRooms.delete(taskId);
  }
}

/** AI提案エリアの生成(対応方針・確認事項・次のアクション・不足情報の整理のみ) */
export async function generateTaskSuggestions(taskId: string): Promise<void> {
  if (busyRooms.has(taskId)) return;
  busyRooms.add(taskId);
  try {
    const s = useOffice.getState();
    s.ensureTaskRoom(taskId);
    const task = s.tasks.find((t) => t.id === taskId);
    const agentId = task?.assigneeId ?? 'secretary';
    const { data, usage } = await callAgent('taskwork', 'このタスクの対応方針・確認すべきこと・次のアクション・不足している情報を整理してください。', buildRoomContext(taskId));
    useOffice.getState().recordRunUsage(agentId, usage, taskId);
    applyTaskWork(taskId, data as TaskWorkOutput, agentId);
    useOffice.getState().addRoomActivity(taskId, 'AI提案(対応方針・確認事項・次のアクション)を作成しました');
  } catch {
    useOffice.getState().addRoomMessage(taskId, { role: 'ai', content: 'AI提案の作成に失敗しました。少し待ってからもう一度お試しください。' });
  } finally {
    busyRooms.delete(taskId);
  }
}

/**
 * 元の依頼が「返事の文を考えて欲しい」等の場合、ルーム初回表示で自動下書きを作成する。
 * SNSディレクター等への発注や外部送信は行わない(下書きの保存まで)。
 */
export async function autoDraftIfRequested(taskId: string): Promise<void> {
  const s = useOffice.getState();
  const room = s.taskRooms[taskId];
  if (!room || room.autoDrafted || busyRooms.has(taskId)) return;
  if (!wantsDraft(room.sourceRequest)) {
    return;
  }
  s.markRoomAutoDrafted(taskId); // 先にマークして二重実行を防止
  busyRooms.add(taskId);
  try {
    const task = s.tasks.find((t) => t.id === taskId);
    const agentId = task?.assigneeId ?? 'secretary';
    // 元の依頼文そのものをリクエストとして渡す(下書き指示は依頼文に含まれている)
    const { data, usage } = await callAgent('taskwork', room.sourceRequest, buildRoomContext(taskId));
    useOffice.getState().recordRunUsage(agentId, usage, taskId);
    applyTaskWork(taskId, data as TaskWorkOutput, agentId);
    useOffice.getState().addRoomActivity(taskId, '元の依頼内容から下書きを自動作成しました(送信はしていません)');
  } catch {
    useOffice.getState().markRoomAutoDrafted(taskId);
  } finally {
    busyRooms.delete(taskId);
  }
}

const reviewPanelText = (p: ReviewPanelOutput): string =>
  [
    `\n🏛 レビュー会議(3人の視点)`,
    `・🧐 疑り深い投資家\n 良い点: ${p.investor.good}\n 厳しい指摘: ${p.investor.harsh}`,
    `・🛋 面倒くさがりの読者\n 良い点: ${p.lazyReader.good}\n 厳しい指摘: ${p.lazyReader.harsh}`,
    `・🕰 1年後の自分\n 良い点: ${p.futureSelf.good}\n 厳しい指摘: ${p.futureSelf.harsh}`,
  ].join('\n');

const insightsText = (i: CeoAdviceOutput['userInsights']): string => {
  const rows = [
    ['判断基準', i.criteria],
    ['価値観', i.values],
    ['よく使う言葉', i.phrases],
    ['思考パターン', i.patterns],
    ['得意', i.strengths],
    ['苦手', i.weaknesses],
  ].filter(([, v]) => (v as string[]).length > 0) as [string, string[]][];
  if (rows.length === 0) return '';
  return `\n💡 今回の相談から見えた特徴\n${rows.map(([k, v]) => `・${k}: ${v.join(' / ')}`).join('\n')}`;
};

/** 経営相談モード: ①需要②勝てる理由③最悪のケース④最初の一歩 + レビュー会議 */
export async function runCeoAdvice(request: string): Promise<void> {
  const s = useOffice.getState();
  s.setAgentRunActivity('ceo', '経営相談の論点を整理しています', 'desk', 30);
  pushLog('ceo', `社長からの経営相談を受領しました: 「${request.slice(0, 50)}」`);
  const profile = s.ceoProfile;
  const profileNote =
    profile.updatedAt && (profile.criteria.length || profile.patterns.length)
      ? `これまでの会話から把握している社長の特徴: 判断基準=${profile.criteria.join('、') || '不明'} / 思考パターン=${profile.patterns.join('、') || '不明'}`
      : undefined;
  const { data, usage } = await callAgent('advise', request, profileNote);
  const a = data as CeoAdviceOutput;
  useOffice.getState().recordRunUsage('ceo', usage, null);
  useOffice.getState().mergeCeoProfile(a.userInsights);

  const content = [
    `ご相談ありがとうございます。結論は出しません — 判断材料を整理しました。`,
    `\n① 需要\n${a.demand.map((l) => `・${l}`).join('\n')}`,
    `\n② 勝てる理由\n${a.winningReason.map((l) => `・${l}`).join('\n')}`,
    `\n③ 最悪のケース\n${a.worstCase.map((l) => `・${l}`).join('\n')}`,
    `\n④ 最初の一歩(今日30分以内)\n⭕ ${a.firstStep.action}\n${a.firstStep.breakdown.map((b) => ` - ${b}`).join('\n')}`,
    reviewPanelText(a.reviewPanel),
    insightsText(a.userInsights),
    `\n判断は社長にお任せします。制作に進む場合は「◯◯を作って」とご依頼ください。担当ディレクターへ引き継ぎます。`,
  ]
    .filter(Boolean)
    .join('\n');
  useOffice.setState((st) => ({ chat: [...st.chat, { id: uid('chat'), role: 'ceo_ai' as const, content, timestamp: nowIso() }] }));
  useOffice.getState().setAgentRunActivity('ceo', '', 'desk', 0);
  pushLog('ceo', '経営相談の判断材料(需要・勝てる理由・最悪のケース・最初の一歩)を整理しました。', 'success');
}

/** ディープリサーチの5つの確認質問(作業前に必ず確認する) */
export const RESEARCH_QUESTIONS = [
  'なぜ調べたいのですか?(背景)',
  '誰へ提案しますか?(読み手)',
  '判断したいことは何ですか?(意思決定)',
  '対象は日本市場ですか?(範囲)',
  'どこまで深く調べますか?(概要レベル / 意思決定レベル)',
];

/** 回答待ちのリサーチ(テーマ提示済み・5つの質問へ未回答)を取得 */
export function getPendingResearch(): { messageId: string; theme: string } | null {
  const chat = useOffice.getState().chat;
  for (let i = chat.length - 1; i >= 0; i--) {
    const m = chat[i];
    if (m.role === 'ceo_user') continue;
    if (m.research && !m.research.answered) return { messageId: m.id, theme: m.research.theme };
    return null;
  }
  return null;
}

/** ディープリサーチ開始: まず5つの質問(作業はしない) */
export function startCeoResearch(request: string): void {
  const theme = request.replace(/^テーマ[::]\s*/, '').trim() || request;
  pushLog('ceo', `ディープリサーチのテーマを受領しました: 「${theme.slice(0, 40)}」調査の前に前提を確認します。`);
  const content = [
    `テーマ「${theme}」ですね。精度の低い調査は判断を誤らせるため、作業前に5点だけ確認させてください。`,
    ...RESEARCH_QUESTIONS.map((q, i) => `${i + 1}. ${q}`),
    `\nまとめてご回答ください(番号ごとでなくても構いません)。ご回答後に調査を開始します。`,
  ].join('\n');
  useOffice.setState((st) => ({
    chat: [
      ...st.chat,
      { id: uid('chat'), role: 'ceo_ai' as const, content, research: { theme, answered: false }, timestamp: nowIso() },
    ],
  }));
}

/** 5つの質問への回答を受けて調査を実行し、判断材料を整理する(結論は出さない) */
export async function runCeoResearch(messageId: string, theme: string, answers: string): Promise<void> {
  useOffice.setState((st) => ({
    chat: st.chat.map((m) => (m.id === messageId && m.research ? { ...m, research: { ...m.research, answered: true } } : m)),
  }));
  const s = useOffice.getState();
  s.setAgentRunActivity('ceo', 'ディープリサーチを実行中', 'desk', 40);
  pushLog('ceo', '前提を確認しました。判断材料の調査・整理を開始します。');
  const { data, usage } = await callAgent('research', `テーマ: ${theme}\n\n前提の確認への回答:\n${answers}`);
  const r = data as CeoResearchOutput;
  useOffice.getState().recordRunUsage('ceo', usage, null);

  const content = [
    `調査結果をまとめました。CEOとして結論は出しません — 判断材料の整理です。`,
    `\n① 今わかっている事実\n${r.facts.map((f) => `・${f}`).join('\n')}`,
    `\n② 賛成意見\n${r.pros.map((p) => `・${p.point}\n (根拠: ${p.basis})`).join('\n')}`,
    `\n③ 反対意見\n${r.cons.map((c) => `・${c.point}\n (根拠: ${c.basis})`).join('\n')}`,
    `\n④ 一次情報(確認先)\n${r.sources.map((src) => `・[${src.type}] ${src.title}\n ${src.url}`).join('\n')}`,
    r.cautions.length ? `\n⚠ 確認時の注意\n${r.cautions.map((c) => `・${c}`).join('\n')}` : '',
    reviewPanelText(r.reviewPanel),
    `\n判断は社長にお任せします。追加で深掘りしたい論点があればお知らせください。`,
  ]
    .filter(Boolean)
    .join('\n');
  useOffice.setState((st) => ({ chat: [...st.chat, { id: uid('chat'), role: 'ceo_ai' as const, content, timestamp: nowIso() }] }));
  useOffice.getState().setAgentRunActivity('ceo', '', 'desk', 0);
  pushLog('ceo', 'ディープリサーチの判断材料(事実・賛成・反対・一次情報)を整理しました。', 'success');
}

/**
 * CEOチャットの統一入口。回答待ち(制作の確認/リサーチの質問)を処理し、
 * それ以外は 経営相談 / ディープリサーチ / 制作依頼 へ振り分ける
 */
export async function handleCeoMessage(text: string): Promise<void> {
  const pendingC = getPendingConsult();
  if (pendingC) {
    await answerCeoConsultation(pendingC.messageId, text);
    return;
  }
  const pendingR = getPendingResearch();
  if (pendingR) {
    await runCeoResearch(pendingR.messageId, pendingR.theme, text);
    return;
  }
  const mode = detectCeoMode(text);
  if (mode === 'tasks') {
    // AI秘書: 箇条書き・名詞句はタスク候補として登録のみ(AI社員への依頼はしない)
    const items = parseBulletTasks(text) ?? [text.trim()];
    registerTasksFromChat(items, text);
    return;
  }
  if (mode === 'research') {
    startCeoResearch(text);
    return;
  }
  if (mode === 'advice') {
    await runCeoAdvice(text);
    return;
  }
  await startCeoConsultation(text);
}

/**
 * CEOへの依頼の入口。
 * CEO(経営判断)が100〜200字で一次回答し、専門ディレクター(制作判断)が会話を引き継ぐ。
 * 判断根拠などの詳細は「詳しく見る」で展開。確認質問がなければ実行計画の作成まで進む。
 * @returns 'asked'=質問への回答待ち / 'planned'=実行計画を作成済み
 */
export async function startCeoConsultation(request: string): Promise<'asked' | 'planned'> {
  const store = useOffice.getState();
  const caseDef = CASE_DEFS[classifyRequest(request)];
  store.setAgentRunActivity('ceo', '依頼の目的を整理しています', 'desk', 15);
  pushLog('ceo', `社長の依頼を受領しました: 「${request.slice(0, 50)}」経営判断を行い、担当ディレクターへ引き継ぎます。`);

  const { data, usage } = await callAgent('consult', request, undefined, undefined, caseDef.label);
  const consult = data as CeoConsultOutput;
  useOffice.getState().recordRunUsage('ceo', usage, null);

  // ① CEO: 経営判断の短い一次回答(詳細は「詳しく見る」)
  const ceoMsg: ChatMessage = {
    id: uid('chat'),
    role: 'ceo_ai',
    content: consult.shortReply,
    consult: { request, questions: [], answered: true, detail: consultDetail(consult) },
    timestamp: nowIso(),
  };
  useOffice.setState((s) => ({ chat: [...s.chat, ceoMsg] }));
  pushSignal('ceo', caseDef.directorAgentId, `${caseDef.label}を引き継ぎ`);

  // ② 専門ディレクター: 制作判断として会話を引き継ぐ(確認質問もディレクターから)
  await sleep(900);
  const directorMsg: ChatMessage = {
    id: uid('chat'),
    role: 'ceo_ai',
    content: consult.directorComment,
    speakerId: caseDef.directorAgentId,
    speakerName: caseDef.directorLabel,
    consult: { request, questions: consult.questions, answered: consult.questions.length === 0 },
    timestamp: nowIso(),
  };
  useOffice.setState((s) => ({ chat: [...s.chat, directorMsg] }));
  pushLog(caseDef.directorAgentId, `CEOから「${caseDef.label}」を引き継ぎました。制作判断を担当します。`, 'info');

  if (consult.questions.length > 0) {
    useOffice.getState().setAgentRunActivity(caseDef.directorAgentId, '社長への確認事項の回答待ち', 'desk', 40);
    pushLog(caseDef.directorAgentId, `成果物の質に影響する確認事項${consult.questions.length}件を社長へ質問しました。`, 'info');
    return 'asked';
  }
  pushLog(caseDef.directorAgentId, '制作内容を確定しました。実行計画の作成へ進みます。', 'success');
  await createRunPlan(request);
  return 'planned';
}

/** 確認質問への回答を受けて実行計画を作成する */
export async function answerCeoConsultation(messageId: string, answer: string): Promise<string> {
  const pending = getPendingConsult();
  const request = pending?.messageId === messageId ? pending.request : (pending?.request ?? answer);
  markConsultAnswered(messageId);
  pushLog('ceo', '社長からの回答を受領しました。内容を反映して実行計画を作成します。', 'success');
  const combined = `${request}\n\n【社長からの補足(確認への回答)】\n${answer}`;
  return createRunPlan(combined);
}

/** 「お任せで進める」: 質問には回答せず、CEOの妥当な仮定で進める */
export async function proceedWithoutAnswers(messageId: string): Promise<string> {
  const pending = getPendingConsult();
  const request = pending?.messageId === messageId ? pending.request : (pending?.request ?? '');
  markConsultAnswered(messageId);
  pushLog('ceo', '社長より一任いただきました。妥当な仮定を明記して実行計画を作成します。', 'info');
  const combined = `${request}\n\n【社長からの補足】確認事項は一任します。妥当な仮定を明記して進めてください。`;
  return createRunPlan(combined);
}

/** ① 社長の依頼 → CEO AIが案件種別を判定し、実行計画を作成(実行はまだしない) */
export async function createRunPlan(request: string): Promise<string> {
  const store = useOffice.getState();
  store.setAgentRunActivity('ceo', '社長の依頼を分析しています', 'desk', 20);
  pushLog('ceo', `社長の依頼を受領しました: 「${request.slice(0, 50)}」分析を開始します。`);

  // 案件種別の判定と担当部署への振り分け(Web制作/SNS/デザイン/ドキュメントで完全分岐)
  const caseDef = CASE_DEFS[classifyRequest(request)];
  pushLog('ceo', `案件種別を「${caseDef.label}」と判定しました。${caseDef.departmentLabel}へ振り分けます。`, 'success');
  pushSignal('ceo', caseDef.steps[0].agentId, `${caseDef.label}を依頼`);

  const { data, usage } = await callAgent('plan', request, undefined, undefined, caseDef.label);
  const plan = data as ExecutionPlanOutput;

  // タスクは案件種別の標準フローから決定的に構成する(AI計画は説明資料として保持)
  const mkStepTask = (i: number, st: PipelineStep): RunTask => ({
    id: `rt_${i}`,
    title: st.title,
    description: st.description,
    assignedAgentId: st.agentId,
    kind: st.kind,
    status: 'pending',
    dependsOn: i === 0 ? [] : [`rt_${i - 1}`],
    startedAt: null,
    completedAt: null,
    retryCount: 0,
    maxRetries: 2,
    estimatedTokens: 2400 + i * 400,
    actualInputTokens: 0,
    actualOutputTokens: 0,
    estimatedCostJPY: plan.tasks[i]?.estimatedCostJPY ?? 0,
    actualCostJPY: 0,
    model: null,
    provider: null,
    error: null,
    reviewStatus: 'none',
    deliverableId: null,
  });
  const reviewTask: RunTask = {
    ...mkStepTask(caseDef.steps.length, {
      kind: 'content',
      agentId: 'reviewer',
      title: '品質レビュー',
      description: '整合性・誇大表現・誤字・要確認事項をチェック',
      deliverableType: 'review',
      deliverableTitle: 'レビュー報告書',
      activity: '成果物を確認中',
    }),
    kind: 'reviewer',
    assignedAgentId: 'reviewer',
  };

  const run: AgentRun = {
    id: uid('run'),
    request,
    caseType: caseDef.type,
    caseLabel: caseDef.label,
    planMarkdown: planToMarkdown(plan),
    planJson: JSON.stringify(plan, null, 2),
    status: 'awaiting_approval',
    tasks: [...caseDef.steps.map((st, i) => mkStepTask(i, st)), reviewTask],
    deliverableIds: [],
    totalInputTokens: usage.inputTokens,
    totalOutputTokens: usage.outputTokens,
    totalCostJpy: usageToJpy(usage),
    isMock: usage.isMock,
    revisionCount: 0,
    maxRevisions: 1,
    currentActivity: '社長の承認待ちです(承認までAIは実行されません)',
    error: null,
    createdAt: nowIso(),
    completedAt: null,
  };

  const store2 = useOffice.getState();
  store2.recordRunUsage('ceo', usage, null);
  store2.addAgentRun(
    run,
    `案件種別を「${caseDef.label}」と判定し、${caseDef.departmentLabel}へ振り分けました${usage.isMock ? '(デモ生成)' : ''}。実行計画をご確認のうえ「この内容で開始」を押してください。開始まで実行しません。`,
  );
  store2.setAgentRunActivity('ceo', '実行計画の承認待ち', 'desk', 100);
  pushLog('ceo', `実行計画を作成しました(タスク${run.tasks.length}件)。社長の承認待ちです。`, 'success');
  return run.id;
}

// 実行中ランの管理(ページリロードで中断された「孤児ラン」の検出用)
const activeRuns = new Set<string>();
export const isRunActive = (runId: string) => activeRuns.has(runId);

const getRun = (runId: string) => useOffice.getState().agentRuns.find((r) => r.id === runId);
const isStopped = (runId: string) => {
  const r = getRun(runId);
  return !r || r.status === 'cancelled' || r.status === 'failed';
};

function addUsageToRun(runId: string, taskId: string, usage: RunUsage) {
  const s = useOffice.getState();
  s.recordRunUsage(taskIdToAgent(runId, taskId), usage, null);
  const run = getRun(runId);
  if (!run) return;
  s.updateAgentRun(runId, {
    totalInputTokens: run.totalInputTokens + usage.inputTokens,
    totalOutputTokens: run.totalOutputTokens + usage.outputTokens,
    totalCostJpy: run.totalCostJpy + usageToJpy(usage),
  });
  s.updateRunTask(runId, taskId, {
    actualInputTokens: usage.inputTokens,
    actualOutputTokens: usage.outputTokens,
    actualCostJPY: Math.round(usageToJpy(usage)),
    model: usage.model,
    provider: usage.provider,
  });
}

function taskIdToAgent(runId: string, taskId: string): string {
  return getRun(runId)?.tasks.find((t) => t.id === taskId)?.assignedAgentId ?? 'ceo';
}

/** コスト上限チェック: 超過なら停止して承認を求める(trueなら継続可) */
function checkCostCap(runId: string, ignoreCap: boolean): boolean {
  if (ignoreCap) return true;
  const s = useOffice.getState();
  const cap = s.settings.aiRunCostCapJpy ?? 500;
  const run = getRun(runId);
  if (!run) return false;
  if (run.totalCostJpy >= cap) {
    s.updateAgentRun(runId, {
      status: 'awaiting_cost_approval',
      currentActivity: `AI利用料が上限(¥${cap.toLocaleString()})に達したため停止しました。続行には承認が必要です`,
    });
    pushLog('ceo', `AI利用料が実行上限に達したため処理を停止しました。社長の承認をお待ちします。`, 'warning');
    return false;
  }
  return true;
}

/** ② 承認後の実行(resume=trueで途中から再開 / ignoreCapで上限超過を承認済みとして続行) */
export async function executeRun(runId: string, opts: { ignoreCap?: boolean } = {}): Promise<void> {
  if (activeRuns.has(runId)) return; // 二重実行防止
  activeRuns.add(runId);
  try {
    await executeRunInner(runId, opts);
  } finally {
    activeRuns.delete(runId);
  }
}

async function executeRunInner(runId: string, opts: { ignoreCap?: boolean } = {}): Promise<void> {
  const s = () => useOffice.getState();
  const run = getRun(runId);
  if (!run) return;
  s().updateAgentRun(runId, { status: 'running', error: null });

  const findTask = (kind: RunTask['kind']) => getRun(runId)!.tasks.find((t) => t.kind === kind);
  const doneDeliverable = (type: DeliverableType) =>
    s().deliverables.find((d) => d.runId === runId && d.type === type);

  const caseLabel = run.caseLabel;

  const runStep = async <T>(
    kind: RunKind,
    taskKind: RunTask['kind'],
    activity: string,
    context: string | undefined,
    revisionNotes: string | undefined,
    agentIdOverride?: string,
  ): Promise<{ data: T; usage: RunUsage; taskId: string } | null> => {
    if (isStopped(runId)) return null;
    if (!checkCostCap(runId, opts.ignoreCap ?? false)) return null;
    const task = findTask(taskKind);
    const taskId = task?.id ?? `rt_${taskKind}`;
    const agentId = agentIdOverride ?? task?.assignedAgentId ?? taskKind;
    s().updateRunTask(runId, taskId, { status: 'running', startedAt: nowIso() });
    s().updateAgentRun(runId, { currentActivity: activity });
    s().setAgentRunActivity(agentId, activity, 'project', 30);
    pushLog(agentId, activity);
    try {
      const result = await callAgent(kind, getRun(runId)!.request, context, revisionNotes, caseLabel);
      addUsageToRun(runId, taskId, result.usage);
      s().updateRunTask(runId, taskId, { status: 'done', completedAt: nowIso() });
      s().setAgentRunActivity(agentId, '', 'desk', 0);
      return { data: result.data as T, usage: result.usage, taskId };
    } catch (e) {
      const message = e instanceof Error ? e.message : 'AI実行に失敗しました';
      const t = findTask(taskKind);
      if (t && t.retryCount < t.maxRetries) {
        s().updateRunTask(runId, taskId, { retryCount: t.retryCount + 1 });
        pushLog(agentId, `エラーが発生したため再試行します(${t.retryCount + 1}/${t.maxRetries}): ${message}`, 'warning');
        return runStep(kind, taskKind, activity, context, revisionNotes);
      }
      s().updateRunTask(runId, taskId, { status: 'failed', error: message });
      s().updateAgentRun(runId, { status: 'failed', error: message, currentActivity: 'エラーで停止しました。再実行できます' });
      s().setAgentRunActivity(agentId, '', 'desk', 0);
      pushLog(agentId, `処理に失敗しました: ${message}`, 'error');
      return null;
    }
  };

  const request = run.request;

  /** 完了処理(共通): アナウンス + CEOからの報告DM */
  const finishRun = (approve: boolean, deliverableTitles: string[]) => {
    s().updateAgentRun(runId, {
      status: 'done',
      completedAt: nowIso(),
      currentActivity: approve ? 'レビュー承認済み。最終成果物の確定は成果物画面から行えます' : '要修正のまま完了しました',
    });
    const finalRun = getRun(runId)!;
    useOffice.setState((st) => ({
      announcements: [
        { id: uid('ann'), message: `成果物が完成しました(${finalRun.isMock ? 'デモ生成' : 'AI生成'})。成果物画面でご確認ください`, tone: 'success' as const, createdAt: nowIso() },
        ...st.announcements,
      ].slice(0, 6),
      directChats: {
        ...st.directChats,
        ceo: [
          ...(st.directChats.ceo ?? []),
          {
            id: uid('dm'),
            role: 'agent' as const,
            content: `ご依頼の件、完了しました。\n結論: ${deliverableTitles.join('・')}の${deliverableTitles.length}点が完成しています。\n根拠: レビュー${approve ? '承認済み' : 'は要修正1件(上限到達のため人間確認へ)'}、総コスト¥${Math.round(finalRun.totalCostJpy).toLocaleString()}。\n提案: 成果物画面でご確認のうえ、「最終版に設定」をお願いします。`,
            timestamp: nowIso(),
          },
        ].slice(-100),
      },
      unread: { ...st.unread, ceo: (st.unread.ceo ?? 0) + 1 },
    }));
    pushLog('ceo', '全工程が完了しました。成果物を承認待ちとして保存しています。', 'success');
  };

  /** 案件種別パイプライン(SNS/デザイン/ドキュメント。Web制作フローとは完全分岐) */
  const executeCasePipeline = async (def: CaseDef): Promise<void> => {
    let prevAgent = 'ceo';
    const produced: { step: PipelineStep; dlv: Deliverable }[] = [];
    let revisionTarget: { dlv: Deliverable; step: PipelineStep } | null = null;

    for (const stp of def.steps) {
      // 再開時: 既に成果物があればスキップ
      let dlv = doneDeliverable(stp.deliverableType);
      if (!dlv) {
        pushSignal(prevAgent, stp.agentId, stp.title.length > 14 ? `${stp.title.slice(0, 13)}…` : stp.title);
        const context = produced.length > 0 ? produced.map((p) => p.dlv.markdown).join('\n\n---\n\n') : getRun(runId)!.planMarkdown;
        const step = await runStep<unknown>(stp.kind, stp.kind, stp.activity, context, undefined);
        if (!step) return;
        dlv = makeDeliverable(runId, step.taskId, stp.deliverableTitle, stp.deliverableType, stp.agentId, stepToMarkdown(stp, step.data), step.data, request, step.usage);
        s().addDeliverable(dlv);
        s().updateRunTask(runId, step.taskId, { deliverableId: dlv.id });
        pushLog(stp.agentId, `「${stp.deliverableTitle}」が完成しました。次の工程へ引き渡します。`, 'success');
      }
      produced.push({ step: stp, dlv });
      if (stp.kind === def.revisionKind) revisionTarget = { dlv, step: stp };
      prevAgent = stp.agentId;
    }

    // レビュアーAI: 品質確認(差し戻しは1回まで)
    pushSignal(prevAgent, 'reviewer', 'レビューを依頼');
    const allMd = () => produced.map((p) => (useOffice.getState().deliverables.find((d) => d.id === p.dlv.id) ?? p.dlv).markdown).join('\n\n---\n\n');
    const review1 = await runStep<ReviewResultOutput>('reviewer', 'reviewer', `${def.label}の成果物を確認中`, allMd(), undefined);
    if (!review1) return;
    let reviewData = review1.data;
    const reviewDlv = makeDeliverable(runId, review1.taskId, 'レビュー報告書', 'review', 'reviewer', reviewToMarkdown(reviewData), reviewData, request, review1.usage);
    s().addDeliverable(reviewDlv);

    if (!reviewData.approve && revisionTarget) {
      const currentRun = getRun(runId)!;
      if (currentRun.revisionCount >= currentRun.maxRevisions) {
        s().updateDeliverable(revisionTarget.dlv.id, { status: 'needs_fix' });
        s().updateAgentRun(runId, { status: 'done', completedAt: nowIso(), currentActivity: '修正上限に達したため、要修正のまま完了しました。成果物画面から編集または修正依頼できます' });
        return;
      }
      s().updateAgentRun(runId, { status: 'revising', revisionCount: currentRun.revisionCount + 1, currentActivity: 'レビュー指摘を反映した修正版を作成中' });
      s().updateDeliverable(revisionTarget.dlv.id, { status: 'needs_fix' });
      pushSignal('reviewer', revisionTarget.step.agentId, '修正指示を送付');
      pushLog('reviewer', `重大な問題${reviewData.criticalIssues.length}件を検出しました。${revisionTarget.step.agentId === 'designer' ? 'デザイナーAI' : 'ライターAI'}へ修正を依頼します。`, 'warning');

      const notes = [...reviewData.criticalIssues, ...reviewData.minorIssues].join('\n');
      const revision = await runStep<unknown>(revisionTarget.step.kind, revisionTarget.step.kind, 'レビュー指摘を反映した修正版を作成中', produced[0].dlv.markdown, notes);
      if (!revision) return;
      s().saveDeliverableVersion(revisionTarget.dlv.id, stepToMarkdown(revisionTarget.step, revision.data), 'ai', `レビュー指摘${reviewData.criticalIssues.length + reviewData.minorIssues.length}件を反映した修正版`);
      s().updateDeliverable(revisionTarget.dlv.id, { json: JSON.stringify(revision.data, null, 2) });

      pushSignal(revisionTarget.step.agentId, 'reviewer', '修正版のレビューを依頼');
      const review2 = await runStep<ReviewResultOutput>('reviewer', 'reviewer', '修正版を確認中', allMd(), '修正版の確認です');
      if (!review2) return;
      reviewData = review2.data;
      s().saveDeliverableVersion(reviewDlv.id, reviewToMarkdown(reviewData), 'ai', '修正版の再レビュー');
    }

    // 完了処理
    const finalStatus = reviewData.approve ? ('reviewed' as const) : ('needs_fix' as const);
    for (const p of produced) {
      s().updateDeliverable(p.dlv.id, { status: p.dlv.id === revisionTarget?.dlv.id ? finalStatus : 'reviewed' });
    }
    finishRun(reviewData.approve, [...produced.map((p) => p.step.deliverableTitle), 'レビュー報告書']);
  };

  // 案件種別によりパイプラインを分岐(SNS/デザイン/ドキュメントはWeb制作と完全分岐)
  const caseDef = run.caseType ? CASE_DEFS[run.caseType as keyof typeof CASE_DEFS] : undefined;
  if (caseDef && caseDef.pipeline !== 'web') {
    await executeCasePipeline(caseDef);
    return;
  }

  // --- ディレクターAI: 要件整理(既に成果物があれば再開時はスキップ) ---
  let directorDlv = doneDeliverable('requirements');
  if (!directorDlv) {
    pushSignal('ceo', 'director', '要件整理を依頼');
    const step = await runStep<DirectorDocOutput>('director', 'director', 'ターゲットとサイト構成を整理中', run.planMarkdown, undefined);
    if (!step) return;
    directorDlv = makeDeliverable(runId, step.taskId, '要件整理書', 'requirements', 'director', directorToMarkdown(step.data), step.data, request, step.usage);
    s().addDeliverable(directorDlv);
    s().updateRunTask(runId, step.taskId, { deliverableId: directorDlv.id });
    pushLog('director', '要件整理書が完成しました。ライターAIへ引き渡します。', 'success');
  }

  // --- ライターAI: 原稿作成 ---
  let writerDlv = doneDeliverable('copy');
  if (!writerDlv) {
    pushSignal('director', 'writer', '設計資料を引き渡し');
    const step = await runStep<WriterCopyOutput>('writer', 'writer', 'キャッチコピーと原稿を作成中', directorDlv.markdown, undefined);
    if (!step) return;
    writerDlv = makeDeliverable(runId, step.taskId, 'Web原稿・キャッチコピー', 'copy', 'writer', writerToMarkdown(step.data), step.data, request, step.usage);
    s().addDeliverable(writerDlv);
    s().updateRunTask(runId, step.taskId, { deliverableId: writerDlv.id });
    pushLog('writer', '原稿が完成しました。レビュアーAIへ確認を依頼します。', 'success');
  }

  // --- レビュアーAI: 品質確認(→重大問題があれば修正ループ、上限1回) ---
  pushSignal('writer', 'reviewer', 'レビューを依頼');
  const review1 = await runStep<ReviewResultOutput>('reviewer', 'reviewer', '要件と文章を確認中', `${directorDlv.markdown}\n\n---\n\n${writerDlv.markdown}`, undefined);
  if (!review1) return;
  let reviewData = review1.data;
  let reviewDlv = makeDeliverable(runId, review1.taskId, 'レビュー報告書', 'review', 'reviewer', reviewToMarkdown(reviewData), reviewData, request, review1.usage);
  s().addDeliverable(reviewDlv);

  if (!reviewData.approve) {
    const currentRun = getRun(runId)!;
    if (currentRun.revisionCount >= currentRun.maxRevisions) {
      // 修正ループ上限: 無限ループ防止のためここで終了し、人間の判断に委ねる
      s().updateDeliverable(writerDlv.id, { status: 'needs_fix' });
      s().updateAgentRun(runId, { status: 'done', completedAt: nowIso(), currentActivity: '修正上限に達したため、要修正のまま完了しました。成果物画面から編集または修正依頼できます' });
      return;
    }
    s().updateAgentRun(runId, { status: 'revising', revisionCount: currentRun.revisionCount + 1, currentActivity: 'レビュー指摘を反映した修正版を作成中' });
    s().updateDeliverable(writerDlv.id, { status: 'needs_fix' });
    pushSignal('reviewer', 'writer', '修正指示を送付');
    pushLog('reviewer', `重大な問題${reviewData.criticalIssues.length}件を検出しました。ライターAIへ修正を依頼します。`, 'warning');

    const notes = [...reviewData.criticalIssues, ...reviewData.minorIssues].join('\n');
    const revision = await runStep<WriterCopyOutput>('writer', 'writer', 'レビュー指摘を反映した修正版を作成中', directorDlv.markdown, notes);
    if (!revision) return;
    s().saveDeliverableVersion(writerDlv.id, writerToMarkdown(revision.data), 'ai', `レビュー指摘${reviewData.criticalIssues.length + reviewData.minorIssues.length}件を反映した修正版`);
    s().updateDeliverable(writerDlv.id, { json: JSON.stringify(revision.data, null, 2) });

    // 修正版の再レビュー
    pushSignal('writer', 'reviewer', '修正版のレビューを依頼');
    const review2 = await runStep<ReviewResultOutput>('reviewer', 'reviewer', '修正版を確認中', `${directorDlv.markdown}\n\n---\n\n${useOffice.getState().deliverables.find((d) => d.id === writerDlv!.id)!.markdown}`, '修正版の確認です');
    if (!review2) return;
    reviewData = review2.data;
    s().saveDeliverableVersion(reviewDlv.id, reviewToMarkdown(reviewData), 'ai', '修正版の再レビュー');
  }

  // --- 完了処理 ---
  const finalStatus = reviewData.approve ? 'reviewed' : 'needs_fix';
  s().updateDeliverable(writerDlv.id, { status: finalStatus });
  s().updateDeliverable(directorDlv.id, { status: 'reviewed' });
  s().updateAgentRun(runId, {
    status: 'done',
    completedAt: nowIso(),
    currentActivity: reviewData.approve ? 'レビュー承認済み。最終成果物の確定は成果物画面から行えます' : '要修正のまま完了しました',
  });
  const finalRun = getRun(runId)!;
  useOffice.setState((st) => ({
    announcements: [
      { id: uid('ann'), message: `成果物が完成しました(${finalRun.isMock ? 'デモ生成' : 'AI生成'})。成果物画面でご確認ください`, tone: 'success' as const, createdAt: nowIso() },
      ...st.announcements,
    ].slice(0, 6),
    directChats: {
      ...st.directChats,
      ceo: [
        ...(st.directChats.ceo ?? []),
        {
          id: uid('dm'),
          role: 'agent' as const,
          content: `ご依頼の件、完了しました。\n結論: 要件整理書・Web原稿・レビュー報告書の3点が完成しています。\n根拠: レビュー${reviewData.approve ? '承認済み' : 'は要修正1件(上限到達のため人間確認へ)'}、総コスト¥${Math.round(finalRun.totalCostJpy).toLocaleString()}。\n提案: 成果物画面でご確認のうえ、「最終版に設定」をお願いします。`,
          timestamp: nowIso(),
        },
      ].slice(-100),
    },
    unread: { ...st.unread, ceo: (st.unread.ceo ?? 0) + 1 },
  }));
  pushLog('ceo', '全工程が完了しました。成果物を承認待ちとして保存しています。', 'success');
}
