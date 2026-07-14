'use client';

import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { CameraPreview } from '@/components/camera-preview';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input, Label } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';
import { createClient } from '@/lib/supabase/client';
import { DURATIONS, DEFAULT_DURATION, rpcErrorToMessage } from '@/lib/constants';
import { cn } from '@/lib/utils';

function PrejoinForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [topic, setTopic] = useState(params.get('topic') ?? '');
  const initialDuration = Number(params.get('duration'));
  const [duration, setDuration] = useState<number>(
    (DURATIONS as readonly number[]).includes(initialDuration) ? initialDuration : DEFAULT_DURATION
  );
  const [agreed, setAgreed] = useState(false);
  const [cameraReady, setCameraReady] = useState(false);
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState('');

  const join = async () => {
    setJoining(true);
    setError('');
    const supabase = createClient();
    const { data, error } = await supabase.rpc('join_room', {
      p_topic: topic.trim().slice(0, 100),
      p_duration: duration,
      p_is_trial: false,
    });
    if (error) {
      setError(rpcErrorToMessage(error));
      setJoining(false);
      return;
    }
    const result = data as { room_id: string; session_id: string };
    // 開始通知を応援者へ(プレミアムのみ・サーバー側で判定)
    void supabase
      .rpc('queue_start_notifications', { p_session_id: result.session_id })
      .then(() => fetch('/api/supporters/dispatch', { method: 'POST' }).catch(() => {}));
    router.push(`/room/${result.room_id}`);
  };

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold">入室の準備</h1>
        <p className="mt-1 text-sm text-brand-600 dark:text-brand-300">
          設定は3つだけ。準備ができたら入室しましょう。
        </p>
      </div>

      <div className="grid gap-6 sm:grid-cols-2">
        <div className="space-y-5">
          <div>
            <Label htmlFor="topic">今回勉強する内容</Label>
            <Input
              id="topic"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="例: 数学の過去問、英単語"
              maxLength={100}
            />
          </div>
          <div>
            <Label>集中時間</Label>
            <div className="grid grid-cols-4 gap-2" role="radiogroup" aria-label="集中時間">
              {DURATIONS.map((d) => (
                <button
                  key={d}
                  type="button"
                  role="radio"
                  aria-checked={duration === d}
                  onClick={() => setDuration(d)}
                  className={cn(
                    'h-12 rounded-xl border text-sm font-bold transition-colors',
                    duration === d
                      ? 'border-brand-600 bg-brand-600 text-white'
                      : 'border-brand-200 bg-white text-brand-700 hover:border-brand-400 dark:border-brand-700 dark:bg-brand-950 dark:text-brand-200'
                  )}
                >
                  {d}分{d === 25 && <span className="block text-[10px] font-normal">標準</span>}
                </button>
              ))}
            </div>
          </div>
          <Card className="text-sm leading-relaxed">
            <p className="mb-2 font-bold">自習室のルール</p>
            <ul className="list-disc space-y-1 pl-5 text-brand-700 dark:text-brand-200">
              <li>映像には強いぼかしが入ります(解除できません)</li>
              <li>マイクは使用しません(会話はできません)</li>
              <li>タイマーの一時停止はできません</li>
              <li>途中退出はできますが、完了コマにはなりません</li>
              <li>不適切な利用は通報の対象になります</li>
            </ul>
            <label className="mt-3 flex items-start gap-2">
              <input
                type="checkbox"
                checked={agreed}
                onChange={(e) => setAgreed(e.target.checked)}
                className="mt-0.5 h-4 w-4 rounded border-brand-300"
              />
              <span>ルールに同意して入室します</span>
            </label>
          </Card>
        </div>

        <div>
          <Label>カメラプレビュー(ぼかし確認)</Label>
          <CameraPreview onPipeline={(p) => setCameraReady(!!p)} />
        </div>
      </div>

      {error && <Alert tone="error">{error}</Alert>}

      <Button
        variant="lantern"
        size="xl"
        className="w-full"
        disabled={!agreed || !cameraReady || joining}
        onClick={join}
      >
        {joining ? '部屋を探しています…' : `${duration}分の自習を始める`}
      </Button>
      {!cameraReady && (
        <p className="text-center text-sm text-brand-500">
          カメラの準備ができると入室できます(うまくいかない場合は上の案内をご確認ください)
        </p>
      )}
    </div>
  );
}

export default function PrejoinPage() {
  return (
    <Suspense>
      <PrejoinForm />
    </Suspense>
  );
}
