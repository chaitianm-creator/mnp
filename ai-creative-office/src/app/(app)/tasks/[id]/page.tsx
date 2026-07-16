'use client';

// タスク詳細
import { Badge, Button, Card, CardHeader, PageHeader, ProgressBar } from '@/components/ui';
import { TASK_PRIORITY, TASK_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDate, formatDateTime, num, yen } from '@/lib/utils';
import Link from 'next/link';
import { useParams } from 'next/navigation';

export default function TaskDetailPage() {
  const params = useParams<{ id: string }>();
  const task = useOffice((s) => s.tasks.find((t) => t.id === params.id));
  const tasks = useOffice((s) => s.tasks);
  const agents = useOffice((s) => s.agents);
  const logs = useOffice((s) => s.logs.filter((l) => l.taskId === params.id));
  const projects = useOffice((s) => s.projects);
  const usdJpyRate = useOffice((s) => s.settings.usdJpyRate);
  const setTaskStatus = useOffice((s) => s.setTaskStatus);

  if (!task) {
    return <p className="py-20 text-center text-sm text-slate-400">タスクが見つかりません。</p>;
  }

  const assignee = agents.find((a) => a.id === task.assigneeId);
  const requester = agents.find((a) => a.id === task.requesterId);
  const project = projects.find((p) => p.id === task.projectId);
  const st = TASK_STATUS[task.status];

  return (
    <div>
      <PageHeader
        title={task.title}
        sub={task.description}
        action={
          <div className="flex gap-2">
            {task.status === 'running' && (
              <Button variant="secondary" onClick={() => setTaskStatus(task.id, 'stopped')}>停止</Button>
            )}
            {(task.status === 'stopped' || task.status === 'failed') && (
              <Button onClick={() => setTaskStatus(task.id, 'running')}>再実行</Button>
            )}
          </div>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <Badge className={cn(st.bg, st.color)}>{st.label}</Badge>
        <Badge className="bg-slate-100 text-slate-600">優先度: {TASK_PRIORITY[task.priority].label}</Badge>
        {task.needsApproval && <Badge className="bg-amber-50 text-amber-700">要承認(承認者: {task.approver ?? '社長'})</Badge>}
        <div className="flex w-full max-w-xs items-center gap-2">
          <ProgressBar value={task.progress} className="flex-1" />
          <span className="text-xs font-semibold tabular-nums text-slate-600">{task.progress}%</span>
        </div>
      </div>

      {task.errorMessage && (
        <div className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          ⚠️ {task.errorMessage}
        </div>
      )}

      <div className="grid gap-3 lg:grid-cols-2">
        <Card>
          <CardHeader title="基本情報" />
          <dl className="divide-y divide-slate-50 text-sm">
            <Row label="担当AI">
              {assignee ? (
                <Link href={`/agents/${assignee.id}`} className="text-brand-600 hover:underline">
                  {assignee.avatar} {assignee.name}
                </Link>
              ) : '—'}
            </Row>
            <Row label="依頼元">{requester ? `${requester.avatar} ${requester.name}` : '社長(直接指示)'}</Row>
            <Row label="関連案件">
              {project ? (
                <Link href={`/projects/${project.id}`} className="text-brand-600 hover:underline">{project.name}</Link>
              ) : '—'}
            </Row>
            <Row label="期限">{formatDate(task.deadline)}</Row>
            <Row label="開始日時">{formatDateTime(task.startedAt)}</Row>
            <Row label="完了日時">{formatDateTime(task.completedAt)}</Row>
            <Row label="依存タスク">
              {task.dependsOn.length === 0
                ? 'なし'
                : task.dependsOn.map((depId) => {
                    const dep = tasks.find((t) => t.id === depId);
                    return dep ? (
                      <Link key={depId} href={`/tasks/${depId}`} className="mr-2 text-brand-600 hover:underline">
                        {dep.title}({TASK_STATUS[dep.status].label})
                      </Link>
                    ) : null;
                  })}
            </Row>
          </dl>
        </Card>

        <Card>
          <CardHeader title="実行情報" />
          <dl className="divide-y divide-slate-50 text-sm">
            <Row label="使用モデル">{task.model}</Row>
            <Row label="入力トークン">{num(task.inputTokens)}</Row>
            <Row label="出力トークン">{num(task.outputTokens)}</Row>
            <Row label="推定料金">{yen(task.costUsd * usdJpyRate)}</Row>
            <Row label="入力データ">{task.input ?? '—'}</Row>
            <Row label="出力データ">{task.output ?? '—'}</Row>
          </dl>
        </Card>
      </div>

      <Card className="mt-3">
        <CardHeader title="活動ログ" sub={`${logs.length}件`} />
        <ul className="divide-y divide-slate-50">
          {logs.map((l) => (
            <li key={l.id} className="px-4 py-2 text-xs">
              <span className="tabular-nums text-slate-400">{formatDateTime(l.timestamp)}</span>
              <p className="mt-0.5 text-slate-600">{l.message}</p>
            </li>
          ))}
          {logs.length === 0 && <p className="px-4 py-6 text-center text-xs text-slate-400">ログはまだありません</p>}
        </ul>
      </Card>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex gap-3 px-4 py-2.5">
      <dt className="w-28 shrink-0 text-xs text-slate-400">{label}</dt>
      <dd className="min-w-0 flex-1 text-sm text-slate-700">{children}</dd>
    </div>
  );
}
