# 画面一覧

| # | パス | 画面名 | 認証 | 実装状況 |
|---|------|--------|------|---------|
| 1 | `/` | ランディングページ | 不要 | MVP実装済 |
| 2 | `/auth/register` | 新規登録 | 不要 | MVP実装済 |
| 3 | `/auth/login` | ログイン | 不要 | MVP実装済 |
| 4 | `/auth/reset-password` | パスワード再設定(メール送信) | 不要 | MVP実装済 |
| 5 | `/auth/update-password` | 新パスワード設定 | リンク経由 | MVP実装済 |
| 6 | `/onboarding` | 初回オンボーディング(8ステップ+体験) | 必要 | MVP実装済 |
| 7 | `/home` | ホーム | 必要 | MVP実装済 |
| 8 | `/prejoin` | 入室前設定 | 必要 | MVP実装済 |
| 9 | `/camera-test` | カメラテスト | 必要 | MVP実装済 |
| 10 | `/room/[roomId]` | オンライン自習室 | 必要 | MVP実装済 |
| 11 | `/session/[sessionId]/complete` | セッション終了 | 必要 | MVP実装済 |
| 12 | `/history` | 学習履歴・ダッシュボード | 必要 | MVP実装済 |
| 13 | `/reservations` | 予約一覧 | 必要 | MVP実装済 |
| 14 | `/reservations/new` | 予約作成 | 必要 | MVP実装済 |
| 15 | `/reservations/[id]/edit` | 予約編集 | 必要 | MVP実装済 |
| 16 | `/goals` | 目標設定 | 必要 | MVP実装済 |
| 17 | `/achievements` | 実績・バッジ | 必要 | MVP実装済 |
| 18 | `/settings/profile` | プロフィール設定(退会含む) | 必要 | MVP実装済 |
| 19 | `/settings/notifications` | 通知設定 | 必要 | MVP実装済 |
| 20 | `/settings/supporters` | 応援者管理 | 必要 | MVP実装済 |
| 21 | `/settings/plan` | プラン・支払い | 必要 | MVP実装済(Stripeは要キー設定) |
| 22 | `/terms` | 利用規約 | 不要 | MVP実装済 |
| 23 | `/privacy` | プライバシーポリシー | 不要 | MVP実装済 |
| 24 | `/contact` | お問い合わせ | 不要 | MVP実装済 |
| 25 | `/report` | 通報画面(自習室内モーダルからも可) | 必要 | MVP実装済 |
| 26 | `/admin` | 管理者ダッシュボード | 管理者 | MVP実装済 |
| 27 | `/admin/users` | 管理者: ユーザー管理 | 管理者 | MVP実装済 |
| 28 | `/admin/rooms` | 管理者: ルーム管理 | 管理者 | MVP実装済 |
| 29 | `/admin/reports` | 管理者: 通報管理 | 管理者 | MVP実装済 |
| 30 | `/admin/announcements` | 管理者: お知らせ管理 | 管理者 | MVP実装済 |
| 31 | `/not-found` ほか | 404・エラー画面 | 不要 | MVP実装済 |

## レイアウト構成

- `(marketing)` グループ: LP・規約・プライバシー・問い合わせ(共通ヘッダー/フッター)
- `(app)` グループ: 認証必須。左サイドバー(PC) / 下部タブ(スマホ)のナビゲーション
- `admin`: 管理者ロール必須。専用レイアウト。一般ナビとは完全分離
- `room`: 没入型フルスクリーンレイアウト(ナビ非表示)
