'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Flag, LogOut, Video, VideoOff, WifiOff } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { createBlurPipeline, type BlurPipeline } from '@/lib/media/blur-pipeline';
import { MeshRoom, type RemotePeer } from '@/lib/webrtc/mesh';
import { computeTimerState, formatSeconds } from '@/lib/timer';
import { useServerClock } from '@/lib/use-server-clock';
import { showNotification, playChime, requestNotificationPermission } from '@/lib/notify';
import { Button } from '@/components/ui/button';
import { Dialog, Alert, Badge } from '@/components/ui/misc';
import { Textarea, Label, Select } from '@/components/ui/input';
import { TomoshibiMessage, TomoshibiIcon } from '@/components/tomoshibi';
import { REPORT_CATEGORIES, rpcErrorToMessage } from '@/lib/constants';
import { cn } from '@/lib/utils';

interface RoomInfo {
  id: string;
  starts_at: string;
  ends_at: string;
  duration_minutes: number;
  is_trial: boolean;
}
interface Member {
  user_id: string;
  display_name: string;
  topic: string;
  camera_on: boolean;
  joined_at: string;
  left_at: string | null;
}

const START_MESSAGES = [
  'それでは、はじめましょう。手が止まったら、深呼吸をひとつ。',
  '準備はいいですか。この時間はあなたのものです。',
  'ようこそ。みんな一緒です。静かにいきましょう。',
];
const END_MESSAGES = [
  'おつかれさまでした。ちゃんと机に向かえましたね。',
  'ここまでよく集中しました。少し休みましょう。',
  '今日の積み重ねが、明日のあなたを助けます。',
];

