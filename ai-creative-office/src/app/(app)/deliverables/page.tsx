'use client';

// 成果物管理: AI生成成果物の一覧・詳細・編集・バージョン管理・ダウンロード
import { MarkdownView } from '@/components/markdown-view';
import { Badge, Button, Card, PageHeader } from '@/components/ui';
import { useOffice } from '@/lib/store';
import type { Deliverable, DeliverableStatus } from '@/lib/types';
import { cn, formatDateTime, num, yen } from '@/lib/utils';
import { Check, Copy, Download, FileJson, FileText, Pencil, X } from 'lucide-react';
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

function download(filename: string, content: string) {
  const blob = new Blob([content], { type: 'text/markdown;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.style.display = 'none';
  document.body.appendChild(a); // ファイル名を保持するためDOMへ追加してからクリック
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export default function DeliverablesPage() {
  const deliverables = useOffice((s) => s.deliverables);
  const agents = useOffice((s) => s.agents);
  const [openId, setOpenId] = useState<string | null>(null);

  return (
    <div>
      <PageHeader
        title="成果物"
        sub="AI社員が生成した成果物の確認・編集・バージョン管理(外部への共有・公開は行いません)"
      />
      {deliverables.length === 0 ? (
        <div className="rounded-xl border border-dashed border-slate-200 py-16 text-center text-sm text-slate-400">
          成果物はまだありません。
          <br />
          社長指示チャットの「AI実働モード」から依頼すると、ここに成果物が保存されます。
        </div>
      ) : (
        <div className="space-y-3">
          {deliverables.map((d) => (
            <DeliverableCard
              key={d.id}
              deliverable={d}
              agentName={agents.find((a) => a.id === d.agentId)?.name ?? d.agentId}
              open={openId === d.id}
              onToggle={() => setOpenId(openId === d.id ? null : d.id)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function DeliverableCard({
  deliverable: d,
  agentName,
  open,
  onToggle,
}: {
  deliverable: Deliverable;
  agentName: string;
  open: boolean;
  onToggle: () => void;
}) {
  const updateDeliverable = useOffice((s) => s.updateDeliverable);
  const saveDeliverableVersion = useOffice((s) => s.saveDeliverableVersion);
  const [view, setView] = useState<'md' | 'json' | 'history'>('md');
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [copied, setCopied] = useState(false);
  const st = STATUS[d.status];

  return (
    <Card className="overflow-hidden">
      <button onClick={onToggle} className="flex w-full flex-wrap items-center gap-2 px-4 py-3 text-left outline-none hover:bg-slate-50/60 focus-visible:ring-2 focus-visible:ring-brand-500" aria-expanded={open}>
        <FileText className="h-4 w-4 shrink-0 text-brand-600" />
        <span className="text-sm font-bold text-slate-900">{d.title}</span>
        <Badge className="bg-slate-100 text-slate-500">{TYPE_LABEL[d.type]}</Badge>
        <Badge className={st.cls}>{st.label}</Badge>
        {d.isMock && <Badge className="bg-slate-100 text-slate-500">デモ生成</Badge>}
        <span className="text-[10px] text-slate-400">v{d.version}</span>
        <span className="ml-auto text-[10px] text-slate-400">
          {agentName} ・ {formatDateTime(d.updatedAt)} ・ {num(d.inputTokens + d.outputTokens)}tok / {yen(d.costJpy)}
        </span>
      </button>

      {open && (
        <div className="border-t border-slate-100 px-4 py-3">
          {/* ツールバー */}
          <div className="mb-3 flex flex-wrap items-center gap-1.5">
            <TabBtn active={view === 'md'} onClick={() => setView('md')}>Markdown</TabBtn>
            <TabBtn active={view === 'json'} onClick={() => setView('json')}><FileJson className="h-3 w-3" /> JSON</TabBtn>
            <TabBtn active={view === 'history'} onClick={() => setView('history')}>バージョン履歴({d.versions.length})</TabBtn>
            <span className="mx-1 h-4 w-px bg-slate-200" />
            <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => { navigator.clipboard?.writeText(d.markdown); setCopied(true); setTimeout(() => setCopied(false), 1500); }}>
              <Copy className="h-3 w-3" /> {copied ? 'コピーしました' : 'コピー'}
            </Button>
            <Button
              variant="ghost"
              className="px-2 py-1 text-xs"
              aria-label="Markdownをダウンロード"
              onClick={() => download(`${d.title}-v${d.version}.md`, d.markdown)}
            >
              <Download className="h-3 w-3" /> Markdown
            </Button>
            {!editing && (
              <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => { setDraft(d.markdown); setEditing(true); setView('md'); }}>
                <Pencil className="h-3 w-3" /> 編集
              </Button>
            )}
            <span className="ml-auto flex gap-1.5">
              {d.status !== 'final' && d.status !== 'rejected' && (
                <>
                  <Button variant="success" className="px-2.5 py-1 text-xs" onClick={() => updateDeliverable(d.id, { status: 'approved' })}>
                    <Check className="h-3 w-3" /> 承認
                  </Button>
                  <Button className="px-2.5 py-1 text-xs" onClick={() => updateDeliverable(d.id, { status: 'final' })}>
                    最終版に設定
                  </Button>
                  <Button variant="danger" className="px-2.5 py-1 text-xs" onClick={() => updateDeliverable(d.id, { status: 'rejected' })}>
                    <X className="h-3 w-3" /> 却下
                  </Button>
                </>
              )}
            </span>
          </div>

          {/* 本文 */}
          {editing ? (
            <div>
              <textarea
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                rows={16}
                aria-label="成果物の編集"
                className="w-full rounded-lg border border-slate-200 p-3 font-mono text-xs leading-relaxed outline-none focus:border-brand-400"
              />
              <div className="mt-2 flex gap-2">
                <Button
                  onClick={() => {
                    saveDeliverableVersion(d.id, draft, 'human', '人間による編集');
                    setEditing(false);
                  }}
                >
                  新しいバージョンとして保存
                </Button>
                <Button variant="ghost" onClick={() => setEditing(false)}>キャンセル</Button>
                <p className="self-center text-[10px] text-slate-400">※ AIによる自動上書きはされません。編集は別バージョンとして保存されます</p>
              </div>
            </div>
          ) : view === 'md' ? (
            <div className="max-h-[520px] overflow-y-auto rounded-lg border border-slate-100 bg-slate-50/40 p-4">
              <MarkdownView markdown={d.markdown} />
            </div>
          ) : view === 'json' ? (
            <pre className="max-h-[520px] overflow-auto rounded-lg border border-slate-100 bg-slate-900 p-4 text-[11px] leading-relaxed text-slate-200">
              {d.json ?? '{}'}
            </pre>
          ) : (
            <div className="space-y-2">
              {[...d.versions].reverse().map((v, i, arr) => {
                const prev = arr[i + 1];
                const diff = prev
                  ? {
                      added: v.markdown.split('\n').filter((l) => !prev.markdown.includes(l)).length,
                      removed: prev.markdown.split('\n').filter((l) => !v.markdown.includes(l)).length,
                    }
                  : null;
                return (
                  <div key={v.version} className="rounded-lg border border-slate-100 px-3 py-2 text-xs">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-bold text-slate-700">v{v.version}</span>
                      <Badge className={v.editedBy === 'human' ? 'bg-amber-50 text-amber-700' : 'bg-brand-50 text-brand-700'}>
                        {v.editedBy === 'human' ? '人間の編集' : 'AI生成'}
                      </Badge>
                      <span className="text-slate-500">{v.note}</span>
                      {diff && (
                        <span className="tabular-nums text-slate-400">
                          前バージョン比: <span className="text-emerald-600">+{diff.added}行</span> / <span className="text-red-500">-{diff.removed}行</span>
                        </span>
                      )}
                      <span className="ml-auto tabular-nums text-slate-400">{formatDateTime(v.createdAt)}</span>
                      <Button variant="ghost" className="px-1.5 py-0.5 text-[10px]" onClick={() => download(`${d.title}-v${v.version}.md`, v.markdown)}>
                        <Download className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          <p className="mt-2 text-[10px] text-slate-400">
            元となった指示: 「{d.sourceRequest.slice(0, 60)}」 ・ モデル: {d.model}({d.provider}
            {d.isMock ? '・デモ生成' : ''})
          </p>
        </div>
      )}
    </Card>
  );
}

function TabBtn({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium outline-none transition focus-visible:ring-2 focus-visible:ring-brand-500',
        active ? 'bg-slate-900 text-white' : 'text-slate-500 hover:bg-slate-100',
      )}
    >
      {children}
    </button>
  );
}
