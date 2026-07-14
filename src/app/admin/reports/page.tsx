'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/misc';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/input';
import { REPORT_CATEGORIES } from '@/lib/constants';

interface ReportRow {
  id: string;
  reporter_id: string;
  reported_user_id: string;
  category: string;
  description: string;
  status: string;
  resolution_note: string | null;
  created_at: string;
}

export default function AdminReportsPage() {
  const supabase = useMemo(() => createClient(), []);
  const [reports, setReports] = useState<ReportRow[]>([]);
  const [names, setNames] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState('');

  const load = useCallback(async () => {
    const { data } = await supabase
      .from('reports')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100);
    const list = (data ?? []) as ReportRow[];
    setReports(list);
    const ids = Array.from(new Set(list.flatMap((r) => [r.reporter_id, r.reported_user_id])));
    if (ids.length > 0) {
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, display_name, status')
        .in('id', ids);
      const map: Record<string, string> = {};
      for (const p of profiles ?? []) {
        map[p.id] = `${p.display_name}${p.status === 'suspended' ? '(停止中)' : ''}`;
      }
      setNames(map);
    }
  }, [supabase]);

  useEffect(() => {
    void load();
  }, [load]);

  const updateStatus = async (id: string, status: string) => {
    setBusy(id);
    const { error } = await supabase.rpc('admin_update_report', {
      p_report_id: id,
      p_status: status,
      p_note: notes[id] ?? '',
    });
    if (error) alert('操作に失敗しました: ' + error.message);
    await load();
    setBusy('');
  };

  const suspend = async (userId: string) => {
    if (!confirm('通報対象のユーザーを利用停止にしますか?')) return;
    const { error } = await supabase.rpc('admin_set_user_status', {
      p_user_id: userId,
      p_status: 'suspended',
      p_note: '通報対応',
    });
    if (error) alert('操作に失敗しました: ' + error.message);
    await load();
  };

  const categoryLabel = new Map<string, string>(REPORT_CATEGORIES.map((c) => [c.value, c.label]));
  const statusTone: Record<string, 'red' | 'lantern' | 'brand' | 'gray'> = {
    open: 'red',
    reviewing: 'lantern',
    resolved: 'brand',
    dismissed: 'gray',
  };
  const statusLabel: Record<string, string> = {
    open: '未対応',
    reviewing: '確認中',
    resolved: '対応済み',
    dismissed: '対応不要',
  };

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold">通報管理</h1>
      {reports.length === 0 && (
        <Card className="py-10 text-center text-sm text-brand-500">通報はありません。</Card>
      )}
      {reports.map((r) => (
        <Card key={r.id}>
          <div className="mb-2 flex flex-wrap items-center gap-2 text-sm">
            <Badge tone={statusTone[r.status] ?? 'gray'}>{statusLabel[r.status] ?? r.status}</Badge>
            <span className="font-bold">{categoryLabel.get(r.category) ?? r.category}</span>
            <span className="ml-auto text-xs text-brand-500">
              {new Date(r.created_at).toLocaleString('ja-JP')}
            </span>
          </div>
          <p className="text-sm">
            <span className="text-brand-500">通報者:</span> {names[r.reporter_id] ?? '不明'}
            {' → '}
            <span className="text-brand-500">対象:</span>{' '}
            <strong>{names[r.reported_user_id] ?? '不明'}</strong>
          </p>
          {r.description && (
            <p className="mt-2 whitespace-pre-wrap rounded-lg bg-brand-50 p-3 text-sm dark:bg-brand-900">
              {r.description}
            </p>
          )}
          {r.resolution_note && (
            <p className="mt-2 text-xs text-brand-500">対応メモ: {r.resolution_note}</p>
          )}
          {(r.status === 'open' || r.status === 'reviewing') && (
            <div className="mt-3 space-y-2">
              <Textarea
                rows={2}
                placeholder="対応メモ(任意)"
                value={notes[r.id] ?? ''}
                onChange={(e) => setNotes((n) => ({ ...n, [r.id]: e.target.value }))}
              />
              <div className="flex flex-wrap gap-2">
                {r.status === 'open' && (
                  <Button
                    variant="outline"
                    size="sm"
                    disabled={busy === r.id}
                    onClick={() => updateStatus(r.id, 'reviewing')}
                  >
                    確認中にする
                  </Button>
                )}
                <Button
                  variant="danger"
                  size="sm"
                  disabled={busy === r.id}
                  onClick={() => suspend(r.reported_user_id)}
                >
                  対象を利用停止
                </Button>
                <Button
                  variant="primary"
                  size="sm"
                  disabled={busy === r.id}
                  onClick={() => updateStatus(r.id, 'resolved')}
                >
                  対応済みにする
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={busy === r.id}
                  onClick={() => updateStatus(r.id, 'dismissed')}
                >
                  対応不要
                </Button>
              </div>
            </div>
          )}
        </Card>
      ))}
    </div>
  );
}
