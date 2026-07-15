import { test, expect, type Page, type BrowserContext } from '@playwright/test';
import { execSync } from 'node:child_process';

/**
 * MokuTomo E2Eテスト。
 * 前提: ローカルスタック(README「E2Eテスト」参照)が起動していること。
 *   1. PostgreSQL (127.0.0.1:55432) + e2e-stack/reset-db.sh 済み
 *   2. node e2e-stack/server.mjs (Supabase互換エミュレータ)
 *   3. npm run dev (エミュレータのキーを.env.localに設定)
 * カメラはPlaywrightのfake media deviceを使用する。
 */

const DB_URL = process.env.E2E_DB_URL ?? 'postgresql://postgres@127.0.0.1:55432/mokutomo';
const sql = (query: string) => execSync(`psql "${DB_URL}" -v ON_ERROR_STOP=1 -qtAc "${query.replaceAll('"', '\\"')}"`).toString().trim();

async function login(page: Page, email: string, password = 'password123') {
  await page.goto('/auth/login');
  await page.getByLabel('メールアドレス').fill(email);
  await page.getByLabel('パスワード').fill(password);
  await page.getByRole('button', { name: 'ログイン' }).click();
  await page.waitForURL(/\/(home|onboarding)/, { timeout: 20_000 });
}

/** 入室前設定を通って自習室に入る。roomId を返す */
async function joinRoom(page: Page, topic: string, durationLabel: string) {
  await page.goto('/prejoin');
  await page.getByPlaceholder(/数学の過去問/).fill(topic);
  await page.getByRole('radio', { name: durationLabel, exact: true }).click();
  await page.getByText('ルールに同意して入室します').click();
  const joinButton = page.getByRole('button', { name: /分の自習を始める/ });
  await expect(joinButton).toBeEnabled({ timeout: 20_000 });
  await joinButton.click();
  await page.waitForURL(/\/room\//, { timeout: 30_000, waitUntil: 'commit' });
  return page.url().split('/room/')[1];
}

test.describe.configure({ mode: 'serial' });

test('1. ランディングページが表示される', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('黙々、でもひとりじゃない。')).toBeVisible();
  await expect(page.getByRole('link', { name: '無料ではじめる' })).toBeVisible();
});

test('2. 新規登録画面が表示され、実際に登録できる(→オンボーディング)', async ({ page }) => {
  await page.goto('/auth/register');
  await expect(page.getByRole('heading', { name: '新規登録' })).toBeVisible();

  const email = `e2e-${Date.now()}@example.com`;
  await page.getByLabel(/表示名/).fill('E2Eテストユーザー');
  await page.getByLabel('メールアドレス').fill(email);
  await page.getByLabel(/パスワード/).fill('password123');
  await page.getByLabel(/利用規約/).check();
  await page.getByRole('button', { name: '登録してはじめる' }).click();
  await page.waitForURL(/\/onboarding/, { timeout: 20_000 });
  await expect(page.getByText('ようこそ、MokuTomoへ')).toBeVisible();
});

test('3. ログインしてホームが表示される', async ({ page }) => {
  await login(page, 'sakura@example.com');
  await expect(page.getByText('本日の集中時間')).toBeVisible();
  await expect(page.getByRole('link', { name: /今すぐ入室/ }).first()).toBeVisible();
});

test('4. カメラ拒否時に原因と設定方法の案内が表示される', async ({ page }) => {
  await page.addInitScript(() => {
    navigator.mediaDevices.getUserMedia = () =>
      Promise.reject(new DOMException('Permission denied', 'NotAllowedError'));
  });
  await login(page, 'sakura@example.com');
  await page.goto('/camera-test');
  await expect(page.getByText('カメラの利用が許可されていません').first()).toBeVisible({
    timeout: 15_000,
  });
  await expect(page.getByText(/Chrome \/ Edge/)).toBeVisible();
});

test('5. カメラ許可時にぼかしプレビューが表示される(カメラテスト)', async ({ page }) => {
  await login(page, 'sakura@example.com');
  await page.goto('/camera-test');
  await expect(page.getByText('この見え方のまま送信されます')).toBeVisible({ timeout: 20_000 });
  // プレビューvideoにフレームが流れている(=パイプラインが動作している)
  await expect
    .poll(
      () =>
        page.evaluate(() => {
          const v = document.querySelector('video');
          return v ? v.videoWidth : 0;
        }),
      { timeout: 20_000 }
    )
    .toBeGreaterThan(0);
});

