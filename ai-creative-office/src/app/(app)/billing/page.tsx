'use client';

// AI利用料金管理
import { HorizontalBars } from '@/components/charts';
import { Card, CardHeader, PageHeader, StatCard } from '@/components/ui';
import { useOffice } from '@/lib/store';
import { formatDateTime, num, pct, usd, yen } from '@/lib/utils';

export default function BillingPage() {
  const usage = useOffice((s) => s.usage);
  const agents = useOffice((s) => s.agents);
  const settings = useOffice((s) => s.settings);
  const updateSettings = useOffice((s) => s.updateSettings);

  const totalUsd = agents.reduce((a, x) => a + x.costUsd, 0);
  const totalJpy = totalUsd * settings.usdJpyRate;
  const budgetUse = (totalJpy / settings.monthlyAiBudgetJpy) * 100;

  const byAgent = agents
    .map((a) => ({ label: a.name, value: Math.round(a.costUsd * settings.usdJpyRate), color: a.color }))
    .sort((a, b) => b.value - a.value);

  return (
    <div>
      <PageHeader title="AI利用料金" sub="AI社員ごと・タスクごとの利用料金を日本円で管理します" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="今月のAI利用料" value={yen(totalJpy)} sub={usd(totalUsd)} tone="brand" />
        <StatCard label="月間予算" value={yen(settings.monthlyAiBudgetJpy)} />
        <StatCard label="予算消化率" value={pct(budgetUse)} tone={budgetUse > 80 ? 'danger' : budgetUse > 50 ? 'warning' : 'positive'} />
        <StatCard label="為替レート" value={`¥${settings.usdJpyRate} / $1`} />
      </div>

      <Card className="mt-4 p-4">
        <p className="mb-2 text-xs font-semibold text-slate-500">単価・為替レート設定</p>
        <div className="flex flex-wrap items-end gap-3">
          <div>
            <label className="text-[11px] text-slate-400">為替レート(円/ドル)</label>
            <input
              type="number"
              value={settings.usdJpyRate}
              onChange={(e) => updateSettings({ usdJpyRate: Number(e.target.value) || 1 })}
              className="block w-32 rounded-lg border border-slate-200 px-3 py-1.5 text-sm outline-none focus:border-brand-400"
            />
          </div>
          <div>
            <label className="text-[11px] text-slate-400">月間AI利用予算(円)</label>
            <input
              type="number"
              value={settings.monthlyAiBudgetJpy}
              onChange={(e) => updateSettings({ monthlyAiBudgetJpy: Number(e.target.value) || 0 })}
              className="block w-40 rounded-lg border border-slate-200 px-3 py-1.5 text-sm outline-none focus:border-brand-400"
            />
          </div>
          <p className="text-[11px] text-slate-400">変更は即時にすべての金額表示へ反映されます。</p>
        </div>
      </Card>

      <div className="mt-4 grid gap-3 lg:grid-cols-2">
        <Card>
          <CardHeader title="AI社員別の利用料金(今月)" />
          <div className="p-3">
            <HorizontalBars data={byAgent} unit="円" />
          </div>
        </Card>
        <Card>
          <CardHeader title="利用履歴(直近)" sub="タスク単位のAPI呼び出し記録" />
          <div className="max-h-96 overflow-auto">
            <table className="w-full min-w-[560px] text-xs">
              <thead className="sticky top-0 bg-white">
                <tr className="border-b border-slate-100 text-left text-slate-400">
                  <th className="px-4 py-2 font-medium">日時</th>
                  <th className="px-4 py-2 font-medium">AI社員</th>
                  <th className="px-4 py-2 font-medium">モデル</th>
                  <th className="px-4 py-2 text-right font-medium">入力</th>
                  <th className="px-4 py-2 text-right font-medium">出力</th>
                  <th className="px-4 py-2 text-right font-medium">$</th>
                  <th className="px-4 py-2 text-right font-medium">¥</th>
                </tr>
              </thead>
              <tbody>
                {usage.slice(0, 60).map((u) => {
                  const agent = agents.find((a) => a.id === u.agentId);
                  return (
                    <tr key={u.id} className="border-b border-slate-50">
                      <td className="px-4 py-1.5 tabular-nums text-slate-500">{formatDateTime(u.executedAt)}</td>
                      <td className="px-4 py-1.5">{agent?.name ?? u.agentId}</td>
                      <td className="px-4 py-1.5 text-slate-500">{u.model}</td>
                      <td className="px-4 py-1.5 text-right tabular-nums">{num(u.inputTokens)}</td>
                      <td className="px-4 py-1.5 text-right tabular-nums">{num(u.outputTokens)}</td>
                      <td className="px-4 py-1.5 text-right tabular-nums">{u.costUsd.toFixed(3)}</td>
                      <td className="px-4 py-1.5 text-right font-medium tabular-nums">{yen(u.costUsd * settings.usdJpyRate)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </div>
  );
}
