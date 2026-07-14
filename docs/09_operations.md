# 本番公開手順・運用マニュアル

## 1. 本番公開手順 (Vercel + Supabase)

### 1-1. Supabaseプロジェクト作成

1. https://supabase.com でプロジェクトを作成(リージョン: Tokyo推奨)
2. SQL Editor で以下を順に実行
   - `supabase/migrations/0001_schema.sql`
   - `supabase/migrations/0002_functions.sql`
   - `supabase/migrations/0003_rls.sql`
   - ※ `supabase/seed.sql` は**本番では実行しない**(開発専用のテストデータ)
   - CLIを使う場合: `supabase link --project-ref <ref>` → `supabase db push`
3. Authentication → Providers → Email: **Confirm email を有効化**
4. Authentication → URL Configuration:
   - Site URL: `https://<本番ドメイン>`
   - Redirect URLs: `https://<本番ドメイン>/auth/callback`
5. (任意) Google ログイン: Providers → Google を有効化し、
   Google CloudのOAuthクライアントID/シークレットを設定。
   フロント側は `supabase.auth.signInWithOAuth({ provider: 'google' })` の
   ボタンを追加するだけで対応可能(現状は未実装)。

### 1-2. Vercelデプロイ

1. このリポジトリをVercelへインポート(Framework: Next.js、設定はデフォルト)
2. 環境変数を設定(`.env.example` 参照):
   - `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`(**Server環境変数として。Publicにしない**)
   - `NEXT_PUBLIC_APP_URL`(本番URL)
   - `NEXT_PUBLIC_STUN_URLS`、本番では `NEXT_PUBLIC_TURN_URL/USERNAME/CREDENTIAL` も推奨
   - Stripe/Resend/Sentry(使用する場合)
3. デプロイ → 発行されたURLで動作確認

### 1-3. Stripe設定 (有料プラン)

1. Stripeダッシュボード(**テストモード**)で「プレミアム」月額980円のPriceを作成
2. `STRIPE_SECRET_KEY` / `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` / `STRIPE_PRICE_ID_PREMIUM` を設定
3. Webhook: `https://<本番ドメイン>/api/stripe/webhook` を登録
   - イベント: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
   - 署名シークレットを `STRIPE_WEBHOOK_SECRET` に設定
4. Customer Portal を有効化(Billing → Customer portal)
5. 本番移行時は本番キーに差し替え

### 1-4. TURNサーバー (推奨)

フルメッシュWebRTCはNAT環境によってはSTUNだけで接続できない場合がある。
Metered / Twilio NTS / 自前coturn のいずれかを用意し、`NEXT_PUBLIC_TURN_*` を設定する。

### 1-5. 管理者アカウント作成

1. 通常どおり新規登録する
2. Supabase SQL Editorで:
   ```sql
   update public.profiles set role = 'admin' where id = (
     select id from auth.users where email = '<管理者のメール>'
   );
   ```
3. `/admin` にアクセスできることと、一般ユーザーではアクセスできないことを確認

## 2. 動作確認チェックリスト (公開直後)

1. 新規登録 → メール確認 → オンボーディング → 体験セッション
2. 2つのブラウザ(またはPC+スマホ)で同時に「今すぐ入室」→ 同室に入り、
   相手のぼかし映像が見えること・入退室が即時反映されること
3. タイマーが両者で同じ残り時間であること・リロード後も復帰すること
4. 完了後に履歴へ記録されること
5. 予約の作成・変更・削除、開始前のホーム強調表示
6. 管理者画面での利用状況・強制退室・通報対応
7. スマートフォン表示

## 3. 運用マニュアル

### 日常運用
- **通報対応**: `/admin/reports` を毎日確認。悪質な場合は「対象を利用停止」。
  すべての操作は `admin_audit_logs` に記録される。
- **お知らせ**: `/admin/announcements` で作成し「公開」でホームに表示。
- **利用状況**: `/admin` でDAU/MAU/総集中時間/稼働ルームを確認。

### エラー監視
- Vercel → Functions ログ、Supabase → Logs を確認。
- `SENTRY_DSN` を設定すればSentryへ送信可能(正式版で本組み込み予定)。

### バックアップ方針
- Supabase有料プランの自動バックアップ(PITR)を有効化する。
- 無料プランの場合は日次で `supabase db dump` をCI(GitHub Actions cron)から
  実行しオブジェクトストレージへ保管する。
- 映像は保存していないため、バックアップ対象はDBのみ。

### 障害時の対応手順
1. Vercel/Supabaseのステータスページを確認
2. 直近のデプロイが原因の場合: Vercelで即座に前バージョンへロールバック
3. DB障害: バックアップからリストア(Supabaseダッシュボード)
4. 自習室に入れない障害の場合: `/admin/announcements` でお知らせを掲示
5. 対応後、原因と再発防止をdocs/10_known_issues.mdに追記

### 定期ジョブ (正式版で推奨)
- 予約リマインダーメール: Vercel Cron で15分おきに未通知の直近予約を抽出し
  `sendEmail` で送信(`notified_at` で二重送信防止)。
- 週間レポート: 週次cronで `supporter_notifications` に `weekly_report` を
  キューし、同cron内で送信。
- 期限切れルームの掃除は `join_room` 内で自動実行されるが、
  日次で `select public.close_expired_rooms();` を実行するとより確実。