export default function RoomPage() {
  const params = useParams<{ roomId: string }>();
  const roomId = params.roomId;
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { nowMs, synced } = useServerClock(250);

  const [room, setRoom] = useState<RoomInfo | null>(null);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [myId, setMyId] = useState<string>('');
  const [members, setMembers] = useState<Member[]>([]);
  const [peers, setPeers] = useState<RemotePeer[]>([]);
  const [cameraOn, setCameraOn] = useState(true);
  const [fatal, setFatal] = useState('');
  const [duplicate, setDuplicate] = useState(false);
  const [leaveOpen, setLeaveOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [startMessage] = useState(() => START_MESSAGES[Math.floor(Math.random() * START_MESSAGES.length)]);

  const pipelineRef = useRef<BlurPipeline | null>(null);
  const meshRef = useRef<MeshRoom | null>(null);
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const startedNotifiedRef = useRef(false);
  const finishedRef = useRef(false);

  const refreshMembers = useCallback(async () => {
    const { data } = await supabase.rpc('get_room_members', { p_room_id: roomId });
    if (data) setMembers(data as Member[]);
  }, [supabase, roomId]);

  // 初期化: セッション確認 → カメラ → メッシュ接続
  useEffect(() => {
    let cancelled = false;

    const init = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      setMyId(user.id);

      // 自分のこの部屋のセッションを確認 (終了済みセッションへの再入室防止)
      const { data: session } = await supabase
        .from('study_sessions')
        .select('id, status')
        .eq('room_id', roomId)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (!session) {
        router.replace('/prejoin');
        return;
      }
      if (session.status === 'completed') {
        router.replace(`/session/${session.id}/complete`);
        return;
      }
      if (session.status !== 'active') {
        router.replace('/home');
        return;
      }
      setSessionId(session.id);

      const { data: roomData, error: roomError } = await supabase
        .from('study_rooms')
        .select('id, starts_at, ends_at, duration_minutes, is_trial')
        .eq('id', roomId)
        .single();
      if (roomError || !roomData) {
        setFatal('部屋の情報を取得できませんでした。');
        return;
      }
      if (new Date(roomData.ends_at).getTime() < Date.now()) {
        router.replace('/home');
        return;
      }
      if (cancelled) return;
      setRoom(roomData as RoomInfo);

      const { data: ns } = await supabase
        .from('notification_settings')
        .select('sound_enabled')
        .maybeSingle();
      if (ns) setSoundEnabled(ns.sound_enabled);
      void requestNotificationPermission();

      // ぼかしパイプライン起動
      try {
        const pipeline = await createBlurPipeline();
        if (cancelled) {
          pipeline.stop();
          return;
        }
        pipelineRef.current = pipeline;
        if (localVideoRef.current) {
          localVideoRef.current.srcObject = pipeline.stream;
          void localVideoRef.current.play().catch(() => {});
        }

        const mesh = new MeshRoom({
          supabase,
          roomId,
          userId: user.id,
          localStream: pipeline.stream,
          onPeersChanged: (p) => {
            setPeers(p);
            void refreshMembers();
          },
          onDuplicateConnection: () => setDuplicate(true),
        });
        meshRef.current = mesh;
        await mesh.join();
        mesh.onMemberState(() => void refreshMembers());
        void refreshMembers();
      } catch (e) {
        setFatal(
          e instanceof Error && e.message.startsWith('camera_')
            ? 'カメラを起動できませんでした。カメラテストページで設定を確認してください。'
            : '自習室への接続に失敗しました。ページを再読み込みしてください。'
        );
      }
    };

    void init();
    return () => {
      cancelled = true;
      meshRef.current?.leave();
      meshRef.current = null;
      pipelineRef.current?.stop();
      pipelineRef.current = null;
    };
  }, [supabase, roomId, router, refreshMembers]);

  const timer = room
    ? computeTimerState(new Date(room.starts_at).getTime(), new Date(room.ends_at).getTime(), nowMs)
    : null;

  // 開始・終了イベント
  useEffect(() => {
    if (!timer || !room || !synced) return;
    if (timer.phase === 'running' && !startedNotifiedRef.current) {
      startedNotifiedRef.current = true;
      if (soundEnabled) playChime();
      showNotification('集中タイム開始', `${room.duration_minutes}分間、一緒にがんばりましょう。`);
    }
    if (timer.phase === 'finished' && !finishedRef.current) {
      finishedRef.current = true;
      if (soundEnabled) playChime();
      showNotification('おつかれさまでした', '集中タイムが終了しました。');
      meshRef.current?.leave();
      pipelineRef.current?.stop();
      if (sessionId) router.replace(`/session/${sessionId}/complete`);
    }
  }, [timer, room, synced, soundEnabled, sessionId, router]);

  const toggleCamera = async () => {
    const next = !cameraOn;
    setCameraOn(next);
    if (next) {
      try {
        const pipeline = await createBlurPipeline();
        pipelineRef.current = pipeline;
        if (localVideoRef.current) {
          localVideoRef.current.srcObject = pipeline.stream;
          void localVideoRef.current.play().catch(() => {});
        }
        await meshRef.current?.replaceLocalTrack(pipeline.stream.getVideoTracks()[0] ?? null);
      } catch {
        setCameraOn(false);
        return;
      }
    } else {
      await meshRef.current?.replaceLocalTrack(null);
      pipelineRef.current?.stop();
      pipelineRef.current = null;
      if (localVideoRef.current) localVideoRef.current.srcObject = null;
    }
    await supabase.rpc('set_camera_state', { p_room_id: roomId, p_camera_on: next });
    meshRef.current?.broadcastState({ camera_on: next });
  };

  const leave = async () => {
    if (!sessionId) return;
    meshRef.current?.leave();
    pipelineRef.current?.stop();
    await supabase.rpc('leave_session', { p_session_id: sessionId });
    router.replace('/home');
  };

  // タイル一覧 (自分 + アクティブメンバー)
  const activeMembers = members.filter((m) => !m.left_at && m.user_id !== myId);
  const leftMembers = members.filter((m) => m.left_at && m.user_id !== myId);
  const myMember = members.find((m) => m.user_id === myId);
  const tileCount = activeMembers.length + 1;
  const gridClass =
    tileCount <= 1
      ? 'grid-cols-1 max-w-md'
      : tileCount <= 2
        ? 'grid-cols-1 sm:grid-cols-2'
        : tileCount <= 4
          ? 'grid-cols-2'
          : 'grid-cols-2 sm:grid-cols-3';

  if (fatal) {
    return (
      <div className="flex min-h-dvh items-center justify-center p-6">
        <div className="w-full max-w-md space-y-4">
          <Alert tone="error">{fatal}</Alert>
          <Button className="w-full" onClick={() => router.push('/home')}>
            ホームへ戻る
          </Button>
        </div>
      </div>
    );
  }

  if (duplicate) {
    return (
      <div className="flex min-h-dvh items-center justify-center p-6">
        <div className="w-full max-w-md space-y-4">
          <Alert tone="warning">
            別のタブまたは端末でこの自習室に接続中です。多重入室はできません。このタブを閉じるか、他の接続を終了してください。
          </Alert>
          <Button className="w-full" onClick={() => router.push('/home')}>
            ホームへ戻る
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh flex-col bg-brand-950 text-white">
      {/* ヘッダー: タイマー */}
      <header className="flex items-center justify-between gap-3 px-4 py-3">
        <div className="flex items-center gap-2 text-sm text-brand-200">
          <TomoshibiIcon className="h-8 w-8" glow />
          <span className="hidden sm:inline">{room?.is_trial ? '体験セッション' : 'MokuTomo 自習室'}</span>
        </div>
        <div className="text-center" role="timer" aria-live="off">
          {!room || !timer || !synced ? (
            <p className="text-2xl font-bold tabular-nums">--:--</p>
          ) : timer.phase === 'countdown' ? (
            <>
              <p className="text-xs text-lantern-300">開始まで</p>
              <p className="text-2xl font-bold tabular-nums">{formatSeconds(timer.secondsToStart)}</p>
            </>
          ) : (
            <>
              <p className="text-xs text-brand-300">残り時間</p>
              <p className="text-3xl font-bold tabular-nums">{formatSeconds(timer.secondsRemaining)}</p>
            </>
          )}
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="ghost"
            size="sm"
            className="text-brand-200 hover:bg-brand-800"
            onClick={toggleCamera}
            aria-label={cameraOn ? 'カメラをオフにする' : 'カメラをオンにする'}
          >
            {cameraOn ? <Video className="h-5 w-5" /> : <VideoOff className="h-5 w-5 text-lantern-300" />}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className="text-brand-200 hover:bg-brand-800"
            onClick={() => setReportOpen(true)}
            aria-label="通報する"
            disabled={activeMembers.length === 0}
          >
            <Flag className="h-5 w-5" />
          </Button>
          <Button variant="danger" size="sm" onClick={() => setLeaveOpen(true)}>
            <LogOut className="h-4 w-4" />
            <span className="hidden sm:inline">退出</span>
          </Button>
        </div>
      </header>

      {/* 進捗バー */}
      <div className="h-1 w-full bg-brand-900">
        <div
          className="h-full bg-lantern-400 transition-all duration-1000"
          style={{ width: `${(timer?.progress ?? 0) * 100}%` }}
        />
      </div>

      {/* 開始前メッセージ */}
      {timer?.phase === 'countdown' && (
        <div className="mx-auto mt-4 max-w-md px-4">
          <TomoshibiMessage glow message={startMessage} />
        </div>
      )}

      {/* 参加者グリッド */}
      <main className="flex flex-1 items-center justify-center p-4">
        <div className={cn('grid w-full max-w-4xl gap-3', gridClass)}>
          {/* 自分 */}
          <RoomTile
            name={`${myMember?.display_name ?? 'あなた'}(自分)`}
            topic={myMember?.topic ?? ''}
            state="connected"
            cameraOn={cameraOn}
            left={false}
          >
            <video
              ref={localVideoRef}
              muted
              playsInline
              className={cn('h-full w-full object-cover', !cameraOn && 'hidden')}
            />
          </RoomTile>

          {activeMembers.map((m) => {
            const peer = peers.find((p) => p.userId === m.user_id);
            return (
              <RoomTile
                key={m.user_id}
                name={m.display_name}
                topic={m.topic}
                state={peer?.state ?? 'connecting'}
                cameraOn={m.camera_on && !!peer?.stream}
                left={false}
              >
                {peer?.stream && m.camera_on && <PeerVideo stream={peer.stream} />}
              </RoomTile>
            );
          })}
        </div>
      </main>

      {leftMembers.length > 0 && (
        <p className="pb-3 text-center text-xs text-brand-400">
          {leftMembers.map((m) => m.display_name).join('、')} さんは退出しました
        </p>
      )}

      {/* 退出確認 */}
      <Dialog open={leaveOpen} onClose={() => setLeaveOpen(false)} title="途中退出しますか?">
        <div className="text-brand-900 dark:text-brand-50">
          <p className="mb-4 text-sm">
            途中退出すると、このコマは完了になりません(ここまでの時間は記録されます)。
          </p>
          <div className="flex gap-3">
            <Button variant="outline" className="flex-1" onClick={() => setLeaveOpen(false)}>
              続ける
            </Button>
            <Button variant="danger" className="flex-1" onClick={leave}>
              退出する
            </Button>
          </div>
        </div>
      </Dialog>

      {/* 通報 */}
      <ReportDialog
        open={reportOpen}
        onClose={() => setReportOpen(false)}
        roomId={roomId}
        members={activeMembers}
      />
    </div>
  );
}

function PeerVideo({ stream }: { stream: MediaStream }) {
  const ref = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    if (ref.current) {
      ref.current.srcObject = stream;
      void ref.current.play().catch(() => {});
    }
  }, [stream]);
  // 受信映像にも表示側で追加のぼかしをかける(送信側加工との二重防御)
  return <video ref={ref} muted playsInline className="h-full w-full object-cover [filter:blur(2px)]" />;
}

