import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { Card, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/misc';
import { Button } from '@/components/ui/button';
import { REPORT_CATEGORIES } from '@/lib/constants';

export const metadata = { title: '通報' };
export const dynamic = 'force-dynamic';

/**
 * 通報の案内ページ。実際の通報は自習室内(参加者を特定できる場面)から行う。
 * 過去に自分が送った通報の状況もここで確認できる。
 */
export default async function ReportPage() {
  const supabase = createClient();
  const { data: myReports } = await supabase
    .from('reports')
    .select('id, category, description, status, created_at')
    .order('created_at', { ascending: false })
    .limit(20);

  const categoryLabel = new Map(REPORT_CATEGORIES.map((c) => [c.value, c.label]));
  const statusLabel: Record<string, string> = {
    open: '確認待ち',
    reviewing: '確認中',
    resolved: '対応済み',
    dismissed: '対応不要',
  };

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <h1 className="text-2xl font-bold">通報について</h1>
      <Card className="space-y-3 text-sm leading-relaxed text-brand-700 dark:text-brand-200">
        <p>
          自習室内で不適切な行動(カメラの不正利用、なりすまし、迷惑行為など)を見かけた場合は、
          自習室画面の<strong>旗アイコン</strong>からその参加者を通報できます。
        </p>
        <p>
          通報時に「今後同じ部屋にならない(ブロック)」を選ぶと、以後その利用者と同室になりません。
        </p>
        <p>通報内容は運営が確認し、必要に応じて利用停止などの対応を行います。</p>
        <p className="text-xs text-brand-500">
          通報の悪用を防ぐため、通報は1日10件までに制限されています。
        </p>
      </Card>

      <Card>
        <CardTitle>あなたの通報履歴</CardTitle>
        {(myReports?.length ?? 0) === 0 ? (
          <p className="py-4 text-center text-sm text-brand-500">通報履歴はありません。</p>
        ) : (
          <ul className="divide-y divide-brand-100 dark:divide-brand-800">
            {myReports!.map((r) => (
              <li key={r.id} className="flex items-center justify-between gap-3 py-3 text-sm">
                <div>
                  <p className="font-medium">{categoryLabel.get(r.category) ?? r.category}</p>
                  <p className="text-xs text-brand-500">
                    {new Date(r.created_at).toLocaleDateString('ja-JP')}
                  </p>
                </div>
                <Badge tone={r.status === 'resolved' ? 'brand' : 'gray'}>
                  {statusLabel[r.status] ?? r.status}
                </Badge>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Link href="/home">
        <Button variant="outline">ホームへ戻る</Button>
      </Link>
    </div>
  );
}
