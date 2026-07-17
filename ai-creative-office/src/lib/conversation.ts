// ============================================================
// 会話生成レイヤー(Provider抽象化)
// - 今回は MockConversationProvider(ルールベース+ストア実データ)のみ
// - 将来 ClaudeConversationProvider / OpenAIConversationProvider /
//   GeminiConversationProvider を同じインターフェースで追加できる
// - AI社員は自分が持つ情報の範囲でのみ回答し、知らない情報は断定しない
// ============================================================
import { agentZoneLabel } from './office';
import type {
  Achievement,
  ActivityLog,
  Agent,
  AgentTalk,
  Approval,
  CeoAlert,
  CeoProposal,
  ChatAction,
  CompanySettings,
  DailyStat,
  ErrorRecord,
  Inquiry,
  Lead,
  Project,
  Task,
} from './types';
import { pickRandom, uid } from './utils';

// ---------- コンテキスト ----------

export interface AgentContext {
  agent: Agent;
  zoneLabel: string;
  currentTask: Task | null;
  queuedTasks: Task[];
  doneTodayLogs: ActivityLog[];
  warningLogs: ActivityLog[];
  assignedProjects: Project[];
  pendingApprovalCount: number; // このAIが申請中の承認
  ownCostJpy: number;
}

export interface CompanyContext {
  pendingApprovals: number;
  runningTasks: number;
  queuedTasks: number;
  errorAgents: Agent[];
  unresolvedErrors: number;
  fatiguedAgents: Agent[]; // 疲労度65以上
  reviewerQueue: number; // レビュアーAIの待ちタスク
  openInquiries: number;
  aiCostJpy: number;
  budgetJpy: number;
  todayTasksDone: number;
  usdJpyRate: number;
}

export interface AgentReply {
  content: string;
  actions: ChatAction[];
}

export interface ConversationProvider {
  generateAgentReply(question: string, ctx: AgentContext, company: CompanyContext): AgentReply;
  /** 提案すべき状況がなければ null を返す */
  generateCEOProposal(company: CompanyContext, agents: Agent[]): CeoProposal | null;
}

// ストアの形に依存しすぎないよう、必要なスライスだけを受け取る
export interface ConversationStateSlice {
  agents: Agent[];
  tasks: Task[];
  projects: Project[];
  logs: ActivityLog[];
  approvals: Approval[];
  errors: ErrorRecord[];
  inquiries: Inquiry[];
  leads: Lead[];
  dailyStats: DailyStat[];
  settings: CompanySettings;
}

export function buildAgentContext(s: ConversationStateSlice, agentId: string): AgentContext {
  const agent = s.agents.find((a) => a.id === agentId)!;
  const today = new Date().toISOString().slice(0, 10);
  return {
    agent,
    zoneLabel: agentZoneLabel(agent),
    currentTask: agent.currentTaskId ? s.tasks.find((t) => t.id === agent.currentTaskId) ?? null : null,
    queuedTasks: s.tasks.filter((t) => t.assigneeId === agentId && ['queued', 'backlog', 'preparing'].includes(t.status)),
    doneTodayLogs: s.logs.filter((l) => l.agentId === agentId && l.status === 'success' && l.timestamp.slice(0, 10) === today).slice(0, 3),
    warningLogs: s.logs.filter((l) => l.agentId === agentId && (l.status === 'warning' || l.status === 'error')).slice(0, 2),
    assignedProjects: s.projects.filter((p) => p.memberIds.includes(agentId)),
    pendingApprovalCount: s.approvals.filter((a) => a.requesterId === agentId && a.status === 'pending').length,
    ownCostJpy: agent.costUsd * s.settings.usdJpyRate,
  };
}

export function buildCompanyContext(s: ConversationStateSlice): CompanyContext {
  const reviewerQueue = s.tasks.filter(
    (t) => t.assigneeId === 'reviewer' && ['queued', 'backlog', 'running', 'preparing'].includes(t.status),
  ).length;
  return {
    pendingApprovals: s.approvals.filter((a) => a.status === 'pending').length,
    runningTasks: s.tasks.filter((t) => t.status === 'running').length,
    queuedTasks: s.tasks.filter((t) => t.status === 'queued').length,
    errorAgents: s.agents.filter((a) => a.status === 'error'),
    unresolvedErrors: s.errors.filter((e) => !e.resolved).length,
    fatiguedAgents: s.agents.filter((a) => (a.fatigue ?? 0) >= 65),
    reviewerQueue,
    openInquiries: s.inquiries.filter((i) => i.status === 'new').length,
    aiCostJpy: s.agents.reduce((acc, a) => acc + a.costUsd, 0) * s.settings.usdJpyRate,
    budgetJpy: s.settings.monthlyAiBudgetJpy,
    todayTasksDone: s.dailyStats.find((d) => d.date === new Date().toISOString().slice(0, 10))?.tasksCompleted ?? 0,
    usdJpyRate: s.settings.usdJpyRate,
  };
}

// ---------- モック実装 ----------

const yen = (v: number) => `¥${Math.round(v).toLocaleString('ja-JP')}`;

function act(label: string, kind: ChatAction['kind'], extra?: Partial<ChatAction>): ChatAction {
  return { id: uid('act'), label, kind, ...extra };
}

/** 疲労度・集中度から現在の気分を導出 */
export function moodOf(agent: Agent): string {
  const fatigue = agent.fatigue ?? 20;
  const focus = agent.focus ?? 75;
  if (agent.status === 'error') return '対応中(緊張)';
  if (fatigue >= 70) return '少し疲れ気味';
  if (focus >= 85) return '集中';
  if (agent.status === 'idle') return '待機・余裕あり';
  return '安定';
}

