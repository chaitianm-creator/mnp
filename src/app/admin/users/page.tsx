'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/misc';
import { Button } from '@/components/ui/button';

interface UserRow {
  id: string;
  display_name: string;
  study_purpose: string | null;
  role: string;
  status: string;
  created_at: string;
}

export default function AdminUsersPage() {
  const supabase = useMemo(() => createClient(), []);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [query, setQuery] = useState('');
  const [busy, setBusy] = useState('');

  const load = useCallback(async () => {
    let req = supabase
      .from('profiles')
      .select('id, display_name, study_purpose, role, status, created_at')
      .order('created_at', { ascending: false })
      .limit(100);
    if (query.trim()) {
      req = req.ilike('display_name', `%${query.trim()}%`);
    }
    const { data } = await req;
    setUsers((data ?? []) as UserRow[]);
  }, [supabase, query]);

  useEffect(() => {
    void load();
  }, [load]);

  const setStatus = async (id: string, status: 'active' | 'suspended') => {
    const label = status === 'suspended' ? '利用停止' : '停止解除';
    if (!confirm(`このユーザーを${label}しますか?`)) return;
    setBusy(id);
    const { error } = await supabase.rpc('admin_set_user_status', {
      p_user_id: id,
      p_status: status,
      p_note: '',
    });
    if (error) alert('操作に失敗しました: ' + error.message);
    await load();
    setBusy('');
  };

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold">ユーザー管理</h1>
      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-3 h-5 w-5 text-brand-400" />
        <Input
          className="pl-10"
          placeholder="表示名で検索"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          aria-label="ユーザー検索"
        />
      </div>
      <Card className="overflow-x-auto p-0">
        <table className="w-full min-w-[640px] text-sm">
          <thead>
            <tr className="border-b border-brand-100 text-left text-xs text-brand-500 dark:border-brand-800">
              <th className="p-3">表示名</th>
              <th className="p-3">ID</th>
              <th className="p-3">登録日</th>
              <th className="p-3">ロール</th>
              <th className="p-3">状態</th>
              <th className="p-3">操作</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className="border-b border-brand-50 dark:border-brand-800/50">
                <td className="p-3 font-medium">{u.display_name}</td>
                <td className="p-3 font-mono text-xs text-brand-500">{u.id.slice(0, 8)}…</td>
                <td className="p-3">{new Date(u.created_at).toLocaleDateString('ja-JP')}</td>
                <td className="p-3">
                  {u.role === 'admin' ? <Badge tone="lantern">管理者</Badge> : '一般'}
                </td>
                <td className="p-3">
                  <Badge tone={u.status === 'active' ? 'brand' : u.status === 'suspended' ? 'red' : 'gray'}>
                    {u.status === 'active' ? '有効' : u.status === 'suspended' ? '停止中' : '退会'}
                  </Badge>
                </td>
                <td className="p-3">
                  {u.role !== 'admin' && u.status === 'active' && (
                    <Button
                      variant="danger"
                      size="sm"
                      disabled={busy === u.id}
                      onClick={() => setStatus(u.id, 'suspended')}
                    >
                      利用停止
                    </Button>
                  )}
                  {u.status === 'suspended' && (
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={busy === u.id}
                      onClick={() => setStatus(u.id, 'active')}
                    >
                      停止解除
                    </Button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {users.length === 0 && (
          <p className="p-6 text-center text-sm text-brand-500">該当するユーザーがいません。</p>
        )}
      </Card>
    </div>
  );
}
