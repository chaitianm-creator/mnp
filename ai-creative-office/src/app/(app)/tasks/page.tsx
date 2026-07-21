'use client';

// タスク管理(カンバン / 一覧 / AI社員別)
// - タスクカードはドラッグ&ドロップで並び替え可能(@dnd-kit)
//   ・PC: ハンドル(⠿)をマウスでつかんで上下に移動
//   ・スマホ: ハンドルを長押し(250ms)して移動
//   ・カード本体のクリックは案件ルームを開く(ドラッグと競合しない)
// - 並び順は sortOrder として保存され、リロード後も維持される
import { Badge, Card, PageHeader, ProgressBar } from '@/components/ui';
import { KANBAN_COLUMNS, TASK_PRIORITY, TASK_STATUS } from '@/lib/labels';
import { sortTasks, useOffice } from '@/lib/store';
import type { Task } from '@/lib/types';
import { cn, formatDate } from '@/lib/utils';
import {
  DndContext,
  DragOverlay,
  KeyboardSensor,
  PointerSensor,
  TouchSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core';
import { SortableContext, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { GripVertical } from 'lucide-react';
import Link from 'next/link';
import { useMemo, useState } from 'react';

type ViewMode = 'kanban' | 'list' | 'agent';

export default function TasksPage() {
  const tasksRaw = useOffice((s) => s.tasks);
  const agents = useOffice((s) => s.agents);
  const taskRooms = useOffice((s) => s.taskRooms);
  const reorderTasks = useOffice((s) => s.reorderTasks);
  const [view, setView] = useState<ViewMode>('kanban');
  const [activeId, setActiveId] = useState<string | null>(null);

  // 並び順(sortOrder昇順)で表示。D&Dで変更するとsortOrderが振り直されて保存される
  const tasks = useMemo(() => sortTasks(tasksRaw), [tasksRaw]);
  const agentName = (id: string | null) => agents.find((a) => a.id === id)?.name ?? '—';
  const unreadOf = (taskId: string) => taskRooms[taskId]?.unreadCount ?? 0;
  const activeTask = tasks.find((t) => t.id === activeId) ?? null;

  // PC=マウス(6px動かすまでクリック扱い) / スマホ=長押し250ms / キーボード操作にも対応
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 250, tolerance: 8 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  const onDragStart = (e: DragStartEvent) => setActiveId(String(e.active.id));
  const onDragEnd = (e: DragEndEvent) => {
    setActiveId(null);
    const { active, over } = e;
    if (!over || active.id === over.id) return;
    if (view === 'kanban') {
      // カンバンでは同じ列(同じステータス)内の上下移動のみ(ステータスはルームのセレクトで変更)
      const a = tasks.find((t) => t.id === active.id);
      const o = tasks.find((t) => t.id === over.id);
      if (!a || !o || a.status !== o.status) return;
    }
    reorderTasks(String(active.id), String(over.id));
  };

  return (
    <div>
      <PageHeader
        title="タスク管理"
        sub={`全${tasks.length}件 — カードをクリックで案件ルーム / ⠿ハンドルをドラッグ(スマホは長押し)で並び替え`}
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

      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragStart={onDragStart}
        onDragEnd={onDragEnd}
        onDragCancel={() => setActiveId(null)}
      >
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
                    <SortableContext id={status} items={columnTasks.map((t) => t.id)} strategy={verticalListSortingStrategy}>
                      <div className="space-y-2">
                        {columnTasks.map((task) => (
                          <SortableTaskCard key={task.id} task={task} agentName={agentName(task.assigneeId)} unread={unreadOf(task.id)} />
                        ))}
                        {columnTasks.length === 0 && (
                          <p className="rounded-lg border border-dashed border-slate-200 py-4 text-center text-[10px] text-slate-400">
                            なし
                          </p>
                        )}
                      </div>
                    </SortableContext>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {view === 'list' && (
          <Card className="overflow-x-auto">
            <table className="w-full min-w-[800px] text-sm">
              <thead>
                <tr className="border-b border-slate-100 text-left text-xs text-slate-400">
                  <th className="w-8 px-2 py-2.5" aria-label="並び替え" />
                  <th className="px-2 py-2.5 font-medium">タスク名</th>
                  <th className="px-4 py-2.5 font-medium">担当AI</th>
                  <th className="px-4 py-2.5 font-medium">優先度</th>
                  <th className="px-4 py-2.5 font-medium">ステータス</th>
                  <th className="px-4 py-2.5 font-medium">進捗</th>
                  <th className="px-4 py-2.5 font-medium">期限</th>
                </tr>
              </thead>
              <SortableContext id="list" items={tasks.map((t) => t.id)} strategy={verticalListSortingStrategy}>
                <tbody>
                  {tasks.map((task) => (
                    <SortableRow key={task.id} task={task} agentName={agentName(task.assigneeId)} unread={unreadOf(task.id)} />
                  ))}
                </tbody>
              </SortableContext>
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
                        <TaskCardBody key={task.id} task={task} agentName="" unread={unreadOf(task.id)} />
                      ))}
                    </div>
                  </Card>
                );
              })}
          </div>
        )}

        {/* ドラッグ中: カードが浮いて追従する(移動中の表示) */}
        <DragOverlay dropAnimation={{ duration: 180 }}>
          {activeTask ? (
            <div className="rotate-2 scale-105 cursor-grabbing">
              <TaskCardBody task={activeTask} agentName={agentName(activeTask.assigneeId)} unread={unreadOf(activeTask.id)} overlay />
            </div>
          ) : null}
        </DragOverlay>
      </DndContext>
    </div>
  );
}

