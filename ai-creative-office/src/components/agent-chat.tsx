'use client';

// AI社員との個別チャット(詳細パネル内で使用)
// - よく使う質問 / 入力欄 / 返答内アクションボタン(押すまで実行しない)
import { useOffice } from '@/lib/store';
import type { Agent, ChatAction } from '@/lib/types';
import { cn, formatDateTime } from '@/lib/utils';
import { motion, useReducedMotion } from 'framer-motion';
import { ArrowUpRight, Send } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Button } from './ui';

const QUICK_QUESTIONS = [
  '今何をしていますか?',
  '今日の成果を教えて',
  '問題はありますか?',
  '次に何をすべきですか?',
  'この案件の状況を教えて',
  'もっと効率化できますか?',
  'あなたに仕事を依頼したい',
  '今日の利用料金はいくらですか?',
];

export function AgentChat({ agent, onClose }: { agent: Agent; onClose?: () => void }) {
  const router = useRouter();
  const reduced = useReducedMotion();
  const messages = useOffice((s) => s.directChats[agent.id] ?? []);
  const openChat = useOffice((s) => s.openChat);
  const sendDirectMessage = useOffice((s) => s.sendDirectMessage);
  const executeChatAction = useOffice((s) => s.executeChatAction);
  const [input, setInput] = useState('');
  const [executed, setExecuted] = useState<Set<string>>(new Set());
  const bottomRef = useRef<HTMLDivElement>(null);

  // 開いた時点で挨拶の初期化+既読化
  useEffect(() => {
    openChat(agent.id);
  }, [agent.id]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'end' });
  }, [messages.length]);

  const send = (text: string) => {
    if (!text.trim()) return;
    sendDirectMessage(agent.id, text.trim());
    setInput('');
  };

  const runAction = (action: ChatAction) => {
    if (action.kind === 'link') {
      if (action.href) {
        onClose?.();
        router.push(action.href);
      }
      return;
    }
    executeChatAction(agent.id, action);
    setExecuted((prev) => new Set(prev).add(action.id));
  };

  return (
    <div className="flex h-full min-h-0 flex-col">
      {/* 会話履歴 */}
      <div
        className="min-h-0 flex-1 space-y-3 overflow-y-auto px-1 py-3"
        aria-live="polite"
        aria-label={`${agent.name}との会話履歴`}
      >
        {messages.map((msg) => (
          <motion.div
            key={msg.id}
            initial={reduced ? false : { opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.25 }}
            className={msg.role === 'user' ? 'flex justify-end' : 'flex justify-start'}
          >
            <div className={cn('max-w-[92%]', msg.role === 'user' && 'text-right')}>
              <p className="mb-0.5 px-1 text-[10px] tabular-nums text-slate-400">
                {msg.role === 'user' ? 'あなた(社長)' : agent.name} ・ {formatDateTime(msg.timestamp)}
              </p>
              <div
                className={cn(
                  'whitespace-pre-wrap rounded-2xl px-3.5 py-2.5 text-left text-[13px] leading-relaxed',
                  msg.role === 'user'
                    ? 'rounded-tr-sm bg-gradient-to-r from-brand-600 to-accent-600 text-white'
                    : 'rounded-tl-sm border border-slate-200 bg-white text-slate-700',
                )}
              >
                {msg.content}
              </div>
              {/* アクションボタン(押すまで実行しない) */}
              {msg.actions && msg.actions.length > 0 && (
                <div className="mt-1.5 flex flex-wrap justify-start gap-1.5">
                  {msg.actions.map((action) => {
                    const done = executed.has(action.id);
                    return (
                      <button
                        key={action.id}
                        onClick={() => !done && runAction(action)}
                        disabled={done}
                        className={cn(
                          'inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-[11px] font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand-500',
                          done
                            ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
                            : 'border-brand-200 bg-brand-50/60 text-brand-700 hover:bg-brand-50',
                        )}
                      >
                        {done ? '✓ 実行済み' : action.label}
                        {!done && action.kind === 'link' && <ArrowUpRight className="h-3 w-3" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          </motion.div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* よく使う質問 */}
      <div className="flex gap-1.5 overflow-x-auto pb-2 pt-1">
        {QUICK_QUESTIONS.map((q) => (
          <button
            key={q}
            onClick={() => send(q)}
            className="shrink-0 rounded-full border border-slate-200 bg-white px-2.5 py-1 text-[11px] text-slate-500 outline-none transition-colors hover:border-brand-300 hover:text-brand-600 focus-visible:ring-2 focus-visible:ring-brand-500"
          >
            {q}
          </button>
        ))}
      </div>

      {/* 入力欄 */}
      <div className="flex gap-2 border-t border-slate-100 pt-2.5">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.nativeEvent.isComposing) send(input);
          }}
          placeholder={`${agent.name}へメッセージ…`}
          aria-label={`${agent.name}へのメッセージ入力`}
          className="min-w-0 flex-1 rounded-xl border border-slate-200 px-3.5 py-2 text-sm outline-none focus:border-brand-400"
        />
        <Button onClick={() => send(input)} aria-label="送信">
          <Send className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}
