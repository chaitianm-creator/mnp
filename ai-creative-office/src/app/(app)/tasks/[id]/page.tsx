'use client';

// ============================================================
// 案件ルーム: 1タスク=1ルーム
// タスクの詳細・専用チャット・AI提案・成果物・活動履歴を
// この画面にまとめる(会話・成果物は他の案件と混ざらない)
// PC: 2〜3カラム / スマホ: 縦積み。木目×パステルの箱庭テイスト
// ============================================================
import {
  assigneeCandidates,
  autoDraftIfRequested,
  generateTaskSuggestions,
  sendTaskRoomMessage,
} from '@/lib/agent-runner';
import { TASK_PRIORITY, TASK_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import type { TaskArtifact, TaskPriority, TaskStatus } from '@/lib/types';
import { cn, formatDateTime } from '@/lib/utils';
import { ArrowLeft, Check, Copy, Pencil, Send, Sparkles, Star, Trash2 } from 'lucide-react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';

/** ルームで切り替え可能な5ステータス(未着手/進行中/確認待ち/完了/保留) */
const ROOM_STATUSES: TaskStatus[] = ['backlog', 'running', 'waiting_approval', 'done', 'stopped'];
const ROOM_STATUS_LABEL: Record<string, string> = {
  backlog: '未着手',
  running: '進行中',
  waiting_approval: '確認待ち',
  done: '完了',
  stopped: '保留',
};
const PRIORITIES: TaskPriority[] = ['urgent', 'high', 'medium', 'low'];

export default function TaskRoomPage() {
  const params = useParams<{ id: string }>();
  const taskId = params.id;
  const task = useOffice((s) => s.tasks.find((t) => t.id === taskId));
  const room = useOffice((s) => s.taskRooms[taskId]);
  const agents = useOffice((s) => s.agents);
  const ensureTaskRoom = useOffice((s) => s.ensureTaskRoom);
  const markRoomRead = useOffice((s) => s.markRoomRead);
  const updateTask = useOffice((s) => s.updateTask);
  const addRoomActivity = useOffice((s) => s.addRoomActivity);

  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [suggesting, setSuggesting] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  // ルームの初期化 + 未対応件数のリセット + 「返事の文を考えて」への自動下書き
  useEffect(() => {
    if (!task) return;
    ensureTaskRoom(taskId);
    markRoomRead(taskId);
    void autoDraftIfRequested(taskId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [taskId, !!task]);

  // ルームを開いている間に届いたAI返信は既読にする
  useEffect(() => {
    if (room && room.unreadCount > 0) markRoomRead(taskId);
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [room?.messages.length, room?.unreadCount, taskId, markRoomRead, room]);

  if (!task) {
    return (
      <div className="py-20 text-center">
        <p className="text-sm text-slate-400">タスクが見つかりません。</p>
        <Link href="/tasks" className="mt-3 inline-block text-sm font-semibold text-brand-600 hover:underline">
          ← タスク管理へ戻る
        </Link>
      </div>
    );
  }

  const assignee = agents.find((a) => a.id === task.assigneeId);
  const candidates = assigneeCandidates(task);
  const agentOf = (id: string) => agents.find((a) => a.id === id);

  const changeStatus = (status: TaskStatus) => {
    if (status === task.status) return;
    updateTask(taskId, { status });
    addRoomActivity(taskId, `ステータスを「${ROOM_STATUS_LABEL[status] ?? TASK_STATUS[status].label}」へ変更しました`);
  };
  const changePriority = (priority: TaskPriority) => {
    if (priority === task.priority) return;
    updateTask(taskId, { priority });
    addRoomActivity(taskId, `優先度を「${TASK_PRIORITY[priority].label}」へ変更しました`);
  };
  const changeDeadline = (value: string) => {
    updateTask(taskId, { deadline: value ? new Date(`${value}T18:00:00`).toISOString() : null });
    addRoomActivity(taskId, value ? `期限を ${value} に設定しました` : '期限を解除しました');
  };
  const changeAssignee = (agentId: string) => {
    if (agentId === task.assigneeId) return;
    updateTask(taskId, { assigneeId: agentId });
    addRoomActivity(taskId, `担当AIを「${agentOf(agentId)?.name ?? agentId}」へ変更しました(実行は社長の指示があるまで行いません)`);
  };

  const send = async () => {
    const text = input.trim();
    if (!text || sending) return;
    setInput('');
    setSending(true);
    try {
      await sendTaskRoomMessage(taskId, text);
    } finally {
      setSending(false);
    }
  };

  const suggest = async () => {
    if (suggesting) return;
    setSuggesting(true);
    try {
      await generateTaskSuggestions(taskId);
    } finally {
      setSuggesting(false);
    }
  };

  const deadlineValue = task.deadline ? task.deadline.slice(0, 10) : '';
  const st = TASK_STATUS[task.status];

  return (
    <div className="mx-auto max-w-6xl">
      {/* ヘッダー: タスク名 + ステータス・優先度・期限・担当AI */}
      <div className="rounded-2xl border border-amber-200/70 bg-gradient-to-br from-amber-50 via-orange-50/60 to-rose-50/50 p-4 shadow-sm">
        <div className="flex items-start gap-2">
          <Link
            href="/tasks"
            className="mt-0.5 flex shrink-0 items-center gap-1 rounded-full border border-amber-200 bg-white/80 px-2.5 py-1 text-[11px] font-semibold text-amber-700 transition hover:bg-white"
          >
            <ArrowLeft className="h-3 w-3" /> タスク一覧
          </Link>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="text-base">🗂</span>
              <h1 className="text-base font-extrabold leading-snug text-slate-800">{task.title}</h1>
              {task.category && (
                <span className="rounded-full bg-sky-100 px-2 py-0.5 text-[10px] font-bold text-sky-700">{task.category}</span>
              )}
              <span className={cn('rounded-full px-2 py-0.5 text-[10px] font-bold', st.bg, st.color)}>{st.label}</span>
            </div>
            <p className="mt-0.5 text-[11px] text-slate-500">
              この案件専用のルームです。会話・成果物・履歴はこのタスクにだけ保存されます。
            </p>
          </div>
        </div>

        <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
          <label className="block">
            <span className="text-[10px] font-bold text-slate-500">ステータス</span>
            <select
              value={ROOM_STATUSES.includes(task.status) ? task.status : ''}
              onChange={(e) => e.target.value && changeStatus(e.target.value as TaskStatus)}
              aria-label="ステータスを変更"
              className="mt-0.5 w-full rounded-lg border border-amber-200 bg-white px-2 py-1.5 text-xs font-semibold text-slate-700 outline-none focus:border-brand-400"
            >
              {!ROOM_STATUSES.includes(task.status) && <option value="">{st.label}</option>}
              {ROOM_STATUSES.map((s2) => (
                <option key={s2} value={s2}>
                  {ROOM_STATUS_LABEL[s2]}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="text-[10px] font-bold text-slate-500">優先度</span>
            <select
              value={task.priority}
              onChange={(e) => changePriority(e.target.value as TaskPriority)}
              aria-label="優先度を変更"
              className="mt-0.5 w-full rounded-lg border border-amber-200 bg-white px-2 py-1.5 text-xs font-semibold text-slate-700 outline-none focus:border-brand-400"
            >
              {PRIORITIES.map((p) => (
                <option key={p} value={p}>
                  {TASK_PRIORITY[p].label}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="text-[10px] font-bold text-slate-500">期限</span>
            <input
              type="date"
              value={deadlineValue}
              onChange={(e) => changeDeadline(e.target.value)}
              aria-label="期限を設定"
              className="mt-0.5 w-full rounded-lg border border-amber-200 bg-white px-2 py-1.5 text-xs font-semibold text-slate-700 outline-none focus:border-brand-400"
            />
          </label>
          <div>
            <span className="text-[10px] font-bold text-slate-500">担当AI</span>
            <p className="mt-0.5 flex h-[30px] items-center gap-1 rounded-lg border border-amber-200 bg-white px-2 text-xs font-semibold text-slate-700">
              <span>{assignee?.avatar ?? '🤖'}</span>
              <span className="truncate">{assignee?.name ?? '未設定'}</span>
            </p>
          </div>
        </div>

        {/* 担当AI候補(押すまで実行しない) */}
        <div className="mt-2 flex flex-wrap items-center gap-1.5">
          <span className="text-[10px] font-bold text-slate-400">担当候補:</span>
          {candidates.map((c) => {
            const a = agentOf(c.agentId);
            const active = task.assigneeId === c.agentId;
            return (
              <button
                key={c.agentId}
                onClick={() => changeAssignee(c.agentId)}
                title={c.reason}
                className={cn(
                  'rounded-full border px-2 py-1 text-[10px] font-semibold transition',
                  active
                    ? 'border-brand-300 bg-brand-50 text-brand-700'
                    : 'border-amber-200 bg-white/80 text-slate-600 hover:bg-white',
                )}
              >
                {a?.avatar} {a?.name ?? c.agentId}
                {active && ' ✓'}
              </button>
            );
          })}
          <span className="text-[10px] text-slate-400">※選択しても自動実行はしません。指示はチャットからどうぞ</span>
        </div>
      </div>

      <div className="mt-3 grid gap-3 lg:grid-cols-3">
        {/* 左カラム(PC 2/3幅): 元の依頼内容 + 案件専用チャット */}
        <div className="min-w-0 space-y-3 lg:col-span-2">
          {/* 元の指示・依頼内容(全文) */}
          <section className="rounded-2xl border border-emerald-200/70 bg-emerald-50/50 p-3.5">
            <h2 className="flex items-center gap-1.5 text-xs font-extrabold text-emerald-800">📝 元の指示・依頼内容(全文)</h2>
            <p className="mt-2 whitespace-pre-wrap rounded-xl border border-emerald-100 bg-white/80 p-3 text-[12.5px] leading-relaxed text-slate-700">
              {room?.sourceRequest || task.input || task.description || '(元の依頼内容は記録されていません)'}
            </p>
          </section>

          {/* 案件専用チャット */}
          <section className="flex flex-col rounded-2xl border border-amber-200/70 bg-[#fdf9f0] shadow-sm">
            <div className="flex items-center gap-1.5 border-b border-amber-100 px-3.5 py-2.5">
              <h2 className="text-xs font-extrabold text-amber-800">💬 案件専用チャット</h2>
              <span className="text-[10px] text-slate-400">この会話は「{task.title}」だけに保存されます</span>
            </div>
            <div className="max-h-[420px] min-h-[180px] space-y-2.5 overflow-y-auto px-3.5 py-3" aria-label="案件チャットの履歴">
              {(room?.messages ?? []).length === 0 && (
                <div className="rounded-xl border border-dashed border-amber-200 bg-white/60 px-3 py-5 text-center text-[11px] text-slate-400">
                  まだ会話はありません。
                  <br />
                  「返信文を作って」「この件どう進める?」など、この案件のことを何でも相談できます。
                </div>
              )}
              {(room?.messages ?? []).map((m) => {
                const a = m.agentId ? agentOf(m.agentId) : undefined;
                return (
                  <div key={m.id} className={cn('flex', m.role === 'user' ? 'justify-end' : 'justify-start')}>
                    <div className={cn('max-w-[85%]', m.role === 'user' ? 'text-right' : 'text-left')}>
                      <p className="mb-0.5 px-1 text-[9.5px] text-slate-400">
                        {m.role === 'user' ? '社長' : `${a?.avatar ?? '🤖'} ${a?.name ?? '秘書AI'}`}
                      </p>
                      <div
                        className={cn(
                          'whitespace-pre-wrap rounded-2xl px-3 py-2 text-left text-[12.5px] leading-relaxed shadow-sm',
                          m.role === 'user'
                            ? 'rounded-tr-sm bg-gradient-to-br from-brand-600 to-accent-600 text-white'
                            : 'rounded-tl-sm border border-amber-100 bg-white text-slate-700',
                        )}
                      >
                        {m.content}
                      </div>
                    </div>
                  </div>
                );
              })}
              {sending && (
                <div className="flex items-center gap-1.5 px-1 text-[11px] text-slate-400">
                  <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-amber-400" />
                  AIが返信を作成しています…
                </div>
              )}
              <div ref={chatEndRef} />
            </div>
            <div className="border-t border-amber-100 p-2.5">
              <div className="flex items-end gap-2">
                <textarea
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                      e.preventDefault();
                      void send();
                    }
                  }}
                  rows={Math.min(4, Math.max(1, input.split('\n').length))}
                  placeholder="この案件について相談・指示(Enterで送信 / Shift+Enterで改行)"
                  className="min-w-0 flex-1 resize-none rounded-xl border border-amber-200 bg-white px-3 py-2 text-[12.5px] text-slate-700 outline-none placeholder:text-slate-300 focus:border-brand-400"
                />
                <button
                  onClick={() => void send()}
                  disabled={sending || !input.trim()}
                  aria-label="送信"
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-brand-600 to-accent-600 text-white shadow-sm transition disabled:opacity-40"
                >
                  <Send className="h-4 w-4" />
                </button>
              </div>
              <p className="mt-1 px-1 text-[9.5px] text-slate-400">
                外部への送信・SNS投稿は行いません。下書き・提案までをこのルームで行います。
              </p>
            </div>
          </section>
        </div>

        {/* 右カラム: AI提案 + 成果物 + 活動履歴 */}
        <div className="min-w-0 space-y-3">
          {/* AI提案エリア */}
          <section className="rounded-2xl border border-violet-200/70 bg-violet-50/50 p-3.5">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-xs font-extrabold text-violet-800">✨ AI提案</h2>
              <button
                onClick={() => void suggest()}
                disabled={suggesting}
                className="flex items-center gap-1 rounded-full border border-violet-200 bg-white px-2.5 py-1 text-[10px] font-bold text-violet-700 transition hover:bg-violet-100 disabled:opacity-50"
              >
                <Sparkles className="h-3 w-3" />
                {suggesting ? '作成中…' : room?.suggestions ? '提案を更新' : '提案を作成'}
              </button>
            </div>
            {room?.suggestions ? (
              <div className="mt-2 space-y-2">
                <SuggestBlock title="対応方針" items={room.suggestions.approaches} emoji="🧭" />
                <SuggestBlock title="確認すべきこと" items={room.suggestions.checkpoints} emoji="☑️" />
                <SuggestBlock title="次のアクション" items={room.suggestions.nextActions} emoji="👣" />
                <SuggestBlock title="不足している情報" items={room.suggestions.missingInfo} emoji="🧩" />
              </div>
            ) : (
              <p className="mt-2 rounded-xl border border-dashed border-violet-200 bg-white/60 px-3 py-4 text-center text-[11px] text-slate-400">
                「提案を作成」を押すと、対応方針・確認事項・
                <br />
                次のアクションをAIが整理します。
              </p>
            )}
          </section>

          {/* 成果物エリア */}
          <section className="rounded-2xl border border-sky-200/70 bg-sky-50/50 p-3.5">
            <h2 className="text-xs font-extrabold text-sky-800">📦 成果物({room?.artifacts.length ?? 0}件)</h2>
            <div className="mt-2 space-y-2">
              {(room?.artifacts ?? []).map((a) => (
                <ArtifactCard key={a.id} taskId={taskId} artifact={a} />
              ))}
              {(room?.artifacts ?? []).length === 0 && (
                <p className="rounded-xl border border-dashed border-sky-200 bg-white/60 px-3 py-4 text-center text-[11px] text-slate-400">
                  まだ成果物はありません。チャットで
                  <br />
                  「返信文を作って」と頼むとここに保存されます。
                </p>
              )}
            </div>
          </section>

          {/* 活動履歴 */}
          <section className="rounded-2xl border border-slate-200 bg-white/80 p-3.5">
            <h2 className="text-xs font-extrabold text-slate-600">🕰 活動履歴</h2>
            <ul className="mt-2 max-h-56 space-y-1.5 overflow-y-auto">
              {(room?.activities ?? []).map((act) => (
                <li key={act.id} className="text-[10.5px] leading-relaxed text-slate-500">
                  <span className="tabular-nums text-slate-400">{formatDateTime(act.timestamp)}</span>
                  <span className="ml-1.5">{act.message}</span>
                </li>
              ))}
              {(room?.activities ?? []).length === 0 && (
                <li className="text-[11px] text-slate-400">まだ履歴はありません。</li>
              )}
            </ul>
          </section>
        </div>
      </div>
    </div>
  );
}

function SuggestBlock({ title, items, emoji }: { title: string; items: string[]; emoji: string }) {
  if (items.length === 0) return null;
  return (
    <div className="rounded-xl border border-violet-100 bg-white/80 px-3 py-2">
      <p className="text-[10px] font-extrabold text-violet-700">
        {emoji} {title}
      </p>
      <ul className="mt-1 space-y-0.5">
        {items.map((item, i) => (
          <li key={i} className="flex gap-1 text-[11px] leading-relaxed text-slate-600">
            <span className="text-violet-300">・</span>
            <span className="min-w-0 flex-1">{item}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** 成果物カード: コピー / 編集して保存 / 削除 / 最新版に設定 */
function ArtifactCard({ taskId, artifact }: { taskId: string; artifact: TaskArtifact }) {
  const updateRoomArtifact = useOffice((s) => s.updateRoomArtifact);
  const deleteRoomArtifact = useOffice((s) => s.deleteRoomArtifact);
  const setArtifactLatest = useOffice((s) => s.setArtifactLatest);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(artifact.content);
  const [copied, setCopied] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(artifact.content);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      /* クリップボード非対応環境では何もしない */
    }
  };

  return (
    <div className={cn('rounded-xl border bg-white/90 p-2.5', artifact.isLatest ? 'border-sky-300 ring-1 ring-sky-200' : 'border-sky-100')}>
      <div className="flex items-center gap-1.5">
        <span className="rounded bg-sky-100 px-1.5 py-0.5 text-[9px] font-bold text-sky-700">{artifact.kind}</span>
        {artifact.isLatest && (
          <span className="flex items-center gap-0.5 rounded bg-amber-100 px-1.5 py-0.5 text-[9px] font-bold text-amber-700">
            <Star className="h-2.5 w-2.5 fill-amber-500 text-amber-500" /> 最新版
          </span>
        )}
        <span className="ml-auto text-[9px] tabular-nums text-slate-400">{formatDateTime(artifact.updatedAt)}</span>
      </div>
      <p className="mt-1.5 text-[11.5px] font-bold text-slate-700">{artifact.title}</p>

      {editing ? (
        <div className="mt-1.5">
          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            rows={8}
            aria-label="成果物を編集"
            className="w-full resize-y rounded-lg border border-sky-200 bg-white px-2.5 py-2 text-[11.5px] leading-relaxed text-slate-700 outline-none focus:border-brand-400"
          />
          <div className="mt-1.5 flex gap-1.5">
            <button
              onClick={() => {
                updateRoomArtifact(taskId, artifact.id, { content: draft });
                setEditing(false);
              }}
              className="flex items-center gap-1 rounded-lg bg-brand-600 px-2.5 py-1.5 text-[10px] font-bold text-white"
            >
              <Check className="h-3 w-3" /> 保存
            </button>
            <button
              onClick={() => {
                setDraft(artifact.content);
                setEditing(false);
              }}
              className="rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 text-[10px] font-semibold text-slate-500"
            >
              キャンセル
            </button>
          </div>
        </div>
      ) : (
        <p className="mt-1.5 max-h-40 overflow-y-auto whitespace-pre-wrap rounded-lg bg-slate-50 px-2.5 py-2 text-[11px] leading-relaxed text-slate-600">
          {artifact.content}
        </p>
      )}

      {!editing && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          <button onClick={() => void copy()} className="flex items-center gap-1 rounded-lg border border-slate-200 bg-white px-2 py-1 text-[10px] font-semibold text-slate-600 transition hover:bg-slate-50">
            <Copy className="h-3 w-3" /> {copied ? 'コピーしました' : 'コピー'}
          </button>
          <button
            onClick={() => {
              setDraft(artifact.content);
              setEditing(true);
            }}
            className="flex items-center gap-1 rounded-lg border border-slate-200 bg-white px-2 py-1 text-[10px] font-semibold text-slate-600 transition hover:bg-slate-50"
          >
            <Pencil className="h-3 w-3" /> 編集
          </button>
          {!artifact.isLatest && (
            <button
              onClick={() => setArtifactLatest(taskId, artifact.id)}
              className="flex items-center gap-1 rounded-lg border border-amber-200 bg-amber-50 px-2 py-1 text-[10px] font-semibold text-amber-700 transition hover:bg-amber-100"
            >
              <Star className="h-3 w-3" /> 最新版に設定
            </button>
          )}
          {confirmDelete ? (
            <span className="flex items-center gap-1">
              <button onClick={() => deleteRoomArtifact(taskId, artifact.id)} className="rounded-lg bg-red-500 px-2 py-1 text-[10px] font-bold text-white">
                削除する
              </button>
              <button onClick={() => setConfirmDelete(false)} className="rounded-lg border border-slate-200 bg-white px-2 py-1 text-[10px] text-slate-500">
                やめる
              </button>
            </span>
          ) : (
            <button
              onClick={() => setConfirmDelete(true)}
              className="flex items-center gap-1 rounded-lg border border-red-100 bg-white px-2 py-1 text-[10px] font-semibold text-red-500 transition hover:bg-red-50"
            >
              <Trash2 className="h-3 w-3" /> 削除
            </button>
          )}
        </div>
      )}
    </div>
  );
}