/** カンバンカードのソート用ラッパー(元位置は破線プレースホルダー=挿入位置表示) */
function SortableTaskCard({ task, agentName, unread }: { task: Task; agentName: string; unread: number }) {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({ id: task.id });
  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={cn(isDragging && 'rounded-lg outline-dashed outline-2 outline-brand-300')}
    >
      <div className={cn(isDragging && 'pointer-events-none opacity-30')}>
        <TaskCardBody
          task={task}
          agentName={agentName}
          unread={unread}
          handle={
            <DragHandle
              label={`${task.title} をドラッグして並び替え`}
              handleRef={setActivatorNodeRef}
              props={{ ...attributes, ...listeners }}
            />
          }
        />
      </div>
    </div>
  );
}

/** 一覧(テーブル)行のソート用ラッパー */
function SortableRow({ task, agentName, unread }: { task: Task; agentName: string; unread: number }) {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({ id: task.id });
  return (
    <tr
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={cn('border-b border-slate-50 hover:bg-slate-50', isDragging && 'bg-brand-50/60 opacity-60 outline-dashed outline-2 outline-brand-300')}
    >
      <td className="px-2 py-2.5">
        <DragHandle label={`${task.title} をドラッグして並び替え`} handleRef={setActivatorNodeRef} props={{ ...attributes, ...listeners }} inline />
      </td>
      <td className="px-2 py-2.5">
        <Link href={`/tasks/${task.id}`} className="font-medium text-slate-700 hover:text-brand-600">
          {task.title}
        </Link>
        {task.category && (
          <span className="ml-1.5 rounded bg-sky-50 px-1 py-0.5 text-[9px] font-medium text-sky-700">{task.category}</span>
        )}
        {unread > 0 && (
          <span className="ml-1.5 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
            {unread}
          </span>
        )}
      </td>
      <td className="px-4 py-2.5 text-xs text-slate-500">{agentName}</td>
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
  );
}

/**
 * ドラッグ専用ハンドル(⠿)。ドラッグはこのハンドルからのみ開始されるため、
 * カード本体のクリック(案件ルームを開く)やカード内のボタン操作と競合しない
 */
function DragHandle({
  label,
  handleRef,
  props,
  inline,
}: {
  label: string;
  handleRef: (el: HTMLElement | null) => void;
  props: Record<string, unknown>;
  inline?: boolean;
}) {
  return (
    <button
      ref={handleRef}
      {...props}
      aria-label={label}
      onClick={(e) => {
        // ハンドルのクリックでは画面遷移しない(ドラッグ専用)
        e.preventDefault();
        e.stopPropagation();
      }}
      className={cn(
        'flex h-7 w-7 cursor-grab touch-none items-center justify-center rounded-md text-slate-300 transition hover:bg-slate-100 hover:text-slate-500 active:cursor-grabbing',
        !inline && 'absolute right-1 top-1 z-10',
      )}
    >
      <GripVertical className="h-4 w-4" />
    </button>
  );
}

/** タスクカード本体。カード全体クリック=案件ルーム、右上のハンドル=並び替え */
function TaskCardBody({
  task,
  agentName,
  unread = 0,
  handle,
  overlay,
}: {
  task: Task;
  agentName: string;
  unread?: number;
  handle?: React.ReactNode;
  overlay?: boolean;
}) {
  const st = TASK_STATUS[task.status];
  return (
    <div className="relative">
      {handle}
      <Link
        href={`/tasks/${task.id}`}
        aria-label={`案件ルームを開く: ${task.title}`}
        className={cn(
          'block rounded-lg border border-slate-200 bg-white p-2.5 shadow-sm transition hover:border-brand-300',
          overlay && 'pointer-events-none border-brand-300 shadow-xl',
        )}
      >
        <div className={cn('flex items-start gap-1.5', handle && 'pr-6')}>
          <p className="min-w-0 flex-1 text-xs font-semibold leading-snug text-slate-800">{task.title}</p>
          {unread > 0 && (
            <span
              className="flex h-4 min-w-4 shrink-0 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white"
              aria-label={`未対応${unread}件`}
            >
              {unread}
            </span>
          )}
        </div>
        <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
          {task.category && (
            <span className="rounded bg-sky-50 px-1 py-0.5 text-[9px] font-medium text-sky-700">{task.category}</span>
          )}
          <span className={cn('rounded px-1 py-0.5 text-[9px] font-medium', st.bg, st.color)}>{st.label}</span>
          <span className={cn('ml-auto text-[10px] font-semibold', TASK_PRIORITY[task.priority].color)}>
            {TASK_PRIORITY[task.priority].label}
          </span>
          {task.needsApproval && (
            <span className="rounded bg-amber-100 px-1 py-0.5 text-[9px] font-medium text-amber-700">要承認</span>
          )}
        </div>
        <div className="mt-1.5 flex items-center gap-1.5 text-[9.5px] text-slate-400">
          {agentName && <span className="truncate">🤖 {agentName}</span>}
          <span className="ml-auto tabular-nums">{task.deadline ? `期限 ${formatDate(task.deadline)}` : '期限なし'}</span>
        </div>
        {task.status === 'running' && (
          <div className="mt-1.5 flex items-center gap-1.5">
            <ProgressBar value={task.progress} className="h-1 flex-1" />
            <span className="text-[10px] tabular-nums text-slate-400">{task.progress}%</span>
          </div>
        )}
      </Link>
    </div>
  );
}
