'use client';

import Link from 'next/link';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { emailSchema } from '@/lib/validation';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';

const schema = z.object({ email: emailSchema });
type FormValues = z.input<typeof schema>;

export default function ResetPasswordPage() {
  const [sent, setSent] = useState(false);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = async (values: FormValues) => {
    const supabase = createClient();
    await supabase.auth.resetPasswordForEmail(values.email, {
      redirectTo: `${location.origin}/auth/callback?next=/auth/update-password`,
    });
    // 存在しないメールでも成功表示にする(アカウント有無を漏らさない)
    setSent(true);
  };

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold">パスワード再設定</h1>
      {sent ? (
        <Alert tone="success">
          入力されたメールアドレスが登録されている場合、再設定用のリンクを送信しました。メールをご確認ください。
        </Alert>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
          <div>
            <Label htmlFor="email">登録済みのメールアドレス</Label>
            <Input id="email" type="email" {...register('email')} autoComplete="email" />
            <FieldError message={errors.email?.message} />
          </div>
          <Button type="submit" size="lg" className="w-full" disabled={isSubmitting}>
            {isSubmitting ? '送信中…' : '再設定リンクを送る'}
          </Button>
        </form>
      )}
      <p className="mt-6 text-center text-sm">
        <Link href="/auth/login" className="text-brand-600 underline dark:text-brand-300">
          ログインへ戻る
        </Link>
      </p>
    </div>
  );
}
