'use client';

// 社長指示チャット(CEO AIとの対話)
// 「AI実働」: 依頼→CEO計画→承認→ディレクター/ライター/レビュアーが実際の成果物を生成
import { RunCard } from '@/components/run-card';
import { Button, PageHeader } from '@/components/ui';
import { getPendingConsult, getPendingResearch, handleCeoMessage, proceedWithoutAnswers } from '@/lib/agent-runner';
import { useOffice } from '@/lib/store';
import { formatDateTime, uid, yen } from '@/lib/utils';
import { motion } from 'framer-motion';
import { ChevronDown, ChevronUp, Loader2, Play, Send, Sparkles, Trash2 } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

// AI実働の依頼テンプレート(クリックでたたき台を入力)
const RUN_TEMPLATES = [
  { label: 'Instagram投稿', text: '中小企業の経営者向けに、Web制作の豆知識を伝えるInstagram投稿を作って' },
  { label: 'Instagramカルーセル', text: 'ホームページ改善のポイントをまとめたInstagramカルーセル投稿を作って' },
  { label: 'Instagramリール', text: '制作実績を紹介するInstagramリールの構成を作って' },
  { label: 'X投稿', text: 'Web制作の役立ち情報をXに投稿する文章を作って' },
  { label: 'ブログ記事', text: '「ホームページ リニューアル 費用」で上位を狙うブログ記事を作って' },
  { label: 'LP構成とコピー', text: '新サービスのランディングページの構成とキャッチコピーを作って。ターゲットは中小企業の経営者' },
  { label: 'コーポレートサイト構成', text: '製造業の中小企業向けに、信頼感のあるコーポレートサイトの構成案を作って' },
  { label: 'バナー制作', text: '無料相談キャンペーンの告知バナーを作って' },
  { label: '提案書作成', text: '製造業のお客様向けに、ホームページリニューアルの提案書を作って' },
];

const EXAMPLES = [
  '今月、制作会社100社の営業リストを作成して',
  '問い合わせへの返信案を作成して',
  '今週の営業結果をまとめて',
];

