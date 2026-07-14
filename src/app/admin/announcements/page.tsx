'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Card, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/misc';
import { Button } from '@/components/ui/button';
import { Input, Textarea, Label } from '@/components/ui/input';

interface Announcement {
  id: string;
  title: string;
  body: string;
  is_published: boolean;
  published_at: string | null;
  created_at: string;
}

export default function AdminAnnouncementsPage() {
  const supabase = useMemo(() => createClient(), []);
  const [items, setItems] = useState<Announcement[]>([]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const { data } = await supabase
      .from('announcements')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50);
    setItems((data ?? []) as Announcement[]);
  }, [supabase]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    if (!title.trim() || !body.trim()) return;
    setBusy(true);
    if (editing) {
      await supabase
        .from('announcements')
        .update({ title: title.trim(), body: body.trim() })
        .eq('id', editing);
    } else {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      await supabase.from('announcements').insert({
        title: title.trim(),
        body: body.trim(),
        created_by: user!.id,
      });
    }
    setTitle('');
    setBody('');
    setEditing(null);
    await load();
    setBusy(false);
  };

  const togglePublish = async (a: Announcement) => {
    await supabase
      .from('announcements')
      .update({
        is_published: !a.is_published,
        published_at: !a.is_published ? new Date().toISOString() : a.published_at,
      })
      .eq('id', a.id);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm('このお知らせを削除しますか?')) return;
    await supabase.from('announcements').delete().eq('id', id);
    await load();
  };

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-bold">お知らせ管理</h1>

      <Card className="space-y-4">
        <CardTitle>{editing ? 'お知らせを編集' : '新しいお知らせ'}</CardTitle>
        <div>
          <Label htmlFor="ann-title">タイトル</Label>
          <Input id="ann-title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={100} />
        </div>
        <div>
          <Label htmlFor="ann-body">本文</Label>
          <Textarea id="ann-body" rows={4} value={body} onChange={(e) => setBody(e.target.value)} maxLength={4000} />
        </div>
        <div className="flex gap-2">
          <Button onClick={save} disabled={busy || !title.trim() || !body.trim()}>
            {editing ? '更新する' : '下書きとして作成'}
          </Button>
          {editing && (
            <Button
              variant="ghost"
              onClick={() => {
                setEditing(null);
                setTitle('');
                setBody('');
              }}
            >
              キャンセル
            </Button>
          )}
        </div>
      </Card>

      <div className="space-y-3">
        {items.map((a) => (
          <Card key={a.id}>
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={a.is_published ? 'brand' : 'gray'}>
                {a.is_published ? '公開中' : '下書き'}
              </Badge>
              <span className="font-bold">{a.title}</span>
              <span className="ml-auto text-xs text-brand-500">
                {new Date(a.created_at).toLocaleDateString('ja-JP')}
              </span>
            </div>
            <p className="mt-2 whitespace-pre-wrap text-sm text-brand-700 dark:text-brand-200">{a.body}</p>
            <div className="mt-3 flex gap-2">
              <Button variant="outline" size="sm" onClick={() => togglePublish(a)}>
                {a.is_published ? '非公開にする' : '公開する'}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setEditing(a.id);
                  setTitle(a.title);
                  setBody(a.body);
                  window.scrollTo({ top: 0, behavior: 'smooth' });
                }}
              >
                編集
              </Button>
              <Button variant="ghost" size="sm" onClick={() => remove(a.id)}>
                削除
              </Button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
