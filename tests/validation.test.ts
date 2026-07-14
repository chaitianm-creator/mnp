import { describe, expect, it } from 'vitest';
import {
  registerSchema,
  loginSchema,
  reservationSchema,
  supporterInviteSchema,
  reportSchema,
  durationSchema,
} from '@/lib/validation';

describe('registerSchema', () => {
  const valid = {
    email: 'test@example.com',
    password: 'password123',
    displayName: 'テスト太郎',
    termsAccepted: true as const,
  };
  it('正しい入力を受け付ける', () => {
    expect(registerSchema.safeParse(valid).success).toBe(true);
  });
  it('規約未同意は拒否', () => {
    expect(registerSchema.safeParse({ ...valid, termsAccepted: false }).success).toBe(false);
  });
  it('短いパスワードは拒否', () => {
    expect(registerSchema.safeParse({ ...valid, password: 'short' }).success).toBe(false);
  });
  it('不正なメールは拒否', () => {
    expect(registerSchema.safeParse({ ...valid, email: 'not-an-email' }).success).toBe(false);
  });
  it('31文字の表示名は拒否', () => {
    expect(registerSchema.safeParse({ ...valid, displayName: 'あ'.repeat(31) }).success).toBe(false);
  });
});

describe('durationSchema', () => {
  it('5/15/25/50のみ受け付ける', () => {
    for (const d of [5, 15, 25, 50]) expect(durationSchema.safeParse(d).success).toBe(true);
    for (const d of [0, 10, 30, 60, -25]) expect(durationSchema.safeParse(d).success).toBe(false);
  });
});

describe('reservationSchema', () => {
  it('正しい予約を受け付ける', () => {
    const r = reservationSchema.safeParse({
      date: '2026-08-01',
      time: '07:00',
      duration: 25,
      topic: '英単語',
      repeatWeekly: false,
    });
    expect(r.success).toBe(true);
  });
  it('時刻形式が不正なら拒否', () => {
    const r = reservationSchema.safeParse({
      date: '2026-08-01',
      time: '7時',
      duration: 25,
      topic: '',
      repeatWeekly: false,
    });
    expect(r.success).toBe(false);
  });
});

describe('supporterInviteSchema / reportSchema', () => {
  it('応援者の招待メールを検証する', () => {
    expect(supporterInviteSchema.safeParse({ email: 'a@b.com' }).success).toBe(true);
    expect(supporterInviteSchema.safeParse({ email: 'bad' }).success).toBe(false);
  });
  it('通報カテゴリは定義済みのみ', () => {
    expect(reportSchema.safeParse({ category: 'harassment', description: '' }).success).toBe(true);
    expect(reportSchema.safeParse({ category: 'invalid', description: '' }).success).toBe(false);
  });
  it('1001文字の通報詳細は拒否', () => {
    expect(
      reportSchema.safeParse({ category: 'other', description: 'a'.repeat(1001) }).success
    ).toBe(false);
  });
});

describe('loginSchema', () => {
  it('空パスワードは拒否', () => {
    expect(loginSchema.safeParse({ email: 'a@b.com', password: '' }).success).toBe(false);
  });
});
