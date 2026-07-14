'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { passwordSchema } from '@/lib/validation';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';

const schema = z
  .object({ password: passwordSchema, confirm: z.string() })
  .refine((v) => v.password === v.confirm, {
    message: 'パスワードが一致しません',
    path: ['confirm'],
  });
type FormValues = z.input<typeof schema>;

export default function UpdatePasswordPage() {
  const router = useRouter();
  const [error, setError] = useState('');
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = async (values: FormValues) => {
    setError('');
    const supabase = createClient();
    const { error } = await supabase.auth.updateUser({ password: values.password });
    if (error) {
      setError('パスワードの更新に失敗しました。リンクの有効期限が切れている可能性があります。');
      return;
    }
    router.push('/home');
    router.refresh();
  };

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold">新しいパスワードを設定</h1>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <div>
          <Label htmlFor="password">新しいパスワード(8文字以上)</Label>
          <Input id="password" type="password" {...register('password')} autoComplete="new-password" />
          <FieldError message={errors.password?.message} />
        </div>
        <div>
          <Label htmlFor="confirm">確認のためもう一度</Label>
          <Input id="confirm" type="password" {...register('confirm')} autoComplete="new-password" />
          <FieldError message={errors.confirm?.message} />
        </div>
        {error && <Alert tone="error">{error}</Alert>}
        <Button type="submit" size="lg" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? '更新中…' : 'パスワードを更新'}
        </Button>
      </form>
    </div>
  );
}
