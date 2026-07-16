'use client';

// SNS投稿管理(初期版は実投稿なし・下書きと承認フローまで)
import { Badge, Card, PageHeader, StatCard } from '@/components/ui';
import { SNS_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDate, num } from '@/lib/utils';

const PLATFORM_ICON: Record<string, string> = {
  Instagram: '📷',
  X: '𝕏',
  Threads: '🧵',
  LinkedIn: '💼',
  Facebook: '📘',
};

export default function SnsPage() {
  const posts = useOffice((s) => s.snsPosts);
  const posted = posts.filter((p) => p.status === 'posted');

  return (
    <div>
      <PageHeader title="SNS投稿管理" sub="初期版は実投稿を行いません。下書き作成と承認フローまでを管理します" />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        <StatCard label="投稿予定" value={`${posts.filter((p) => ['draft', 'waiting_approval', 'approved'].includes(p.status)).length}件`} />
        <StatCard label="下書き" value={`${posts.filter((p) => p.status === 'draft').length}件`} />
        <StatCard label="承認待ち" value={`${posts.filter((p) => p.status === 'waiting_approval').length}件`} tone="warning" />
        <StatCard label="投稿済み" value={`${posted.length}件`} />
        <StatCard label="インプレッション" value={num(posted.reduce((a, p) => a + p.impressions, 0))} tone="brand" />
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
        {posts.map((post) => (
          <Card key={post.id} className="p-4">
            <div className="flex items-center gap-2">
              <span className="text-lg">{PLATFORM_ICON[post.platform]}</span>
              <span className="text-xs font-semibold text-slate-600">{post.platform}</span>
              <Badge className={cn('ml-auto', SNS_STATUS[post.status].bg, SNS_STATUS[post.status].color)}>
                {SNS_STATUS[post.status].label}
              </Badge>
            </div>
            <h3 className="mt-2 text-sm font-bold text-slate-900">{post.title}</h3>
            <p className="mt-1 text-xs leading-relaxed text-slate-500">{post.body}</p>
            <div className="mt-3 flex items-center gap-3 border-t border-slate-100 pt-2 text-xs text-slate-500">
              <span>予定日: {formatDate(post.scheduledAt)}</span>
              {post.status === 'posted' && (
                <>
                  <span>imp {num(post.impressions)}</span>
                  <span>click {num(post.clicks)}</span>
                </>
              )}
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
