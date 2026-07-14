'use client';

import { TomoshibiIcon } from '@/components/tomoshibi';
import { Button } from '@/components/ui/button';

export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-4 px-4 text-center">
      <TomoshibiIcon className="h-16 w-16" />
      <h1 className="text-2xl font-bold">エラーが発生しました</h1>
      <p className="text-brand-600 dark:text-brand-300">
        ご迷惑をおかけしています。時間をおいてもう一度お試しください。
      </p>
      <div className="flex gap-3">
        <Button onClick={reset}>もう一度試す</Button>
        <Button variant="outline" onClick={() => (location.href = '/home')}>
          ホームへ戻る
        </Button>
      </div>
    </div>
  );
}
