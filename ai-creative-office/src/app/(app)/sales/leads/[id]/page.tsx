'use client';

// 企業詳細
import { Badge, Card, CardHeader, PageHeader } from '@/components/ui';
import { LEAD_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDate } from '@/lib/utils';
import { useParams } from 'next/navigation';

export default function LeadDetailPage() {
  const params = useParams<{ id: string }>();
  const lead = useOffice((s) => s.leads.find((l) => l.id === params.id));
  const campaigns = useOffice((s) => s.campaigns);
  const deals = useOffice((s) => s.deals.filter((d) => d.leadId === params.id));

  if (!lead) {
    return <p className="py-20 text-center text-sm text-slate-400">企業が見つかりません。</p>;
  }

  const campaign = campaigns.find((c) => c.id === lead.campaignId);

  return (
    <div>
      <PageHeader
        title={lead.companyName}
        sub={`${lead.industry} / ${lead.region} / ${lead.employeeSize}`}
        action={
          <div className="flex gap-1.5">
            <Badge className={cn(LEAD_STATUS[lead.status].bg, LEAD_STATUS[lead.status].color)}>
              {LEAD_STATUS[lead.status].label}
            </Badge>
            {lead.optedOut && <Badge className="bg-red-50 text-red-700">配信停止(再送信されません)</Badge>}
            {lead.doNotContact && <Badge className="bg-red-50 text-red-700">連絡禁止</Badge>}
          </div>
        }
      />

      <div className="grid gap-3 lg:grid-cols-2">
        <Card>
          <CardHeader title="企業情報" />
          <dl className="divide-y divide-slate-50 text-sm">
            <Row label="URL"><a className="text-brand-600 hover:underline" href={lead.url} target="_blank" rel="noreferrer">{lead.url}</a></Row>
            <Row label="問い合わせページ">{lead.contactFormUrl ?? 'なし'}</Row>
            <Row label="メール">{lead.email ?? '不明'}</Row>
            <Row label="電話">{lead.phone ?? '不明'}</Row>
            <Row label="担当者">{lead.contactPerson ?? '不明'}</Row>
            <Row label="関連キャンペーン">{campaign?.name ?? '—'}</Row>
            <Row label="最終接触日">{formatDate(lead.lastContactAt)}</Row>
            <Row label="次回アクション日">{formatDate(lead.nextActionAt)}</Row>
          </dl>
        </Card>
        <Card>
          <CardHeader title="営業メモ" />
          <dl className="divide-y divide-slate-50 text-sm">
            <Row label="営業対象になった理由">{lead.reason}</Row>
            <Row label="課題仮説">{lead.hypothesis}</Row>
            <Row label="提案内容">{lead.proposal ?? '未作成'}</Row>
            <Row label="メモ">{lead.memo || '—'}</Row>
          </dl>
        </Card>
        <Card className="lg:col-span-2">
          <CardHeader title="関連商談" />
          {deals.length === 0 ? (
            <p className="px-4 py-6 text-center text-xs text-slate-400">商談はまだありません</p>
          ) : (
            <ul className="divide-y divide-slate-50">
              {deals.map((d) => (
                <li key={d.id} className="flex items-center gap-3 px-4 py-3 text-sm">
                  <Badge className={cn(LEAD_STATUS[d.status].bg, LEAD_STATUS[d.status].color)}>
                    {LEAD_STATUS[d.status].label}
                  </Badge>
                  <span className="flex-1">{d.title}</span>
                  <span className="tabular-nums text-slate-500">¥{d.amountJpy.toLocaleString()}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex gap-3 px-4 py-2.5">
      <dt className="w-36 shrink-0 text-xs text-slate-400">{label}</dt>
      <dd className="min-w-0 flex-1 text-sm text-slate-700">{children}</dd>
    </div>
  );
}
