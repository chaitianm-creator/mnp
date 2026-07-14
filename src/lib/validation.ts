import { z } from 'zod';
import { DURATIONS } from './constants';

export const emailSchema = z
  .string()
  .min(1, 'メールアドレスを入力してください')
  .email('メールアドレスの形式が正しくありません')
  .max(254);

export const passwordSchema = z
  .string()
  .min(8, 'パスワードは8文字以上にしてください')
  .max(72, 'パスワードが長すぎます');

export const displayNameSchema = z
  .string()
  .trim()
  .min(1, '表示名を入力してください')
  .max(30, '表示名は30文字以内にしてください');

export const topicSchema = z.string().trim().max(100, '100文字以内で入力してください');

export const durationSchema = z.coerce
  .number()
  .refine((v): v is (typeof DURATIONS)[number] => (DURATIONS as readonly number[]).includes(v), {
    message: '集中時間は5・15・25・50分から選択してください',
  });

export const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  displayName: displayNameSchema,
  termsAccepted: z.literal(true, {
    errorMap: () => ({ message: '利用規約とプライバシーポリシーへの同意が必要です' }),
  }),
});

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, 'パスワードを入力してください'),
});

export const reservationSchema = z
  .object({
    date: z.string().min(1, '日付を選択してください'),
    time: z.string().regex(/^\d{2}:\d{2}$/, '開始時刻を選択してください'),
    duration: durationSchema,
    topic: topicSchema,
    repeatWeekly: z.boolean().default(false),
  })
  .refine(
    (v) => {
      const dt = new Date(`${v.date}T${v.time}`);
      return !Number.isNaN(dt.getTime());
    },
    { message: '日時の形式が正しくありません', path: ['date'] }
  );

export const goalSchema = z.object({
  daily: z.coerce.number().int().min(0).max(1440),
  weekly: z.coerce.number().int().min(0).max(10080),
  monthly: z.coerce.number().int().min(0).max(44640),
});

export const supporterInviteSchema = z.object({
  email: emailSchema,
  name: z.string().trim().max(50).optional().default(''),
});

export const reportSchema = z.object({
  category: z.enum([
    'inappropriate_behavior',
    'camera_misuse',
    'impersonation',
    'harassment',
    'other',
  ]),
  description: z.string().trim().max(1000, '1000文字以内で入力してください'),
});

export const contactSchema = z.object({
  name: z.string().trim().max(50).optional().default(''),
  email: emailSchema,
  message: z.string().trim().min(1, 'お問い合わせ内容を入力してください').max(2000),
});