export default function ChatPage() {
  const chat = useOffice((s) => s.chat);
  const agents = useOffice((s) => s.agents);
  const sendChat = useOffice((s) => s.sendChat);
  const startPlan = useOffice((s) => s.startPlan);
  const discardPlan = useOffice((s) => s.discardPlan);
  const [input, setInput] = useState('');
  const [planning, setPlanning] = useState(false);
  const [aiMode, setAiMode] = useState(true); // true=AI実働(実成果物) / false=デモプラン
  const [expandedDetails, setExpandedDetails] = useState<Set<string>>(new Set()); // 「詳しく見る」の展開状態
  const bottomRef = useRef<HTMLDivElement>(null);

  const toggleDetail = (id: string) =>
    setExpandedDetails((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
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
    // CEOの統一入口: 経営相談 / ディープリサーチ / 制作依頼(→ディレクター引き継ぎ)を自動判定
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
    } catch (e) {
      const message = e instanceof Error ? e.message : '計画の作成に失敗しました';
      useOffice.setState((s) => ({
        chat: [...s.chat, { id: uid('chat'), role: 'ceo_ai' as const, content: `申し訳ありません、処理に失敗しました: ${message}`, timestamp: new Date().toISOString() }],
      }));
    } finally {
      setPlanning(false);
    }
  };

  return (
    <div className="flex h-[calc(100vh-120px)] flex-col lg:h-[calc(100vh-80px)]">
      <PageHeader
        title="社長指示チャット"
        sub="CEO AIが指示を分析し、実行計画を提案します。「開始」を押すまでAIは実行されません"
        action={
          <label className="flex cursor-pointer items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs">
            <Sparkles className="h-3.5 w-3.5 text-brand-600" />
            AI実働モード(成果物を生成)
            <button
              onClick={() => setAiMode((v) => !v)}
              className={`relative h-5 w-9 rounded-full transition ${aiMode ? 'bg-brand-600' : 'bg-slate-300'}`}
              aria-label="AI実働モード切り替え"
              aria-pressed={aiMode}
            >
              <span className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-all ${aiMode ? 'left-[18px]' : 'left-0.5'}`} />
            </button>
          </label>
        }
      />

      <div className="flex-1 space-y-4 overflow-y-auto rounded-xl border border-slate-200 bg-white p-4">
        {chat.map((msg) => (
          <motion.div
            key={msg.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            className={msg.role === 'ceo_user' ? 'flex justify-end' : 'flex justify-start'}
          >
            <div className={msg.role === 'ceo_user' ? 'max-w-[85%]' : 'w-full max-w-[95%] sm:max-w-[85%]'}>
              <p className="mb-1 flex items-center gap-2 text-[11px] text-slate-400">
                {msg.role === 'ceo_user' ? 'あなた(社長)' : (msg.speakerName ?? '👔 CEO AI')}
                {msg.role === 'ceo_ai' && (
                  <span className={`rounded-full px-1.5 py-px text-[9px] font-semibold ${msg.speakerName ? 'bg-sky-50 text-sky-600' : 'bg-brand-50 text-brand-600'}`}>
                    {msg.speakerName ? '制作判断' : '経営判断'}
                  </span>
                )}
                <span className="tabular-nums">{formatDateTime(msg.timestamp)}</span>
              </p>
              <div
                className={
                  msg.role === 'ceo_user'
                    ? 'whitespace-pre-wrap rounded-2xl rounded-tr-sm bg-gradient-to-r from-brand-600 to-accent-600 px-4 py-2.5 text-sm text-white'
                    : 'whitespace-pre-wrap rounded-2xl rounded-tl-sm border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm leading-relaxed text-slate-700'
                }
              >
                {msg.content}
                {msg.plan && (
                  <div className="mt-3 rounded-xl border border-slate-200 bg-white p-3 text-slate-700">
                    <p className="text-sm font-bold text-slate-900">📋 実行プラン</p>
                    <dl className="mt-2 space-y-2 text-xs">
                      <PlanRow label="指示内容の要約" value={msg.plan.summary} />
                      <PlanRow label="実行目的" value={msg.plan.purpose} />
                      <div>
                        <dt className="font-semibold text-slate-500">実行タスクと担当AI社員</dt>
                        <dd className="mt-1 space-y-1">
                          {msg.plan.tasks.map((t, i) => (
                            <div key={i} className="flex flex-wrap items-center gap-1.5 rounded-lg bg-slate-50 px-2 py-1.5">
                              <span className="flex h-4 w-4 items-center justify-center rounded-full bg-brand-100 text-[10px] font-bold text-brand-700">
                                {t.order}
                              </span>
                              <span className="flex-1">{t.title}</span>
                              <span className="rounded bg-slate-200 px-1.5 py-0.5 text-[10px]">{agentName(t.assigneeId)}</span>
                              {t.parallel && <span className="rounded bg-sky-100 px-1.5 py-0.5 text-[10px] text-sky-700">並列実行</span>}
                              {t.needsApproval && <span className="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] text-amber-700">要承認</span>}
                            </div>
                          ))}
                        </dd>
                      </div>
                      {msg.plan.approvalNotes.length > 0 && (
                        <PlanRow label="承認が必要な処理" value={msg.plan.approvalNotes.join(' / ')} />
                      )}
                      <PlanRow label="想定完了条件" value={msg.plan.completionCriteria} />
                      <PlanRow label="想定コスト" value={`約 ${yen(msg.plan.estimatedCostJpy)}(AI利用料)`} />
                    </dl>
                    {msg.planStatus === 'proposed' && (
                      <div className="mt-3 flex gap-2">
                        <Button onClick={() => startPlan(msg.id)}>
                          <Play className="h-3.5 w-3.5" /> この内容で開始する
                        </Button>
                        <Button variant="secondary" onClick={() => discardPlan(msg.id)}>
                          <Trash2 className="h-3.5 w-3.5" /> 破棄
                        </Button>
                      </div>
                    )}
                    {msg.planStatus === 'started' && (
                      <p className="mt-3 rounded-lg bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700">
                        ✅ 開始しました。タスクを作成し、担当AI社員へ割り振りました。
                      </p>
                    )}
                    {msg.planStatus === 'discarded' && (
                      <p className="mt-3 rounded-lg bg-slate-100 px-3 py-1.5 text-xs text-slate-500">このプランは破棄されました。</p>
                    )}
                  </div>
                )}
                {/* 詳しく見る(判断根拠・詳細説明の展開) */}
                {msg.consult?.detail && (
                  <div className="mt-2">
                    <button
                      onClick={() => toggleDetail(msg.id)}
                      className="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-white px-2.5 py-1 text-[11px] font-medium text-slate-600 outline-none transition hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                      aria-expanded={expandedDetails.has(msg.id)}
                    >
                      {expandedDetails.has(msg.id) ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
                      {expandedDetails.has(msg.id) ? '詳細を閉じる' : '詳しく見る(判断根拠)'}
                    </button>
                    {expandedDetails.has(msg.id) && (
                      <div className="mt-2 whitespace-pre-wrap rounded-xl border border-slate-200 bg-white p-3 text-xs leading-relaxed text-slate-600">
                        {msg.consult.detail}
                      </div>
                    )}
                  </div>
                )}
                {/* ディレクターの確認質問(選択肢クリックで回答を入力欄へ) */}
                {msg.consult && msg.consult.questions.length > 0 && (
                  <div className="mt-3 rounded-xl border border-brand-200 bg-brand-50/40 p-3">
                    <p className="text-xs font-bold text-brand-800">💬 確認事項への回答</p>
                    {msg.consult.answered ? (
                      <p className="mt-1.5 rounded-lg bg-emerald-50 px-2.5 py-1.5 text-xs text-emerald-700">✅ 回答済み。実行計画を作成しました。</p>
                    ) : (
                      <>
                        {msg.consult.questions.map((q, qi) => (
                          <div key={qi} className="mt-2">
                            <p className="text-xs font-semibold text-slate-700">{qi + 1}. {q.question}</p>
                            <div className="mt-1 flex flex-wrap gap-1.5">
                              {q.options.map((opt) => (
                                <button
                                  key={opt}
                                  onClick={() => setInput((cur) => (cur ? `${cur} / ${opt}` : `${q.question} → ${opt}`))}
                                  className="rounded-full border border-brand-200 bg-white px-2.5 py-1 text-[11px] text-brand-700 outline-none transition hover:bg-brand-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                                >
                                  {opt}
                                </button>
                              ))}
                            </div>
                          </div>
                        ))}
                        <div className="mt-2.5 flex items-center gap-2">
                          <Button variant="secondary" className="px-3 py-1.5 text-xs" onClick={() => omakase(msg.id)} disabled={planning}>
                            お任せで進める
                          </Button>
                          <p className="text-[10px] text-slate-400">選択肢をクリックするか、下の入力欄へ直接ご回答ください</p>
                        </div>
                      </>
                    )}
                  </div>
                )}
                {msg.runId && <RunCard runId={msg.runId} onModify={(req) => setInput(req)} />}
              </div>
            </div>
          </motion.div>
        ))}
        {planning && (
          <div className="flex items-center gap-2 rounded-2xl rounded-tl-sm border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-500">
            <Loader2 className="h-4 w-4 animate-spin text-brand-600" />
            CEO AIが依頼の目的を整理し、進め方を検討しています…
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      <div className="mt-3">
        <div className="mb-2 flex flex-wrap gap-1.5">
          {aiMode
            ? RUN_TEMPLATES.map((t) => (
                <button
                  key={t.label}
                  onClick={() => setInput(t.text)}
                  className="rounded-full border border-brand-200 bg-brand-50/50 px-2.5 py-1 text-[11px] text-brand-700 outline-none hover:bg-brand-50 focus-visible:ring-2 focus-visible:ring-brand-500"
                >
                  ✨ {t.label}
                </button>
              ))
            : EXAMPLES.map((ex) => (
                <button
                  key={ex}
                  onClick={() => setInput(ex)}
                  className="rounded-full border border-slate-200 bg-white px-2.5 py-1 text-[11px] text-slate-500 hover:border-brand-300 hover:text-brand-600"
                >
                  {ex}
                </button>
              ))}
        </div>
        <div className="flex gap-2">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              // Enter=送信 / Shift+Enter=改行(箇条書き入力用)
              if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                e.preventDefault();
                submit();
              }
            }}
            rows={Math.min(5, Math.max(1, input.split('\n').length))}
            placeholder={
              pendingConsult
                ? 'ディレクターの確認事項へのご回答を入力…'
                : pendingResearch
                  ? '5つの確認へのご回答を入力…(まとめてでOK)'
                  : aiMode
                    ? '依頼・相談・箇条書きでタスク登録(Shift+Enterで改行)…'
                    : 'CEO AIへ指示を入力…'
            }
            disabled={planning}
            className="min-w-0 flex-1 resize-none rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm leading-relaxed outline-none focus:border-brand-400 disabled:opacity-60"
          />
          <Button onClick={submit} className="px-4" disabled={planning}>
            <Send className="h-4 w-4" />
            <span className="hidden sm:inline">送信</span>
          </Button>
        </div>
      </div>
    </div>
  );
}

function PlanRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="font-semibold text-slate-500">{label}</dt>
      <dd className="mt-0.5">{value}</dd>
    </div>
  );
}
