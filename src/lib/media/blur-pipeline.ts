/**
 * 送信映像への強制ぼかしパイプライン。
 *
 * カメラの生映像 → 非表示<video> → <canvas>に縮小+強blur描画 → canvas.captureStream()
 * WebRTCへは canvas 由来のトラックだけを渡すため、
 * 「CSSで隠しているだけで送信映像は鮮明」という状態が構造的に発生しない。
 *
 * - 音声は一切取得しない (getUserMedia に audio を渡さない)
 * - requestAnimationFrame はバックグラウンドで停止するため setInterval で描画する
 * - MediaStreamTrackProcessor/WebCodecs は対応ブラウザが限られるため、
 *   互換性の高い Canvas 2D 方式を採用 (docs/04_architecture.md 参照)
 */

export const OUTPUT_WIDTH = 320;
export const OUTPUT_HEIGHT = 240;
export const OUTPUT_FPS = 15;
/** 縮小(1/2〜1/4)との併用で顔・背景が判別できない強度 */
export const BLUR_PX = 12;

export interface BlurPipeline {
  /** ぼかし済みの送信用ストリーム (videoのみ・audioなし) */
  stream: MediaStream;
  /** 使用中のカメラdeviceId */
  deviceId: string | null;
  stop: () => void;
}

export class CameraPermissionError extends Error {
  constructor(public reason: 'denied' | 'notfound' | 'busy' | 'unknown') {
    super(`camera_${reason}`);
  }
}

export async function getCameraStream(deviceId?: string): Promise<MediaStream> {
  if (typeof navigator === 'undefined' || !navigator.mediaDevices?.getUserMedia) {
    throw new CameraPermissionError('unknown');
  }
  try {
    return await navigator.mediaDevices.getUserMedia({
      video: {
        deviceId: deviceId ? { exact: deviceId } : undefined,
        width: { ideal: 640 },
        height: { ideal: 480 },
        frameRate: { ideal: 15, max: 24 },
      },
      audio: false, // マイクは仕様として一切使用しない
    });
  } catch (e) {
    const name = (e as DOMException)?.name ?? '';
    if (name === 'NotAllowedError' || name === 'SecurityError') {
      throw new CameraPermissionError('denied');
    }
    if (name === 'NotFoundError' || name === 'OverconstrainedError') {
      throw new CameraPermissionError('notfound');
    }
    if (name === 'NotReadableError' || name === 'AbortError') {
      throw new CameraPermissionError('busy');
    }
    throw new CameraPermissionError('unknown');
  }
}

export async function listCameras(): Promise<MediaDeviceInfo[]> {
  const devices = await navigator.mediaDevices.enumerateDevices();
  return devices.filter((d) => d.kind === 'videoinput');
}

export async function createBlurPipeline(deviceId?: string): Promise<BlurPipeline> {
  const raw = await getCameraStream(deviceId);

  const video = document.createElement('video');
  video.muted = true;
  video.playsInline = true;
  video.srcObject = raw;
  await video.play().catch(() => {
    /* Safariでユーザー操作前にplayが拒否された場合もloadeddataで描画される */
  });

  const canvas = document.createElement('canvas');
  canvas.width = OUTPUT_WIDTH;
  canvas.height = OUTPUT_HEIGHT;
  const ctx = canvas.getContext('2d')!;

  // 【重要】ぼかしの主方式は「極小キャンバスへ縮小→拡大」。
  // ctx.filter='blur()' はSafari 17以前のCanvas 2Dで未実装(無視される)ため、
  // filterだけに頼ると旧Safariで鮮明な映像が送信されてしまう。
  // 縮小→拡大は全ブラウザで物理的に情報を失わせるため、確実に判別不能になる。
  // 対応ブラウザでは ctx.filter を「追加の」平滑化として併用する。
  const tiny = document.createElement('canvas');
  tiny.width = 32; // 320x240を32x24へ縮小 = 1/10。顔・文字は復元不能
  tiny.height = 24;
  const tinyCtx = tiny.getContext('2d')!;
  const filterSupported = typeof ctx.filter === 'string';

  // 初期フレーム(黒)を描いてからキャプチャ開始
  ctx.fillStyle = '#111';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const draw = () => {
    if (video.readyState < 2) return;
    // 1段目: 極小へ縮小 (情報の破壊 = ぼかしの本体)
    tinyCtx.drawImage(video, 0, 0, tiny.width, tiny.height);
    // 2段目: 平滑化しながら拡大 + 対応ブラウザではblurフィルタを追加適用
    ctx.save();
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    if (filterSupported) {
      ctx.filter = `blur(${BLUR_PX}px)`;
    }
    // ぼかしのエッジ(透明縁)が出ないよう少し拡大して描画する
    const overdraw = BLUR_PX;
    ctx.drawImage(
      tiny,
      -overdraw,
      -overdraw,
      canvas.width + overdraw * 2,
      canvas.height + overdraw * 2
    );
    ctx.restore();
  };

  const interval = window.setInterval(draw, Math.round(1000 / OUTPUT_FPS));
  const stream = canvas.captureStream(OUTPUT_FPS);

  const actualDeviceId = raw.getVideoTracks()[0]?.getSettings().deviceId ?? null;

  return {
    stream,
    deviceId: actualDeviceId,
    stop: () => {
      window.clearInterval(interval);
      stream.getTracks().forEach((t) => t.stop());
      raw.getTracks().forEach((t) => t.stop());
      video.srcObject = null;
    },
  };
}

/** カメラ許可エラーのユーザー向け説明 (ブラウザ別の設定方法つき) */
export function cameraErrorHelp(reason: CameraPermissionError['reason']): {
  title: string;
  steps: string[];
} {
  switch (reason) {
    case 'denied':
      return {
        title: 'カメラの利用が許可されていません',
        steps: [
          'Chrome / Edge: アドレスバー左の鍵(またはカメラ)アイコン → 「カメラ」を「許可」に変更 → ページを再読み込み',
          'Safari (Mac): メニューバー「Safari」→「設定」→「Webサイト」→「カメラ」でこのサイトを「許可」に変更',
          'Safari (iPhone/iPad): 「設定」アプリ →「アプリ」→「Safari」→「カメラ」を「確認」または「許可」に変更',
          'Firefox: アドレスバー左のカメラアイコン → ブロックを解除 → ページを再読み込み',
          'Android Chrome: アドレスバー右の「︙」→「設定」→「サイトの設定」→「カメラ」で許可',
        ],
      };
    case 'notfound':
      return {
        title: 'カメラが見つかりません',
        steps: [
          'カメラが接続されているか確認してください',
          '外付けカメラの場合は接続し直してからページを再読み込みしてください',
        ],
      };
    case 'busy':
      return {
        title: 'カメラを起動できません',
        steps: [
          '他のアプリ(Zoom、Teamsなど)がカメラを使用中の場合は終了してください',
          'ブラウザの他のタブでカメラを使用していないか確認してください',
          'ページを再読み込みしてください',
        ],
      };
    default:
      return {
        title: 'カメラの起動に失敗しました',
        steps: [
          'お使いのブラウザが最新か確認してください(推奨: Chrome / Edge / Safari / Firefoxの最新版)',
          'ページを再読み込みしてもう一度お試しください',
        ],
      };
  }
}