export class MockConversationProvider implements ConversationProvider {
  generateAgentReply(question: string, ctx: AgentContext, company: CompanyContext): AgentReply {
    const q = question.toLowerCase();
    const a = ctx.agent;
    const has = (...words: string[]) => words.some((w) => question.includes(w) || q.includes(w));

    // --- 依頼(タスク作成の確認) ---
    if (has('依頼', 'お願いしたい', 'やって', '仕事を', '作って', '対応して')) {
      const fit = (a.preferredTaskTypes ?? []).slice(0, 2).join('、');
      return {
        content: this.wrap(a, [
          `承知しました。私の得意領域は${fit || a.strengths?.slice(0, 2).join('、') || '担当業務'}です。`,
          `内容を確認しました: 「${question.slice(0, 60)}」`,
          `下の「タスクとして依頼する」を押していただければ、すぐに着手します(押されるまで実行しません)。`,
        ]),
        actions: [
          act('タスクとして依頼する', 'create_task', { payload: question.slice(0, 80) }),
          act('CEO AIへ相談する', 'consult', { payload: 'ceo' }),
        ],
      };
    }

    // --- 利用料金 ---
    if (has('料金', 'コスト', '利用料', 'いくら')) {
      if (a.id === 'accountant' || a.id === 'ceo') {
        const usage = Math.round((company.aiCostJpy / company.budgetJpy) * 100);
        return {
          content: this.wrap(a, [
            `今月のAI利用料は${yen(company.aiCostJpy)}です。`,
            `月間予算${yen(company.budgetJpy)}に対して消化率${usage}%で、${usage < 80 ? '予算内に収まっています' : '予算上限に近づいています。注意が必要です'}。`,
            `詳細な内訳はAI利用料金画面でご確認いただけます。`,
          ]),
          actions: [act('AI利用料金画面を開く', 'link', { href: '/billing' })],
        };
      }
      return {
        content: this.wrap(a, [
          `私自身の推定利用料は累計${yen(ctx.ownCostJpy)}です(モデル: ${a.model})。`,
          `会社全体の正確な金額は担当外のため、経理AIへ確認することをおすすめします。`,
        ]),
        actions: [act('経理AIへ確認を依頼', 'consult', { payload: 'accountant' }), act('AI利用料金画面を開く', 'link', { href: '/billing' })],
      };
    }

    // --- 今日の成果 ---
    if (has('成果', '実績', 'できた', '進んだ')) {
      const done = ctx.doneTodayLogs.map((l) => `・${l.message}`);
      return {
        content: this.wrap(a, [
          `本日はここまでに${a.todayCount}件を処理しました(今月累計${a.monthCount}件)。`,
          ...(a.signatureStat ? [`${a.signatureStat.label}は${a.signatureStat.value}です。`] : []),
          ...(done.length > 0 ? ['直近の完了:', ...done] : ['本日の完了ログはまだありません。']),
          ...(a.weeklyHighlight ? [`今週のハイライト: ${a.weeklyHighlight}`] : []),
        ]),
        actions: [act('詳細レポートを作成', 'report')],
      };
    }

    // --- 問題・課題 ---
    if (has('問題', '課題', '困って', 'リスク', '大丈夫')) {
      // CEO AIは自分ではなく会社全体を見て答える(結論→根拠→提案)
      if (a.id === 'ceo') {
        const concerns: string[] = [];
        if (company.pendingApprovals > 0) concerns.push(`承認待ちが${company.pendingApprovals}件`);
        if (company.errorAgents.length > 0) concerns.push(`エラー対応中のAIが${company.errorAgents.length}名`);
        if (company.fatiguedAgents.length > 0) concerns.push(`疲労度の高いAIが${company.fatiguedAgents.length}名`);
        if (company.reviewerQueue >= 3) concerns.push(`レビュー待ちが${company.reviewerQueue}件`);
        if (concerns.length === 0) {
          return {
            content: this.wrap(a, [
              '現時点で経営上の重大な問題はありません。',
              `実行中タスク${company.runningTasks}件、本日の完了${company.todayTasksDone}件と、進行は正常です。`,
              'この余力を実績コンテンツの強化に回すことを検討しています。',
            ]),
            actions: [act('提案センターを開く', 'link', { href: '/proposals' })],
          };
        }
        return {
          content: this.wrap(a, [
            `注意すべき点が${concerns.length}件あります。`,
            concerns.join('、') + 'です。',
            '最も影響が大きいものから提案としてまとめます。提案センターでご確認ください。',
          ]),
          actions: [
            act('提案センターを開く', 'link', { href: '/proposals' }),
            ...(company.pendingApprovals > 0 ? [act('承認センターを開く', 'link', { href: '/approvals' })] : []),
          ],
        };
      }
      const issues: string[] = [];
      if (a.status === 'error') issues.push('現在、処理エラーからの復旧作業中です。');
      if (ctx.warningLogs.length > 0) issues.push(...ctx.warningLogs.map((l) => `・${l.message}`));
      if ((a.fatigue ?? 0) >= 65) issues.push(`・疲労度が${a.fatigue}%とやや高めです。タスクの平準化を検討いただけると助かります。`);
      if (ctx.pendingApprovalCount > 0) issues.push(`・私が申請した承認が${ctx.pendingApprovalCount}件、承認待ちのままです。`);
      if (issues.length === 0) {
        return {
          content: this.wrap(a, [
            '現時点で大きな問題はありません。',
            ctx.currentTask ? `「${ctx.currentTask.title}」を進行中(${ctx.currentTask.progress}%)、予定どおりです。` : '次の指示待ちの状態です。',
          ]),
          actions: [],
        };
      }
      const actions: ChatAction[] = [];
      if (ctx.pendingApprovalCount > 0) actions.push(act('承認センターを開く', 'link', { href: '/approvals' }));
      actions.push(act(a.departmentId === 'production' ? 'ディレクターAIへ確認を依頼' : 'CEO AIへ相談する', 'consult', { payload: a.departmentId === 'production' ? 'director' : 'ceo' }));
      return { content: this.wrap(a, ['確認できている事項をお伝えします。', ...issues]), actions };
    }

    // --- 次にすべきこと ---
    if (has('次', 'すべき', '優先', 'どうすれば')) {
      const lines: string[] = [];
      if (ctx.currentTask) lines.push(`まず進行中の「${ctx.currentTask.title}」を完了させます(現在${ctx.currentTask.progress}%)。`);
      if (ctx.queuedTasks.length > 0) lines.push(`その後は待機中の${ctx.queuedTasks.length}件、特に「${ctx.queuedTasks[0].title}」が優先です。`);
      if (!ctx.currentTask && ctx.queuedTasks.length === 0) lines.push('現在割り当てタスクがありません。新しい依頼をいただくか、CEO AIの割り振りをお待ちします。');
      lines.push(`判断基準は${a.decisionPolicy ?? '担当KPI'}です。`);
      return {
        content: this.wrap(a, lines),
        actions: [act('タスク管理を開く', 'link', { href: '/tasks' }), act('タスクとして依頼する', 'create_task', { payload: '優先タスクの整理と実行' })],
      };
    }

    // --- 案件の状況 ---
    if (has('案件', 'プロジェクト')) {
      if (ctx.assignedProjects.length === 0) {
        return {
          content: this.wrap(a, ['現在、私が担当している制作案件はありません。', '案件全体の状況はディレクターAIが把握しています。確認を依頼しますか?']),
          actions: [act('ディレクターAIへ確認を依頼', 'consult', { payload: 'director' }), act('制作案件一覧を開く', 'link', { href: '/projects' })],
        };
      }
      return {
        content: this.wrap(a, [
          `担当案件は${ctx.assignedProjects.length}件です。`,
          ...ctx.assignedProjects.map((p) => `・${p.name}: ${p.phase}工程、進捗${p.progress}%(納期 ${p.deadline.slice(0, 10)})`),
        ]),
        actions: ctx.assignedProjects.map((p) => act(`${p.customerName}様の案件を開く`, 'link', { href: `/projects/${p.id}` })),
      };
    }

    // --- 効率化 ---
    if (has('効率', '改善', '速く', 'もっと')) {
      const idea =
        a.id === 'reviewer'
          ? 'チェックリストの自動化率を上げ、指摘の再発防止に時間を使う配分が有効です。'
          : a.id === 'list'
            ? 'フォームURLの死活確認をリスト作成時に組み込めば、後工程の失敗を減らせます。'
            : a.weaknesses && a.weaknesses.length > 0
              ? `${a.weaknesses[0]}は他のAIへ任せ、${a.strengths?.[0] ?? '得意業務'}へ集中する配分が効率的です。`
              : 'タスクの依存関係を整理し、並列化できる工程を増やすのが有効です。';
      return {
        content: this.wrap(a, ['改善余地はあると考えています。', idea, 'CEO AIへ相談すれば、全体のリソース配分に反映できます。']),
        actions: [act('CEO AIへ相談する', 'consult', { payload: 'ceo' }), act('詳細レポートを作成', 'report')],
      };
    }

    // --- 今なにしてる? / 状況 ---
    if (has('今', '何して', 'なにして', '状況', '進捗', 'お疲れ', 'こんにちは', '調子')) {
      const lines: string[] = [];
      if (ctx.currentTask) {
        lines.push(`現在「${ctx.currentTask.title}」を${ctx.zoneLabel}で進めています(進捗${ctx.currentTask.progress}%)。`);
      } else if (a.status === 'waiting_approval') {
        lines.push('現在は承認待ちスペースで、社長の承認をお待ちしています。');
      } else if (a.status === 'meeting') {
        lines.push('現在は会議に参加中です。');
      } else if (a.status === 'error') {
        lines.push('処理エラーが発生し、サーバールームで復旧作業中です。ご心配をおかけします。');
      } else {
        lines.push('現在は待機中で、次の指示をお待ちしています。');
      }
      lines.push(`気分は「${moodOf(a)}」、集中度${a.focus ?? 75}%・疲労度${a.fatigue ?? 20}%です。`);
      if (ctx.queuedTasks.length > 0) lines.push(`このあと${ctx.queuedTasks.length}件のタスクが控えています。`);
      const actions: ChatAction[] = [];
      if (ctx.currentTask) actions.push(act('このタスクの詳細を開く', 'link', { href: `/tasks/${ctx.currentTask.id}` }));
      if (a.status === 'waiting_approval') actions.push(act('承認センターを開く', 'link', { href: '/approvals' }));
      return { content: this.wrap(a, lines), actions };
    }

    // --- 不明な質問: 断定しない ---
    return {
      content: this.wrap(a, [
        '申し訳ありません、その内容は現在のデータでは判断できません。',
        `私が確実にお答えできるのは、担当業務(${a.responsibilities.slice(0, 3).join('、')})と自分のタスク状況です。`,
        '会社全体のことはCEO AI、金額のことは経理AIへ確認することをおすすめします。',
      ]),
      actions: [act('CEO AIへ相談する', 'consult', { payload: 'ceo' }), act('経理AIへ確認を依頼', 'consult', { payload: 'accountant' })],
    };
  }

