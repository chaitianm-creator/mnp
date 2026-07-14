'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { registerSchema } from '@/lib/validation';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';

type FormValues = z.input<typeof registerSchema>;

export default function RegisterPage() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [emailSent, setEmailSent] = useState(false);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(registerSchema) });

  const onSubmit = async (values: FormValues) => {
    setError('');
    const supabase = createClient();
    const { data, error } = await supabase.auth.signUp({
      email: values.email,
      password: values.password,
      options: {
        data: { display_name: values.displayName, terms_accepted: 'true' },
        emailRedirectTo: `${location.origin}/auth/callback?next=/onboarding`,
      },
    });
    if (error) {
      setError(
        error.message.includes('already registered')
          ? 'このメールアドレスは既に登録されています。'
          : '登録に失敗しました。時間をおいてお試しください。'
      );
      return;
    }
    // メール確認が無効な環境(ローカル)ではそのままセッションが作られる
    if (data.session) {
      router.push('/onboarding');
      router.refresh();
    } else {
      setEmailSent(true);
    }
  };

  if (emailSent) {
    return (
      <Alert tone="success">
        確認メールを送信しました。メール内のリンクをクリックして登録を完了してください。
      </Alert>
    );
  }

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold">新規登録</h1>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <div>
          <Label htmlFor="displayName">表示名(あとで変更できます)</Label>
          <Input id="displayName" {...register('displayName')} autoComplete="nickname" />
          <FieldError message={errors.displayName?.message} />
        </div>
        <div>
          <Label htmlFor="email">メールアドレス</Label>
          <Input id="email" type="email" {...register('email')} autoComplete="email" />
          <FieldError message={errors.email?.message} />
        </div>
        <div>
          <Label htmlFor="password">パスワード(8文字以上)</Label>
          <Input id="password" type="password" {...register('password')} autoComplete="new-password" />
          <FieldError message={errors.password?.message} />
        </div>
        <div className="flex items-start gap-2">
          <input
            id="terms"
            type="checkbox"
            className="mt-1 h-4 w-4 rounded border-brand-300"
            {...register('termsAccepted')}
          />
          <label htmlFor="terms" className="text-sm">
            <Link href="/terms" className="underline" target="_blank">
              利用規約
            </Link>
            と
            <Link href="/privacy" className="underline" target="_blank">
              プライバシーポリシー
            </Link>
            に同意します
          </label>
        </div>
        <FieldError message={errors.termsAccepted?.message} />
        {error && <Alert tone="error">{error}</Alert>}
        <Button type="submit" size="lg" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? '登録中…' : '登録してはじめる'}
        </Button>
      </form>
      <p className="mt-6 text-center text-sm">
        アカウントをお持ちの方は{' '}
        <Link href="/auth/login" className="font-medium text-brand-600 underline dark:text-brand-300">
          ログイン
        </Link>
      </p>
    </div>
  );
}
