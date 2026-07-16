'use client';

// 問い合わせ・受付管理
import { Badge, Card, PageHeader, StatCard } from '@/components/ui';
import { INQUIRY_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime } from '@/lib/utils';

const URGENCY = {
  high: { label: '緊急度: 高', cls: 'bg-red-50 text-red-700' },
  medium: { label: '緊急度: 中', cls: 'bg-amber-50 text-amber-700' },
  low: { label: '緊急度: 低', cls: 'bg-slate-100 text-slate-500' },
} as const;

export default function InquiriesPage() {
  const inquiries = useOffice((s) => s.inquiries);
  const avgResponse =
    inquiries.filter((i) => i.firstResponseMinutes != null).reduce((a, i) => a + (i.firstResponseMinutes ?? 0), 0) /
    Math.max(1, inquiries.filter((i) => i.firstResponseMinutes != null).length);

  return (
    <div>
      <PageHeader title="問い合わせ・受付管理" sub="受付AIが分類・緊急度判定・一次返信案の作成を行います" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="問い合わせ数" value={`${inquiries.length}件`} />
        <StatCard label="未対応" value={`${inquiries.filter((i) => i.status === 'new').length}件`} tone="danger" />
        <StatCard label="商談化" value={`${inquiries.filter((i) => i.status === 'converted').length}件`} tone="positive" />
        <StatCard label="平均初回対応時間" value={`${Math.round(avgResponse)}分`} />
      </div>

      <div className="mt-4 space-y-3">
        {inquiries.map((inq) => (
          <Card key={inq.id} className="p-4">
            <div className="flex flex-wrap items-center gap-1.5">
              <Badge className={cn(INQUIRY_STATUS[inq.status].bg, INQUIRY_STATUS[inq.status].color)}>
                {INQUIRY_STATUS[inq.status].label}
              </Badge>
              <Badge className={URGENCY[inq.urgency].cls}>{URGENCY[inq.urgency].label}</Badge>
              <Badge className="bg-slate-100 text-slate-600">{inq.service}</Badge>
              <span className="ml-auto text-xs tabular-nums text-slate-400">{formatDateTime(inq.receivedAt)}</span>
            </div>
            <h3 className="mt-2 text-sm font-bold text-slate-900">{inq.subject}</h3>
            <p className="text-xs text-slate-500">
              {inq.fromCompany} {inq.fromName} 様({inq.email})
              {inq.firstResponseMinutes != null && ` ・ 初回対応 ${inq.firstResponseMinutes}分`}
            </p>
            <p className="mt-2 rounded-lg bg-slate-50 px-3 py-2 text-xs leading-relaxed text-slate-600">{inq.body}</p>
            {inq.draftReply && (
              <div className="mt-2 rounded-lg border border-amber-200 bg-amber-50/60 px-3 py-2">
                <p className="text-[10px] font-semibold text-amber-700">✍️ 受付AIの一次返信案(承認センターで承認後に送信されます)</p>
                <p className="mt-1 text-xs leading-relaxed text-slate-600">{inq.draftReply}</p>
              </div>
            )}
          </Card>
        ))}
      </div>
    </div>
  );
}