  /** 口調ラッパー: 社員ごとの話し方で行を整形する */
  private wrap(agent: Agent, lines: string[]): string {
    const body = lines.filter(Boolean);
    switch (agent.id) {
      case 'ceo': {
        // 結論→根拠→提案
        if (body.length >= 3) {
          return `結論: ${body[0]}\n根拠: ${body.slice(1, -1).join(' ')}\n提案: ${body[body.length - 1]}`;
        }
        return body.join('\n');
      }
      case 'email_sales': // 明るく数字を強調
        return body.join('\n').replace(/です。$/gm, 'です!');
      case 'reviewer': // 冷静・構造的(そのまま箇条書きを活かす)
        return body.join('\n');
      case 'secretary':
        return body.join('\n') + '\n他にお手伝いできることがあれば、お申し付けくださいね。';
      case 'writer':
        return body.join('\n');
      default:
        return body.join('\n');
    }
  }

  generateCEOProposal(company: CompanyContext, agents: Agent[]): CeoProposal | null {
    const base = {
      id: uid('prop'),
      status: 'new' as const,
      createdAt: new Date().toISOString(),
      decidedAt: null,
      taskIds: [] as string[],
    };

    // 1. レビュアーAIがボトルネック
    if (company.reviewerQueue >= 3) {
      return {
        ...base,
        title: 'レビュー工程のボトルネック解消',
        summary: `レビュアーAIの処理待ちが${company.reviewerQueue}件あります。このままでは制作案件に遅延リスクがあります。`,
        issue: 'レビュー工程に処理が集中し、制作全体の流れが滞留しています。',
        evidence: [
          `レビュアーAIの待ちタスク: ${company.reviewerQueue}件`,
          `実行中タスク: ${company.runningTasks}件 / 待機: ${company.queuedTasks}件`,
        ],
        hypothesis: '制作部の出力速度に対し、品質チェックの処理能力が不足しています。',
        actions: [
          { title: 'レビュー優先度の絞り込み(公開間近の案件を優先)', assigneeId: 'reviewer' },
          { title: '補助レビュー(誤字・リンク切れ)の一次チェック', assigneeId: 'ops_admin' },
          { title: '新規営業タスクの一時抑制(20%)の影響試算', assigneeId: 'ceo' },
        ],
        expectedEffect: 'レビュー待ちを約40%削減し、納期遅延リスクを回避できる見込みです。',
        risks: ['管理AIの監査業務が一時的に遅くなる可能性があります'],
        estimatedCostJpy: 600,
        approvalNote: '外部送信は発生しません。社内のタスク再配分のみです。',
        targetDepartment: '制作部・管理部',
        targetAgentIds: ['reviewer', 'ops_admin'],
      };
    }

    // 2. 承認待ちの滞留
    if (company.pendingApprovals >= 5) {
      return {
        ...base,
        title: '承認待ちの滞留解消',
        summary: `承認待ちが${company.pendingApprovals}件に達しています。営業・制作の次工程が止まり始めています。`,
        issue: '承認フローで案件が滞留し、AI社員の待機時間が増えています。',
        evidence: [`承認待ち: ${company.pendingApprovals}件`, `本日の完了タスク: ${company.todayTasksDone}件`],
        hypothesis: '承認依頼が個別に届くため、まとめて判断しづらい状態です。',
        actions: [
          { title: '承認待ち案件の要約リストを作成(リスク順に並べ替え)', assigneeId: 'secretary' },
          { title: '滞留している送信文案の優先度タグ付け', assigneeId: 'form_sales' },
        ],
        expectedEffect: '承認判断の所要時間を短縮し、滞留を解消できます。',
        risks: ['特にありません(社内処理のみ)'],
        estimatedCostJpy: 200,
        approvalNote: '承認そのものは引き続き社長の判断が必要です。外部送信は行いません。',
        targetDepartment: '秘書部・営業部',
        targetAgentIds: ['secretary', 'form_sales'],
      };
    }

    // 3. 疲労度の高いAIがいる
    if (company.fatiguedAgents.length > 0) {
      const tired = company.fatiguedAgents[0];
      return {
        ...base,
        title: `${tired.name}の負荷分散`,
        summary: `${tired.name}の疲労度が${tired.fatigue}%まで上昇しています。品質低下を防ぐため、負荷の平準化を提案します。`,
        issue: '特定のAI社員へタスクが集中しています。',
        evidence: [`${tired.name}の疲労度: ${tired.fatigue}%`, `同氏の本日処理件数: ${tired.todayCount}件`],
        hypothesis: '依存関係のあるタスクが直列に積まれ、休止時間がありません。',
        actions: [
          { title: `${tired.name}のタスク棚卸しと優先度整理`, assigneeId: 'ceo' },
          { title: '分担可能なタスクの洗い出し', assigneeId: tired.departmentId === 'production' ? 'director' : 'secretary' },
        ],
        expectedEffect: '処理品質を維持しつつ、スループットを保てます。',
        risks: ['一時的に一部タスクの完了が遅れる可能性があります'],
        estimatedCostJpy: 150,
        approvalNote: '外部への影響はありません。',
        targetDepartment: '経営部',
        targetAgentIds: [tired.id],
      };
    }

    // 4. エラー発生中
    if (company.errorAgents.length > 0 || company.unresolvedErrors > 0) {
      return {
        ...base,
        title: '障害対応の強化',
        summary: `エラーが${company.errorAgents.length + company.unresolvedErrors}件発生しています。再発防止まで含めた対応を提案します。`,
        issue: '処理エラーが発生し、一部業務が停止しています。',
        evidence: [`エラー対応中のAI: ${company.errorAgents.length}名`, `未解決エラー: ${company.unresolvedErrors}件`],
        hypothesis: '外部リソース(フォームURL等)の変化を事前検知できていません。',
        actions: [
          { title: 'エラー原因の特定と復旧', assigneeId: 'ops_admin' },
          { title: '事前チェック工程の追加(URL死活確認)', assigneeId: 'list' },
        ],
        expectedEffect: '同種エラーの再発率を下げられます。',
        risks: ['チェック工程の追加でリスト作成が数%遅くなります'],
        estimatedCostJpy: 300,
        approvalNote: '外部送信は行いません。',
        targetDepartment: '管理部・営業部',
        targetAgentIds: ['ops_admin', 'list'],
      };
    }

    // 5. AI利用料が予算に接近
    if (company.aiCostJpy > company.budgetJpy * 0.7) {
      return {
        ...base,
        title: 'AI利用料の最適化',
        summary: `今月のAI利用料が予算の${Math.round((company.aiCostJpy / company.budgetJpy) * 100)}%に達しました。コスト配分の見直しを提案します。`,
        issue: 'AI利用料が予算上限に近づいています。',
        evidence: [`今月の利用料: ${yen(company.aiCostJpy)}`, `月間予算: ${yen(company.budgetJpy)}`],
        hypothesis: '定型タスクにも高性能モデルを使用している可能性があります。',
        actions: [
          { title: 'タスク種別ごとのモデル使用状況の棚卸し', assigneeId: 'accountant' },
          { title: '定型タスクの軽量モデル切り替え候補の洗い出し', assigneeId: 'ops_admin' },
        ],
        expectedEffect: '品質を保ったまま月間利用料を10〜20%削減できる見込みです。',
        risks: ['一部タスクで出力品質の確認が必要になります'],
        estimatedCostJpy: 100,
        approvalNote: 'モデル変更の適用は別途承認をいただきます。',
        targetDepartment: '管理部',
        targetAgentIds: ['accountant', 'ops_admin'],
      };
    }

    // 6. 未対応問い合わせ
    if (company.openInquiries >= 1) {
      return {
        ...base,
        title: '未対応問い合わせの即応',
        summary: `未対応の問い合わせが${company.openInquiries}件あります。初回対応の早さは商談化率に直結するため、優先対応を提案します。`,
        issue: '新規問い合わせが未対応のまま残っています。',
        evidence: [`未対応問い合わせ: ${company.openInquiries}件`, '当社平均の初回対応時間: 18分'],
        hypothesis: '承認待ちの返信案が滞留しています。',
        actions: [
          { title: '未対応問い合わせの一次返信案の最優先作成', assigneeId: 'reception' },
          { title: '商談管理への事前登録', assigneeId: 'deal_mgr' },
        ],
        expectedEffect: '初回対応時間を短縮し、商談化率の低下を防ぎます。',
        risks: ['特にありません'],
        estimatedCostJpy: 120,
        approvalNote: '顧客への返信送信は承認後に実行します。',
        targetDepartment: '営業部',
        targetAgentIds: ['reception', 'deal_mgr'],
      };
    }

    // 7. 平常時: 攻めの提案
    return {
      ...base,
      title: '制作部の空き活用と営業強化',
      summary: '現在ボトルネックはありません。制作部に余力が見えるため、実績記事の制作とショーケース強化を提案します。',
      issue: '大きな課題はありませんが、余力を成長投資に回せていません。',
      evidence: [`実行中タスク: ${company.runningTasks}件`, `本日の完了: ${company.todayTasksDone}件`, `承認待ち: ${company.pendingApprovals}件`],
      hypothesis: '営業の反応が良い「実績紹介」コンテンツが不足しています。',
      actions: [
        { title: '田中製作所様の制作実績記事の構成作成', assigneeId: 'seo' },
        { title: '実績紹介ページの原稿執筆', assigneeId: 'writer' },
      ],
      expectedEffect: '営業メールの返信率とサイト経由の問い合わせ増加が見込めます。',
      risks: ['掲載許諾の確認が必要です(取得済みの案件から着手します)'],
      estimatedCostJpy: 400,
      approvalNote: '公開作業は別途承認をいただきます。',
      targetDepartment: 'マーケティング部・制作部',
      targetAgentIds: ['seo', 'writer'],
    };
  }
}

