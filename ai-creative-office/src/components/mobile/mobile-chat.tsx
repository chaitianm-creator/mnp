'use client';

// スマホ版チャット: 会話一覧(CEO + AI社員) → スレッド表示
// CEOスレッドはPC版「社長指示チャット」と同じストア・同じ実行フローを使う
import { AgentChat } from '@/components/agent-chat';
import { AgentAvatar, AgentStatusBadge } from '@/components/agent-bits';
import { RunCard } from '@/components/run-card';
import { getPendingConsult, getPendingResearch, handleCeoMessage, proceedWithoutAnswers } from '@/lib/agent-runner';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime, uid, yen } from '@/lib/utils';
import { ChevronLeft, ChevronRight, Loader2, Play, Send, Sparkles, Trash2 } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

const RUN_TEMPLATES = [
  { label: 'Instagram投稿', text: '中小企業の経営者向けに、Web制作の豆知識を伝えるInstagram投稿を作って' },
  { label: 'Instagramカルーセル', text: 'ホームページ改善のポイントをまとめたInstagramカルーセル投稿を作って' },
  { label: 'X投稿', text: 'Web制作の役立ち情報をXに投稿する文章を作って' },
  { label: 'ブログ記事', text: '「ホームページ リニューアル 費用」で上位を狙うブログ記事を作って' },
  { label: 'LP構成とコピー', text: '新サービスのランディングページの構成とキャッチコピーを作って。ターゲットは中小企業の経営者' },
  { label: 'バナー制作', text: '無料相談キャンペーンの告知バナーを作って' },
];

