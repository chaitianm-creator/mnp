/**
 * フルメッシュWebRTC接続マネージャ (MVP: 最大6名)。
 * シグナリングは Supabase Realtime の private チャネル (RLSで参加者のみ) を使用。
 *
 * 正式版でLiveKit等のSFUへ移行する場合はこのクラスを差し替える
 * (UI側は peers の Map と状態変化コールバックにのみ依存する)。
 */
import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';

export type PeerConnectionState = 'connecting' | 'connected' | 'disconnected';

export interface RemotePeer {
  userId: string;
  stream: MediaStream | null;
  state: PeerConnectionState;
}

interface SignalMessage {
  from: string;
  to: string;
  kind: 'offer' | 'answer' | 'ice';
  payload: unknown;
}

export interface MeshRoomOptions {
  supabase: SupabaseClient;
  roomId: string;
  userId: string;
  localStream: MediaStream;
  onPeersChanged: (peers: RemotePeer[]) => void;
  /** 同じユーザーが既に別タブで接続している場合 */
  onDuplicateConnection?: () => void;
}

function iceServers(): RTCIceServer[] {
  const servers: RTCIceServer[] = [];
  const stun = process.env.NEXT_PUBLIC_STUN_URLS;
  servers.push({ urls: (stun || 'stun:stun.l.google.com:19302').split(',') });
  const turnUrl = process.env.NEXT_PUBLIC_TURN_URL;
  if (turnUrl) {
    servers.push({
      urls: turnUrl,
      username: process.env.NEXT_PUBLIC_TURN_USERNAME || '',
      credential: process.env.NEXT_PUBLIC_TURN_CREDENTIAL || '',
    });
  }
  return servers;
}

export class MeshRoom {
  private channel: RealtimeChannel | null = null;
  private peers = new Map<string, { pc: RTCPeerConnection; info: RemotePeer }>();
  private closed = false;
  private connectionId = Math.random().toString(36).slice(2);
  private currentTrack: MediaStreamTrack | null;

  constructor(private opts: MeshRoomOptions) {
    this.currentTrack = opts.localStream.getVideoTracks()[0] ?? null;
  }