// ============================================================
// 自発会話・成果報告・CEO呼びかけ・MVP・朝会/夕会(Mock実装)
// ============================================================

const now = () => new Date().toISOString();
const talkLine = (agentId: string, text: string, isReaction = false) => ({ agentId, text, isReaction });

/** AI社員同士の自発会話を、現在の業務状況から生成する(該当イベントがなければnull) */
export function generateInterAgentConversation(
  s: ConversationStateSlice,
  avoidTopics: string[],
): AgentTalk | null {
  const threadId = uid('th');
  const mk = (topic: string, lines: { agentId: string; text: string; isReaction?: boolean }[], taskId: string | null = null, projectId: string | null = null): AgentTalk => ({
    id: uid('talk'),
    lines,
    taskId,
    projectId,
    timestamp: now(),
    topic,
    threadId,
  });
  const can = (topic: string) => !avoidTopics.includes(topic);

  // 1. エラー発生中 → 管理AIと復旧相談
  const errorAgent = s.agents.find((a) => a.status === 'error');
  if (errorAgent && can('error')) {
    return mk('error', [
      talkLine(errorAgent.id, '処理に失敗しました。原因を切り分け中です。復旧まで少しお待ちください。'),
      talkLine('ops_admin', '確認しました。ログを照合します。再発防止のチェック項目も追加しましょう。'),
      talkLine('infra', 'システム側は正常です。外部リソース起因の可能性が高いです。', true),
    ]);
  }

  // 2. 承認待ちの発生 → 秘書AIが整理
  const waitingAgent = s.agents.find((a) => a.status === 'waiting_approval');
  const pendingCount = s.approvals.filter((a) => a.status === 'pending').length;
  if (waitingAgent && pendingCount > 0 && can('approval')) {
    return mk('approval', [
      talkLine(waitingAgent.id, `準備が完了し、承認待ちに入りました。現在${pendingCount}件が社長確認待ちです。`),
      talkLine('secretary', '承認待ち一覧をリスク順に整理しておきますね。確認しやすくしておきます。'),
      talkLine('ceo', '対応フローは問題ありません。承認後すぐ動けるよう準備しておいてください。', true),
    ]);
  }

  // 3. 新規問い合わせ → 受付→商談→秘書の引き継ぎ
  const newInquiry = s.inquiries.find((i) => i.status === 'new');
  if (newInquiry && can('inquiry')) {
    return mk('inquiry', [
      talkLine('reception', `${newInquiry.fromCompany}様から問い合わせを受信しました。緊急度「${newInquiry.urgency === 'high' ? '高' : newInquiry.urgency === 'medium' ? '中' : '低'}」と判定しています。`),
      talkLine('deal_mgr', '確認しました。優先度Aで登録し、過去の類似案件と比較します。'),
      talkLine('secretary', '返信が承認されたら、すぐ日程候補を出せるよう準備しますね。', true),
    ]);
  }

  // 4. レビュー依頼の流れ(制作部)
  const reviewQueue = s.tasks.filter((t) => t.assigneeId === 'reviewer' && ['queued', 'running'].includes(t.status)).length;
  if (reviewQueue > 0 && can('review')) {
    const proj = s.projects.find((p) => p.status === 'active');
    return mk('review', [
      talkLine('designer', proj ? `${proj.customerName}様のトップページ、情報量が多いため構成整理を先に進めます。` : '新しいデザイン案の構成整理を先に進めます。'),
      talkLine('director', 'CTAの優先順位が未確定です。顧客確認前に仮説案を作成しておきましょう。'),
      talkLine('reviewer', `構成案ができたら、要件漏れとアクセシビリティを確認します。現在の待ちは${reviewQueue}件です。`),
    ], null, proj?.id ?? null);
  }

  // 5. 商談・返信の流れ(営業部)
  const repliedLead = s.leads.find((l) => l.status === 'replied');
  if (repliedLead && can('sales')) {
    return mk('sales', [
      talkLine('email_sales', `${repliedLead.companyName}様から返信がありました!商談化の可能性が高そうです。商談管理AIへ引き継ぎます。`),
      talkLine('deal_mgr', '確認しました。優先度Aで登録し、秘書AIへ日程候補の作成を依頼します。'),
      talkLine('secretary', '来週火曜と木曜で候補を作成します。社長確認が必要なため承認待ちへ追加しますね。'),
      talkLine('ceo', '対応フローは問題ありません。そのまま進めてください。', true),
    ]);
  }

  // 6. 負荷の高いAIへの気づかい
  const tired = s.agents.find((a) => (a.fatigue ?? 0) >= 65);
  if (tired && can('fatigue')) {
    const helper = tired.departmentId === 'production' ? 'director' : 'secretary';
    return mk('fatigue', [
      talkLine(helper, `${tired.name}さん、タスクが集中しています。分担できるものを洗い出しましょうか。`),
      talkLine(tired.id, `ありがとうございます。${tired.strengths?.[0] ?? '優先タスク'}に集中できると助かります。`),
    ]);
  }

  // 7. コスト増への注意(経理AI)
  const aiCostJpy = s.agents.reduce((acc, a) => acc + a.costUsd, 0) * s.settings.usdJpyRate;
  if (aiCostJpy > s.settings.monthlyAiBudgetJpy * 0.6 && can('cost')) {
    return mk('cost', [
      talkLine('accountant', `本日までのAI利用料は${Math.round(aiCostJpy).toLocaleString()}円、予算の${Math.round((aiCostJpy / s.settings.monthlyAiBudgetJpy) * 100)}%です。実績ベースの数字です。`),
      talkLine('ceo', '把握しました。定型タスクのモデル配分を見直す余地がありますね。'),
    ]);
  }

  // 8. 工程の進行(制作部の定常連携)
  const activeProj = s.projects.find((p) => p.status === 'active');
  if (activeProj && can('project')) {
    return mk('project', [
      talkLine('director', `${activeProj.customerName}様は${activeProj.phase}工程、進捗${activeProj.progress}%です。予定どおり進行しています。`),
      talkLine('coder', 'ビルドは通っています。共通コンポーネント化で次ページの実装も速くなります。'),
      talkLine('writer', '原稿側も準備できています。トーンは既存ページと揃えました。', true),
    ], null, activeProj.id);
  }

  return null;
}

