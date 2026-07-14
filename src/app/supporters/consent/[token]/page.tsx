'use client';

import { useParams } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Logo, TomoshibiMessage } from '@/components/tomoshibi';
import { Button } from '@/components/ui/button';
import { Alert } from '@/components/ui/misc';
import { rpcErrorToMessage } from '@/lib/constants';

/** 応援者の同意ページ (未ログインで開ける) */
export default function SupporterConsentPage() {
  const params = useParams<{ token: string }>();
  const supabase = useMemo(() => createClient(), []);
  const [state, setState] = useState<'confirm' | 'done' | 'error'>('confirm');
  const [userName, setUserName] = useState('');
  const [error, setError] = useState('');
  const busyRef = useRef(false);

  const accept = async () => {
    if (busyRef.current) return;
    busyRef.current = true;
    const { data, error } = await supabase.rpc('accept_supporter_invite', {
      p_token: params.token,
    });
    if (error) {
      setError(rpcErrorToMessage(error));
      setState('error');
      return;
    }
    setUserName((data as { user_display_name: string }).user_display_name ?? '');
    setState('done');
  };

  return (
    <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-6 px-4 py-10 text-center">
      <Logo />
      {state === 'confirm' && (
        <>
          <h1 className="text-xl font-bold">応援・見守りへの同意</h1>
          <p className="text-sm leading-relaxed text-brand-700 dark:text-brand-200">
            オンライン自習室MokuTomoの利用者が、学習状況(開始・完了・週間レポート)を
            あなたにメールで共有したいと希望しています。
            <strong>映像が共有されることはありません。</strong>
            同意すると通知メールが届くようになります。配信はいつでも本人側から停止できます。
          </p>
          <Button variant="lantern" size="lg" className="w-full" onClick={accept}>
            同意して応援する
          </Button>
          <p className="text-xs text-brand-500">
            心当たりがない場合は、このページを閉じてください。何も起こりません。
          </p>
        </>
      )}
      {state === 'done' && (
        <>
          <TomoshibiMessage glow message={`ありがとうございます! ${userName}さんの応援がはじまりました。`} />
          <p className="text-sm text-brand-600 dark:text-brand-300">
            このページは閉じていただいて大丈夫です。
          </p>
        </>
      )}
      {state === 'error' && <Alert tone="error">{error}</Alert>}
    </div>
  );
}
