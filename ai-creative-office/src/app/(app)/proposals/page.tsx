'use client';

// CEO提案センター: CEO AIが自発的に作成した経営提案の一覧・採用・修正・却下
import { Badge, Button, Card, PageHeader } from '@/components/ui';
import { PROPOSAL_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime, yen } from '@/lib/utils';
import { motion } from 'framer-motion';
import { Check, Lightbulb, Pencil, X } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

export default function ProposalsPage() {
  const proposals = useOffice((s) => s.proposals);
  const agents = useOffice((s) => s.agents);
  const decideProposal = useOffice((s) => s.decideProposal);
  const openChat = useOffice((s) => s.openChat);
  const [tab, setTab] = useState<'open' | 'closed'>('open');

  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;
  const open = proposals.filter((p) => ['new', 'reviewing', 'revision'].includes(p.status));
  const closed = proposals.filter((p) => !['new', 'reviewing', 'revision'].includes(p.status));
  const shown = tab === 'open' ? open : closed;

  // 提案センターを開いたらCEOの未読を既読化
  useState(() => {
    openChat('ceo');
    return undefined;
  });

  return (
    <div>
      <PageHeader
        title="CEO提案センター"
        sub="CEO AIが会社の状況を分析し、自発的に作成した経営提案です。採用すると自動でタスク化されます"
        action={
          <div className="flex rounded-lg border border-slate-200 bg-white p-0.5">
            <TabButton active={tab === 'open'} onClick={() => setTab('open')}>
              対応待ち({open.length})
            </TabButton>
            <TabButton active={tab === 'closed'} onClick={() => setTab('closed')}>
              対応済み({closed.length})
            </TabButton>
          </div>
        }
      />

      <div className="space-y-3">
        {shown.length === 0 && (
          <p className="rounded-xl border border-dashed border-slate-200 py-14 text-center text-sm text-slate-400">
            {tab === 'open' ? '対応待ちの提案はありません。CEO AIが状況を分析中です' : '対応済みの提案はありません'}
          </p>
        )}
        {shown.map((p) => {
          const st = PROPOSAL_STATUS[p.status];
          const actionable = ['new', 'reviewing', 'revision'].includes(p.status);
          return (
            <motion.div key={p.id} layout initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
              <Card className="p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-1.5">
                      <span className="flex h-6 w-6 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
                        <Lightbulb className="h-3.5 w-3.5" />
                      </span>
                      <h3 className="text-sm font-bold text-slate-900">{p.title}</h3>
                      <Badge className={cn(st.bg, st.color)}>{st.label}</Badge>
                      <span className="text-[10px] tabular-nums text-slate-400">{formatDateTime(p.createdAt)}</span>
                    </div>
                    <p className="mt-1.5 text-[13px] leading-relaxed text-slate-600">{p.summary}</p>
                  </div>
                  {actionable && (
                    <div className="flex shrink-0 gap-2">
                      <Button variant="success" onClick={() => decideProposal(p.id, 'adopted')}>
                        <Check className="h-3.5 w-3.5" /> 採用
                      </Button>
                      <Button variant="secondary" onClick={() => decideProposal(p.id, 'revision')}>
                        <Pencil className="h-3.5 w-3.5" /> 修正依頼
                      </Button>
                      <Button variant="danger" onClick={() => decideProposal(p.id, 'rejected')}>
                        <X className="h-3.5 w-3.5" /> 却下
                      </Button>
                    </div>
                  )}
                </div>

                <div className="mt-3 grid gap-3 text-xs lg:grid-cols-2">
                  <div className="space-y-2.5">
                    <Row label="課題" value={p.issue} />
                    <div>
                      <p className="text-[10px] font-semibold text-slate-400">根拠となる数字</p>
                      <ul className="mt-0.5 space-y-0.5 text-slate-600">
                        {p.evidence.map((e, i) => (
                          <li key={i}>・{e}</li>
                        ))}
                      </ul>
                    </div>
                    <Row label="原因仮説" value={p.hypothesis} />
                  </div>
                  <div className="space-y-2.5">
                    <div>
                      <p className="text-[10px] font-semibold text-slate-400">提案内容(採用時にタスク化)</p>
                      <ul className="mt-0.5 space-y-1">
                        {p.actions.map((item, i) => (
                          <li key={i} className="flex items-center gap-1.5 rounded-lg bg-slate-50 px-2 py-1.5 text-slate-700">
                            <span className="flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-brand-100 text-[9px] font-bold text-brand-700">
                              {i + 1}
                            </span>
                            <span className="min-w-0 flex-1">{item.title}</span>
                            <span className="shrink-0 rounded bg-slate-200 px-1.5 py-0.5 text-[10px] text-slate-600">
                              {agentName(item.assigneeId)}
                            </span>
                          </li>
                        ))}
                      </ul>
                    </div>
                    <Row label="想定効果" value={p.expectedEffect} />
                    <div className="flex flex-wrap gap-x-4 gap-y-1">
                      <Row label="想定コスト" value={yen(p.estimatedCostJpy)} inline />
                      <Row label="対象部署" value={p.targetDepartment} inline />
                    </div>
                    <div>
                      <p className="text-[10px] font-semibold text-slate-400">想定リスク</p>
                      <ul className="mt-0.5 space-y-0.5 text-slate-600">
                        {p.risks.map((r, i) => (
                          <li key={i}>・{r}</li>
                        ))}
                      </ul>
                    </div>
                    <p className="rounded-lg bg-amber-50/70 px-2.5 py-1.5 text-[11px] text-amber-800">
                      🔒 承認が必要な処理: {p.approvalNote}
                    </p>
                  </div>
                </div>

                {p.taskIds.length > 0 && (
                  <div className="mt-3 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-2.5">
                    <span className="text-[10px] font-semibold text-slate-400">作成されたタスク:</span>
                    {p.taskIds.map((tid, i) => (
                      <Link key={tid} href={`/tasks/${tid}`} className="text-[11px] text-brand-600 hover:underline">
                        タスク{i + 1} →
                      </Link>
                    ))}
                  </div>
                )}
              </Card>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}

function Row({ label, value, inline }: { label: string; value: string; inline?: boolean }) {
  return (
    <div className={inline ? 'flex items-baseline gap-1.5' : undefined}>
      <p className="text-[10px] font-semibold text-slate-400">{label}</p>
      <p className={cn('text-slate-600', !inline && 'mt-0.5')}>{value}</p>
    </div>
  );
}

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'rounded-md px-3 py-1 text-xs font-medium transition',
        active ? 'bg-gradient-to-r from-brand-600 to-accent-600 text-white' : 'text-slate-500 hover:text-slate-700',
      )}
    >
      {children}
    </button>
  );
}