test('6. 入室→タイマー表示→退出確認→途中退出できる', async ({ page }) => {
  await login(page, 'mei@example.com');
  await joinRoom(page, 'E2E集中テスト', '15分');
  // タイマー(開始前カウントダウンまたは残り時間)
  await expect(page.getByText(/開始まで|残り時間/)).toBeVisible({ timeout: 20_000 });
  // 自分のタイルと学習内容
  await expect(page.getByText('(自分)')).toBeVisible();
  await expect(page.getByText('E2E集中テスト').first()).toBeVisible();
  // 退出確認ダイアログ
  await page.getByRole('button', { name: '退出' }).click();
  await expect(page.getByText('途中退出しますか?')).toBeVisible();
  await page.getByRole('button', { name: '続ける' }).click();
  await page.getByRole('button', { name: '退出' }).click();
  await page.getByRole('button', { name: '退出する' }).click();
  await page.waitForURL(/\/home/, { timeout: 15_000 });
});

test('7. セッション完了→自己評価→履歴に保存される', async ({ page }) => {
  await login(page, 'kaito@example.com');
  const roomId = await joinRoom(page, 'E2E完了テスト', '5分');

  // 部屋の時間をサーバー側で過去にずらし、終了済み状態を作る
  sql(`update public.study_rooms set starts_at = now() - interval '6 minutes', ends_at = now() - interval '10 seconds' where id = '${roomId}'`);
  sql(`update public.study_sessions set started_at = now() - interval '6 minutes' where room_id = '${roomId}'`);

  await page.reload();
  await page.waitForURL(/\/session\/.+\/complete/, { timeout: 20_000 });
  await expect(page.getByText(/コマ完了|記録を保存しました/)).toBeVisible({ timeout: 20_000 });

  // 自己評価と振り返りメモ
  await page.getByRole('radio', { name: /集中できた/ }).click();
  await page.getByPlaceholder('振り返りメモ(任意)').fill('E2Eからの振り返り');
  await page.getByRole('button', { name: '振り返りを保存' }).click();
  await expect(page.getByText('保存しました ✓')).toBeVisible();

  // 履歴に反映されている
  await page.goto('/history');
  await expect(page.getByText('E2E完了テスト').first()).toBeVisible({ timeout: 15_000 });
});

test('8. 予約の作成・編集・削除ができる', async ({ page }) => {
  await login(page, 'sakura@example.com');

  // 作成
  await page.goto('/reservations/new');
  const date = new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10);
  await page.locator('#res-date').fill(date);
  await page.locator('#res-time').fill('07:30');
  await page.getByRole('radio', { name: '50分', exact: true }).click();
  await page.locator('#res-topic').fill('E2E予約テスト');
  await page.getByRole('button', { name: '予約する' }).click();
  await page.waitForURL(/\/reservations$/, { timeout: 15_000 });
  await expect(page.getByText('E2E予約テスト')).toBeVisible();

  // 編集
  const row = page.locator('li', { hasText: 'E2E予約テスト' }).first();
  await row.getByRole('link', { name: '変更' }).click();
  await page.waitForURL(/\/edit/, { timeout: 15_000 });
  await page.locator('#res-topic').fill('E2E予約テスト(変更後)');
  await page.getByRole('button', { name: '変更を保存' }).click();
  await page.waitForURL(/\/reservations$/, { timeout: 15_000 });
  await expect(page.getByText('E2E予約テスト(変更後)')).toBeVisible();

  // 削除 (confirmダイアログを受諾)
  page.on('dialog', (d) => d.accept());
  await page
    .locator('li', { hasText: 'E2E予約テスト(変更後)' })
    .first()
    .getByRole('button', { name: '削除' })
    .click();
  // 削除(キャンセル)されると「今後の予約」から消え、過去の予約に「キャンセル」として残る
  await expect(
    page.locator('li', { hasText: 'E2E予約テスト(変更後)' }).getByText('キャンセル')
  ).toBeVisible({ timeout: 15_000 });
  await expect(
    page.locator('li', { hasText: 'E2E予約テスト(変更後)' }).getByRole('button', { name: '削除' })
  ).toBeHidden();
});

test('9. 一般ユーザーは管理者画面に入れない / 管理者は入れる', async ({ browser }) => {
  const c1 = await browser.newContext();
  const general = await c1.newPage();
  await login(general, 'mei@example.com');
  await general.goto('/admin');
  await general.waitForURL(/\/home/, { timeout: 15_000 });
  await c1.close();

  const c2 = await browser.newContext();
  const admin = await c2.newPage();
  await login(admin, 'admin@example.com');
  await admin.goto('/admin');
  await expect(admin.getByText('総ユーザー数')).toBeVisible({ timeout: 15_000 });
  await c2.close();
});

