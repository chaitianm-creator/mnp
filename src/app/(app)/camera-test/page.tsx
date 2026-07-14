'use client';

import Link from 'next/link';
import { CameraPreview } from '@/components/camera-preview';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';

export default function CameraTestPage() {
  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold">カメラテスト</h1>
        <p className="mt-1 text-sm text-brand-600 dark:text-brand-300">
          入室前に、ぼかしの見え方とカメラの位置を確認できます。
          表示されている映像が、そのまま他の参加者に見える映像です。
        </p>
      </div>
      <CameraPreview />
      <Card className="text-sm leading-relaxed text-brand-700 dark:text-brand-200">
        <ul className="list-disc space-y-1 pl-5">
          <li>顔や部屋が判別できない強さのぼかしが、送信前に必ず適用されます</li>
          <li>ぼかしを解除する設定はありません</li>
          <li>マイクは使用しないため、音声が送られることはありません</li>
          <li>手元やノートがうっすら見える角度にすると「勉強中」の気配が伝わります</li>
        </ul>
      </Card>
      <div className="flex gap-3">
        <Link href="/prejoin" className="flex-1">
          <Button variant="lantern" size="lg" className="w-full">
            このまま入室設定へ
          </Button>
        </Link>
        <Link href="/home" className="flex-1">
          <Button variant="outline" size="lg" className="w-full">
            ホームへ戻る
          </Button>
        </Link>
      </div>
    </div>
  );
}
