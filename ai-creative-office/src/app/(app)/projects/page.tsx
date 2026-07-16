'use client';

// 制作案件一覧
import { Badge, Card, PageHeader, ProgressBar, StatCard } from '@/components/ui';
import { useOffice } from '@/lib/store';
import { formatDate, yen } from '@/lib/utils';
import Link from 'next/link';

export default function ProjectsPage() {
  const projects = useOffice((s) => s.projects);
  const agents = useOffice((s) => s.agents);
  const active = projects.filter((p) => p.status === 'active');
  const totalOrder = projects.reduce((a, p) => a + p.orderAmountJpy, 0);
  const totalProfit = projects.reduce(
    (a, p) => a + p.orderAmountJpy - p.productionCostJpy - p.aiCostJpy - p.outsourcingCostJpy,
    0,
  );

  return (
    <div>
      <PageHeader title="制作案件" sub="ディレクターAIが進行を管理しています" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="進行中案件" value={`${active.length}件`} tone="brand" />
        <StatCard label="受注金額合計" value={yen(totalOrder)} />
        <StatCard label="粗利益合計" value={yen(totalProfit)} tone="positive" />
        <StatCard label="遅延案件" value="0件" />
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
        {projects.map((p) => {
          const director = agents.find((a) => a.id === p.directorId);
          return (
            <Link key={p.id} href={`/projects/${p.id}`}>
              <Card className="h-full p-4 transition hover:border-brand-300">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="text-xs text-slate-400">{p.customerName}</p>
                    <h3 className="truncate text-sm font-bold text-slate-900">{p.name}</h3>
                  </div>
                  <Badge className="bg-brand-50 text-brand-700">{p.phase}</Badge>
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <ProgressBar value={p.progress} className="flex-1" />
                  <span className="text-xs font-semibold tabular-nums text-slate-600">{p.progress}%</span>
                </div>
                <div className="mt-3 grid grid-cols-3 gap-2 border-t border-slate-100 pt-2 text-center text-xs">
                  <div>
                    <p className="text-[10px] text-slate-400">受注金額</p>
                    <p className="font-bold tabular-nums">{yen(p.orderAmountJpy)}</p>
                  </div>
                  <div>
                    <p className="text-[10px] text-slate-400">納期</p>
                    <p className="font-bold tabular-nums">{formatDate(p.deadline)}</p>
                  </div>
                  <div>
                    <p className="text-[10px] text-slate-400">担当D</p>
                    <p className="font-bold">{director?.avatar} {director?.name.replace('AI', '')}</p>
                  </div>
                </div>
              </Card>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
