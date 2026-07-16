'use client';

// 経営ダッシュボード
// - 経営者向け: 今日の意思決定に必要なKPIを重要度順に配置(前日比/前時間比つき)
// - 投資家向け: ワンクリックで年間利益・ROI・AI削減人件費などの大型表示へ切り替え
import { AnimatedNumber, DeltaBadge } from '@/components/animated-number';
import { HorizontalBars, TrendBars, TrendLine } from '@/components/charts';
import { Card, CardHeader, PageHeader, StatCard } from '@/components/ui';
import { DEPARTMENTS } from '@/lib/labels';
import { computeInvestorMetrics, DEFAULT_SIMULATION, type SimMetric } from '@/lib/simulation';
import { selectDashboardStats, useOffice } from '@/lib/store';
import { cn, num, pct, todayKey, yen } from '@/lib/utils';
import { AnimatePresence, motion } from 'framer-motion';
import { ChevronDown, ChevronUp, Info, X } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useState } from 'react';

export default function DashboardPage() {
  const stats = useOffice(selectDashboardStats);
  const dailyStats = useOffice((s) => s.dailyStats);
  const agents = useOffice((s) => s.agents);
  const projects = useOffice((s) => s.projects);
  const usage = useOffice((s) => s.usage);
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);
  const investorMode = useOffice((s) => s.settings.investorMode ?? false);
  const updateSettings = useOffice((s) => s.updateSettings);
  const [showAll, setShowAll] = useState(false);

  const today = dailyStats.find((d) => d.date === todayKey());
  const yesterday = dailyStats.length >= 2 ? dailyStats[dailyStats.length - 2] : undefined;

  // 前時間比(AI利用料): 直近60分と、その前の60分の実利用レコードから算出
  const nowMs = Date.now();
  const costInWindow = (fromMin: number, toMin: number) =>
    usage
      .filter((u) => {
        const t = new Date(u.executedAt).getTime();
        return t > nowMs - fromMin * 60000 && t <= nowMs - toMin * 60000;
      })
      .reduce((acc, u) => acc + u.costUsd, 0) * usdJpyRate;
  const costLastHour = costInWindow(60, 0);
  const costPrevHour = costInWindow(120, 60);

  const chartData = dailyStats.map((d) => ({
    label: d.date.slice(5).replace('-', '/'),
    tasks: d.tasksCompleted,
    outreach: d.formsSent + d.emailsSent,
    meetingRate: d.leadsAdded > 0 ? Math.round((d.meetings / d.leadsAdded) * 1000) / 10 : 0,
    orderRate: d.meetings > 0 ? Math.round((d.orders / d.meetings) * 1000) / 10 : 0,
    cost: d.costJpy,
  }));

  const deptData = Object.entries(DEPARTMENTS).map(([id, d]) => ({
    label: d.name,
    value: agents.filter((a) => a.departmentId === id).reduce((acc, a) => acc + a.todayCount, 0),
    color: d.color,
  }));
  const agentData = agents
    .map((a) => ({ label: a.name, value: a.monthCount, color: a.color }))
    .sort((x, y) => y.value - x.value)
    .slice(0, 10);
  const projectProfit = projects.map((p) => ({
    label: p.customerName,
    value: p.orderAmountJpy - p.productionCostJpy - p.aiCostJpy - p.outsourcingCostJpy,
    color: '#10b981',
  }));

  // 投資家向け指標: 固定値ではなく、設定(算出条件)+現在のストアデータから毎回再計算する
  const simulation = useOffice((s) => s.settings.simulation) ?? DEFAULT_SIMULATION;
  const [openMetric, setOpenMetric] = useState<string | null>(null);
  const productionCost = projects.reduce((a, p) => a + p.productionCostJpy + p.outsourcingCostJpy, 0);
  const periodLabel = dailyStats.length > 0 ? `${dailyStats[0].date} 〜 ${todayKey()}` : '当月';
  const simMetrics = computeInvestorMetrics({
    assumptions: simulation,
    periodLabel,
    monthTasksDone: stats.monthTasksDone,
    aiCostJpy: stats.aiCostJpy,
    revenueJpy: stats.revenue,
    grossProfitJpy: stats.grossProfit,
    productionCostJpy: productionCost,
    activeAgents: stats.activeAgents,
    totalAgents: agents.length,
    humanHeadcount: 1,
  });

  return (
    <div>
      <PageHeader
        title="経営ダッシュボード"
        sub={investorMode ? '投資家向けサマリー(推定値を含みます)' : 'CEOが毎日確認する重要指標を上から順に配置しています'}
        action={
          <div className="flex rounded-lg border border-slate-200 bg-white p-0.5" role="tablist" aria-label="表示モード">
            <ModeButton active={!investorMode} onClick={() => updateSettings({ investorMode: false })}>
              経営者向け
            </ModeButton>
            <ModeButton active={investorMode} onClick={() => updateSettings({ investorMode: true })}>
              投資家向け
            </ModeButton>
          </div>
        }
      />

      {investorMode ? (
        // ================= 投資家向け(シミュレーション) =================
        <div className="space-y-3">
          {/* 免責の明記 */}
          <div className="flex items-start gap-2 rounded-xl border border-slate-200 bg-white px-4 py-3 text-xs text-slate-600">
            <span className="mt-0.5 shrink-0 rounded-full bg-slate-900 px-2 py-0.5 text-[10px] font-semibold tracking-wide text-white">
              SIMULATION
            </span>
            <p>
              表示値は<span className="font-semibold">デモデータを用いたシミュレーション</span>であり、実際の成果を保証するものではありません。
              各カードをクリックすると算出根拠を確認できます。算出条件は
              <Link href="/settings" className="mx-0.5 text-brand-600 underline-offset-2 hover:underline">設定画面</Link>
              から変更できます。
            </p>
          </div>

          {/* 上段3指標(ダークヒーロー) */}
          <div className="rounded-2xl bg-gradient-to-br from-slate-900 via-brand-900 to-slate-900 p-6 text-white sm:p-8">
            <p className="text-xs font-medium tracking-wider text-white/50">
              ANNUAL OUTLOOK — デモ推定値(月次実績×12のシミュレーション)
            </p>
            <div className="mt-4 grid gap-6 sm:grid-cols-3">
              {simMetrics.slice(0, 3).map((m) => (
                <MetricButton key={m.key} metric={m} dark onClick={() => setOpenMetric(m.key)} />
              ))}
            </div>
          </div>

          {/* 下段3指標 */}
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            {simMetrics.slice(3).map((m) => (
              <MetricButton key={m.key} metric={m} onClick={() => setOpenMetric(m.key)} />
            ))}
          </div>

          <div className="grid gap-3 lg:grid-cols-2">
            <Card>
              <CardHeader title="受注率の推移" sub="デモデータ" />
              <div className="p-3"><TrendLine data={chartData} dataKey="orderRate" color="#10b981" unit="%" /></div>
            </Card>
            <Card>
              <CardHeader title="案件別の粗利益" sub="デモデータ" />
              <div className="p-3"><HorizontalBars data={projectProfit} unit="円" /></div>
            </Card>
          </div>

          {/* 算出根拠モーダル */}
          <BasisModal metric={simMetrics.find((m) => m.key === openMetric) ?? null} onClose={() => setOpenMetric(null)} />
        </div>
      ) : (
        // ================= 経営者向け =================
        <div className="space-y-3">
          {/* 最重要: 財務3指標 */}
          <div className="grid gap-3 sm:grid-cols-3">
            <HeroCard label="売上(今月)" value={stats.revenue} format={(v) => yen(v)} sub={<DeltaBadge current={today?.revenueJpy ?? 0} previous={yesterday?.revenueJpy ?? 0} />} tone="brand" />
            <HeroCard label="粗利益(今月)" value={stats.grossProfit} format={(v) => yen(v)} sub={<span className="text-[10px] text-slate-400">粗利率 {pct(stats.grossMargin)}</span>} tone="positive" />
            <HeroCard
              label="AI利用料金(今月)"
              value={stats.aiCostJpy}
              format={(v) => yen(v)}
              sub={
                <span className="flex items-center gap-1.5">
                  <DeltaBadge current={today?.costJpy ?? 0} previous={yesterday?.costJpy ?? 0} invert />
                  <span className="text-[10px] text-slate-400">
                    直近1時間 {yen(costLastHour)}{costPrevHour > 0 ? `(前時間 ${yen(costPrevHour)})` : ''}
                  </span>
                </span>
              }
            />
          </div>

          {/* 今日の動き(前日比つき) */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
            <LiveStat label="今日の完了タスク" value={today?.tasksCompleted ?? 0} unit="件" prev={yesterday?.tasksCompleted} />
            <LiveStat label="今日の営業件数" value={(today?.formsSent ?? 0) + (today?.emailsSent ?? 0)} unit="件" prev={(yesterday?.formsSent ?? 0) + (yesterday?.emailsSent ?? 0)} />
            <LiveStat label="今日の問い合わせ" value={today?.inquiries ?? 0} unit="件" prev={yesterday?.inquiries} />
            <Link href="/approvals" className="block">
              <StatCard label="承認待ち(要対応)" value={`${stats.pendingApprovals}件`} tone={stats.pendingApprovals > 0 ? 'warning' : 'default'} sub="クリックで承認センターへ" />
            </Link>
            <StatCard label="エラー" value={`${stats.errorCount}件`} tone={stats.errorCount > 0 ? 'danger' : 'positive'} />
            <StatCard label="稼働AI社員" value={`${stats.activeAgents}名`} tone="brand" sub={`待機 ${stats.idleAgents}名 / 全${agents.length}名`} />
          </div>

          {/* 主要グラフ */}
          <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
            <Card>
              <CardHeader title="日別タスク完了数" />
              <div className="p-3"><TrendBars data={chartData} dataKey="tasks" color="#6366f1" unit="件" /></div>
            </Card>
            <Card>
              <CardHeader title="営業件数の推移" sub="フォーム+メール送信数" />
              <div className="p-3"><TrendLine data={chartData} dataKey="outreach" color="#f59e0b" unit="件" /></div>
            </Card>
            <Card>
              <CardHeader title="AI利用料金の推移" />
              <div className="p-3"><TrendBars data={chartData} dataKey="cost" color="#ec4899" unit="円" /></div>
            </Card>
          </div>

          {/* 詳細指標(折りたたみ) */}
          <button
            onClick={() => setShowAll((v) => !v)}
            className="flex w-full items-center justify-center gap-1.5 rounded-xl border border-dashed border-slate-300 py-2 text-xs font-medium text-slate-500 outline-none transition hover:bg-white focus-visible:ring-2 focus-visible:ring-brand-500"
            aria-expanded={showAll}
          >
            {showAll ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
            {showAll ? '詳細指標を閉じる' : 'すべての指標・グラフを表示'}
          </button>

          {showAll && (
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 xl:grid-cols-8">
                <StatCard label="営業リスト" value={`${num(stats.leadsTotal)}社`} />
                <StatCard label="フォーム下書き" value={`${stats.formDrafts}件`} />
                <StatCard label="フォーム送信" value={`${num(stats.formsSent)}件`} />
                <StatCard label="メール下書き" value={`${stats.emailDrafts}件`} />
                <StatCard label="メール送信" value={`${num(stats.emailsSent)}件`} />
                <StatCard label="商談" value={`${stats.deals}件`} />
                <StatCard label="アポイント" value={`${stats.meetings}件`} />
                <StatCard label="受注" value={`${stats.orders}件`} tone="positive" />
              </div>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <StatCard label="進行中案件" value={`${stats.activeProjects}件`} />
                <StatCard label="完了案件" value={`${stats.doneProjects}件`} />
                <StatCard label="今月の完了タスク" value={`${num(stats.monthTasksDone)}件`} />
                <StatCard label="為替レート" value={`¥${usdJpyRate}/$`} sub="AI利用料金画面で変更可" />
              </div>
              <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
                <Card>
                  <CardHeader title="商談化率の推移" />
                  <div className="p-3"><TrendLine data={chartData} dataKey="meetingRate" color="#8b5cf6" unit="%" /></div>
                </Card>
                <Card>
                  <CardHeader title="受注率の推移" />
                  <div className="p-3"><TrendLine data={chartData} dataKey="orderRate" color="#10b981" unit="%" /></div>
                </Card>
                <Card>
                  <CardHeader title="部署別の本日の処理件数" />
                  <div className="p-3"><HorizontalBars data={deptData} unit="件" /></div>
                </Card>
                <Card>
                  <CardHeader title="AI社員別の処理件数(今月・上位10名)" />
                  <div className="p-3"><HorizontalBars data={agentData} unit="件" /></div>
                </Card>
                <Card>
                  <CardHeader title="案件別の粗利益" />
                  <div className="p-3"><HorizontalBars data={projectProfit} unit="円" /></div>
                </Card>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function ModeButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      role="tab"
      aria-selected={active}
      className={cn(
        'rounded-md px-3 py-1 text-xs font-medium transition-colors duration-200',
        active ? 'bg-gradient-to-r from-brand-600 to-accent-600 text-white' : 'text-slate-500 hover:text-slate-700',
      )}
    >
      {children}
    </button>
  );
}

function HeroCard({
  label,
  value,
  format,
  sub,
  tone,
}: {
  label: string;
  value: number;
  format: (v: number) => string;
  sub?: React.ReactNode;
  tone?: 'brand' | 'positive';
}) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white px-5 py-4 shadow-card transition-shadow duration-300 hover:shadow-md">
      <p className="text-xs font-medium text-slate-500">{label}</p>
      <p className={cn('mt-1 text-2xl font-bold tracking-tight', tone === 'positive' ? 'text-emerald-600' : tone === 'brand' ? 'text-brand-700' : 'text-slate-900')}>
        <AnimatedNumber value={value} format={format} />
      </p>
      {sub && <div className="mt-1.5">{sub}</div>}
    </div>
  );
}

function LiveStat({ label, value, unit, prev }: { label: string; value: number; unit: string; prev?: number }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white px-4 py-3 shadow-card">
      <p className="truncate text-xs font-medium text-slate-500">{label}</p>
      <p className="mt-1 text-xl font-bold text-slate-900">
        <AnimatedNumber value={value} />
        <span className="ml-0.5 text-xs font-medium text-slate-400">{unit}</span>
      </p>
      {prev !== undefined && (
        <div className="mt-0.5">
          <DeltaBadge current={value} previous={prev} />
        </div>
      )}
    </div>
  );
}

// 投資家向け指標カード(クリックで算出根拠モーダルを開く)
function MetricButton({ metric, dark, onClick }: { metric: SimMetric; dark?: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      aria-label={`${metric.label}の算出根拠を表示`}
      className={cn(
        'group rounded-xl text-left outline-none transition-all duration-300',
        dark
          ? 'focus-visible:ring-2 focus-visible:ring-white/60'
          : 'border border-slate-200 bg-white px-5 py-4 shadow-card hover:shadow-md focus-visible:ring-2 focus-visible:ring-brand-500',
      )}
    >
      <p className={cn('flex items-center gap-1.5 text-xs font-medium', dark ? 'text-white/60' : 'text-slate-500')}>
        {metric.label}
        <span
          className={cn(
            'rounded-full px-1.5 py-px text-[9px] font-semibold tracking-wide',
            dark ? 'bg-white/10 text-white/70' : 'bg-slate-100 text-slate-500',
          )}
        >
          デモ推定値
        </span>
      </p>
      {metric.value === null ? (
        <p className={cn('mt-1 text-lg font-semibold', dark ? 'text-white/40' : 'text-slate-400')}>算出データ不足</p>
      ) : (
        <p className={cn('mt-1 font-bold tracking-tight', dark ? 'text-3xl sm:text-4xl' : 'text-2xl text-slate-900')}>
          <AnimatedNumber value={metric.value} format={metric.format} />
        </p>
      )}
      <p className={cn('mt-1 flex items-center gap-1 text-[11px]', dark ? 'text-white/50' : 'text-slate-400')}>
        {metric.value === null ? metric.insufficientReason : metric.sub}
      </p>
      <p
        className={cn(
          'mt-1.5 flex items-center gap-1 text-[10px] opacity-70 transition-opacity group-hover:opacity-100',
          dark ? 'text-white/60' : 'text-brand-600',
        )}
      >
        <Info className="h-3 w-3" /> 算出根拠を見る
      </p>
    </button>
  );
}

// 算出根拠モーダル
function BasisModal({ metric, onClose }: { metric: SimMetric | null; onClose: () => void }) {
  useEffect(() => {
    if (!metric) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [metric, onClose]);

  return (
    <AnimatePresence>
      {metric && (
        <>
          <motion.div
            className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={`${metric.label}の算出根拠`}
            initial={{ opacity: 0, scale: 0.96, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.98, y: 4 }}
            transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
            className="fixed left-1/2 top-1/2 z-50 w-[calc(100%-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-2xl bg-white p-5 shadow-panel"
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="flex items-center gap-1.5 text-xs text-slate-400">
                  算出根拠
                  <span className="rounded-full bg-slate-900 px-1.5 py-px text-[9px] font-semibold tracking-wide text-white">
                    SIMULATION
                  </span>
                </p>
                <h3 className="mt-0.5 text-base font-bold text-slate-900">{metric.label}</h3>
              </div>
              <button onClick={onClose} aria-label="閉じる" className="rounded-lg p-1 outline-none hover:bg-slate-100 focus-visible:ring-2 focus-visible:ring-brand-500">
                <X className="h-4 w-4 text-slate-500" />
              </button>
            </div>

            <p className="mt-3 text-2xl font-bold tracking-tight text-slate-900">
              {metric.value === null ? (
                <span className="text-lg font-semibold text-slate-400">算出データ不足</span>
              ) : (
                metric.format(metric.value)
              )}
            </p>
            {metric.value === null && metric.insufficientReason && (
              <p className="mt-1 text-xs text-amber-600">{metric.insufficientReason}</p>
            )}

            <div className="mt-3 rounded-lg bg-slate-50 px-3 py-2">
              <p className="text-[10px] font-semibold text-slate-400">計算式</p>
              <p className="mt-0.5 text-xs text-slate-700">{metric.formula}</p>
            </div>

            <dl className="mt-3 divide-y divide-slate-50 rounded-lg border border-slate-100">
              {metric.basis.map((row) => (
                <div key={row.label} className="flex items-center justify-between gap-3 px-3 py-1.5">
                  <dt className="text-[11px] text-slate-500">{row.label}</dt>
                  <dd className="text-[11px] font-semibold tabular-nums text-slate-800">{row.value}</dd>
                </div>
              ))}
            </dl>

            <p className="mt-3 text-[10px] leading-relaxed text-slate-400">
              表示値はデモデータを用いたシミュレーションであり、実際の成果を保証するものではありません。算出条件は
              <Link href="/settings" className="mx-0.5 text-brand-600 hover:underline">設定画面</Link>
              から変更できます。
            </p>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