function RoomTile({
  name,
  topic,
  state,
  cameraOn,
  left,
  children,
}: {
  name: string;
  topic: string;
  state: 'connecting' | 'connected' | 'disconnected';
  cameraOn: boolean;
  left: boolean;
  children?: React.ReactNode;
}) {
  return (
    <div className="relative aspect-[4/3] overflow-hidden rounded-2xl bg-brand-900">
      {children}
      {!cameraOn && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-gradient-to-br from-brand-900 to-brand-800">
          <TomoshibiIcon className="h-10 w-10 opacity-80" />
          <p className="text-xs text-brand-300">カメラオフで自習中</p>
        </div>
      )}
      {state !== 'connected' && !left && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/50">
          <p className="flex items-center gap-1.5 text-xs text-white">
            {state === 'connecting' ? (
              '接続中…'
            ) : (
              <>
                <WifiOff className="h-4 w-4" /> 再接続中…
              </>
            )}
          </p>
        </div>
      )}
      <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-2 bg-gradient-to-t from-black/70 to-transparent p-2.5">
        <div className="min-w-0">
          <p className="truncate text-sm font-medium text-white">{name}</p>
          {topic && <p className="truncate text-xs text-brand-200">{topic}</p>}
        </div>
        {state === 'connected' && <span className="h-2 w-2 shrink-0 rounded-full bg-emerald-400" aria-label="接続中" />}
      </div>
    </div>
  );
}

