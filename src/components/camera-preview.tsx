'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { RefreshCw, VideoOff } from 'lucide-react';
import {
  createBlurPipeline,
  listCameras,
  cameraErrorHelp,
  CameraPermissionError,
  type BlurPipeline,
} from '@/lib/media/blur-pipeline';
import { Select, Label } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';
import { Button } from '@/components/ui/button';

/**
 * ぼかし済みカメラプレビュー。
 * ここで表示されるのは「実際に他の参加者へ送信されるのと同じ」加工済み映像。
 */
export function CameraPreview({
  onPipeline,
  showDeviceSelect = true,
  className,
}: {
  onPipeline?: (p: BlurPipeline | null) => void;
  showDeviceSelect?: boolean;
  className?: string;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const pipelineRef = useRef<BlurPipeline | null>(null);
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const [deviceId, setDeviceId] = useState<string>('');
  const [error, setError] = useState<CameraPermissionError | null>(null);
  const [loading, setLoading] = useState(true);

  const start = useCallback(
    async (id?: string) => {
      setLoading(true);
      setError(null);
      pipelineRef.current?.stop();
      pipelineRef.current = null;
      onPipeline?.(null);
      try {
        const pipeline = await createBlurPipeline(id || undefined);
        pipelineRef.current = pipeline;
        if (videoRef.current) {
          videoRef.current.srcObject = pipeline.stream;
          await videoRef.current.play().catch(() => {});
        }
        setDevices(await listCameras());
        if (pipeline.deviceId) setDeviceId(pipeline.deviceId);
        onPipeline?.(pipeline);
      } catch (e) {
        setError(e instanceof CameraPermissionError ? e : new CameraPermissionError('unknown'));
      } finally {
        setLoading(false);
      }
    },
    [onPipeline]
  );

  useEffect(() => {
    void start();
    return () => {
      pipelineRef.current?.stop();
      pipelineRef.current = null;
      onPipeline?.(null);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const help = error ? cameraErrorHelp(error.reason) : null;

  return (
    <div className={className}>
      <div className="relative aspect-[4/3] w-full overflow-hidden rounded-2xl bg-brand-950">
        {/* 送信されるのと同一のぼかし済み映像 */}
        <video
          ref={videoRef}
          muted
          playsInline
          className="h-full w-full object-cover"
          aria-label="ぼかし済みカメラプレビュー"
        />
        {loading && (
          <p className="absolute inset-0 flex items-center justify-center text-sm text-white">
            カメラを起動しています…
          </p>
        )}
        {error && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 p-4 text-white">
            <VideoOff className="h-8 w-8" />
            <p className="text-sm font-medium">{help?.title}</p>
          </div>
        )}
        <span className="absolute bottom-2 right-2 rounded-full bg-black/60 px-2.5 py-1 text-xs text-white">
          この見え方のまま送信されます
        </span>
      </div>

      {help && (
        <Alert tone="warning" className="mt-3">
          <p className="mb-2 font-bold">{help.title}</p>
          <ul className="list-disc space-y-1 pl-5">
            {help.steps.map((s) => (
              <li key={s}>{s}</li>
            ))}
          </ul>
          <Button variant="outline" size="sm" className="mt-3" onClick={() => start(deviceId)}>
            <RefreshCw className="h-4 w-4" /> もう一度試す
          </Button>
        </Alert>
      )}

      {showDeviceSelect && devices.length > 1 && !error && (
        <div className="mt-3">
          <Label htmlFor="camera-select">カメラを選択</Label>
          <Select
            id="camera-select"
            value={deviceId}
            onChange={(e) => {
              setDeviceId(e.target.value);
              void start(e.target.value);
            }}
          >
            {devices.map((d, i) => (
              <option key={d.deviceId} value={d.deviceId}>
                {d.label || `カメラ ${i + 1}`}
              </option>
            ))}
          </Select>
        </div>
      )}
    </div>
  );
}
