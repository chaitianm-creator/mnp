'use client';

// レポート(日報・週報・月報)
import { Badge, Button, Card, PageHeader } from '@/components/ui';
import { selectDashboardStats, useOffice } from '@/lib/store';
import { formatDate, todayKey, yen } from '@/lib/utils';
import { Download, FilePlus2 } from 'lucide-react';
import { useState } from 'react';

export default function ReportsPage() {
  const reports = useOffice((s) => s.reports);
  const stats = useOffice(selectDashboardStats);
  const dailyStats = useOffice((s) => s.dailyStats);
  const [generated, setGenerated] = useState<string | null>(null);

  const today = dailyStats.find((d) => d.date === todayKey());

  const generateDaily = () => {
    const body = [
      `# 日報(${todayKey()})`,
      '## 実績',
      `- 完了タスク数: ${today?.tasksCompleted ?? 0}件`,
      `- 営業リスト取得: ${today?.leadsAdded ?? 0}件 / フォーム送信: ${today?.formsSent ?? 0}件 / メール送信: ${today?.emailsSent ?? 0}件`,
      `- 問い合わせ: ${today?.inquiries ?? 0}件 / 商談: ${today?.meetings ?? 0}件 / 受注: ${today?.orders ?? 0}件`,
      `- 進行中案件: ${stats.activeProjects}件 / 承認待ち: ${stats.pendingApprovals}件`,
      `- 売上: ${yen(today?.revenueJpy ?? 0)} / AI利用料: ${yen(today?.costJpy ?? 0)}`,
      '## 課題',
      `- エラー ${stats.errorCount}件(エラー・障害管理を参照)`,
      '## 翌日の優先事項',
      '- 承認待ち項目の確認と、営業アプローチの実行',
    ].join('\n');
    setGenerated(body);
  };

  const downloadCsv = () => {
    const header = 'date,tasksCompleted,leadsAdded,formsSent,emailsSent,inquiries,meetings,orders,costJpy,revenueJpy';
    const rows = dailyStats.map((d) =>
      [d.date, d.tasksCompleted, d.leadsAdded, d.formsSent, d.emailsSent, d.inquiries, d.meetings, d.orders, d.costJpy, d.revenueJpy].join(','),
    );
    const blob = new Blob(['﻿' + [header, ...rows].join('\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `daily-report-${todayKey()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div>
      <PageHeader
        title="レポート"
        sub="日報・週報・月報の作成とCSV出力(PDF/Excelは今後対応)"
        action={
          <div className="flex gap-2">
            <Button variant="secondary" onClick={downloadCsv}>
              <Download className="h-3.5 w-3.5" /> 日別実績CSV
            </Button>
            <Button onClick={generateDaily}>
              <FilePlus2 className="h-3.5 w-3.5" /> 本日の日報を作成
            </Button>
          </div>
        }
      />

      {generated && (
        <Card className="mb-4 border-brand-200 p-4">
          <p className="mb-2 text-xs font-semibold text-brand-600">✨ 生成された日報(プレビュー)</p>
          <pre className="whitespace-pre-wrap rounded-lg bg-slate-50 p-3 text-xs leading-relaxed text-slate-700">{generated}</pre>
        </Card>
      )}

      <div className="grid gap-3 lg:grid-cols-2">
        {reports.map((r) => (
          <Card key={r.id} className="p-4">
            <div className="flex items-center gap-2">
              <Badge className={r.type === 'daily' ? 'bg-sky-50 text-sky-700' : r.type === 'weekly' ? 'bg-violet-50 text-violet-700' : 'bg-emerald-50 text-emerald-700'}>
                {r.type === 'daily' ? '日報' : r.type === 'weekly' ? '週報' : '月報'}
              </Badge>
              <p className="text-sm font-bold text-slate-800">{r.periodLabel}</p>
              <span className="ml-auto text-xs text-slate-400">{formatDate(r.createdAt)}</span>
            </div>
            <pre className="mt-3 max-h-64 overflow-y-auto whitespace-pre-wrap rounded-lg bg-slate-50 p-3 text-xs leading-relaxed text-slate-600">
              {r.body}
            </pre>
          </Card>
        ))}
      </div>
    </div>
  );
}