function ReportDialog({
  open,
  onClose,
  roomId,
  members,
}: {
  open: boolean;
  onClose: () => void;
  roomId: string;
  members: Member[];
}) {
  const supabase = useMemo(() => createClient(), []);
  const [target, setTarget] = useState('');
  const [category, setCategory] = useState('inappropriate_behavior');
  const [description, setDescription] = useState('');
  const [block, setBlock] = useState(true);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    if (!target) return;
    setSubmitting(true);
    setError('');
    const { error } = await supabase.rpc('create_report', {
      p_reported_user_id: target,
      p_room_id: roomId,
      p_category: category,
      p_description: description,
    });
    if (error) {
      setError(rpcErrorToMessage(error));
      setSubmitting(false);
      return;
    }
    if (block) {
      await supabase.from('blocked_users').insert({
        user_id: (await supabase.auth.getUser()).data.user!.id,
        blocked_user_id: target,
      });
    }
    setDone(true);
    setSubmitting(false);
  };

  return (
    <Dialog open={open} onClose={onClose} title="参加者を通報">
      <div className="text-brand-900 dark:text-brand-50">
        {done ? (
          <div className="space-y-4">
            <Alert tone="success">
              通報を受け付けました。運営が内容を確認します。ご協力ありがとうございます。
            </Alert>
            <Button className="w-full" onClick={onClose}>
              閉じる
            </Button>
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <Label htmlFor="report-target">対象の参加者</Label>
              <Select id="report-target" value={target} onChange={(e) => setTarget(e.target.value)}>
                <option value="">選択してください</option>
                {members.map((m) => (
                  <option key={m.user_id} value={m.user_id}>
                    {m.display_name}
                  </option>
                ))}
              </Select>
            </div>
            <div>
              <Label htmlFor="report-category">理由</Label>
              <Select id="report-category" value={category} onChange={(e) => setCategory(e.target.value)}>
                {REPORT_CATEGORIES.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </Select>
            </div>
            <div>
              <Label htmlFor="report-desc">詳細(任意)</Label>
              <Textarea
                id="report-desc"
                rows={3}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                maxLength={1000}
              />
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={block}
                onChange={(e) => setBlock(e.target.checked)}
                className="h-4 w-4 rounded"
              />
              この参加者と今後同じ部屋にならないようにする(ブロック)
            </label>
            {error && <Alert tone="error">{error}</Alert>}
            <div className="flex gap-3">
              <Button variant="outline" className="flex-1" onClick={onClose}>
                キャンセル
              </Button>
              <Button variant="danger" className="flex-1" onClick={submit} disabled={!target || submitting}>
                通報する
              </Button>
            </div>
          </div>
        )}
      </div>
    </Dialog>
  );
}
