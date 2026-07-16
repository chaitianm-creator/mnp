'use client';

// 営業リスト(CRM)
import { Badge, Card, CardHeader, PageHeader, StatCard } from '@/components/ui';
import { LEAD_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDate } from '@/lib/utils';
import Link from 'next/link';
import { useState } from 'react';

export default function LeadsPage() {
  const leads = useOffice((s) => s.leads);
  const campaigns = useOffice((s) => s.campaigns);
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  const filtered = leads.filter((l) => {
    if (statusFilter !== 'all' && l.status !== statusFilter) return false;
    if (query && !`${l.companyName}${l.industry}${l.region}`.includes(query)) return false;
    return true;
  });

  return (
    <div>
      <PageHeader title="営業リスト" sub="同一企業への重複送信は自動で防止されます。配信停止・連絡禁止の企業には再送信されません" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="登録企業数" value={`${leads.length}社`} />
        <StatCard label="返信あり" value={`${leads.filter((l) => ['replied', 'scheduling', 'meeting_set', 'met', 'proposing'].includes(l.status)).length}社`} tone="brand" />
        <StatCard label="受注" value={`${leads.filter((l) => l.status === 'won').length}社`} tone="positive" />
        <StatCard label="配信停止・連絡禁止" value={`${leads.filter((l) => l.optedOut || l.doNotContact).length}社`} tone="warning" />
      </div>

      <Card className="mt-4">
        <CardHeader
          title="営業キャンペーン"
          sub="実行中のアウトリーチ施策"
        />
        <div className="grid gap-3 p-4 sm:grid-cols-2">
          {campaigns.map((c) => (
            <div key={c.id} className="rounded-lg border border-slate-200 p-3">
              <div className="flex items-center gap-2">
                <p className="flex-1 text-sm font-bold text-slate-800">{c.name}</p>
                <Badge className={c.status === 'active' ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-500'}>
                  {c.status === 'active' ? '実行中' : c.status}
                </Badge>
              </div>
              <p className="mt-1 text-xs text-slate-500">{c.targetCondition}</p>
              <div className="mt-2 grid grid-cols-4 gap-2 text-center text-xs">
                <div><p className="text-slate-400">対象</p><p className="font-bold tabular-nums">{c.totalLeads}</p></div>
                <div><p className="text-slate-400">送信</p><p className="font-bold tabular-nums">{c.sent}</p></div>
                <div><p className="text-slate-400">返信</p><p className="font-bold tabular-nums">{c.replied}</p></div>
                <div><p className="text-slate-400">商談</p><p className="font-bold tabular-nums">{c.meetings}</p></div>
              </div>
            </div>
          ))}
        </div>
      </Card>

      <Card className="mt-4">
        <div className="flex flex-wrap items-center gap-2 border-b border-slate-100 px-4 py-3">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="企業名・業種・地域で検索"
            className="w-56 rounded-lg border border-slate-200 px-3 py-1.5 text-xs outline-none focus:border-brand-400"
          />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded-lg border border-slate-200 px-2 py-1.5 text-xs outline-none"
          >
            <option value="all">すべてのステータス</option>
            {Object.entries(LEAD_STATUS).map(([k, v]) => (
              <option key={k} value={k}>{v.label}</option>
            ))}
          </select>
          <span className="ml-auto text-xs text-slate-400">{filtered.length}社</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs text-slate-400">
                <th className="px-4 py-2.5 font-medium">企業名</th>
                <th className="px-4 py-2.5 font-medium">業種</th>
                <th className="px-4 py-2.5 font-medium">地域</th>
                <th className="px-4 py-2.5 font-medium">規模</th>
                <th className="px-4 py-2.5 font-medium">ステータス</th>
                <th className="px-4 py-2.5 font-medium">最終接触</th>
                <th className="px-4 py-2.5 font-medium">次回アクション</th>
                <th className="px-4 py-2.5 font-medium">フラグ</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((lead) => (
                <tr key={lead.id} className="border-b border-slate-50 hover:bg-slate-50">
                  <td className="px-4 py-2.5">
                    <Link href={`/sales/leads/${lead.id}`} className="font-medium text-slate-700 hover:text-brand-600">
                      {lead.companyName}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-xs text-slate-500">{lead.industry}</td>
                  <td className="px-4 py-2.5 text-xs text-slate-500">{lead.region}</td>
                  <td className="px-4 py-2.5 text-xs text-slate-500">{lead.employeeSize}</td>
                  <td className="px-4 py-2.5">
                    <Badge className={cn(LEAD_STATUS[lead.status].bg, LEAD_STATUS[lead.status].color)}>
                      {LEAD_STATUS[lead.status].label}
                    </Badge>
                  </td>
                  <td className="px-4 py-2.5 text-xs tabular-nums text-slate-500">{formatDate(lead.lastContactAt)}</td>
                  <td className="px-4 py-2.5 text-xs tabular-nums text-slate-500">{formatDate(lead.nextActionAt)}</td>
                  <td className="px-4 py-2.5">
                    {lead.optedOut && <Badge className="bg-red-50 text-red-700">配信停止</Badge>}
                    {lead.doNotContact && <Badge className="bg-red-50 text-red-700">連絡禁止</Badge>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
