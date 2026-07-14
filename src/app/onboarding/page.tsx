'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Camera, MicOff, ShieldCheck, Sparkles } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';
import { CameraPreview } from '@/components/camera-preview';
import { TomoshibiMessage, Logo } from '@/components/tomoshibi';
import { STUDY_PURPOSES, rpcErrorToMessage } from '@/lib/constants';
import { Select } from '@/components/ui/input';

const TOTAL_STEPS = 6;

export default function OnboardingPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [step, setStep] = useState(0);
  const [displayName, setDisplayName] = useState('');
  const [purpose, setPurpose] = useState('habit');
  const [topic, setTopic] = useState('');
  const [nameError, setNameError] = useState('');
  const [cameraOk, setCameraOk] = useState(false);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void supabase
      .from('profiles')
      .select('display_name, onboarding_completed_at')
      .single()
      .then(({ data }) => {
        if (data?.onboarding_completed_at) {
          router.replace('/home');
          return;
        }
        if (data?.display_name) setDisplayName(data.display_name);
      });
  }, [supabase, router]);

  const saveProfile = async (): Promise<boolean> => {
    const name = displayName.trim();
    if (!name || name.length > 30) {
      setNameError('表示名は1〜30文字で入力してください');
      return false;
    }
    setNameError('');
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return false;
    const { error } = await supabase
      .from('profiles')
      .update({ display_name: name, study_purpose: purpose })
      .eq('id', user.id);
    return !error;
  };

  const startTrial = async () => {
    setBusy(true);
    setError('');
    const { data, error } = await supabase.rpc('join_room', {
      p_topic: topic.trim().slice(0, 100) || '体験セッション',
      p_duration: 5,
      p_is_trial: true,
    });
    if (error || !data) {
      setError(rpcErrorToMessage(error));
      setBusy(false);
      return;
    }
    router.push(`/room/${(data as { room_id: string }).room_id}`);
  };

  const finishWithoutTrial = async () => {
    setBusy(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      await supabase
        .from('profiles')
        .update({ onboarding_completed_at: new Date().toISOString() })
        .eq('id', user.id);
    }
    router.push('/home');
    router.refresh();
  };

  const steps: React.ReactNode[] = [
    // 1. サービス説明
    <div key="intro" className="space-y-5 text-center">
      <Logo className="justify-center" />
      <h1 className="text-2xl font-bold">ようこそ、MokuTomoへ</h1>
      <p className="leading-relaxed text-brand-700 dark:text-brand-200">
        MokuTomoは「やる気に頼らない」オンライン自習室です。
        ぼかしの入った映像ごしに、同じ時間に勉強する仲間とゆるくつながることで、
        自然と机に向かえるようになります。
      </p>
      <TomoshibiMessage
        glow
        message="はじめまして、案内役の「ともしび」です。3分だけ、大事な説明をさせてくださいね。"
      />
      <Button size="lg" className="w-full" onClick={() => setStep(1)}>
        すすむ
      </Button>
    </div>,

    // 2-4. カメラ・ぼかし・マイクの説明
    <div key="camera-explain" className="space-y-5">
      <h1 className="text-xl font-bold">カメラについての大事な約束</h1>
      <ul className="space-y-4">
        <li className="flex gap-3">
          <Camera className="mt-0.5 h-6 w-6 shrink-0 text-brand-500" />
          <div>
            <p className="font-bold">カメラを使います</p>
            <p className="text-sm text-brand-600 dark:text-brand-300">
              「誰かと一緒に勉強している」気配を共有するために、カメラの映像を使います。
            </p>
          </div>
        </li>
        <li className="flex gap-3">
          <ShieldCheck className="mt-0.5 h-6 w-6 shrink-0 text-brand-500" />
          <div>
            <p className="font-bold">映像には強いぼかしが入ります</p>
            <p className="text-sm text-brand-600 dark:text-brand-300">
              顔や部屋が判別できない強さのぼかしが、送信される前にあなたの端末の中で必ずかかります。
              誰も(運営も)ぼかしを外せません。録画もされません。
            </p>
          </div>
        </li>
        <li className="flex gap-3">
          <MicOff className="mt-0.5 h-6 w-6 shrink-0 text-brand-500" />
          <div>
            <p className="font-bold">マイクは使いません</p>
            <p className="text-sm text-brand-600 dark:text-brand-300">
              音声はそもそも取得しない設計です。話し声や生活音が聞かれることはありません。
            </p>
          </div>
        </li>
      </ul>
      <Button size="lg" className="w-full" onClick={() => setStep(2)}>
        わかりました
      </Button>
    </div>,

    // 5-6. 権限確認 + カメラ位置確認
    <div key="camera-check" className="space-y-5">
      <h1 className="text-xl font-bold">カメラを確認しましょう</h1>
      <p className="text-sm text-brand-600 dark:text-brand-300">
        「許可」を押すとカメラが起動します。表示されるのは、実際に送信されるぼかし済みの映像です。
        手元やノートがうっすら映る位置がおすすめです。
      </p>
      <CameraPreview onPipeline={(p) => setCameraOk(!!p)} />
      <div className="flex gap-3">
        <Button variant="outline" size="lg" className="flex-1" onClick={() => setStep(3)}>
          あとで設定する
        </Button>
        <Button size="lg" className="flex-1" disabled={!cameraOk} onClick={() => setStep(3)}>
          確認できた
        </Button>
      </div>
    </div>,

    // 7. 表示名
    <div key="name" className="space-y-5">
      <h1 className="text-xl font-bold">表示名を決めましょう</h1>
      <p className="text-sm text-brand-600 dark:text-brand-300">
        自習室で他の参加者に表示される名前です。本名でなくてかまいません。
      </p>
      <div>
        <Label htmlFor="displayName">表示名</Label>
        <Input
          id="displayName"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
          maxLength={30}
        />
        <FieldError message={nameError} />
      </div>
      <div>
        <Label htmlFor="purpose">学習の目的</Label>
        <Select id="purpose" value={purpose} onChange={(e) => setPurpose(e.target.value)}>
          {STUDY_PURPOSES.map((p) => (
            <option key={p.value} value={p.value}>
              {p.label}
            </option>
          ))}
        </Select>
      </div>
      <Button
        size="lg"
        className="w-full"
        onClick={async () => {
          if (await saveProfile()) setStep(4);
        }}
      >
        すすむ
      </Button>
    </div>,

    // 8. 今日の学習内容
    <div key="topic" className="space-y-5">
      <h1 className="text-xl font-bold">今日は何を勉強しますか?</h1>
      <p className="text-sm text-brand-600 dark:text-brand-300">
        ひとことで大丈夫です。自習室であなたの名前と一緒に表示されます。
      </p>
      <Input
        value={topic}
        onChange={(e) => setTopic(e.target.value)}
        placeholder="例: 英単語、数学の宿題、資格の勉強"
        maxLength={100}
      />
      <Button size="lg" className="w-full" onClick={() => setStep(5)}>
        すすむ
      </Button>
    </div>,

    // 9. 体験セッション
    <div key="trial" className="space-y-5 text-center">
      <Sparkles className="mx-auto h-10 w-10 text-lantern-400" aria-hidden />
      <h1 className="text-xl font-bold">5分間の体験セッション</h1>
      <p className="text-sm leading-relaxed text-brand-600 dark:text-brand-300">
        最後に、5分間だけ実際の自習室を体験してみましょう。
        タイマーが終わるまで、{topic.trim() || '好きなこと'}に取り組んでみてください。
      </p>
      <TomoshibiMessage glow message="たった5分でも、始められたことが大きな一歩です。" />
      {error && <Alert tone="error">{error}</Alert>}
      <Button variant="lantern" size="xl" className="w-full" onClick={startTrial} disabled={busy}>
        {busy ? '準備中…' : '体験セッションを始める'}
      </Button>
      <Button variant="ghost" className="w-full" onClick={finishWithoutTrial} disabled={busy}>
        スキップしてホームへ
      </Button>
    </div>,
  ];

  return (
    <div className="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-4 py-10">
      <div className="mb-6 flex gap-1.5" aria-label={`ステップ ${step + 1} / ${TOTAL_STEPS}`}>
        {Array.from({ length: TOTAL_STEPS }).map((_, i) => (
          <div
            key={i}
            className={`h-1.5 flex-1 rounded-full ${i <= step ? 'bg-lantern-400' : 'bg-brand-100 dark:bg-brand-800'}`}
          />
        ))}
      </div>
      <div className="rounded-2xl border border-brand-100 bg-white p-6 shadow-sm dark:border-brand-800 dark:bg-brand-900/60">
        {steps[step]}
      </div>
      {step > 0 && step < steps.length && (
        <button
          className="mt-4 text-sm text-brand-500 underline"
          onClick={() => setStep((s) => Math.max(0, s - 1))}
        >
          ひとつ戻る
        </button>
      )}
    </div>
  );
}