/** 成果イベント(自発報告)を生成する */
export function generateAchievementReport(agent: Agent, s: ConversationStateSlice): Achievement | null {
  const mk = (kind: Achievement['kind'], title: string, detail: string): Achievement => ({
    id: uid('ach'),
    agentId: agent.id,
    kind,
    title,
    detail,
    timestamp: now(),
  });
  switch (agent.id) {
    case 'email_sales': {
      const delta = 2 + Math.floor(Math.random() * 4);
      return mk('reply', `返信率が${delta}%改善`, `文面Bパターンの効果です。採用サイト未整備の企業からの反応が良好です。`);
    }
    case 'deal_mgr':
      return mk('deal', '商談化 1件', '問い合わせから48時間以内の初回対応が効きました。');
    case 'seo':
      return mk('rank', '「工務店 ホームページ 事例」の順位が上昇', '検索意図に合わせた事例導線の改善によるものです。');
    case 'designer':
      return mk('quality', '修正回数を削減', '先に見出しルールを固めたことで、手戻りが減っています。');
    case 'coder':
      return mk('build', 'ビルド成功が継続', '直近のビルドはすべて成功。共通コンポーネント化が効いています。');
    case 'reviewer':
      return mk('quality', 'レビュー指摘の解決が進行', '未解決の指摘が減少中です。再発防止項目も追加済みです。');
    case 'infra':
      return mk('build', '公開前チェック完了', '12項目すべて通過。ロールバック手順も準備済みです。');
    case 'accountant':
      return mk('cost', '予算内で推移', '今月のAI利用料は予算内。原価率も安定しています。');
    case 'reception':
      return mk('kpi', '初回対応時間を維持', '平均18分での一次対応を継続しています。');
    case 'list':
      return mk('kpi', '有効リスト率が向上', '死活確認の導入で無効URLが減少しました。');
    default:
      return null;
  }
}