export function MobileChat({ thread, setThread }: { thread: string | null; setThread: (t: string | null) => void }) {
  const agents = useOffice((s) => s.agents);
  const unread = useOffice((s) => s.unread);
  const directChats = useOffice((s) => s.directChats);
  const chat = useOffice((s) => s.chat);

  if (thread === 'ceo') return <CeoThread onBack={() => setThread(null)} />;
  const threadAgent = agents.find((a) => a.id === thread);
  if (threadAgent) {
    return (
      <div className="flex h-full flex-col">
        <ThreadHeader onBack={() => setThread(null)}>
          <AgentAvatar agent={threadAgent} size="sm" />
          <div className="min-w-0">
            <p className="truncate text-[13px] font-bold text-slate-800">{threadAgent.displayName ?? threadAgent.name}</p>
            <p className="truncate text-[10px] text-slate-400">{threadAgent.statusNote}</p>
          </div>
          <span className="ml-auto shrink-0">
            <AgentStatusBadge agent={threadAgent} />
          </span>
        </ThreadHeader>
        <div className="min-h-0 flex-1 px-3">
          <AgentChat agent={threadAgent} onClose={() => setThread(null)} />
        </div>
      </div>
    );
  }

  // 会話一覧
  const lastCeo = chat[chat.length - 1];
  const sorted = [...agents].sort((a, b) => (unread[b.id] ?? 0) - (unread[a.id] ?? 0));

  return (
    <div className="h-full overflow-y-auto overscroll-contain pb-4">
      <p className="px-4 pb-1 pt-3 text-[11px] font-semibold text-slate-400">経営</p>
      <button
        onClick={() => setThread('ceo')}
        className="flex w-full items-center gap-3 bg-white px-4 py-3 text-left outline-none active:bg-slate-50 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-500"
      >
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-brand-600 to-accent-600 text-lg">
          👔
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-[13px] font-bold text-slate-800">CEO AI(社長指示チャット)</p>
          <p className="mt-0.5 truncate text-[11px] text-slate-400">
            {lastCeo ? lastCeo.content.slice(0, 40) : '依頼するとAI社員が実際に成果物を作ります'}
          </p>
        </div>
        <ChevronRight className="h-4 w-4 shrink-0 text-slate-300" />
      </button>

      <p className="px-4 pb-1 pt-4 text-[11px] font-semibold text-slate-400">AI社員</p>
      <div className="divide-y divide-slate-100 bg-white">
        {sorted.map((agent) => {
          const msgs = directChats[agent.id] ?? [];
          const last = msgs[msgs.length - 1];
          const count = unread[agent.id] ?? 0;
          return (
            <button
              key={agent.id}
              onClick={() => setThread(agent.id)}
              className="flex w-full items-center gap-3 px-4 py-2.5 text-left outline-none active:bg-slate-50 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-500"
              aria-label={`${agent.name}との会話を開く${count > 0 ? `(未読${count}件)` : ''}`}
            >
              <AgentAvatar agent={agent} size="sm" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <p className="truncate text-[13px] font-bold text-slate-800">{agent.displayName ?? agent.name}</p>
                </div>
                <p className="mt-0.5 truncate text-[11px] text-slate-400">
                  {last ? last.content.replace(/\n/g, ' ').slice(0, 40) : agent.statusNote}
                </p>
              </div>
              {count > 0 && (
                <span className="flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-brand-600 px-1.5 text-[10px] font-bold text-white">
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function ThreadHeader({ children, onBack }: { children: React.ReactNode; onBack: () => void }) {
  return (
    <div className="flex shrink-0 items-center gap-2 border-b border-slate-100 bg-white px-2 py-2">
      <button
        onClick={onBack}
        aria-label="会話一覧へ戻る"
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-slate-500 outline-none active:bg-slate-100 focus-visible:ring-2 focus-visible:ring-brand-500"
      >
        <ChevronLeft className="h-5 w-5" />
      </button>
      {children}
    </div>
  );
}

// CEOスレッド(AI実働: 依頼→計画→承認→成果物生成)
function CeoThread({ onBack }: { onBack: () => void }) {
  const chat = useOffice((s) => s.chat);
  const agents = useOffice((s) => s.agents);
  const sendChat = useOffice((s) => s.sendChat);
  const startPlan = useOffice((s) => s.startPlan);
  const discardPlan = useOffice((s) => s.discardPlan);
  const [input, setInput] = useState('');
  const [planning, setPlanning] = useState(false);
  const [aiMode, setAiMode] = useState(true);
  const [expandedDetails, setExpandedDetails] = useState<Set<string>>(new Set());
  const bottomRef = useRef<HTMLDivElement>(null);

  const toggleDetail = (id: string) =>
    setExpandedDetails((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [chat.length, planning]);

  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;

  const pendingConsult = chat.length > 0 ? getPendingConsult() : null;
  const pendingResearch = chat.length > 0 ? getPendingResearch() : null;

  const submit = async () => {
    const request = input.trim();
    if (!request || planning) return;
    setInput('');
    if (!aiMode) {
      sendChat(request);
      return;
    }
    useOffice.setState((s) => ({
      chat: [...s.chat, { id: uid('chat'), role: 'ceo_user' as const, content: request, timestamp: new Date().toISOString() }],
    }));
    setPlanning(true);
    try {
      await handleCeoMessage(request);
    } catch (e) {
      const message = e instanceof Error ? e.message : '計画の作成に失敗しました';
      useOffice.setState((s) => ({
        chat: [
          ...s.chat,
          { id: uid('chat'), role: 'ceo_ai' as const, content: `申し訳ありません、処理に失敗しました: ${message}\nもう一度お試しください。`, timestamp: new Date().toISOString() },
        ],
      }));
    } finally {
      setPlanning(false);
    }
  };

  const omakase = async (messageId: string) => {
    if (planning) return;
    setPlanning(true);
    try {
      await proceedWithoutAnswers(messageId);
    } catch {
      // エラーはチャット側のメッセージで通知済み
    } finally {
      setPlanning(false);
    }
  };

  return (
    <div className="flex h-full flex-col">
      <ThreadHeader onBack={onBack}>
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-brand-600 to-accent-600 text-base">👔</span>
        <div className="min-w-0">
          <p className="text-[13px] font-bold text-slate-800">CEO AI</p>
          <p className="text-[10px] text-slate-400">「開始」を押すまでAIは実行されません</p>
        </div>
        <label className="ml-auto flex shrink-0 items-center gap-1.5 text-[10px] text-slate-500">
          <Sparkles className="h-3 w-3 text-brand-600" />
          AI実働
          <button
            onClick={() => setAiMode((v) => !v)}
            className={cn('relative h-5 w-9 rounded-full transition', aiMode ? 'bg-brand-600' : 'bg-slate-300')}
            aria-label="AI実働モード切り替え"
            aria-pressed={aiMode}
          >
            <span className={cn('absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-all', aiMode ? 'left-[18px]' : 'left-0.5')} />
          </button>
        </label>
      </ThreadHeader>

      {/* 会話履歴 */}
      <div className="min-h-0 flex-1 space-y-3 overflow-y-auto overscroll-contain px-3 py-3" aria-live="polite">
        {chat.map((msg) => (
          <div key={msg.id} className={msg.role === 'ceo_user' ? 'flex justify-end' : 'flex justify-start'}>
            <div className={msg.role === 'ceo_user' ? 'max-w-[88%]' : 'w-full max-w-[95%]'}>
              <p className="mb-0.5 flex items-center gap-1 px-1 text-[10px] tabular-nums text-slate-400">
                {msg.role === 'ceo_user' ? 'あなた(社長)' : (msg.speakerName ?? '👔 CEO AI')}
                {msg.role === 'ceo_ai' && (
                  <span className={`rounded-full px-1 py-px text-[8.5px] font-semibold ${msg.speakerName ? 'bg-sky-50 text-sky-600' : 'bg-brand-50 text-brand-600'}`}>
                    {msg.speakerName ? '制作判断' : '経営判断'}
                  </span>
                )}
                ・ {formatDateTime(msg.timestamp)}
              </p>
              <div
                className={cn(
                  'whitespace-pre-wrap rounded-2xl px-3.5 py-2.5 text-[13px] leading-relaxed',
                  msg.role === 'ceo_user'
                    ? 'rounded-tr-sm bg-gradient-to-r from-brand-600 to-accent-600 text-white'
                    : 'rounded-tl-sm border border-slate-200 bg-white text-slate-700',
                )}
              >
                {msg.content}
                {msg.plan && (
                  <div className="mt-2.5 rounded-xl border border-slate-200 bg-slate-50/70 p-2.5 text-slate-700">
                    <p className="text-[12px] font-bold text-slate-900">📋 実行プラン</p>
                    <p className="mt-1 text-[11px]">{msg.plan.summary}</p>
                    <div className="mt-1.5 space-y-1">
                      {msg.plan.tasks.map((t, i) => (
                        <div key={i} className="flex items-center gap-1.5 rounded-lg bg-white px-2 py-1 text-[11px]">
                          <span className="flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-brand-100 text-[9px] font-bold text-brand-700">
                            {t.order}
                          </span>
                          <span className="min-w-0 flex-1 truncate">{t.title}</span>
                          <span className="shrink-0 rounded bg-slate-100 px-1 py-0.5 text-[9px] text-slate-500">{agentName(t.assigneeId)}</span>
                        </div>
                      ))}
                    </div>
                    <p className="mt-1.5 text-[10px] text-slate-500">想定コスト: 約 {yen(msg.plan.estimatedCostJpy)}(AI利用料)</p>
                    {msg.planStatus === 'proposed' && (
                      <div className="mt-2 flex gap-1.5">
                        <button
                          onClick={() => startPlan(msg.id)}
                          className="flex flex-1 items-center justify-center gap-1 rounded-lg bg-brand-600 px-2 py-2 text-[12px] font-bold text-white outline-none active:bg-brand-700 focus-visible:ring-2 focus-visible:ring-brand-500"
                        >
                          <Play className="h-3.5 w-3.5" /> この内容で開始
                        </button>
                        <button
                          onClick={() => discardPlan(msg.id)}
                          className="flex items-center gap-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-[12px] text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                        >
                          <Trash2 className="h-3.5 w-3.5" /> 破棄
                        </button>
                      </div>
                    )}
                    {msg.planStatus === 'started' && (
                      <p className="mt-2 rounded-lg bg-emerald-50 px-2.5 py-1.5 text-[11px] font-medium text-emerald-700">
                        ✅ 開始しました。担当AI社員へ割り振りました。
                      </p>
                    )}
                    {msg.planStatus === 'discarded' && (
                      <p className="mt-2 rounded-lg bg-slate-100 px-2.5 py-1.5 text-[11px] text-slate-500">このプランは破棄されました。</p>
                    )}
                  </div>
                )}
                {/* 詳しく見る(判断根拠の展開) */}
                {msg.consult?.detail && (
                  <div className="mt-2">
                    <button
                      onClick={() => toggleDetail(msg.id)}
                      className="rounded-full border border-slate-200 bg-white px-2.5 py-1 text-[10.5px] font-medium text-slate-600 outline-none active:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                      aria-expanded={expandedDetails.has(msg.id)}
                    >
                      {expandedDetails.has(msg.id) ? '詳細を閉じる ▲' : '詳しく見る(判断根拠) ▼'}
                    </button>
                    {expandedDetails.has(msg.id) && (
                      <div className="mt-1.5 whitespace-pre-wrap rounded-xl border border-slate-200 bg-white p-2.5 text-[11px] leading-relaxed text-slate-600">
                        {msg.consult.detail}
                      </div>
                    )}
                  </div>
                )}
                {/* ディレクターの確認質問(スマホ: 選択肢タップで回答を入力欄へ) */}
                {msg.consult && msg.consult.questions.length > 0 && (
                  <div className="mt-2.5 rounded-xl border border-brand-200 bg-brand-50/40 p-2.5">
                    <p className="text-[11px] font-bold text-brand-800">💬 確認事項への回答</p>
                    {msg.consult.answered ? (
                      <p className="mt-1.5 rounded-lg bg-emerald-50 px-2 py-1.5 text-[11px] text-emerald-700">✅ 回答済み。実行計画を作成しました。</p>
                    ) : (
                      <>
                        {msg.consult.questions.map((q, qi) => (
                          <div key={qi} className="mt-1.5">
                            <p className="text-[11px] font-semibold text-slate-700">{qi + 1}. {q.question}</p>
                            <div className="mt-1 flex flex-wrap gap-1">
                              {q.options.map((opt) => (
                                <button
                                  key={opt}
                                  onClick={() => setInput((cur) => (cur ? `${cur} / ${opt}` : `${q.question} → ${opt}`))}
                                  className="rounded-full border border-brand-200 bg-white px-2 py-1 text-[10.5px] text-brand-700 outline-none active:bg-brand-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                                >
                                  {opt}
                                </button>
                              ))}
                            </div>
                          </div>
                        ))}
                        <button
                          onClick={() => omakase(msg.id)}
                          disabled={planning}
                          className="mt-2 w-full rounded-lg border border-slate-200 bg-white px-2 py-2 text-[11px] font-medium text-slate-600 outline-none active:bg-slate-50 disabled:opacity-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                        >
                          お任せで進める
                        </button>
                      </>
                    )}
                  </div>
                )}
                {msg.runId && <RunCard runId={msg.runId} onModify={(req) => setInput(req)} />}
              </div>
            </div>
          </div>
        ))}
        {planning && (
          <div className="flex items-center gap-2 rounded-2xl rounded-tl-sm border border-slate-200 bg-white px-3.5 py-2.5 text-[12px] text-slate-500">
            <Loader2 className="h-4 w-4 animate-spin text-brand-600" />
            CEO AIが実行計画を作成しています…
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* テンプレート + 入力欄(下部=親指ゾーン) */}
      <div className="shrink-0 border-t border-slate-100 bg-white px-3 pb-2 pt-2">
        {aiMode && (
          <div className="mb-2 flex gap-1.5 overflow-x-auto pb-0.5">
            {RUN_TEMPLATES.map((t) => (
              <button
                key={t.label}
                onClick={() => setInput(t.text)}
                className="shrink-0 rounded-full border border-brand-200 bg-brand-50/50 px-2.5 py-1 text-[11px] text-brand-700 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
              >
                ✨ {t.label}
              </button>
            ))}
          </div>
        )}
        <div className="flex gap-2">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !e.nativeEvent.isComposing && submit()}
            placeholder={pendingConsult ? '確認事項へのご回答を入力…' : pendingResearch ? '5つの確認へのご回答を入力…' : aiMode ? '依頼・相談・「テーマ: ◯◯」…' : 'CEO AIへ指示を入力…'}
            disabled={planning}
            aria-label="CEO AIへのメッセージ入力"
            className="min-w-0 flex-1 rounded-xl border border-slate-200 px-3.5 py-2.5 text-sm outline-none focus:border-brand-400 disabled:opacity-60"
          />
          <button
            onClick={submit}
            disabled={planning}
            aria-label="送信"
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-r from-brand-600 to-accent-600 text-white outline-none active:opacity-80 disabled:opacity-50 focus-visible:ring-2 focus-visible:ring-brand-500"
          >
            <Send className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
