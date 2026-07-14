'use client';

import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { loginSchema } from '@/lib/validation';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';

type FormValues = z.input<typeof loginSchema>;

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [error, setError] = useState('');
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (values: FormValues) => {
    setError('');
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({
      email: values.email,
      password: values.password,
    });
    if (error) {
      setError('メールアドレスまたはパスワードが正しくありません。');
      return;
    }
    // 利用停止チェック(profiles.statusはRLSで本人が読める)
    const { data: profile } = await supabase
      .from('profiles')
      .select('status, onboarding_completed_at')
      .single();
    if (profile?.status === 'suspended') {
      await supabase.auth.signOut();
      setError('このアカウントは現在利用停止中です。お問い合わせよりご連絡ください。');
      return;
    }
    const next = searchParams.get('next');
    if (!profile?.onboarding_completed_at) {
      router.push('/onboarding');
    } else {
      router.push(next && next.startsWith('/') ? next : '/home');
    }
    router.refresh();
  };

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold">ログイン</h1>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <div>
          <Label htmlFor="email">メールアドレス</Label>
          <Input id="email" type="email" {...register('email')} autoComplete="email" />
          <FieldError message={errors.email?.message} />
        </div>
        <div>
          <Label htmlFor="password">パスワード</Label>
          <Input id="password" type="password" {...register('password')} autoComplete="current-password" />
          <FieldError message={errors.password?.message} />
        </div>
        {error && <Alert tone="error">{error}</Alert>}
        <Button type="submit" size="lg" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? 'ログイン中…' : 'ログイン'}
        </Button>
      </form>
      <div className="mt-6 space-y-2 text-center text-sm">
        <p>
          <Link href="/auth/reset-password" className="text-brand-600 underline dark:text-brand-300">
            パスワードをお忘れの方
          </Link>
        </p>
        <p>
          はじめての方は{' '}
          <Link href="/auth/register" className="font-medium text-brand-600 underline dark:text-brand-300">
            新規登録
          </Link>
        </p>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