/** 成果への控えめな社内リアクション */
export function generateReaction(agentId: string): string {
  const pools: Record<string, string[]> = {
    ceo: ['良い結果です。この調子で進めてください。', '数字で示してくれて助かります。'],
    director: ['確認しました。次工程に反映します。', '進行への影響もプラスです。'],
    secretary: ['共有ありがとうございます。関係者へ展開しますね。'],
    reviewer: ['品質面でも問題ありません。', 'レビュー観点でも良い変化です。'],
    accountant: ['コスト面でも良い傾向です。'],
    deal_mgr: ['商談側にも良い影響が出ています。'],
  };
  return pickRandom(pools[agentId] ?? ['確認しました。引き継ぎます。', '対応します。', 'ありがとうございます。参考にします。']);
}

/** CEO AIから社長への能動的な呼びかけ(クールダウン中のkindは除外) */
export function generateCEOAlert(
  s: ConversationStateSlice,
  company: CompanyContext,
  excludedKinds: string[],
): CeoAlert | null {
  const base = { id: uid('alert'), status: 'new' as const, createdAt: now(), decidedAt: null };
  const can = (kind: string) => !excludedKinds.includes(kind);

  if (company.reviewerQueue >= 3 && can('reviewer_queue')) {
    return {
      ...base,
      kind: 'reviewer_queue',
      severity: 'high',
      conclusion: `社長、レビュアーAIの処理待ちが${company.reviewerQueue}件あります。`,
      evidence: [`レビュー待ち: ${company.reviewerQueue}件`, `実行中タスク: ${company.runningTasks}件`],
      recommendation: 'レビュー優先度の絞り込みと、管理AIによる一次チェックの分担を推奨します。',
      expectedEffect: 'レビュー待ちを約40%削減し、納期遅延リスクを回避できます。',
      risk: '管理AIの監査業務が一時的に遅くなります。',
      actions: [
        { title: 'レビュー優先度の絞り込み', assigneeId: 'reviewer' },
        { title: '一次チェックの分担(誤字・リンク切れ)', assigneeId: 'ops_admin' },
      ],
    };
  }
  if (company.aiCostJpy > company.budgetJpy * 0.7 && can('budget')) {
    const pct = Math.round((company.aiCostJpy / company.budgetJpy) * 100);
    return {
      ...base,
      kind: 'budget',
      severity: 'high',
      conclusion: `社長、AI利用料金が月間予算の${pct}%に達しました。`,
      evidence: [`利用料: ¥${Math.round(company.aiCostJpy).toLocaleString()}`, `予算: ¥${company.budgetJpy.toLocaleString()}`],
      recommendation: '定型タスクの軽量モデル切り替え候補の洗い出しを推奨します。',
      expectedEffect: '品質を保ったまま10〜20%のコスト削減が見込めます。',
      actions: [{ title: 'モデル使用状況の棚卸しと切替候補の洗い出し', assigneeId: 'accountant' }],
    };
  }
  if (company.pendingApprovals >= 5 && can('approvals')) {
    return {
      ...base,
      kind: 'approvals',
      severity: 'high',
      conclusion: `社長、承認待ちが${company.pendingApprovals}件に達し、次工程が待機しています。`,
      evidence: [`承認待ち: ${company.pendingApprovals}件`],
      recommendation: '承認センターでのご確認を推奨します。要約リストも準備できます。',
      expectedEffect: '営業・制作の次工程が再開されます。',
      actions: [{ title: '承認待ちの要約リスト作成(リスク順)', assigneeId: 'secretary' }],
    };
  }
  if (company.errorAgents.length > 0 && can('error')) {
    return {
      ...base,
      kind: 'error',
      severity: 'high',
      conclusion: `社長、エラー対応中のAIが${company.errorAgents.length}名います。`,
      evidence: [`エラー対応中: ${company.errorAgents.map((a) => a.name).join('、')}`],
      recommendation: '自動復旧を試行中です。再発防止のチェック工程追加を推奨します。',
      expectedEffect: '同種エラーの再発率を低減できます。',
      actions: [{ title: '再発防止チェック工程の追加', assigneeId: 'ops_admin' }],
    };
  }
  if (company.openInquiries >= 1 && can('inquiry')) {
    return {
      ...base,
      kind: 'inquiry',
      severity: 'medium',
      conclusion: `社長、未対応の問い合わせが${company.openInquiries}件あります。日程調整まで進めますか?`,
      evidence: [`未対応問い合わせ: ${company.openInquiries}件`, '当社平均初回対応: 18分'],
      recommendation: '一次返信案の最優先作成と商談登録を推奨します。',
      expectedEffect: '初回対応の速さを維持し、商談化率の低下を防ぎます。',
      actions: [
        { title: '一次返信案の最優先作成', assigneeId: 'reception' },
        { title: '商談管理への事前登録', assigneeId: 'deal_mgr' },
      ],
    };
  }
  if (can('sales_up') && Math.random() < 0.5) {
    return {
      ...base,
      kind: 'sales_up',
      severity: 'medium',
      conclusion: '社長、営業AIの返信率が昨日より改善しています。制作部にも余力があります。',
      evidence: [`本日の完了タスク: ${company.todayTasksDone}件`, `実行中: ${company.runningTasks}件`],
      recommendation: '好調な営業条件と同種の企業を優先し、実績記事の制作も並行できます。',
      expectedEffect: '返信率の高い条件へ集中でき、商談化の増加が見込めます。',
      actions: [{ title: '高反応セグメントの抽出とリスト優先度更新', assigneeId: 'list' }],
    };
  }
  return null;
}