test('10. 2ブラウザが同じ自習室に入り、ぼかし映像を相互共有しタイマーが同期する', async ({
  browser,
}) => {
  test.setTimeout(180_000);
  const ctxA: BrowserContext = await browser.newContext({ permissions: ['camera'] });
  const ctxB: BrowserContext = await browser.newContext({ permissions: ['camera'] });
  const pageA = await ctxA.newPage(); // さくら
  const pageB = await ctxB.newPage(); // めい (無料プランの1日2コマ制限に達しないユーザーを使用)

  await login(pageA, 'sakura@example.com');
  await login(pageB, 'mei@example.com');

  const roomA = await joinRoom(pageA, 'E2E相互接続A', '50分');
  const roomB = await joinRoom(pageB, 'E2E相互接続B', '50分');

  // 同じ部屋に割り当てられる
  expect(roomB).toBe(roomA);

  // 相手の表示名が互いに見える (入退室のリアルタイム反映)
  await expect(pageA.getByText('めい').first()).toBeVisible({ timeout: 30_000 });
  await expect(pageB.getByText('さくら').first()).toBeVisible({ timeout: 30_000 });

  // WebRTC映像: 両ページで2本以上のvideoにフレームが流れている(自分+相手)
  const framesFlowing = (page: Page) =>
    page.evaluate(() => {
      const videos = Array.from(document.querySelectorAll('video'));
      return videos.filter((v) => v.videoWidth > 0 && v.readyState >= 2).length;
    });
  await expect.poll(() => framesFlowing(pageA), { timeout: 60_000 }).toBeGreaterThanOrEqual(2);
  await expect.poll(() => framesFlowing(pageB), { timeout: 60_000 }).toBeGreaterThanOrEqual(2);

  // 受信している映像はぼかしパイプラインの縮小解像度(=加工済みの映像そのもの)
  const remoteRes = await pageA.evaluate(() => {
    const videos = Array.from(document.querySelectorAll('video'));
    return videos.map((v) => ({ w: v.videoWidth, h: v.videoHeight }));
  });
  for (const r of remoteRes) {
    expect(r.w).toBeLessThanOrEqual(400); // 320x240で送信している
  }

  // 音声トラックが0本であること
  const audioTracks = await pageA.evaluate(() =>
    Array.from(document.querySelectorAll('video')).reduce(
      (acc, v) => acc + ((v.srcObject as MediaStream | null)?.getAudioTracks().length ?? 0),
      0
    )
  );
  expect(audioTracks).toBe(0);

  // タイマー同期: 両者の残り時間の差が2秒以内
  const readTimer = async (page: Page) => {
    const text = await page.locator('.tabular-nums').first().textContent();
    const [m, s] = (text ?? '0:0').split(':').map(Number);
    return m * 60 + s;
  };
  const [tA, tB] = await Promise.all([readTimer(pageA), readTimer(pageB)]);
  expect(Math.abs(tA - tB)).toBeLessThanOrEqual(2);

  // リロード後の復帰 (同じ部屋・タイマー継続)
  await pageA.reload();
  await expect(pageA.getByText(/残り時間|開始まで/)).toBeVisible({ timeout: 30_000 });
  expect(pageA.url()).toContain(roomA);

  // 多重入室防止: 同じユーザーが別タブで入ると警告
  const dupTab = await ctxA.newPage();
  await dupTab.goto(`/room/${roomA}`);
  await expect(dupTab.getByText('多重入室はできません')).toBeVisible({ timeout: 30_000 });
  await dupTab.close();

  // 片方が退出すると相手側に反映される
  await pageB.getByRole('button', { name: '退出' }).click();
  await pageB.getByRole('button', { name: '退出する' }).click();
  await pageB.waitForURL(/\/home/, { timeout: 15_000 });
  await expect(pageA.getByText(/退出しました/)).toBeVisible({ timeout: 30_000 });

  // 後片付け: さくらも退出
  await pageA.getByRole('button', { name: '退出' }).click();
  await pageA.getByRole('button', { name: '退出する' }).click();
  await pageA.waitForURL(/\/home/, { timeout: 15_000 });

  await ctxA.close();
  await ctxB.close();
});
