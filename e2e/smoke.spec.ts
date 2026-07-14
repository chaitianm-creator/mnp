import { test, expect } from '@playwright/test';

/**
 * 主要フローのスモークテスト。
 * 前提: ローカルSupabaseが起動し、シード(supabase/seed.sql)が投入済みであること。
 */

test('LPが表示され、登録導線がある', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('link', { name: '無料ではじめる' })).toBeVisible();
  await expect(page.getByText('黙々、でもひとりじゃない。')).toBeVisible();
});

test('シードユーザーでログイン → ホーム表示', async ({ page }) => {
  await page.goto('/auth/login');
  await page.getByLabel('メールアドレス').fill('sakura@example.com');
  await page.getByLabel('パスワード').fill('password123');
  await page.getByRole('button', { name: 'ログイン' }).click();
  await expect(page.getByRole('link', { name: /今すぐ入室/ }).first()).toBeVisible({
    timeout: 15_000,
  });
  await expect(page.getByText('本日の集中時間')).toBeVisible();
});

test('入室前設定 → 自習室 → タイマー表示 (fakeカメラ)', async ({ page }) => {
  await page.goto('/auth/login');
  await page.getByLabel('メールアドレス').fill('mei@example.com');
  await page.getByLabel('パスワード').fill('password123');
  await page.getByRole('button', { name: 'ログイン' }).click();
  await page.waitForURL(/\/home/);

  await page.goto('/prejoin');
  await page.getByPlaceholder(/数学の過去問/).fill('E2Eテスト勉強');
  await page.getByRole('radio', { name: /5分/ }).click();
  await page.getByText('ルールに同意して入室します').click();
  // カメラ準備完了を待つ
  await expect(page.getByRole('button', { name: /5分の自習を始める/ })).toBeEnabled({
    timeout: 20_000,
  });
  await page.getByRole('button', { name: /5分の自習を始める/ }).click();
  await page.waitForURL(/\/room\//, { timeout: 20_000 });
  // タイマー(開始前カウントダウンまたは残り時間)が表示される
  await expect(page.getByText(/開始まで|残り時間/)).toBeVisible({ timeout: 20_000 });
  // 退出(確認ダイアログ経由)
  await page.getByRole('button', { name: /退出/ }).click();
  await page.getByRole('button', { name: '退出する' }).click();
  await page.waitForURL(/\/home/, { timeout: 15_000 });
});

test('一般ユーザーは管理者画面へ入れない', async ({ page }) => {
  await page.goto('/auth/login');
  await page.getByLabel('メールアドレス').fill('kaito@example.com');
  await page.getByLabel('パスワード').fill('password123');
  await page.getByRole('button', { name: 'ログイン' }).click();
  await page.waitForURL(/\/home/);
  await page.goto('/admin');
  await page.waitForURL(/\/home/, { timeout: 15_000 }); // /homeへリダイレクトされる
});

test('管理者はダッシュボードを見られる', async ({ page }) => {
  await page.goto('/auth/login');
  await page.getByLabel('メールアドレス').fill('admin@example.com');
  await page.getByLabel('パスワード').fill('password123');
  await page.getByRole('button', { name: 'ログイン' }).click();
  await page.waitForURL(/\/home/);
  await page.goto('/admin');
  await expect(page.getByText('総ユーザー数')).toBeVisible({ timeout: 15_000 });
});
