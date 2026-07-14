import Link from 'next/link';
import { TomoshibiIcon } from '@/components/tomoshibi';
import { Button } from '@/components/ui/button';

export default function NotFound() {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-4 px-4 text-center">
      <TomoshibiIcon className="h-16 w-16" />
      <h1 className="text-3xl font-bold">ページが見つかりません</h1>
      <p className="text-brand-600 dark:text-brand-300">
        お探しのページは移動したか、削除された可能性があります。
      </p>
      <Link href="/home">
        <Button size="lg">ホームへ戻る</Button>
      </Link>
    </div>
  );
}
