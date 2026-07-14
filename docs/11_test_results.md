# テスト結果 (2026-07-14 実施)

## 1. ユニットテスト (Vitest) — ✅ 実行済み・全パス

```
Test Files  4 passed (4)
     Tests  38 passed (38)

✓ tests/timer.test.ts       (9)  同期タイマー計算・サーバー時刻オフセット推定
✓ tests/xp.test.ts          (8)  XP/レベル計算 (SQL関数と同一式・境界値20レベル分)
✓ tests/history.test.ts     (9)  タイムゾーン対応の日別/週別集計・曜日傾向
✓ tests/validation.test.ts (12)  Zodスキーマ (登録/予約/通報/招待)
```

実行コマンド: `npm test`

## 2. 本番ビルド — ✅ 実行済み・成功

`npm run build` (Next.js 14.2.35) — 全39ルートのコンパイル・型チェック成功。
静的ページ(LP/規約/認証)はプリレンダリング、アプリ画面はダイナミックレンダリング。

## 3. データベース・RLSテスト — ✅ 実行済み・全パス

Docker(Supabase CLIのローカルスタック)は本開発環境のネットワークポリシーで
イメージ取得が拒否されたため、**素のPostgreSQL 16 + Supabase互換シム**
(auth.users / auth.uid() / realtime.messages / anon・authenticatedロールを再現)
上で全マイグレーション・シード・RLSを実行して検証した。

```
OK: supabase/migrations/0001_schema.sql   (17テーブル+トリガ)
OK: supabase/migrations/0002_functions.sql (RPC 18関数)
OK: supabase/migrations/0003_rls.sql       (全テーブルRLS+Realtime認可)
OK: supabase/seed.sql                      (4ユーザー+履歴30件+予約+通報 ほか)

supabase/tests/rls.test.sql:
  PASS: 一般ユーザー(さくら)の権限チェック OK
        - 他人のprofiles/study_sessions/reservations/user_stats/supporters: 0行(閲覧不可)
        - user_statsのXP直接更新: 拒否 / study_sessions直接INSERT: 拒否
        - user_achievements直接INSERT: 拒否 / subscriptionsのplan直接変更: 拒否
        - 自分のroleをadminへ昇格: 拒否 / admin_stats実行: 拒否 / 監査ログ閲覧: 不可
  PASS: 管理者の権限チェック OK (全profiles閲覧・reports閲覧・admin_stats実行)
  PASS: 未認証ユーザーの権限チェック OK (全テーブル0行・問い合わせのみ投稿可)
  → RLS TESTS PASSED
```

## 4. サーバーサイドRPCの動作テスト — ✅ 実行済み・全パス

```
PASS: join_room 初回入室で部屋が自動作成される (rejoined=false)
PASS: 同一ユーザーの再joinは同じセッションへ再入室 (rejoined=true / 多重入室防止)
PASS: ブロック関係のユーザーとは別部屋に割り当てられる
PASS: 早すぎるfinish_sessionは拒否 (session_not_finished_yet)
PASS: leave_session で途中退出が記録される
PASS: 無料プラン1日2コマ制限 (free_plan_daily_limit)
PASS: 無料プラン予約3件制限 (4件目で拒否)
PASS: 繰り返し予約はプレミアム限定 (premium_required)
PASS: プレミアムの繰り返し予約がsync_reservationsで実体化 (1→5件)
PASS: 完了処理 xp_awarded=60 (25分×2+10) / レベル・streak更新 / user_stats整合
PASS: 二重完了は拒否 (session_already_finished)
```

## 5. 未検証項目 (環境制約により実行できなかったもの)

| 項目 | 理由 | 実施方法 |
|------|------|---------|
| E2Eテスト (Playwright, `e2e/smoke.spec.ts`) | ローカルSupabase(Auth/Realtime)がDocker取得不可で起動できず | `supabase start` 可能な環境で `npm run test:e2e` |
| 2ブラウザでの同室WebRTC接続・映像相互表示 | 同上 + 実カメラ・実ネットワークが必要 | デプロイ後に2端末で手動確認 (手順: docs/09) |
| 通信切断・再接続の実機挙動 | 同上 | 同上 |
| メール送信 (Resend) / Stripe決済 | APIキーが必要 | テストモードキー設定後に確認 |
| Vercel本番デプロイ・公開URL | デプロイ先アカウントが必要 | docs/09_operations.md の手順で実施 |
| スマートフォン実機表示 | 実機なし (レスポンシブCSSは実装済み) | デプロイ後に実機確認 |
