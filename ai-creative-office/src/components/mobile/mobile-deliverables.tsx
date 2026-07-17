'use client';

// スマホ版 成果物: 一覧 → 全文表示・承認操作(編集などの重い操作はPC版で)
import { MarkdownView } from '@/components/markdown-view';
import { useOffice } from '@/lib/store';
import type { Deliverable, DeliverableStatus } from '@/lib/types';
import { cn, formatDateTime } from '@/lib/utils';
import { Check, ChevronLeft, ChevronRight, Copy, FileText, X } from 'lucide-react';
import { useState } from 'react';

const TYPE_LABEL: Record<Deliverable['type'], string> = {
  plan: 'CEO実行計画',
  requirements: '要件整理書',
  copy: 'Web原稿',
  review: 'レビュー報告書',
  brief: '企画・構成案',
  sns_content: 'SNS本文・コピー',
  visual: 'ビジュアル案',
  distribution: '配信戦略',
  document: '文書原稿',
};

const STATUS: Record<DeliverableStatus, { label: string; cls: string }> = {
  draft: { label: '下書き', cls: 'bg-slate-100 text-slate-600' },
  needs_fix: { label: '要修正', cls: 'bg-orange-50 text-orange-700' },
  reviewed: { label: 'レビュー済み', cls: 'bg-sky-50 text-sky-700' },
  approved: { label: '承認済み', cls: 'bg-emerald-50 text-emerald-700' },
  final: { label: '最終版', cls: 'bg-brand-50 text-brand-700' },
  rejected: { label: '却下', cls: 'bg-red-50 text-red-700' },
};

export function MobileDeliverables({ onClose }: { onClose: () => void }) {
  const deliverables = useOffice((s) => s.deliverables);
  const agents = useOffice((s) => s.agents);
  const updateDeliverable = useOffice((s) => s.updateDeliverable);
  const [openId, setOpenId] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const open = deliverables.find((d) => d.id === openId) ?? null;
  const agentName = (id: string) => agents.find((a) => a.id === id)?.name ?? id;

  return (
    <div className="absolute inset-0 z-20 flex flex-col bg-slate-50">
      {/* ヘッダー */}
      <div className="flex shrink-0 items-center gap-1.5 border-b border-slate-200 bg-white px-2 py-2">
        <button
          onClick={() => (open ? setOpenId(null) : onClose())}
          aria-label={open ? '成果物一覧へ戻る' : 'ホームへ戻る'}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-slate-500 outline-none active:bg-slate-100 focus-visible:ring-2 focus-visible:ring-brand-500"
        >
          <ChevronLeft className="h-5 w-5" />
        </button>
        <p className="min-w-0 flex-1 truncate text-[13px] font-bold text-slate-800">
          {open ? open.title : `成果物(${deliverables.length}件)`}
        </p>
        {open && (
          <span className={cn('shrink-0 rounded px-1.5 py-0.5 text-[9.5px] font-bold', STATUS[open.status].cls)}>
            {STATUS[open.status].label}
          </span>
        )}
      </div>

      {open ? (
        /* 詳細: 本文 + 下部に承認操作(親指ゾーン) */
        <>
          <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3">
            <p className="mb-2 text-[10px] text-slate-400">
              {TYPE_LABEL[open.type]} ・ v{open.version} ・ {agentName(open.agentId)} ・ {formatDateTime(open.updatedAt)}
              {open.isMock && ' ・ デモ生成'}
            </p>
            <div className="rounded-xl border border-slate-100 bg-white p-3.5">
              <MarkdownView markdown={open.markdown} />
            </div>
            <p className="mt-2 pb-2 text-[10px] text-slate-400">
              元となった指示: 「{open.sourceRequest.slice(0, 60)}」 ・ モデル: {open.model}({open.provider})
            </p>
          </div>
          <div className="shrink-0 border-t border-slate-200 bg-white px-3 pb-2 pt-2">
            <div className="flex gap-1.5">
              <button
                onClick={() => {
                  navigator.clipboard?.writeText(open.markdown);
                  setCopied(true);
                  setTimeout(() => setCopied(false), 1500);
                }}
                className="flex items-center gap-1 rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[12px] font-medium text-slate-600 outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
              >
                <Copy className="h-3.5 w-3.5" /> {copied ? 'コピー済み' : 'コピー'}
              </button>
              {open.status !== 'final' && open.status !== 'rejected' && (
                <>
                  <button
                    onClick={() => updateDeliverable(open.id, { status: 'approved' })}
                    className="flex flex-1 items-center justify-center gap-1 rounded-lg bg-emerald-600 px-2 py-2.5 text-[12px] font-bold text-white outline-none active:bg-emerald-700 focus-visible:ring-2 focus-visible:ring-emerald-500"
                  >
                    <Check className="h-3.5 w-3.5" /> 承認
                  </button>
                  <button
                    onClick={() => updateDeliverable(open.id, { status: 'final' })}
                    className="rounded-lg bg-brand-600 px-3 py-2.5 text-[12px] font-bold text-white outline-none active:bg-brand-700 focus-visible:ring-2 focus-visible:ring-brand-500"
                  >
                    最終版
                  </button>
                  <button
                    onClick={() => updateDeliverable(open.id, { status: 'rejected' })}
                    aria-label="却下"
                    className="rounded-lg border border-red-200 bg-white px-3 py-2.5 text-[12px] font-medium text-red-600 outline-none focus-visible:ring-2 focus-visible:ring-red-500"
                  >
                    <X className="h-3.5 w-3.5" />
                  </button>
                </>
              )}
            </div>
            <p className="mt-1.5 text-center text-[9.5px] text-slate-400">編集・バージョン管理・ダウンロードはPC版で行えます</p>
          </div>
        </>
      ) : (
        /* 一覧 */
        <div className="min-h-0 flex-1 space-y-2 overflow-y-auto overscroll-contain px-3 pb-6 pt-3">
          {deliverables.length === 0 ? (
            <div className="rounded-xl border border-dashed border-slate-200 px-4 py-14 text-center text-[12px] text-slate-400">
              成果物はまだありません。
              <br />
              チャットからCEO AIに依頼すると、ここに保存されます。
            </div>
          ) : (
            deliverables.map((d) => (
              <button
                key={d.id}
                onClick={() => setOpenId(d.id)}
                className="flex w-full items-center gap-2.5 rounded-xl border border-slate-200 bg-white px-3 py-3 text-left shadow-card outline-none active:bg-slate-50 focus-visible:ring-2 focus-visible:ring-brand-500"
              >
                <FileText className="h-4 w-4 shrink-0 text-brand-600" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-bold text-slate-800">{d.title}</p>
                  <p className="mt-0.5 flex flex-wrap items-center gap-1.5 text-[10px] text-slate-400">
                    <span className={cn('rounded px-1 py-0.5 text-[9px] font-bold', STATUS[d.status].cls)}>{STATUS[d.status].label}</span>
                    {TYPE_LABEL[d.type]} ・ v{d.version} ・ {formatDateTime(d.updatedAt)}
                    {d.isMock && ' ・ デモ生成'}
                  </p>
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-slate-300" />
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
}
