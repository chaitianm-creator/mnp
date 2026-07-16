'use client';

// AI社員詳細ページ
import { AgentAvatar, AgentStatusBadge, DepartmentBadge } from '@/components/agent-bits';
import { Badge, Card, CardHeader, PageHeader, ProgressBar, StatCard } from '@/components/ui';
import { TASK_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime, num, usd, yen } from '@/lib/utils';
import Link from 'next/link';
import { useParams } from 'next/navigation';

export default function AgentDetailPage() {
  const params = useParams<{ id: string }>();
  const agent = useOffice((s) => s.agents.find((a) => a.id === params.id));
  const tasks = useOffice((s) => s.tasks.filter((t) => t.assigneeId === params.id));
  const logs = useOffice((s) => s.logs.filter((l) => l.agentId === params.id));
  const usage = useOffice((s) => s.usage.filter((u) => u.agentId === params.id));
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);

  if (!agent) {
    return <p className="py-20 text-center text-sm text-slate-400">AI社員が見つかりません。</p>;
  }

  return (
    <div>
      <PageHeader title={agent.name} sub={agent.description} />
      <div className="mb-4 flex flex-wrap items-center gap-3 rounded-xl border border-slate-200 bg-white p-4">
        <AgentAvatar agent={agent} size="lg" />
        <div className="flex-1">
          <div className="flex flex-wrap gap-1.5">
            <DepartmentBadge departmentId={agent.departmentId} />
            <AgentStatusBadge agent={agent} />
            <Badge className="bg-slate-100 text-slate-600">{agent.model}</Badge>
          </div>
          <p className="mt-1.5 text-sm text-slate-600">{agent.statusNote}</p>
        </div>
        <div className="w-full sm:w-56">
          <ProgressBar value={agent.progress} />
          <p className="mt-1 text-right text-xs tabular-nums text-slate-500">{agent.progress}%</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="今日の処理件数" value={`${num(agent.todayCount)}件`} />
        <StatCard label="今月の処理件数" value={`${num(agent.monthCount)}件`} />
        <StatCard label="利用トークン数" value={num(agent.inputTokens + agent.outputTokens)} sub={`入力 ${num(agent.inputTokens)} / 出力 ${num(agent.outputTokens)}`} />
        <StatCard label="推定利用料金" value={yen(agent.costUsd * usdJpyRate)} sub={usd(agent.costUsd)} />
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-2">
        <Card>
          <CardHeader title="成果(KPI)" />
          <div className="grid grid-cols-2 gap-2 p-4 sm:grid-cols-3">
            {agent.kpis.map((k) => (
              <div key={k.label} className="rounded-lg border border-slate-100 px-3 py-2">
                <p className="truncate text-[10px] text-slate-400">{k.label}</p>
                <p className="text-sm font-bold tabular-nums text-slate-800">
                  {k.unit === '円' ? yen(k.value) : `${num(k.value)}${k.unit ?? ''}`}
                </p>
              </div>
            ))}
          </div>
        </Card>
        <Card>
          <CardHeader title="役割" />
          <div className="flex flex-wrap gap-1.5 p-4">
            {agent.responsibilities.map((r) => (
              <Badge key={r} className="bg-slate-100 text-slate-600">{r}</Badge>
            ))}
          </div>
        </Card>
        <Card>
          <CardHeader title="担当タスク" sub={`${tasks.length}件`} />
          <ul className="divide-y divide-slate-100">
            {tasks.slice(0, 10).map((t) => (
              <li key={t.id}>
                <Link href={`/tasks/${t.id}`} className="flex items-center gap-2 px-4 py-2.5 hover:bg-slate-50">
                  <span className={cn('rounded-full px-2 py-0.5 text-[10px] font-medium', TASK_STATUS[t.status].bg, TASK_STATUS[t.status].color)}>
                    {TASK_STATUS[t.status].label}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-sm text-slate-700">{t.title}</span>
                  <span className="text-xs tabular-nums text-slate-400">{t.progress}%</span>
                </Link>
              </li>
            ))}
            {tasks.length === 0 && <p className="px-4 py-6 text-center text-xs text-slate-400">担当タスクはありません</p>}
          </ul>
        </Card>
        <Card>
          <CardHeader title="最近の活動ログ" />
          <ul className="max-h-72 divide-y divide-slate-100 overflow-y-auto">
            {logs.slice(0, 15).map((l) => (
              <li key={l.id} className="px-4 py-2 text-xs">
                <span className="tabular-nums text-slate-400">{formatDateTime(l.timestamp)}</span>
                <p className="mt-0.5 text-slate-600">{l.message}</p>
              </li>
            ))}
            {logs.length === 0 && <p className="px-4 py-6 text-center text-xs text-slate-400">ログはまだありません</p>}
          </ul>
        </Card>
      </div>

      <Card className="mt-3">
        <CardHeader title="AI利用履歴" sub="このAI社員のAPI呼び出し履歴(直近)" />
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-slate-100 text-left text-slate-400">
                <th className="px-4 py-2 font-medium">日時</th>
                <th className="px-4 py-2 font-medium">モデル</th>
                <th className="px-4 py-2 text-right font-medium">入力トークン</th>
                <th className="px-4 py-2 text-right font-medium">出力トークン</th>
                <th className="px-4 py-2 text-right font-medium">料金</th>
              </tr>
            </thead>
            <tbody>
              {usage.slice(0, 10).map((u) => (
                <tr key={u.id} className="border-b border-slate-50">
                  <td className="px-4 py-2 tabular-nums text-slate-500">{formatDateTime(u.executedAt)}</td>
                  <td className="px-4 py-2 text-slate-600">{u.model}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{num(u.inputTokens)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{num(u.outputTokens)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{yen(u.costUsd * usdJpyRate)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
