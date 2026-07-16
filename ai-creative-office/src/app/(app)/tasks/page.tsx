'use client';

// タスク管理(カンバン / 一覧 / AI社員別)
import { Badge, Card, PageHeader, ProgressBar } from '@/components/ui';
import { KANBAN_COLUMNS, TASK_PRIORITY, TASK_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { Task } from '@/lib/types';
import { cn, formatDate } from '@/lib/utils';
import { motion } from 'framer-motion';
import Link from 'next/link';
import { useState } from 'react';

type ViewMode = 'kanban' | 'list' | 'agent';

export default function TasksPage() {
  const tasks = useOffice((s) => s.tasks);
  const agents = useOffice((s) => s.agents);
  const [view, setView] = useState<ViewMode>('kanban');
  const agentName = (id: string | null) => agents.find((a) => a.id === id)?.name ?? '—';

  return (
    <div>
      <PageHeader
        title="タスク管理"
        sub={`全${tasks.length}件`}
        action={
          <div className="flex rounded-lg border border-slate-200 bg-white p-0.5">
            {(
              [
                ['kanban', 'カンバン'],
                ['list', '一覧'],
                ['agent', 'AI社員別'],
              ] as [ViewMode, string][]
            ).map(([mode, label]) => (
              <button
                key={mode}
                onClick={() => setView(mode)}
                className={cn(
                  'rounded-md px-3 py-1 text-xs font-medium transition',
                  view === mode ? 'bg-gradient-to-r from-brand-600 to-accent-600 text-white' : 'text-slate-500 hover:text-slate-700',
                )}
              >
                {label}
              </button>
            ))}
          </div>
        }
      />

      {view === 'kanban' && (
        <div className="overflow-x-auto pb-2">
          <div className="flex min-w-[900px] gap-3">
            {KANBAN_COLUMNS.map((status) => {
              const columnTasks = tasks.filter((t) => t.status === status);
              const st = TASK_STATUS[status];
              return (
                <div key={status} className="w-56 shrink-0 rounded-xl bg-slate-100/80 p-2">
                  <div className="mb-2 flex items-center justify-between px-1">
                    <span className={cn('rounded-full px-2 py-0.5 text-[11px] font-semibold', st.bg, st.color)}>
                      {st.label}
                    </span>
                    <span className="text-xs tabular-nums text-slate-400">{columnTasks.length}</span>
                  </div>
                  <div className="space-y-2">
                    {columnTasks.map((task) => (
                      <TaskCard key={task.id} task={task} agentName={agentName(task.assigneeId)} />
                    ))}
                    {columnTasks.length === 0 && (
                      <p className="rounded-lg border border-dashed border-slate-200 py-4 text-center text-[10px] text-slate-400">
                        なし
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {view === 'list' && (
        <Card className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs text-slate-400">
                <th className="px-4 py-2.5 font-medium">タスク名</th>
                <th className="px-4 py-2.5 font-medium">担当AI</th>
                <th className="px-4 py-2.5 font-medium">優先度</th>
                <th className="px-4 py-2.5 font-medium">ステータス</th>
                <th className="px-4 py-2.5 font-medium">進捗</th>
                <th className="px-4 py-2.5 font-medium">期限</th>
              </tr>
            </thead>
            <tbody>
              {tasks.map((task) => (
                <tr key={task.id} className="border-b border-slate-50 hover:bg-slate-50">
                  <td className="px-4 py-2.5">
                    <Link href={`/tasks/${task.id}`} className="font-medium text-slate-700 hover:text-brand-600">
                      {task.title}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-xs text-slate-500">{agentName(task.assigneeId)}</td>
                  <td className={cn('px-4 py-2.5 text-xs font-semibold', TASK_PRIORITY[task.priority].color)}>
                    {TASK_PRIORITY[task.priority].label}
                  </td>
                  <td className="px-4 py-2.5">
                    <Badge className={cn(TASK_STATUS[task.status].bg, TASK_STATUS[task.status].color)}>
                      {TASK_STATUS[task.status].label}
                    </Badge>
                  </td>
                  <td className="w-36 px-4 py-2.5">
                    <div className="flex items-center gap-2">
                      <ProgressBar value={task.progress} className="flex-1" />
                      <span className="w-8 text-right text-xs tabular-nums text-slate-500">{task.progress}%</span>
                    </div>
                  </td>
                  <td className="px-4 py-2.5 text-xs tabular-nums text-slate-500">{formatDate(task.deadline)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      {view === 'agent' && (
        <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
          {agents
            .filter((a) => tasks.some((t) => t.assigneeId === a.id))
            .map((agent) => {
              const agentTasks = tasks.filter((t) => t.assigneeId === agent.id);
              return (
                <Card key={agent.id} className="p-3">
                  <div className="mb-2 flex items-center gap-2">
                    <span className="text-lg">{agent.avatar}</span>
                    <p className="text-sm font-bold text-slate-800">{agent.name}</p>
                    <span className="ml-auto text-xs text-slate-400">{agentTasks.length}件</span>
                  </div>
                  <div className="space-y-2">
                    {agentTasks.slice(0, 5).map((task) => (
                      <TaskCard key={task.id} task={task} agentName="" />
                    ))}
                  </div>
                </Card>
              );
            })}
        </div>
      )}
    </div>
  );
}

function TaskCard({ task, agentName }: { task: Task; agentName: string }) {
  return (
    <motion.div layout initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }}>
      <Link
        href={`/tasks/${task.id}`}
        className="block rounded-lg border border-slate-200 bg-white p-2.5 shadow-sm transition hover:border-brand-300"
      >
        <p className="text-xs font-semibold leading-snug text-slate-800">{task.title}</p>
        <div className="mt-1.5 flex items-center gap-1.5">
          {agentName && <span className="truncate text-[10px] text-slate-400">{agentName}</span>}
          <span className={cn('ml-auto text-[10px] font-semibold', TASK_PRIORITY[task.priority].color)}>
            {TASK_PRIORITY[task.priority].label}
          </span>
          {task.needsApproval && (
            <span className="rounded bg-amber-100 px-1 py-0.5 text-[9px] font-medium text-amber-700">要承認</span>
          )}
        </div>
        {task.status === 'running' && (
          <div className="mt-1.5 flex items-center gap-1.5">
            <ProgressBar value={task.progress} className="h-1 flex-1" />
            <span className="text-[10px] tabular-nums text-slate-400">{task.progress}%</span>
          </div>
        )}
      </Link>
    </motion.div>
  );
}
