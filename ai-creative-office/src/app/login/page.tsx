'use client';

// モックログイン画面
// Phase 1では認証は行わず、Supabase Auth接続時にこの画面を差し替える
import { Button } from '@/components/ui';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('ceo@example.com');
  const [password, setPassword] = useState('demo');

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-900 via-brand-700 to-accent-600 px-4">
      <div className="w-full max-w-sm rounded-2xl bg-white p-8 shadow-panel">
        <p className="bg-gradient-to-r from-brand-600 to-accent-600 bg-clip-text text-center text-xl font-extrabold text-transparent">
          AI CREATIVE OFFICE
        </p>
        <p className="mt-1 text-center text-xs text-slate-500">
          AI社員と一緒に働く、次世代のWeb制作会社。
        </p>
        <form
          className="mt-6 space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            router.push('/dashboard');
          }}
        >
          <div>
            <label className="text-xs font-medium text-slate-600">メールアドレス</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-brand-400"
            />
          </div>
          <div>
            <label className="text-xs font-medium text-slate-600">パスワード</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-brand-400"
            />
          </div>
          <Button type="submit" className="w-full py-2">
            出社する
          </Button>
        </form>
        <p className="mt-4 text-center text-[11px] text-slate-400">
          デモ版のためそのままログインできます(Supabase Auth接続予定)
        </p>
      </div>
    </div>
  );
}
