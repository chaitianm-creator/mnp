'use client';

// 承認センター: 外部送信・公開などの承認フロー
import { Badge, Button, Card, PageHeader } from '@/components/ui';
import { APPROVAL_STATUS, APPROVAL_TYPE } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime, yen } from '@/lib/utils';
import { motion } from 'framer-motion';
import { AlertTriangle, Check, Pencil, ShieldCheck, X } from 'lucide-react';
import { useState } from 'react';

export default function ApprovalsPage() {
  const approvals = useOffice((s) => s.approvals);
  const agents = useOffice((s) => s.agents);
  const decideApproval = useOffice((s) => s.decideApproval);
  const [tab, setTab] = useState<'pending' | 'decided'>('pending');

  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;
  const pending = approvals.filter((a) => a.status === 'pending');
  const decided = approvals.filter((a) => a.status !== 'pending');
  const shown = tab === 'pending' ? pending : decided;

  return (
    <div>
      <PageHeader
        title="承認センター"
        sub="外部への送信・公開は、社長の承認なしには実行されません"
        action={
          <div className="flex rounded-lg border border-slate-200 bg-white p-0.5">
            <TabButton active={tab === 'pending'} onClick={() => setTab('pending')}>
              承認待ち({pending.length})
            </TabButton>
            <TabButton active={tab === 'decided'} onClick={() => setTab('decided')}>
              対応済み({decided.length})
            </TabButton>
          </div>
        }
      />

      <div className="mb-4 flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2.5 text-xs text-emerald-700">
        <ShieldCheck className="h-4 w-4 shrink-0" />
        メール・フォーム・SNS・公開などの外部処理は「下書き → 承認待ち → 承認済み → 実行中 → 完了」のフローで管理され、承認前に外部送信されることはありません。
      </div>

      <div className="space-y-3">
        {shown.length === 0 && (
          <p className="rounded-xl border border-dashed border-slate-200 py-14 text-center text-sm text-slate-400">
            {tab === 'pending' ? '承認待ちの項目はありません 🎉' : '対応済みの項目はありません'}
          </p>
        )}
        {shown.map((approval) => (
          <motion.div key={approval.id} layout initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
            <Card className="p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <Badge className="bg-brand-50 text-brand-700">{APPROVAL_TYPE[approval.type]}</Badge>
                    <Badge className={cn(APPROVAL_STATUS[approval.status].bg, APPROVAL_STATUS[approval.status].color)}>
                      {APPROVAL_STATUS[approval.status].label}
                    </Badge>
                    {approval.hasOptedOutTargets && (
                      <Badge className="bg-red-50 text-red-700">
                        <AlertTriangle className="h-3 w-3" /> 配信停止対象を自動除外済み
                      </Badge>
                    )}
                    {approval.hasDuplicates && (
                      <Badge className="bg-red-50 text-red-700">重複あり</Badge>
                    )}
                  </div>
                  <h3 className="mt-1.5 text-sm font-bold text-slate-900">{approval.title}</h3>
                  <p className="mt-0.5 text-xs text-slate-500">
                    申請: {agentName(approval.requesterId)} ・ {formatDateTime(approval.createdAt)} ・ 対象: {approval.target} ・ {approval.count}件 ・ 想定費用 {yen(approval.estimatedCostJpy)}
                  </p>
                </div>
                {approval.status === 'pending' && (
                  <div className="flex shrink-0 gap-2">
                    <Button variant="success" onClick={() => decideApproval(approval.id, 'approved')}>
                      <Check className="h-3.5 w-3.5" /> 承認
                    </Button>
                    <Button variant="secondary" onClick={() => decideApproval(approval.id, 'revision_requested')}>
                      <Pencil className="h-3.5 w-3.5" /> 修正依頼
                    </Button>
                    <Button variant="danger" onClick={() => decideApproval(approval.id, 'rejected')}>
                      <X className="h-3.5 w-3.5" /> 却下
                    </Button>
                  </div>
                )}
              </div>
              <div className="mt-3 whitespace-pre-wrap rounded-lg bg-slate-50 px-3 py-2.5 text-xs leading-relaxed text-slate-600">
                {approval.body}
              </div>
              {approval.risks.length > 0 && (
                <ul className="mt-2 space-y-0.5">
                  {approval.risks.map((r, i) => (
                    <li key={i} className="text-[11px] text-slate-500">・{r}</li>
                  ))}
                </ul>
              )}
            </Card>
          </motion.div>
        ))}
      </div>
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