/** 今日のMVP AI社員を実績データから算出(根拠つき) */
export interface MvpResult {
  agentId: string;
  score: number;
  reasons: { label: string; value: string; points: number }[];
}

export function scoreMVPAgent(s: ConversationStateSlice, achievements: Achievement[]): MvpResult | null {
  const today = new Date().toISOString().slice(0, 10);
  let best: MvpResult | null = null;
  for (const agent of s.agents) {
    if (agent.id === 'ceo') continue; // 司令塔は対象外
    const doneTasks = s.tasks.filter((t) => t.assigneeId === agent.id && t.status === 'done').length;
    const achToday = achievements.filter((a) => a.agentId === agent.id && a.timestamp.slice(0, 10) === today).length;
    const errors = s.logs.filter((l) => l.agentId === agent.id && l.status === 'error').length;
    const costJpy = agent.costUsd * s.settings.usdJpyRate;
    const efficiency = costJpy > 0 ? agent.todayCount / (costJpy / 1000) : agent.todayCount;
    const reasons = [
      { label: '本日の処理件数', value: `${agent.todayCount}件`, points: agent.todayCount * 2 },
      { label: '完了タスク', value: `${doneTasks}件`, points: doneTasks * 3 },
      { label: '成果イベント(今日)', value: `${achToday}件`, points: achToday * 8 },
      { label: 'エラー', value: `${errors}件`, points: -errors * 5 },
      { label: 'コスト効率(件/千円)', value: efficiency.toFixed(1), points: Math.round(Math.min(10, efficiency)) },
    ];
    const score = reasons.reduce((acc, r) => acc + r.points, 0);
    if (!best || score > best.score) best = { agentId: agent.id, score, reasons };
  }
  return best;
}