  async join(): Promise<void> {
    const { supabase, roomId, userId } = this.opts;

    this.channel = supabase.channel(`room:${roomId}`, {
      config: {
        private: true,
        presence: { key: userId },
        broadcast: { self: false, ack: false },
      },
    });

    this.channel.on('broadcast', { event: 'signal' }, ({ payload }) => {
      void this.handleSignal(payload as SignalMessage);
    });

    this.channel.on('presence', { event: 'sync' }, () => {
      this.syncPeers();
    });
    this.channel.on('presence', { event: 'leave' }, ({ key }) => {
      if (key !== userId) this.removePeer(key);
    });

    await new Promise<void>((resolve, reject) => {
      this.channel!.subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await this.channel!.track({ connectionId: this.connectionId, joinedAt: Date.now() });
          resolve();
        } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          reject(new Error(`realtime_${status}`));
        }
      });
    });
  }

  private syncPeers() {
    if (!this.channel || this.closed) return;
    const state = this.channel.presenceState<{ connectionId: string }>();

    // 多重入室検知: 自分のキーに別connectionIdの presence がある
    const mine = state[this.opts.userId] ?? [];
    if (mine.some((m) => m.connectionId !== this.connectionId)) {
      this.opts.onDuplicateConnection?.();
    }

    const memberIds = Object.keys(state).filter((k) => k !== this.opts.userId);
    for (const id of memberIds) {
      if (!this.peers.has(id)) {
        // グレア(offer衝突)防止: 辞書順で小さい側だけがofferを出す
        const initiator = this.opts.userId < id;
        this.createPeer(id, initiator);
      }
    }
    for (const id of Array.from(this.peers.keys())) {
      if (!memberIds.includes(id)) this.removePeer(id);
    }
    this.emit();
  }

  private createPeer(remoteId: string, initiator: boolean) {
    const pc = new RTCPeerConnection({ iceServers: iceServers() });
    const info: RemotePeer = { userId: remoteId, stream: null, state: 'connecting' };
    this.peers.set(remoteId, { pc, info });

    // 常にvideoトランシーバを1つ用意する。カメラOFF中はトラックなし(sendrecv)で確保し、
    // 再開時に replaceTrack だけで送信を再開できるようにする(再ネゴシエーション不要)。
    if (this.currentTrack) {
      pc.addTrack(this.currentTrack, this.opts.localStream);
    } else {
      pc.addTransceiver('video', { direction: 'sendrecv' });
    }

    pc.ontrack = (e) => {
      info.stream = e.streams[0] ?? new MediaStream([e.track]);
      this.emit();
    };
    pc.onicecandidate = (e) => {
      if (e.candidate) this.send(remoteId, 'ice', e.candidate.toJSON());
    };
    pc.onconnectionstatechange = () => {
      if (pc.connectionState === 'connected') info.state = 'connected';
      else if (['disconnected', 'failed', 'closed'].includes(pc.connectionState)) {
        info.state = 'disconnected';
        // 一時的な切断からの復帰: initiator側がICE restart
        if (pc.connectionState === 'failed' && initiator && !this.closed) {
          void this.restartIce(remoteId, pc);
        }
      } else info.state = 'connecting';
      this.emit();
    };

    if (initiator) {
      void (async () => {
        try {
          const offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          this.send(remoteId, 'offer', offer);
        } catch {
          /* peer removed mid-negotiation */
        }
      })();
    }
  }

  private async restartIce(remoteId: string, pc: RTCPeerConnection) {
    try {
      const offer = await pc.createOffer({ iceRestart: true });
      await pc.setLocalDescription(offer);
      this.send(remoteId, 'offer', offer);
    } catch {
      /* 復帰失敗時はpresence leaveで削除される */
    }
  }

  private async handleSignal(msg: SignalMessage) {
    if (this.closed || msg.to !== this.opts.userId) return;
    let entry = this.peers.get(msg.from);
    if (!entry && msg.kind === 'offer') {
      this.createPeer(msg.from, false);
      entry = this.peers.get(msg.from);
    }
    if (!entry) return;
    const { pc } = entry;

    try {
      if (msg.kind === 'offer') {
        await pc.setRemoteDescription(msg.payload as RTCSessionDescriptionInit);
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        this.send(msg.from, 'answer', answer);
      } else if (msg.kind === 'answer') {
        if (pc.signalingState === 'have-local-offer') {
          await pc.setRemoteDescription(msg.payload as RTCSessionDescriptionInit);
        }
      } else if (msg.kind === 'ice') {
        await pc.addIceCandidate(msg.payload as RTCIceCandidateInit);
      }
    } catch {
      /* シグナリング競合等は次のsync/restartで回復 */
    }
  }

  private send(to: string, kind: SignalMessage['kind'], payload: unknown) {
    void this.channel?.send({
      type: 'broadcast',
      event: 'signal',
      payload: { from: this.opts.userId, to, kind, payload } satisfies SignalMessage,
    });
  }

  /** カメラON/OFF等の状態を同室へブロードキャスト */
  broadcastState(state: Record<string, unknown>) {
    void this.channel?.send({ type: 'broadcast', event: 'member_state', payload: { from: this.opts.userId, ...state } });
  }

  onMemberState(handler: (payload: Record<string, unknown> & { from: string }) => void) {
    this.channel?.on('broadcast', { event: 'member_state' }, ({ payload }) =>
      handler(payload as Record<string, unknown> & { from: string })
    );
  }

  /**
   * カメラOFF/ONの切替: 全ピアの送信トラックを差し替える。
   * nullで送信停止(受信側はプレースホルダー表示)、再開時は新しいぼかし済みトラックを渡す。
   */
  async replaceLocalTrack(track: MediaStreamTrack | null) {
    this.currentTrack = track;
    for (const { pc } of this.peers.values()) {
      // 各pcはvideoトランシーバを1つだけ持つ構成
      const transceiver = pc.getTransceivers()[0];
      if (!transceiver) continue;
      try {
        await transceiver.sender.replaceTrack(track);
      } catch {
        /* closed済みpc等は無視 */
      }
    }
  }

  private removePeer(id: string) {
    const entry = this.peers.get(id);
    if (entry) {
      entry.pc.close();
      this.peers.delete(id);
      this.emit();
    }
  }

  private emit() {
    this.opts.onPeersChanged(Array.from(this.peers.values()).map((p) => ({ ...p.info })));
  }

  leave() {
    this.closed = true;
    for (const { pc } of this.peers.values()) pc.close();
    this.peers.clear();
    if (this.channel) {
      void this.channel.untrack();
      void this.opts.supabase.removeChannel(this.channel);
      this.channel = null;
    }
  }
}
