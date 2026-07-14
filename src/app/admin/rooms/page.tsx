'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/misc';
import { Button } from '@/components/ui/button';

interface RoomRow {
  id: string;
  status: string;
  duration_minutes: number;
  starts_at: string;
  ends_at: string;
  max_participants: number;
  is_trial: boolean;
}
interface MemberRow {
  user_id: string;
  display_name: string;
  topic: string;
  camera_on: boolean;
  left_at: string | null;
}

export default function AdminRoomsPage() {
  const supabase = useMemo(() => createClient(), []);
  const [rooms, setRooms] = useState<RoomRow[]>([]);
  const [members, setMembers] = useState<Record<string, MemberRow[]>>({});

  const load = useCallback(async () => {
    const { data } = await supabase
      .from('study_rooms')
      .select('*')
      .in('status', ['waiting', 'active'])
      .gte('ends_at', new Date().toISOString())
      .order('starts_at', { ascending: true })
      .limit(50);
    const list = (data ?? []) as RoomRow[];
    setRooms(list);
    const membersMap: Record<string, MemberRow[]> = {};
    await Promise.all(
      list.map(async (r) => {
        const { data: m } = await supabase.rpc('get_room_members', { p_room_id: r.id });
        membersMap[r.id] = (m ?? []) as MemberRow[];
      })
    );
    setMembers(membersMap);
  }, [supabase]);

  useEffect(() => {
    void load();
    const t = window.setInterval(load, 15000);
    return () => window.clearInterval(t);
  }, [load]);

  const forceLeave = async (roomId: string, userId: string, name: string) => {
    if (!confirm(`${name} さんを強制退室させますか?`)) return;
    const { error } = await supabase.rpc('admin_force_leave', {
      p_room_id: roomId,
      p_user_id: userId,
    });
    if (error) alert('操作に失敗しました: ' + error.message);
    await load();
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">ルーム管理(稼働中)</h1>
        <Button variant="outline" size="sm" onClick={load}>
          更新
        </Button>
      </div>
      {rooms.length === 0 && (
        <Card className="py-10 text-center text-sm text-brand-500">
          現在、稼働中のルームはありません。
        </Card>
      )}
      {rooms.map((r) => {
        const active = (members[r.id] ?? []).filter((m) => !m.left_at);
        return (
          <Card key={r.id}>
            <div className="mb-3 flex flex-wrap items-center gap-2 text-sm">
              <span className="font-mono text-xs text-brand-500">{r.id.slice(0, 8)}…</span>
              <Badge tone={r.status === 'active' ? 'brand' : 'gray'}>
                {r.status === 'active' ? '進行中' : '開始待ち'}
              </Badge>
              {r.is_trial && <Badge tone="lantern">体験</Badge>}
              <span>{r.duration_minutes}分</span>
              <span className="text-brand-500">
                {new Date(r.starts_at).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}〜
                {new Date(r.ends_at).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}
              </span>
              <span className="ml-auto">
                {active.length} / {r.max_participants} 人
              </span>
            </div>
            <ul className="divide-y divide-brand-100 text-sm dark:divide-brand-800">
              {active.map((m) => (
                <li key={m.user_id} className="flex items-center justify-between gap-3 py-2">
                  <span>
                    {m.display_name}
                    <span className="ml-2 text-xs text-brand-500">{m.topic}</span>
                    {!m.camera_on && (
                      <Badge tone="gray" className="ml-2">
                        カメラOFF
                      </Badge>
                    )}
                  </span>
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => forceLeave(r.id, m.user_id, m.display_name)}
                  >
                    強制退室
                  </Button>
                </li>
              ))}
              {active.length === 0 && <li className="py-2 text-brand-500">参加者なし</li>}
            </ul>
          </Card>
        );
      })}
      <p className="text-xs text-brand-500">
        プライバシー保護のため、管理者が参加者の映像を閲覧する機能はありません。
      </p>
    </div>
  );
}
