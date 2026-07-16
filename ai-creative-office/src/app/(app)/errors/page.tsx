'use client';

// エラー・障害管理
import { Badge, Button, Card, PageHeader } from '@/components/ui';
import { useOffice } from '@/lib/store';
import { formatDateTime } from '@/lib/utils';
import { CheckCircle2 } from 'lucide-react';
import Link from 'next/link';

export default function ErrorsPage() {
  const errors = useOffice((s) => s.errors);
  const agents = useOffice((s) => s.agents);
  const resolveError = useOffice((s) => s.resolveError);

  return (
    <div>
      <PageHeader title="エラー・障害管理" sub={`未解決 ${errors.filter((e) => !e.resolved).length}件 / 全${errors.length}件`} />
      <div className="space-y-3">
        {errors.map((err) => {
          const agent = agents.find((a) => a.id === err.agentId);
          return (
            <Card key={err.id} className="p-4">
              <div className="flex flex-wrap items-center gap-2">
                <Badge className={err.resolved ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'}>
                  {err.resolved ? '解決済み' : '未解決'}
                </Badge>
                <span className="text-sm font-bold text-slate-900">{err.message}</span>
                <span className="ml-auto text-xs tabular-nums text-slate-400">{formatDateTime(err.timestamp)}</span>
              </div>
              <p className="mt-2 text-xs leading-relaxed text-slate-600">{err.detail}</p>
              <div className="mt-3 flex items-center gap-3 border-t border-slate-100 pt-2 text-xs text-slate-500">
                <span>担当: {agent?.avatar} {agent?.name}</span>
                {err.taskId && (
                  <Link href={`/tasks/${err.taskId}`} className="text-brand-600 hover:underline">関連タスク →</Link>
                )}
                {!err.resolved && (
                  <Button variant="secondary" className="ml-auto" onClick={() => resolveError(err.id)}>
                    <CheckCircle2 className="h-3.5 w-3.5" /> 解決済みにする
                  </Button>
                )}
              </div>
            </Card>
          );
        })}
        {errors.length === 0 && (
          <p className="rounded-xl border border-dashed border-slate-200 py-14 text-center text-sm text-slate-400">
            エラーはありません 🎉
          </p>
        )}
      </div>
    </div>
  );
}
