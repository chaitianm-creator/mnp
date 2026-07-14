import { defineConfig, devices } from '@playwright/test';

/**
 * E2Eテスト設定。
 * 実行にはローカルSupabase(`supabase start` + シード投入)と
 * `.env.local` の設定が必要。カメラはfake deviceを使用する。
 */
export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  retries: 0,
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:3000',
    locale: 'ja-JP',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: [
            '--use-fake-ui-for-media-stream', // カメラ許可ダイアログを自動許可
            '--use-fake-device-for-media-stream', // 仮想カメラ映像
          ],
        },
        permissions: ['camera'],
      },
    },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
