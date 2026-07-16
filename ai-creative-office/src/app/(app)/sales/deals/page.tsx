'use client';

// 商談管理
import { Badge, Card, PageHeader, StatCard } from '@/components/ui';
import { LEAD_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDate, yen } from '@/lib/utils';

export default function DealsPage() {
  const deals = useOffice((s) => s.deals);
  const won = deals.filter((d) => d.status === 'won');
  const lost = deals.filter((d) => d.status === 'lost');
  const winRate = won.length + lost.length > 0 ? (won.length / (won.length + lost.length)) * 100 : 0;

  return (
    <div>
      <PageHeader title="商談管理" sub="商談管理AIがステータス・次回アクション・失注理由を管理します" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        <StatCard label="商談数" value={`${deals.length}件`} />
        <StatCard label="提案中" value={`${deals.filter((d) => d.status === 'proposing').length}件`} />
        <StatCard label="受注" value={`${won.length}件`} tone="positive" />
        <StatCard label="失注" value={`${lost.length}件`} tone="danger" />
        <StatCard label="受注率" value={`${winRate.toFixed(0)}%`} tone="brand" />
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-2">
        {deals.map((deal) => (
          <Card key={deal.id} className="p-4">
            <div className="flex items-start justify-between gap-2">
              <div>
                <p className="text-xs text-slate-400">{deal.companyName}</p>
                <h3 className="text-sm font-bold text-slate-900">{deal.title}</h3>
              </div>
              <Badge className={cn(LEAD_STATUS[deal.status].bg, LEAD_STATUS[deal.status].color)}>
                {LEAD_STATUS[deal.status].label}
              </Badge>
            </div>
            <p className="mt-2 text-xs leading-relaxed text-slate-600">{deal.summary}</p>
            <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 border-t border-slate-100 pt-2 text-xs">
              <span className="font-bold tabular-nums text-slate-800">{yen(deal.amountJpy)}</span>
              <span className="text-slate-500">案件化可能性 {deal.probability}%</span>
              <span className="text-slate-500">次: {deal.nextAction}({formatDate(deal.nextActionAt)})</span>
            </div>
            {deal.lostReason && (
              <p className="mt-2 rounded-lg bg-red-50 px-3 py-1.5 text-xs text-red-600">失注理由: {deal.lostReason}</p>
            )}
          </Card>
        ))}
      </div>
    </div>
  );
}
