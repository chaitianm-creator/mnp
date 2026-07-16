'use client';

// 社長指示チャット(CEO AIとの対話)
// 「AI実働」: 依頼→CEO計画→承認→ディレクター/ライター/レビュアーが実際の成果物を生成
import { RunCard } from '@/components/run-card';
import { Button, PageHeader } from '@/components/ui';
import { createRunPlan } from '@/lib/agent-runner';
import { useOffice } from '@/lib/store';
import { formatDateTime, uid, yen } from '@/lib/utils';
import { motion } from 'framer-motion';
import { Loader2, Play, Send, Sparkles, Trash2 } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

// AI実働の依頼テンプレート(クリックでたたき台を入力)
const RUN_TEMPLATES = [
  { label: '採用サイト企画', text: '採用に困っている中小企業向けに、採用サイトの企画案を作って' },
  { label: 'コーポレートサイト構成', text: '製造業の中小企業向けに、信頼感のあるコーポレートサイトの構成案を作って' },
  { label: 'LP構成とコピー', text: '新サービスのランディングページの構成とキャッチコピーを作って。ターゲットは中小企業の経営者' },
  { label: 'サービス紹介ページ', text: 'Web制作サービスの紹介ページの構成と原稿を作って' },
  { label: '既存サイト改善案', text: '問い合わせが少ない既存コーポレートサイトの改善案を作って' },
  { label: 'SEO記事構成', text: '「ホームページ リニューアル 費用」で上位を狙うSEO記事の構成を作って' },
  { label: '会社案内の文章', text: '誠実さが伝わる会社案内ページの文章を作って' },
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
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chat.length, planning]);

  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;

  const submit = async () => {
    const request = input.trim();
    if (!request || planning) return;
    setInput('');
    if (!aiMode) {
      sendChat(request);
      return;
    }
    // AI実働: CEO AIが実行計画を生成(承認まで実行しない)
    useOffice.setState((s) => ({
      chat: [...s.chat, { id: uid('chat'), role: 'ceo_user' as const, content: request, timestamp: new Date().toISOString() }],
    }));
    setPlanning(true);
    try {
      await createRunPlan(request);
    } catch (e) {
      const message = e instanceof Error ? e.message : '計画の作成に失敗しました';
      useOffice.setState((s) => ({
        chat: [
          ...s.chat,
          { id: uid('chat'), role: 'ceo_ai' as const, content: `申し訳ありません、実行計画の作成に失敗しました: ${message}\nもう一度お試しください。`, timestamp: new Date().toISOString() },
        ],
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
                {msg.role === 'ceo_user' ? 'あなた(社長)' : '👔 CEO AI'}
                <span className="tabular-nums">{formatDateTime(msg.timestamp)}</span>
              </p>
              <div
                className={
                  msg.role === 'ceo_user'
                    ? 'rounded-2xl rounded-tr-sm bg-gradient-to-r from-brand-600 to-accent-600 px-4 py-2.5 text-sm text-white'
                    : 'rounded-2xl rounded-tl-sm border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-slate-700'
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
                {msg.runId && <RunCard runId={msg.runId} onModify={(req) => setInput(req)} />}
              </div>
            </div>
          </motion.div>
        ))}
        {planning && (
          <div className="flex items-center gap-2 rounded-2xl rounded-tl-sm border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-500">
            <Loader2 className="h-4 w-4 animate-spin text-brand-600" />
            CEO AIが依頼を分析し、実行計画を作成しています…
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
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !e.nativeEvent.isComposing && submit()}
            placeholder={aiMode ? 'AI社員への依頼を入力…(例: 採用サイトの企画案を作って)' : 'CEO AIへ指示を入力…'}
            disabled={planning}
            className="min-w-0 flex-1 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm outline-none focus:border-brand-400 disabled:opacity-60"
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
