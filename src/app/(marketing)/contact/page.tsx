'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { contactSchema } from '@/lib/validation';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input, Textarea, Label, FieldError } from '@/components/ui/input';
import { Alert } from '@/components/ui/misc';

type FormValues = z.input<typeof contactSchema>;

export default function ContactPage() {
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(contactSchema) });

  const onSubmit = async (values: FormValues) => {
    setError('');
    const supabase = createClient();
    const { error } = await supabase.from('contact_messages').insert({
      name: values.name ?? '',
      email: values.email,
      message: values.message,
    });
    if (error) {
      setError('送信に失敗しました。時間をおいてお試しください。');
      return;
    }
    setDone(true);
  };

  return (
    <div className="mx-auto max-w-xl px-4 py-12">
      <h1 className="mb-2 text-3xl font-bold">お問い合わせ</h1>
      <p className="mb-8 text-brand-600 dark:text-brand-300">
        不具合のご報告・ご要望・アカウントに関するご相談はこちらから。
      </p>
      {done ? (
        <Alert tone="success">
          お問い合わせを受け付けました。内容を確認のうえ、必要に応じてメールでご連絡します。
        </Alert>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
          <div>
            <Label htmlFor="name">お名前(任意)</Label>
            <Input id="name" {...register('name')} autoComplete="name" />
          </div>
          <div>
            <Label htmlFor="email">メールアドレス</Label>
            <Input id="email" type="email" {...register('email')} autoComplete="email" />
            <FieldError message={errors.email?.message} />
          </div>
          <div>
            <Label htmlFor="message">お問い合わせ内容</Label>
            <Textarea id="message" rows={6} {...register('message')} />
            <FieldError message={errors.message?.message} />
          </div>
          {error && <Alert tone="error">{error}</Alert>}
          <Button type="submit" size="lg" disabled={isSubmitting}>
            {isSubmitting ? '送信中…' : '送信する'}
          </Button>
        </form>
      )}
    </div>
  );
}
