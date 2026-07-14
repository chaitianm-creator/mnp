'use client';

import { useEffect, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { estimateServerOffset } from '@/lib/timer';

/**
 * サーバー時刻に同期した現在時刻(epoch ms)を返すフック。
 * get_server_time RPC でオフセットを推定し、以後はローカルクロック+オフセットで進める。
 */
export function useServerClock(tickMs = 250): { nowMs: number; synced: boolean } {
  const [synced, setSynced] = useState(false);
  const offsetRef = useRef(0);
  const [nowMs, setNowMs] = useState(() => Date.now());

  useEffect(() => {
    let mounted = true;
    const supabase = createClient();

    const sync = async () => {
      const sent = Date.now();
      const { data, error } = await supabase.rpc('get_server_time');
      const received = Date.now();
      if (!mounted || error || !data) return;
      offsetRef.current = estimateServerOffset(sent, received, new Date(data as string).getTime());
      setSynced(true);
    };
    void sync();
    // 5分ごとに再同期 (クロックドリフト対策)
    const resync = window.setInterval(sync, 5 * 60 * 1000);

    const tick = window.setInterval(() => {
      if (mounted) setNowMs(Date.now() + offsetRef.current);
    }, tickMs);

    return () => {
      mounted = false;
      window.clearInterval(tick);
      window.clearInterval(resync);
    };
  }, [tickMs]);

  return { nowMs, synced };
}
