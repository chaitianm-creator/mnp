// ============================================================
// 投資家モードのシミュレーション計算
// - 固定値は使わず、設定(算出条件)+ストアの現在データから毎回再計算する
// - 根拠データが不足する指標は数値を出さず「算出データ不足」を返す
// ============================================================
import type { SimulationAssumptions } from './types';

export const DEFAULT_SIMULATION: SimulationAssumptions = {
  salaryPerHeadJpy: 350000, // 1人あたりの想定人件費(月額)
  minutesPerTask: 25, // タスク1件あたりの人間換算作業時間(分)
  workHoursPerMonth: 160, // 月間想定労働時間
};

export interface SimulationInputs {
  assumptions: SimulationAssumptions;
  periodLabel: string; // 対象期間
  monthTasksDone: number; // 期間内のAI処理件数(完了タスク)
  aiCostJpy: number; // 期間内のAI利用料金
  revenueJpy: number; // 期間内の売上
  grossProfitJpy: number; // 期間内の粗利益
  productionCostJpy: number; // 制作原価+外注費
  activeAgents: number;
  totalAgents: number;
  humanHeadcount: number; // 人間の人数(現状1名=社長)
}

export interface BasisRow {
  label: string;
  value: string;
}

export interface SimMetric {
  key: string;
  label: string;
  /** nullの場合は算出データ不足 */
  value: number | null;
  format: (v: number) => string;
  sub: string;
  formula: string; // 計算式(表示用)
  basis: BasisRow[]; // 算出根拠
  insufficientReason?: string; // 算出データ不足の理由
}

const yen = (v: number) => `¥${Math.round(v).toLocaleString('ja-JP')}`;

