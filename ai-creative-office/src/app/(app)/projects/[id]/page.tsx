'use client';

// 制作案件詳細
import { Badge, Card, CardHeader, PageHeader, ProgressBar } from '@/components/ui';
import { TASK_STATUS } from '@/lib/labels';
import { useOffice } from '@/lib/store';
import { PROJECT_PHASES } from '@/lib/types';
import { cn, formatDate, yen } from '@/lib/utils';
import Link from 'next/link';
import { useParams } from 'next/navigation';

const PAGE_STATUS: Record<string, { label: string; cls: string }> = {
  planned: { label: '未着手', cls: 'bg-slate-100 text-slate-500' },
  writing: { label: '原稿作成中', cls: 'bg-sky-50 text-sky-700' },
  wireframe: { label: 'ワイヤー作成中', cls: 'bg-cyan-50 text-cyan-700' },
  design: { label: 'デザイン中', cls: 'bg-violet-50 text-violet-700' },
  coding: { label: 'コーディング中', cls: 'bg-indigo-50 text-indigo-700' },
  review: { label: 'レビュー中', cls: 'bg-amber-50 text-amber-700' },
  done: { label: '完了', cls: 'bg-emerald-50 text-emerald-700' },
};

export default function ProjectDetailPage() {
  const params = useParams<{ id: string }>();
  const project = useOffice((s) => s.projects.find((p) => p.id === params.id));
  const agents = useOffice((s) => s.agents);
  const tasks = useOffice((s) => s.tasks.filter((t) => t.projectId === params.id));

  if (!project) {
    return <p className="py-20 text-center text-sm text-slate-400">案件が見つかりません。</p>;
  }

  const profit =
    project.orderAmountJpy - project.productionCostJpy - project.aiCostJpy - project.outsourcingCostJpy;
  const phaseIndex = PROJECT_PHASES.indexOf(project.phase);

  return (
    <div>
      <PageHeader title={project.name} sub={`${project.customerName} / ${project.serviceType}`} />

      {/* 工程プログレス */}
      <Card className="mb-4 overflow-x-auto p-4">
        <div className="flex min-w-[900px] items-center gap-1">
          {PROJECT_PHASES.map((phase, i) => (
            <div key={phase} className="flex flex-1 flex-col items-center gap-1">
              <div
                className={cn(
                  'flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-bold',
                  i < phaseIndex && 'bg-emerald-500 text-white',
                  i === phaseIndex && 'bg-gradient-to-r from-brand-600 to-accent-600 text-white ring-4 ring-brand-100',
                  i > phaseIndex && 'bg-slate-100 text-slate-400',
                )}
              >
                {i + 1}
              </div>
              <p className={cn('whitespace-nowrap text-[9px]', i === phaseIndex ? 'font-bold text-brand-700' : 'text-slate-400')}>
                {phase}
              </p>
            </div>
          ))}
        </div>
        <div className="mt-3 flex items-center gap-2">
          <ProgressBar value={project.progress} className="flex-1" />
          <span className="text-xs font-semibold tabular-nums">{project.progress}%</span>
        </div>
      </Card>

      <div className="grid gap-3 lg:grid-cols-2">
        <Card>
          <CardHeader title="収支" />
          <dl className="grid grid-cols-2 gap-3 p-4 sm:grid-cols-3">
            <Money label="受注金額" value={project.orderAmountJpy} />
            <Money label="制作原価" value={project.productionCostJpy} />
            <Money label="AI利用料" value={project.aiCostJpy} />
            <Money label="外注費" value={project.outsourcingCostJpy} />
            <Money label="粗利益" value={profit} highlight />
            <div>
              <p className="text-[10px] text-slate-400">粗利益率</p>
              <p className="text-sm font-bold tabular-nums text-emerald-600">
                {((profit / project.orderAmountJpy) * 100).toFixed(1)}%
              </p>
            </div>
          </dl>
        </Card>

        <Card>
          <CardHeader title="概要" />
          <dl className="divide-y divide-slate-50 text-sm">
            <Row label="目的">{project.purpose}</Row>
            <Row label="ターゲット">{project.target}</Row>
            <Row label="ペルソナ">{project.persona}</Row>
            <Row label="要件">{project.requirements}</Row>
            <Row label="期間">{formatDate(project.startDate)} 〜 {formatDate(project.deadline)}</Row>
            <Row label="公開URL">{project.publishedUrl ?? '未公開'}</Row>
          </dl>
        </Card>

        <Card>
          <CardHeader title="サイトマップ / ページ進捗" />
          <div className="p-4">
            <div className="flex flex-wrap gap-1.5">
              {project.sitemap.map((s) => (
                <Badge key={s} className="bg-slate-100 text-slate-600">{s}</Badge>
              ))}
            </div>
            <ul className="mt-3 space-y-1.5">
              {project.pages.map((pg) => (
                <li key={pg.id} className="flex items-center gap-2 rounded-lg border border-slate-100 px-3 py-2 text-sm">
                  <span className="flex-1 text-slate-700">{pg.name}</span>
                  <Badge className={PAGE_STATUS[pg.status].cls}>{PAGE_STATUS[pg.status].label}</Badge>
                </li>
              ))}
            </ul>
          </div>
        </Card>

        <Card>
          <CardHeader title="チーム / 素材 / 修正履歴" />
          <div className="space-y-4 p-4 text-sm">
            <div>
              <p className="mb-1.5 text-xs font-semibold text-slate-500">担当AI</p>
              <div className="flex flex-wrap gap-1.5">
                {project.memberIds.map((id) => {
                  const a = agents.find((x) => x.id === id);
                  return a ? (
                    <Link key={id} href={`/agents/${id}`}>
                      <Badge className="bg-brand-50 text-brand-700">{a.avatar} {a.name}</Badge>
                    </Link>
                  ) : null;
                })}
              </div>
            </div>
            <div>
              <p className="mb-1.5 text-xs font-semibold text-slate-500">必要素材</p>
              <ul className="list-inside list-disc text-xs text-slate-600">
                {project.assets.map((a) => <li key={a}>{a}</li>)}
              </ul>
            </div>
            <div>
              <p className="mb-1.5 text-xs font-semibold text-slate-500">修正履歴</p>
              {project.revisions.length === 0 ? (
                <p className="text-xs text-slate-400">修正履歴はありません</p>
              ) : (
                <ul className="space-y-1 text-xs text-slate-600">
                  {project.revisions.map((r, i) => (
                    <li key={i}>{formatDate(r.date)} — {r.content}</li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </Card>
      </div>

      <Card className="mt-3">
        <CardHeader title="関連タスク" sub={`${tasks.length}件`} />
        <ul className="divide-y divide-slate-50">
          {tasks.map((t) => (
            <li key={t.id}>
              <Link href={`/tasks/${t.id}`} className="flex items-center gap-2 px-4 py-2.5 hover:bg-slate-50">
                <Badge className={cn(TASK_STATUS[t.status].bg, TASK_STATUS[t.status].color)}>
                  {TASK_STATUS[t.status].label}
                </Badge>
                <span className="min-w-0 flex-1 truncate text-sm text-slate-700">{t.title}</span>
                <span className="text-xs tabular-nums text-slate-400">{t.progress}%</span>
              </Link>
            </li>
          ))}
          {tasks.length === 0 && <p className="px-4 py-6 text-center text-xs text-slate-400">関連タスクはありません</p>}
        </ul>
      </Card>
    </div>
  );
}

function Money({ label, value, highlight }: { label: string; value: number; highlight?: boolean }) {
  return (
    <div>
      <p className="text-[10px] text-slate-400">{label}</p>
      <p className={cn('text-sm font-bold tabular-nums', highlight ? 'text-emerald-600' : 'text-slate-800')}>
        {yen(value)}
      </p>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex gap-3 px-4 py-2.5">
      <dt className="w-24 shrink-0 text-xs text-slate-400">{label}</dt>
      <dd className="min-w-0 flex-1 text-sm text-slate-700">{children}</dd>
    </div>
  );
}
