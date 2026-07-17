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
import type { AgentRun, Deliverable, DeliverableType, RunTask } from './types';
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