export function computeInvestorMetrics(inputs: SimulationInputs): SimMetric[] {
  const a = inputs.assumptions;
  // 人間換算の作業時間(時間)= 処理件数 × 1件あたり分数 ÷ 60
  const humanHours = (inputs.monthTasksDone * a.minutesPerTask) / 60;
  // 想定人員数(人月換算)= 人間換算時間 ÷ 月間想定労働時間
  const headcountEquivalent = a.workHoursPerMonth > 0 ? humanHours / a.workHoursPerMonth : 0;
  // 時給換算 = 月額人件費 ÷ 月間想定労働時間
  const hourlyRate = a.workHoursPerMonth > 0 ? a.salaryPerHeadJpy / a.workHoursPerMonth : 0;
  // 人件費換算額(月)= 人間換算時間 × 時給換算
  const laborValueMonthly = humanHours * hourlyRate;
  const laborSavedMonthly = laborValueMonthly - inputs.aiCostJpy;
  const totalCost = inputs.aiCostJpy + inputs.productionCostJpy;

  const commonBasis: BasisRow[] = [
    { label: '対象期間', value: inputs.periodLabel },
    { label: 'AI処理件数(完了タスク)', value: `${inputs.monthTasksDone.toLocaleString()}件` },
    { label: 'AI利用料金(期間内)', value: yen(inputs.aiCostJpy) },
  ];
  const assumptionBasis: BasisRow[] = [
    { label: '1人あたりの想定人件費(月)', value: yen(a.salaryPerHeadJpy) },
    { label: 'タスク1件の人間換算作業時間', value: `${a.minutesPerTask}分` },
    { label: '月間想定労働時間', value: `${a.workHoursPerMonth}時間` },
    { label: '人間換算の作業時間(期間内)', value: `${humanHours.toFixed(1)}時間` },
    { label: '想定人員数(人月換算)', value: `${headcountEquivalent.toFixed(2)}名` },
  ];

  return [
    {
      key: 'annual_profit',
      label: '年間利益(見込)',
      value: inputs.revenueJpy > 0 ? inputs.grossProfitJpy * 12 : null,
      format: yen,
      sub: `月次粗利 ${yen(inputs.grossProfitJpy)} × 12ヶ月`,
      formula: '(売上 − 制作原価・外注費 − AI利用料金)× 12ヶ月',
      basis: [
        ...commonBasis,
        { label: '売上(期間内)', value: yen(inputs.revenueJpy) },
        { label: '制作原価+外注費', value: yen(inputs.productionCostJpy) },
        { label: '月次粗利益', value: yen(inputs.grossProfitJpy) },
      ],
      insufficientReason: inputs.revenueJpy > 0 ? undefined : '期間内の売上データがないため算出できません',
    },
    {
      key: 'labor_saved',
      label: 'AI削減人件費(年間)',
      value: inputs.monthTasksDone > 0 ? laborSavedMonthly * 12 : null,
      format: yen,
      sub: `人月換算 ${headcountEquivalent.toFixed(1)}名分をAIが処理`,
      formula: '(AI処理件数 × 1件あたり人間換算時間 × 時給換算 − AI利用料金)× 12ヶ月',
      basis: [...commonBasis, ...assumptionBasis, { label: '人件費換算額(月)', value: yen(laborValueMonthly) }],
      insufficientReason:
        inputs.monthTasksDone > 0 ? undefined : '期間内の完了タスクがないため算出できません',
    },
    {
      key: 'roi',
      label: 'ROI',
      value: totalCost > 0 && inputs.revenueJpy > 0 ? (inputs.grossProfitJpy / totalCost) * 100 : null,
      format: (v) => `${v.toFixed(0)}%`,
      sub: '粗利益 ÷ 総コスト(AI費+制作原価)',
      formula: '粗利益 ÷(AI利用料金 + 制作原価・外注費)× 100',
      basis: [
        ...commonBasis,
        { label: '制作原価+外注費', value: yen(inputs.productionCostJpy) },
        { label: '総コスト', value: yen(totalCost) },
        { label: '粗利益', value: yen(inputs.grossProfitJpy) },
      ],
      insufficientReason:
        totalCost > 0 && inputs.revenueJpy > 0 ? undefined : 'コストまたは売上のデータが不足しています',
    },
    {
      key: 'utilization',
      label: 'AI稼働率',
      value: inputs.totalAgents > 0 ? (inputs.activeAgents / inputs.totalAgents) * 100 : null,
      format: (v) => `${v.toFixed(0)}%`,
      sub: `${inputs.activeAgents}/${inputs.totalAgents}名が現在稼働中`,
      formula: '稼働中AI社員数 ÷ 全AI社員数 × 100(現在時点のスナップショット)',
      basis: [
        { label: '対象期間', value: '現在時点' },
        { label: '稼働中AI社員', value: `${inputs.activeAgents}名` },
        { label: '全AI社員', value: `${inputs.totalAgents}名` },
      ],
      insufficientReason: inputs.totalAgents > 0 ? undefined : 'AI社員データがありません',
    },
    {
      key: 'productivity',
      label: '1人あたり生産性',
      value: inputs.revenueJpy > 0 ? inputs.revenueJpy / inputs.humanHeadcount : null,
      format: yen,
      sub: `人間${inputs.humanHeadcount}名+AI社員${inputs.totalAgents}名 / 月商`,
      formula: '売上 ÷ 人間の人数(AI社員は分母に含めない)',
      basis: [
        ...commonBasis,
        { label: '売上(期間内)', value: yen(inputs.revenueJpy) },
        { label: '人間の人数', value: `${inputs.humanHeadcount}名` },
        { label: 'AI社員数', value: `${inputs.totalAgents}名` },
      ],
      insufficientReason: inputs.revenueJpy > 0 ? undefined : '期間内の売上データがないため算出できません',
    },
    {
      key: 'efficiency',
      label: '会社全体効率',
      value:
        inputs.aiCostJpy > 0 && inputs.monthTasksDone > 0
          ? inputs.monthTasksDone / (inputs.aiCostJpy / 10000)
          : null,
      format: (v) => v.toFixed(1),
      sub: 'AI費1万円あたりの完了タスク数',
      formula: '完了タスク数 ÷(AI利用料金 ÷ 1万円)',
      basis: commonBasis,
      insufficientReason:
        inputs.aiCostJpy > 0 && inputs.monthTasksDone > 0
          ? undefined
          : 'AI利用料金または完了タスクのデータが不足しています',
    },
  ];
}
