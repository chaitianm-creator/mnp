'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { createBlurPipeline, getCameraStream, type BlurPipeline } from '@/lib/media/blur-pipeline';
import { estimateServerOffset } from '@/lib/timer';
import { Card, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/misc';

/**
 * WebRTC診断。ローカルでpc1→pc2のループバック接続を張り、
 * 実際に送信されるぼかし済みトラックの統計を表示する。
 * 元の鮮明な映像は表示・保存・送信しない。
 */

interface Stat {
  label: string;
  value: string;
  ok?: boolean;
}

export function WebRTCDiagnostics() {
  const supabase = useMemo(() => createClient(), []);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [stats, setStats] = useState<Stat[]>([]);
  const [running, setRunning] = useState(false);
  const cleanupRef = useRef<(() => void) | null>(null);

  const run = async () => {
    setRunning(true);
    const results = new Map<string, Stat>();
    const put = (label: string, value: string, ok?: boolean) => {
      results.set(label, { label, value, ok });
      setStats(Array.from(results.values()));
    };

    // 1. カメラ権限
    let permission = '不明';
    try {
      const p = await navigator.permissions?.query({ name: 'camera' as PermissionName });
      permission = p?.state ?? '不明';
    } catch {
      /* Safari等はpermissions API未対応 */
    }
    put('カメラ権限', permission, permission !== 'denied');

    // 2. 元映像の解像度 (トラック設定のみ取得。映像自体は表示しない)
    let rawW = 0;
    let rawH = 0;
    try {
      const probe = await getCameraStream();
      const s = probe.getVideoTracks()[0]?.getSettings();
      rawW = s?.width ?? 0;
      rawH = s?.height ?? 0;
      put('使用カメラ', probe.getVideoTracks()[0]?.label || '(ラベル非公開)', true);
      put('元映像の解像度', `${rawW}×${rawH}`, true);
      put('元ストリームの音声トラック数', String(probe.getAudioTracks().length), probe.getAudioTracks().length === 0);
      probe.getTracks().forEach((t) => t.stop());
    } catch (e) {
      put('使用カメラ', `取得失敗 (${(e as Error).message})`, false);
      setRunning(false);
      return;
    }

    // 3. ぼかしパイプライン
    let pipeline: BlurPipeline;
    try {
      pipeline = await createBlurPipeline();
    } catch (e) {
      put('ぼかしパイプライン', `起動失敗 (${(e as Error).message})`, false);
      setRunning(false);
      return;
    }
    const outSettings = pipeline.stream.getVideoTracks()[0]?.getSettings();
    put('加工後映像の解像度', `${outSettings?.width ?? 320}×${outSettings?.height ?? 240}`, true);
    put('送信ストリームの映像トラック数', String(pipeline.stream.getVideoTracks().length), pipeline.stream.getVideoTracks().length === 1);
    put(
      '送信ストリームの音声トラック数',
      String(pipeline.stream.getAudioTracks().length),
      pipeline.stream.getAudioTracks().length === 0
    );
    if (videoRef.current) {
      videoRef.current.srcObject = pipeline.stream;
      void videoRef.current.play().catch(() => {});
    }

    // 4. ICEサーバー設定
    const turnConfigured = !!process.env.NEXT_PUBLIC_TURN_URL;
    put('STUN', process.env.NEXT_PUBLIC_STUN_URLS || 'stun:stun.l.google.com:19302', true);
    put('TURN', turnConfigured ? process.env.NEXT_PUBLIC_TURN_URL! : '未設定 (本番利用には不十分)', turnConfigured);

    // 5. ループバックPeerConnection (pc1=送信側, pc2=受信側)
    const iceServers: RTCIceServer[] = [
      { urls: (process.env.NEXT_PUBLIC_STUN_URLS || 'stun:stun.l.google.com:19302').split(',') },
    ];
    if (turnConfigured) {
      iceServers.push({
        urls: process.env.NEXT_PUBLIC_TURN_URL!,
        username: process.env.NEXT_PUBLIC_TURN_USERNAME || '',
        credential: process.env.NEXT_PUBLIC_TURN_CREDENTIAL || '',
      });
    }
    const pc1 = new RTCPeerConnection({ iceServers });
    const pc2 = new RTCPeerConnection({ iceServers });
    pc1.onicecandidate = (e) => e.candidate && pc2.addIceCandidate(e.candidate);
    pc2.onicecandidate = (e) => e.candidate && pc1.addIceCandidate(e.candidate);
    const track = pipeline.stream.getVideoTracks()[0];
    pc1.addTrack(track, pipeline.stream);

    const updatePcState = () => {
      put('PeerConnection状態', pc1.connectionState, pc1.connectionState === 'connected');
      put('ICE connection state', pc1.iceConnectionState, ['connected', 'completed'].includes(pc1.iceConnectionState));
      put('ICE gathering state', pc1.iceGatheringState);
      put('Signaling state', pc1.signalingState);
    };
    pc1.onconnectionstatechange = updatePcState;
    pc1.oniceconnectionstatechange = updatePcState;
    pc1.onicegatheringstatechange = updatePcState;
    pc1.onsignalingstatechange = updatePcState;

    const offer = await pc1.createOffer();
    await pc1.setLocalDescription(offer);
    await pc2.setRemoteDescription(offer);
    const answer = await pc2.createAnswer();
    await pc2.setLocalDescription(answer);
    await pc1.setRemoteDescription(answer);
    updatePcState();

    // 6. getStatsでcandidate type / ビットレート / フレームレートを継続表示
    let prevBytesSent = 0;
    let prevBytesRecv = 0;
    let prevTime = Date.now();
    const statsTimer = window.setInterval(async () => {
      const now = Date.now();
      const elapsed = (now - prevTime) / 1000;
      prevTime = now;

      const s1 = await pc1.getStats();
      s1.forEach((report) => {
        if (report.type === 'candidate-pair' && report.state === 'succeeded' && report.nominated) {
          const local = s1.get(report.localCandidateId);
          if (local) {
            put('使用中のcandidate type', `${local.candidateType} (host=同一LAN / srflx=STUN経由 / relay=TURN経由)`,
              true);
          }
        }
        if (report.type === 'outbound-rtp' && report.kind === 'video') {
          const bytes = report.bytesSent ?? 0;
          const kbps = elapsed > 0 ? Math.round(((bytes - prevBytesSent) * 8) / 1000 / elapsed) : 0;
          prevBytesSent = bytes;
          put('送信ビットレート', `${kbps} kbps`, kbps > 0);
          put('送信フレームレート', `${report.framesPerSecond ?? '-'} fps`, (report.framesPerSecond ?? 0) > 0);
        }
      });
      const s2 = await pc2.getStats();
      s2.forEach((report) => {
        if (report.type === 'inbound-rtp' && report.kind === 'video') {
          const bytes = report.bytesReceived ?? 0;
          const kbps = elapsed > 0 ? Math.round(((bytes - prevBytesRecv) * 8) / 1000 / elapsed) : 0;
          prevBytesRecv = bytes;
          put('受信ビットレート', `${kbps} kbps`, kbps > 0);
          put(
            '受信解像度',
            `${report.frameWidth ?? '-'}×${report.frameHeight ?? '-'}`,
            (report.frameWidth ?? 0) <= 400 // ぼかし後の縮小解像度であることの確認
          );
        }
      });
    }, 2000);

    // 7. Supabase Realtime接続 (公開チャネルで接続確認のみ)
    const channel = supabase.channel(`diagnostics:${Math.random().toString(36).slice(2)}`);
    channel.subscribe((status) => {
      put(
        'Realtime接続状態',
        status,
        status === 'SUBSCRIBED'
      );
    });

    // 8. サーバー時刻との差
    const sent = Date.now();
    const { data: serverTime, error: timeError } = await supabase.rpc('get_server_time');
    const received = Date.now();
    if (serverTime && !timeError) {
      const offset = estimateServerOffset(sent, received, new Date(serverTime as string).getTime());
      put('タイマーのサーバー時刻との差', `${offset >= 0 ? '+' : ''}${Math.round(offset)} ms (RTT ${received - sent}ms)`, Math.abs(offset) < 5000);
    } else {
      put('タイマーのサーバー時刻との差', '取得失敗', false);
    }

    // 9. 現在の在室情報
    const { data: activeSession } = await supabase
      .from('study_sessions')
      .select('room_id')
      .eq('status', 'active')
      .maybeSingle();
    put('現在のルームID', activeSession?.room_id ?? '(入室していません)');
    const { data: studying } = await supabase.rpc('current_studying_count');
    put('現在の接続人数(全体)', String(studying ?? 0));

    cleanupRef.current = () => {
      window.clearInterval(statsTimer);
      pc1.close();
      pc2.close();
      pipeline.stop();
      void supabase.removeChannel(channel);
    };
  };

  useEffect(() => {
    return () => cleanupRef.current?.();
  }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-6 px-4 py-8">
      <div>
        <h1 className="text-2xl font-bold">WebRTC診断</h1>
        <p className="mt-1 text-sm text-brand-600 dark:text-brand-300">
          端末内でループバック接続(pc1→pc2)を作成し、実際に送信される
          <strong>ぼかし済みトラック</strong>の統計を表示します。
          元の鮮明な映像は表示・保存・送信されません。
        </p>
      </div>

      {!running ? (
        <Button size="lg" onClick={run}>
          診断を開始
        </Button>
      ) : (
        <Button
          variant="outline"
          onClick={() => {
            cleanupRef.current?.();
            cleanupRef.current = null;
            setRunning(false);
            setStats([]);
          }}
        >
          診断を停止
        </Button>
      )}

      {running && (
        <div className="max-w-xs">
          <video ref={videoRef} muted playsInline className="w-full rounded-xl bg-brand-950" />
          <p className="mt-1 text-xs text-brand-500">送信されるぼかし済み映像 (受信側で見える映像と同一)</p>
        </div>
      )}

      {stats.length > 0 && (
        <Card className="p-0">
          <table className="w-full text-sm">
            <tbody>
              {stats.map((s) => (
                <tr key={s.label} className="border-b border-brand-50 last:border-0 dark:border-brand-800/50">
                  <td className="w-1/2 p-3 font-medium">{s.label}</td>
                  <td className="p-3">
                    <span className="mr-2 break-all">{s.value}</span>
                    {s.ok !== undefined && (
                      <Badge tone={s.ok ? 'brand' : 'red'}>{s.ok ? 'OK' : '要確認'}</Badge>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      <Card>
        <CardTitle>判定の目安</CardTitle>
        <ul className="list-disc space-y-1 pl-5 text-sm text-brand-700 dark:text-brand-200">
          <li>「音声トラック数」は常に0本であること(本サービスは音声を扱いません)</li>
          <li>「受信解像度」は320×240程度であること(ぼかし後の縮小映像)</li>
          <li>candidate typeがrelayの場合はTURN経由で接続しています</li>
          <li>TURN未設定の場合、対称NAT環境の相手とは接続できないことがあります</li>
        </ul>
      </Card>
    </div>
  );
}
