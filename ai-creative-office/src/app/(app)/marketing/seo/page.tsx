'use client';

// SEO・AIO管理
import { Badge, Card, CardHeader, PageHeader, StatCard } from '@/components/ui';
import { useOffice } from '@/lib/store';
import { num } from '@/lib/utils';

const ARTICLE_STATUS: Record<string, { label: string; cls: string }> = {
  none: { label: '未着手', cls: 'bg-slate-100 text-slate-500' },
  outline: { label: '構成作成中', cls: 'bg-sky-50 text-sky-700' },
  writing: { label: '執筆中', cls: 'bg-amber-50 text-amber-700' },
  published: { label: '公開済み', cls: 'bg-emerald-50 text-emerald-700' },
};

export default function SeoPage() {
  const keywords = useOffice((s) => s.seoKeywords);
  const seoAgent = useOffice((s) => s.agents.find((a) => a.id === 'seo'));

  return (
    <div>
      <PageHeader title="SEO・AIO管理" sub="検索とAI検索(AIO)の両方で見つかる情報設計を行います" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="調査キーワード" value={`${keywords.length}件`} />
        <StatCard label="公開記事" value={`${keywords.filter((k) => k.articleStatus === 'published').length}本`} tone="positive" />
        <StatCard label="10位以内" value={`${keywords.filter((k) => k.rank != null && k.rank <= 10).length}件`} tone="brand" />
        <StatCard label="検索流入(今月)" value={num(8620)} />
      </div>

      <Card className="mt-4">
        <CardHeader title="キーワード一覧" sub={seoAgent ? `${seoAgent.name}: ${seoAgent.statusNote}` : undefined} />
        <div className="overflow-x-auto">
          <table className="w-full min-w-[700px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs text-slate-400">
                <th className="px-4 py-2.5 font-medium">キーワード</th>
                <th className="px-4 py-2.5 font-medium">検索意図</th>
                <th className="px-4 py-2.5 text-right font-medium">月間検索数</th>
                <th className="px-4 py-2.5 text-right font-medium">難易度</th>
                <th className="px-4 py-2.5 text-right font-medium">現在順位</th>
                <th className="px-4 py-2.5 font-medium">記事状況</th>
              </tr>
            </thead>
            <tbody>
              {keywords.map((k) => (
                <tr key={k.id} className="border-b border-slate-50 hover:bg-slate-50">
                  <td className="px-4 py-2.5 font-medium text-slate-700">{k.keyword}</td>
                  <td className="px-4 py-2.5 text-xs text-slate-500">{k.intent}</td>
                  <td className="px-4 py-2.5 text-right tabular-nums">{num(k.volume)}</td>
                  <td className="px-4 py-2.5 text-right tabular-nums">{k.difficulty}</td>
                  <td className="px-4 py-2.5 text-right tabular-nums">{k.rank ?? '—'}</td>
                  <td className="px-4 py-2.5">
                    <Badge className={ARTICLE_STATUS[k.articleStatus].cls}>{ARTICLE_STATUS[k.articleStatus].label}</Badge>
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
