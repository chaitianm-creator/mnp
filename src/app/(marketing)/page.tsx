import Link from 'next/link';
import { Camera, MicOff, Timer, Users, CalendarClock, Flame } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { TomoshibiMessage } from '@/components/tomoshibi';
import { APP_TAGLINE } from '@/lib/constants';

const features = [
  {
    icon: Users,
    title: '誰かと一緒に、黙々と',
    body: '最大6人の小さな自習室。会話はありません。「みんな勉強してる」気配だけを共有します。',
  },
  {
    icon: Camera,
    title: '強いぼかしで安心',
    body: '映像は送信する前に端末の中で強くぼかされます。顔も部屋も判別できません。解除もできません。',
  },
  {
    icon: MicOff,
    title: 'マイクは使いません',
    body: '音声はそもそも取得しない設計。生活音が漏れる心配はありません。',
  },
  {
    icon: Timer,
    title: '25分の集中タイマー',
    body: '全員で同じタイマーを共有。開始したら一時停止はなし。終わったらしっかり休憩。',
  },
  {
    icon: Flame,
    title: '記録が続ける力になる',
    body: '集中時間・連続日数・バッジを自動で記録。頑張りが目に見えて残ります。',
  },
  {
    icon: CalendarClock,
    title: '予約が背中を押す',
    body: '「明日の朝7時に勉強する」と予約すれば、始める強制力が生まれます。',
  },
];

export default function LandingPage() {
  return (
    <div>
      <section className="mx-auto max-w-5xl px-4 pb-16 pt-14 text-center sm:pt-24">
        <h1 className="text-balance text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">
          {APP_TAGLINE}
        </h1>
        <p className="mx-auto mt-5 max-w-2xl text-balance text-lg text-brand-700 dark:text-brand-200">
          MokuTomoは、やる気に頼らないオンライン自習室。ボタンを押すだけで、
          ぼかしの入った映像ごしに「一緒に勉強する誰か」とつながり、自然と机に向かえます。
        </p>
        <div className="mt-8 flex flex-col items-center gap-3">
          <Link href="/auth/register">
            <Button variant="lantern" size="xl">
              無料で自習をはじめる
            </Button>
          </Link>
          <p className="text-sm text-brand-500 dark:text-brand-300">
            登録は1分。クレジットカードは不要です。
          </p>
        </div>
        <div className="mx-auto mt-10 max-w-md">
          <TomoshibiMessage glow message="こんばんは。今日も一緒に、少しだけ机に向かいませんか?" />
        </div>
      </section>

      <section className="bg-white py-16 dark:bg-brand-900/40">
        <div className="mx-auto grid max-w-5xl gap-5 px-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <Card key={f.title}>
              <f.icon aria-hidden className="mb-3 h-7 w-7 text-brand-500" />
              <h2 className="mb-1.5 font-bold">{f.title}</h2>
              <p className="text-sm leading-relaxed text-brand-600 dark:text-brand-300">{f.body}</p>
            </Card>
          ))}
        </div>
      </section>

      <section className="mx-auto max-w-3xl px-4 py-16 text-center">
        <h2 className="text-2xl font-bold">使い方は3ステップ</h2>
        <ol className="mt-8 space-y-4 text-left">
          {[
            '「今すぐ入室」を押す(勉強する内容と時間を選ぶだけ)',
            'ぼかしカメラで入室。同じ時間を選んだ仲間と集中タイム',
            '終わったら記録が自動で残る。あとは続けるだけ',
          ].map((step, i) => (
            <li key={step} className="flex items-start gap-3 rounded-xl bg-white p-4 shadow-sm dark:bg-brand-900/60">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-lantern-400 text-sm font-bold text-brand-950">
                {i + 1}
              </span>
              <span className="pt-0.5">{step}</span>
            </li>
          ))}
        </ol>
        <div className="mt-10">
          <Link href="/auth/register">
            <Button variant="primary" size="lg">
              今日から始める
            </Button>
          </Link>
        </div>
      </section>
    </div>
  );
}