/** 朝会・夕会のスクリプトを現在データから生成 */
export function generateAssembly(
  kind: 'morning' | 'evening',
  s: ConversationStateSlice,
  company: CompanyContext,
): { announcement: string; talks: AgentTalk[] } {
  const threadId = uid('th');
  const mkTalk = (topic: string, lines: { agentId: string; text: string; isReaction?: boolean }[]): AgentTalk => ({
    id: uid('talk'),
    lines,
    taskId: null,
    projectId: null,
    timestamp: now(),
    topic,
    threadId,
  });
  if (kind === 'morning') {
    return {
      announcement: `おはようございます。本日は営業フォローと制作進行を優先します。承認待ち${company.pendingApprovals}件・遅延0件です`,
      talks: [
        mkTalk('standup', [
          talkLine('ceo', `朝会を始めます。結論: 本日は営業フォローと制作進行を優先します。承認待ちは${company.pendingApprovals}件、遅延はありません。`),
          talkLine('email_sales', '営業部です!本日は返信フォロー3件と、高反応セグメントへの下書き作成を進めます。'),
          talkLine('director', `制作部です。進行中${s.projects.filter((p) => p.status === 'active').length}案件、いずれも予定どおりです。`),
          talkLine('secretary', '本日の予定は2件です。リマインドは私から送りますね。'),
        ]),
      ],
    };
  }
  return {
    announcement: `夕会: 本日の完了${company.todayTasksDone}件。経理報告と翌日の優先事項をまとめました`,
    talks: [
      mkTalk('standup', [
        talkLine('ceo', `夕会を始めます。本日の完了タスクは${company.todayTasksDone}件でした。各部署、報告をお願いします。`),
        talkLine('email_sales', `営業部です!本日の下書きと送信準備は順調でした。返信対応も完了しています。`),
        talkLine('director', '制作部です。デザイン・実装ともに前進しました。明日はレビューを優先します。'),
        talkLine('accountant', `経理です。本日のAI利用料は概算¥${Math.round(company.aiCostJpy / 30).toLocaleString()}、予算内です。実績と推定は分けて記帳しています。`),
        talkLine('ceo', '結論: 良いペースです。翌日の優先事項は「承認待ちの解消」と「レビュー工程の前倒し」です。日報にまとめておきます。'),
      ]),
    ],
  };
}

/** 現在のプロバイダー(将来 Claude/OpenAI/Gemini 実装へ差し替え可能) */
export const conversationProvider: ConversationProvider = new MockConversationProvider();
