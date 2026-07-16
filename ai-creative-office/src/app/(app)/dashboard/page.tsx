'use client';

// 経営ダッシュボード
import { HorizontalBars, TrendBars, TrendLine } from '@/components/charts';
import { Card, CardHeader, PageHeader, StatCard } from '@/components/ui';
import { DEPARTMENTS } from '@/lib/labels';
import { selectDashboardStats, useOffice } from '@/lib/store';
import { num, pct, yen } from '@/lib/utils';
import Link from 'next/link';

export default function DashboardPage() {
  const stats = useOffice(selectDashboardStats);
  const dailyStats = useOffice((s) => s.dailyStats);
  const agents = useOffice((s) => s.agents);
  const projects = useOffice((s) => s.projects);
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);

  const chartData = dailyStats.map((d) => ({
    label: d.date.slice(5).replace('-', '/'),
    tasks: d.tasksCompleted,
    leads: d.leadsAdded,
    outreach: d.formsSent + d.emailsSent,
    meetings: d.meetings,
    meetingRate: d.leadsAdded > 0 ? Math.round((d.meetings / d.leadsAdded) * 1000) / 10 : 0,
    orderRate: d.meetings > 0 ? Math.round((d.orders / d.meetings) * 1000) / 10 : 0,
    cost: d.costJpy,
  }));

  const deptData = Object.entries(DEPARTMENTS).map(([id, d]) => ({
    label: d.name,
    value: agents
      .filter((a) => a.departmentId === id)
      .reduce((acc, a) => acc + a.todayCount, 0),
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

  return (
    <div>
      <PageHeader title="経営ダッシュボード" sub="会社全体の状況をリアルタイムに確認できます" />

      {/* 稼働状況 */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
        <StatCard label="本日の稼働AI社員" value={`${stats.activeAgents}名`} tone="brand" sub={`全${agents.length}名`} />
        <StatCard label="待機中AI社員" value={`${stats.idleAgents}名`} />
        <StatCard label="エラー発生" value={`${stats.errorCount}件`} tone={stats.errorCount > 0 ? 'danger' : 'default'} />
        <Link href="/approvals">
          <StatCard label="承認待ち" value={`${stats.pendingApprovals}件`} tone={stats.pendingApprovals > 0 ? 'warning' : 'default'} sub="クリックで承認センターへ" />
        </Link>
        <StatCard label="今日の完了タスク" value={`${stats.todayTasksDone}件`} />
        <StatCard label="今月の完了タスク" value={`${num(stats.monthTasksDone)}件`} />
      </div>

      {/* 営業・案件 */}
      <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4 xl:grid-cols-8">
        <StatCard label="営業リスト" value={`${num(stats.leadsTotal)}社`} />
        <StatCard label="フォーム下書き" value={`${stats.formDrafts}件`} />
        <StatCard label="フォーム送信" value={`${num(stats.formsSent)}件`} />
        <StatCard label="メール下書き" value={`${stats.emailDrafts}件`} />
        <StatCard label="メール送信" value={`${num(stats.emailsSent)}件`} />
        <StatCard label="問い合わせ" value={`${stats.inquiries}件`} />
        <StatCard label="商談" value={`${stats.deals}件`} />
        <StatCard label="受注" value={`${stats.orders}件`} tone="positive" />
      </div>

      {/* 財務 */}
      <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
        <StatCard label="進行中案件" value={`${stats.activeProjects}件`} />
        <StatCard label="完了案件" value={`${stats.doneProjects}件`} />
        <StatCard label="売上" value={yen(stats.revenue)} tone="positive" />
        <StatCard label="AI利用料金" value={yen(stats.aiCostJpy)} sub={`レート ¥${usdJpyRate}/$`} />
        <StatCard label="粗利益" value={yen(stats.grossProfit)} tone="positive" />
        <StatCard label="粗利益率" value={pct(stats.grossMargin)} />
      </div>

      {/* グラフ */}
      <div className="mt-4 grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
        <Card>
          <CardHeader title="日別タスク完了数" />
          <div className="p-3"><TrendBars data={chartData} dataKey="tasks" color="#6366f1" unit="件" /></div>
        </Card>
        <Card>
          <CardHeader title="営業件数の推移" sub="フォーム+メール送信数" />
          <div className="p-3"><TrendLine data={chartData} dataKey="outreach" color="#f59e0b" unit="件" /></div>
        </Card>
        <Card>
          <CardHeader title="商談化率の推移" />
          <div className="p-3"><TrendLine data={chartData} dataKey="meetingRate" color="#8b5cf6" unit="%" /></div>
        </Card>
        <Card>
          <CardHeader title="受注率の推移" />
          <div className="p-3"><TrendLine data={chartData} dataKey="orderRate" color="#10b981" unit="%" /></div>
        </Card>
        <Card>
          <CardHeader title="AI利用料金の推移" />
          <div className="p-3"><TrendBars data={chartData} dataKey="cost" color="#ec4899" unit="円" /></div>
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
  );
}
