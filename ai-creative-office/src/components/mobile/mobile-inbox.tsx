'use client';

// スマホ版 通知センター: 承認 / CEO提案 / CEO呼びかけ / 成果報告 を1画面で処理
// 外部送信を伴う操作はすべてここでの人間の承認が必要(承認するまで実行されない)
import { APPROVAL_TYPE } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { cn, formatDateTime, yen } from '@/lib/utils';
import { AlertTriangle, Award, CheckCircle2, Lightbulb, Megaphone } from 'lucide-react';
import { useState } from 'react';

type Segment = 'approvals' | 'proposals' | 'alerts' | 'achievements';

export function MobileInbox() {
  const agents = useOffice((s) => s.agents);
  const approvals = useOffice((s) => s.approvals.filter((a) => a.status === 'pending'));
  const proposals = useOffice((s) => s.proposals.filter((p) => ['new', 'reviewing', 'revision'].includes(p.status)));
  const alerts = useOffice((s) => s.ceoAlerts.filter((a) => a.status === 'new' || a.status === 'later'));
  const achievements = useOffice((s) => s.achievements.slice(0, 20));
  const decideApproval = useOffice((s) => s.decideApproval);
  const decideProposal = useOffice((s) => s.decideProposal);
  const decideAlert = useOffice((s) => s.decideAlert);

  const [seg, setSeg] = useState<Segment>('approvals');
  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;

  const segments: { id: Segment; label: string; count: number }[] = [
    { id: 'approvals', label: '承認', count: approvals.length },
    { id: 'proposals', label: '提案', count: proposals.length },
    { id: 'alerts', label: '呼びかけ', count: alerts.filter((a) => a.status === 'new').length },
    { id: 'achievements', label: '実績', count: 0 },
  ];

  return (
    <div className="flex h-full flex-col">
      {/* セグメント切り替え */}
      <div className="shrink-0 border-b border-slate-200 bg-white px-3 pb-2 pt-2.5">
        <div className="flex rounded-lg bg-slate-100 p-0.5" role="tablist" aria-label="通知の種類">
          {segments.map((s) => (
            <button
              key={s.id}
              role="tab"
              aria-selected={seg === s.id}
              onClick={() => setSeg(s.id)}
              className={cn(
                'flex min-h-[36px] flex-1 items-center justify-center gap-1 rounded-md text-[11.5px] font-medium outline-none transition focus-visible:ring-2 focus-visible:ring-brand-500',
                seg === s.id ? 'bg-white font-bold text-slate-900 shadow-sm' : 'text-slate-500',
              )}
            >
              {s.label}
              {s.count > 0 && (
                <span className="flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
                  {s.count}
                </span>
              )}
            </button>
          ))}
        </div>
      </div>

      <div className="min-h-0 flex-1 space-y-2.5 overflow-y-auto overscroll-contain px-3 pb-6 pt-3">
        {/* 承認待ち */}
        {seg === 'approvals' &&
          (approvals.length === 0 ? (
            <Empty icon={CheckCircle2} message="承認待ちはありません。すべて処理済みです。" />
          ) : (
            approvals.map((a) => (
              <article key={a.id} className="rounded-xl border border-slate-200 bg-white p-3 shadow-card">
                <div className="flex items-start gap-2">
                  <span className="mt-0.5 shrink-0 rounded bg-amber-50 px-1.5 py-0.5 text-[9.5px] font-bold text-amber-700">
                    {APPROVAL_TYPE[a.type]}
                  </span>
                  <p className="min-w-0 flex-1 text-[13px] font-bold leading-snug text-slate-800">{a.title}</p>
                </div>
                <p className="mt-1.5 line-clamp-3 whitespace-pre-wrap text-[11.5px] leading-relaxed text-slate-500">{a.body}</p>
                <p className="mt-1.5 text-[10px] text-slate-400">
                  申請: {agentName(a.requesterId)} ・ 対象: {a.target} ・ {a.count}件 ・ 想定 {yen(a.estimatedCostJpy)}
                </p>
                {a.risks.length > 0 && (
                  <p className="mt-1 flex items-start gap-1 text-[10.5px] text-orange-600">
                    <AlertTriangle className="mt-0.5 h-3 w-3 shrink-0" /> {a.risks.join(' / ')}
                  </p>
                )}
                <div className="mt-2.5 flex gap-1.5">
                  <button
                    onClick={() => decideApproval(a.id, 'approved')}
                    className="flex-1 rounded-lg bg-emerald-600 px-2 py-2.5 text-[12px] font-bold text-white outline-none active:bg-emerald-700 focus-visible:ring-2 focus-visible:ring-emerald-500"
                  >
                    承認する
                  </button>
                  <button
                    onClick={() => decideApproval(a.id, 'revision_requested')}
                    className="rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[12px] font-medium text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    修正依頼
                  </button>
                  <button
                    onClick={() => decideApproval(a.id, 'rejected')}
                    className="rounded-lg border border-red-200 bg-white px-3 py-2.5 text-[12px] font-medium text-red-600 outline-none focus-visible:ring-2 focus-visible:ring-red-500"
                  >
                    却下
                  </button>
                </div>
              </article>
            ))
          ))}

        {/* CEO提案 */}
        {seg === 'proposals' &&
          (proposals.length === 0 ? (
            <Empty icon={Lightbulb} message="新しい経営提案はありません。" />
          ) : (
            proposals.map((p) => (
              <article key={p.id} className="rounded-xl border border-slate-200 bg-white p-3 shadow-card">
                <p className="text-[13px] font-bold leading-snug text-slate-800">💡 {p.title}</p>
                <p className="mt-1 text-[11.5px] leading-relaxed text-slate-600">{p.summary}</p>
                {p.evidence[0] && <p className="mt-1 text-[10.5px] text-slate-400">根拠: {p.evidence[0]}</p>}
                <p className="mt-1 text-[10.5px] text-slate-400">
                  想定効果: {p.expectedEffect} ・ 想定コスト: {yen(p.estimatedCostJpy)}
                </p>
                <div className="mt-2.5 flex gap-1.5">
                  <button
                    onClick={() => decideProposal(p.id, 'adopted')}
                    className="flex-1 rounded-lg bg-brand-600 px-2 py-2.5 text-[12px] font-bold text-white outline-none active:bg-brand-700 focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    採用してタスク化
                  </button>
                  <button
                    onClick={() => decideProposal(p.id, 'revision')}
                    className="rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[12px] font-medium text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    修正依頼
                  </button>
                  <button
                    onClick={() => decideProposal(p.id, 'rejected')}
                    className="rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[12px] font-medium text-slate-500 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    却下
                  </button>
                </div>
              </article>
            ))
          ))}

        {/* CEO呼びかけ */}
        {seg === 'alerts' &&
          (alerts.length === 0 ? (
            <Empty icon={Megaphone} message="CEO AIからの呼びかけはありません。" />
          ) : (
            alerts.map((al) => (
              <article key={al.id} className="rounded-xl border border-slate-200 bg-white p-3 shadow-card">
                <div className="flex items-center gap-1.5">
                  <span
                    className={cn(
                      'rounded px-1.5 py-0.5 text-[9.5px] font-bold',
                      al.severity === 'high' ? 'bg-red-50 text-red-600' : al.severity === 'medium' ? 'bg-amber-50 text-amber-700' : 'bg-slate-100 text-slate-500',
                    )}
                  >
                    {al.severity === 'high' ? '重要' : al.severity === 'medium' ? '中' : '低'}
                  </span>
                  {al.status === 'later' && <span className="rounded bg-slate-100 px-1.5 py-0.5 text-[9.5px] text-slate-500">後で確認</span>}
                  <span className="ml-auto text-[10px] tabular-nums text-slate-400">{formatDateTime(al.createdAt)}</span>
                </div>
                <p className="mt-1.5 text-[13px] font-bold leading-snug text-slate-800">{al.conclusion}</p>
                {al.evidence[0] && <p className="mt-1 text-[10.5px] text-slate-400">根拠: {al.evidence[0]}</p>}
                <p className="mt-1 text-[11px] text-slate-600">推奨: {al.recommendation}</p>
                <p className="mt-0.5 text-[10.5px] text-slate-400">想定効果: {al.expectedEffect}</p>
                <div className="mt-2.5 flex gap-1.5">
                  <button
                    onClick={() => decideAlert(al.id, 'accepted')}
                    className="flex-1 rounded-lg bg-brand-600 px-2 py-2.5 text-[12px] font-bold text-white outline-none active:bg-brand-700 focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    承認して実行
                  </button>
                  {al.status !== 'later' && (
                    <button
                      onClick={() => decideAlert(al.id, 'later')}
                      className="rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[12px] font-medium text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                    >
                      後で
                    </button>
                  )}
                  <button
                    onClick={() => decideAlert(al.id, 'dismissed')}
                    className="rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[12px] font-medium text-slate-500 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    却下
                  </button>
                </div>
              </article>
            ))
          ))}

        {/* 成果報告 */}
        {seg === 'achievements' &&
          (achievements.length === 0 ? (
            <Empty icon={Award} message="まだ成果報告はありません。AI社員が働くとここに届きます。" />
          ) : (
            achievements.map((ac) => (
              <article key={ac.id} className="flex items-start gap-2.5 rounded-xl border border-slate-200 bg-white px-3 py-2.5 shadow-card">
                <span className="mt-0.5 text-base">🏅</span>
                <div className="min-w-0 flex-1">
                  <p className="text-[12.5px] font-bold text-slate-800">{ac.title}</p>
                  <p className="mt-0.5 text-[11px] text-slate-500">{ac.detail}</p>
                  <p className="mt-0.5 text-[10px] tabular-nums text-slate-400">
                    {agentName(ac.agentId)} ・ {formatDateTime(ac.timestamp)}
                  </p>
                </div>
              </article>
            ))
          ))}
      </div>
    </div>
  );
}

function Empty({ icon: Icon, message }: { icon: typeof CheckCircle2; message: string }) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed border-slate-200 px-4 py-12 text-center">
      <Icon className="h-6 w-6 text-slate-300" />
      <p className="text-[12px] text-slate-400">{message}</p>
    </div>
  );
}
