# MokuTomo(モクトモ)

> **黙々、でもひとりじゃない。** — やる気に頼らず机に向かえるオンライン自習室

自宅で集中できない人が、**強いぼかしの入った映像**ごしに「一緒に勉強している誰か」と
時間を共有することで、自然と勉強を始められるWebアプリです。
会話・交流を目的としたビデオ通話サービスではありません。

| | |
|---|---|
| フロントエンド | Next.js 14 (App Router) / TypeScript / Tailwind CSS / React Hook Form / Zod |
| バックエンド | Supabase (PostgreSQL / Auth / Realtime / RLS) |
| ビデオ通信 | フルメッシュWebRTC + Canvasぼかしパイプライン(下記参照) |
| 決済 | Stripe Checkout / Customer Portal (テストモード) |
| メール | Resend |
| テスト | Vitest (38件) / Playwright / RLS SQLテスト |
| ホスティング | Vercel |

## 主な機能

- **ワンボタン入室**: 学習内容と時間(5/15/25/50分)を選ぶだけで、空いている部屋へ自動割当(満室なら自動作成、最大6名)
- **強制ぼかし**: 映像は送信前に端末内でCanvas加工(縮小+blur)。**ぼかし前の映像はどこにも送信されず、誰も解除できない。録画なし。マイクは取得すらしない**
- **同期タイマー**: サーバー時刻基準で全員の開始・終了が一致。一時停止不可、リロード/バックグラウンドでもずれない
- **記録と習慣化**: 完了コマ・実参加時間・連続日数・XP/レベル・バッジ(すべてサーバー側で付与、改ざん不可)
- **学習履歴**: 日/週/月グラフ、カレンダー、曜日・時間帯傾向、目標達成率
- **予約**: 単発+毎週繰り返し(プレミアム)、開始前通知、欠席記録、タイムゾーン対応
- **応援・見守り**: 本人が招待し相手が同意した場合のみ、開始・完了・週間レポートをメール通知(映像は共有しない)
- **安全対策**: 通報(5分類)/ブロック(同室回避)/利用停止/レート制限/RLSによる認可/管理操作ログ
- **管理者画面**: 利用状況集計・ユーザー管理・ルーム監視(映像閲覧機能なし)・通報対応・お知らせ
- **プラン**: 無料(1日2コマ・予約3件)/プレミアム(無制限、Stripe)
- レスポンシブ(PC/スマホ)・ダークモード・キーボード操作対応

画面一覧: `docs/02_screens.md` / 機能一覧: `docs/01_features.md`

## セットアップ(ローカル開発)

前提: Node.js 20+ / Docker(Supabaseローカルスタック用)

```bash
# 1. 依存をインストール
npm install

# 2. Supabaseローカルスタックを起動(マイグレーション+シードが自動適用される)
npx supabase start

# 3. 環境変数を設定
cp .env.example .env.local
#    `npx supabase status` に表示される API URL / anon key / service_role key を
#    .env.local の NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY /
#    SUPABASE_SERVICE_ROLE_KEY に設定

# 4. 起動
npm run dev
# → http://localhost:3000
```

シードを再投入する場合: `npx supabase db reset`(migrations + seed.sql を再適用)

### テスト用アカウント(ローカル開発専用・本番では使用しない)

| 役割 | メール | パスワード | 備考 |
|------|--------|-----------|------|
| 一般 | `sakura@example.com` | `password123` | プレミアム。繰り返し予約・応援者あり |
| 一般 | `kaito@example.com` | `password123` | 無料。通報された側のテストデータあり |
| 一般 | `mei@example.com` | `password123` | 無料。カイトをブロック済み |
| 管理者 | `admin@example.com` | `password123` | `/admin` にアクセス可能 |

シードには学習履歴30件・予約・バッジ・お知らせ・通報データが含まれます。

### テスト実行

```bash
npm test          # ユニットテスト (Vitest, 38件)
npm run build     # 本番ビルド

# RLS(他人の非公開データを取得できないこと)の検証
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/tests/rls.test.sql
```

### E2Eテスト (Docker不要のローカルスタック)

`e2e-stack/` に、素のPostgreSQLだけで動くSupabase互換エミュレータ
(REST=PostgRESTサブセット / Auth=GoTrueサブセット / Realtime=Phoenixチャネルサブセット)
が入っており、**実アプリ+実RLS+実RPC+実WebRTC**でE2Eを実行できる。
Supabase CLI(Docker)が使える環境では `supabase start` を使ってもよい。

```bash
# 1. PostgreSQL 16 を用意 (例: ポート55432で起動しておく)
# 2. DB初期化 (マイグレーション+シード適用)
PGURL_SUPER="postgresql://postgres@127.0.0.1:55432/postgres" ./e2e-stack/reset-db.sh
# 3. エミュレータ起動 (起動ログにANON_KEY/SERVICE_KEYが表示される)
(cd e2e-stack && npm install && node server.mjs) &
# 4. 表示されたキーを .env.local に設定して dev サーバー起動
#    NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
npm run dev &
# 5. E2E実行 (fakeカメラ使用。10テスト)
npx playwright test
```

テスト内容: LP表示 / 新規登録 / ログイン / ホーム / カメラ拒否の案内 / ぼかしプレビュー /
入室→タイマー→退出確認→途中退出 / セッション完了→評価→履歴保存 / 予約の作成・編集・削除 /
管理者権限ガード / **2ブラウザ同室(相互ぼかし映像・音声0本・タイマー同期±2秒・リロード復帰・多重入室防止・退出反映)**

テスト結果: `docs/11_test_results.md`(何を実行し、何が環境制約で未検証かを明記)

### 手動テスト手順(複数端末)

デプロイ後(または `npm run dev` 中)に、次の組み合わせで確認する。

**用意**: 2つのアカウント(例: 自分のメール2つ、またはシードのさくら/めい)

| # | 端末A | 端末B |
|---|-------|-------|
| 1 | Chrome通常ウィンドウ | Chromeシークレットウィンドウ |
| 2 | PCのChrome | スマートフォン(Chrome/Safari) |
| 3 | Safari | Chrome |
| 4 | Wi-Fi接続の端末 | モバイル回線の端末 ※TURN未設定だと繋がらない場合あり |

**手順と確認項目**(各組み合わせで):

1. それぞれ**別のアカウント**でログインする
2. 両方で「今すぐ入室」→ 同じ集中時間(例: 25分)を選んで入室する
   - [ ] 2人が**同じルーム**に入る(相手の表示名が見える)
   - [ ] **相互に映像が表示される**
   - [ ] 映像が**強くぼかされている**(顔・文字が判別できない)
   - [ ] **音声が聞こえない**(スピーカー最大でも無音)
   - [ ] **タイマーの残り時間が両者で一致**する(±2秒以内)
3. 端末Bで「退出」→ 確認ダイアログ→退出
   - [ ] 端末Aに「◯◯さんは退出しました」が表示される
4. 端末Aでページを再読み込み
   - [ ] 同じルームに復帰し、残り時間が正しく続いている
5. スマートフォンをスリープ→10秒後に復帰
   - [ ] 映像とタイマーが復帰する(数秒の再接続待ちは正常)
6. 管理者アカウントで `/debug/webrtc` を開き「診断を開始」
   - [ ] 「送信ストリームの音声トラック数: 0」がOK表示
   - [ ] 受信解像度が320×240程度(ぼかし済み映像)
   - [ ] candidate type(host=同一LAN / srflx=STUN / relay=TURN)を記録する

## ビデオ通信方式の選定(要約)

**MVP: フルメッシュWebRTC + Supabase Realtimeシグナリング** を採用。

- 部屋は最大6名で、ぼかし後の映像は320×240/15fpsに縮小されるため、
  メッシュでも上り帯域は約1.5Mbpsに収まる
- **映像がサーバーを一切経由しない**ため「鮮明な映像を保存しない/録画しない」を構造的に保証
- 追加SaaS費用ゼロ(TURNを除く)。シグナリングは既存のSupabase Realtimeで完結
- 正式版で7名以上・安定性強化が必要になった場合は **LiveKit Cloud**(無料枠あり・SFU)へ移行。
  `src/lib/webrtc/mesh.ts` を差し替えるだけで済むようUIとは分離している

比較表・料金・無料枠・拡張性の詳細: `docs/04_architecture.md`

## ぼかしの実装(重要)

`src/lib/media/blur-pipeline.ts`
`getUserMedia({video, audio:false})` → 非表示video → **canvasへ縮小+blur描画** →
`canvas.captureStream()` のトラックのみをWebRTCへ渡す。
CSS表示だけのぼかしではなく**送信される映像自体**が加工済み。
生のカメラトラックはRTCPeerConnectionに一切追加されないため、利用者がぼかしを
解除する経路が存在しない。受信側でも表示時に追いぼかしをかけて二重防御している。
(MediaStreamTrackProcessor/WebCodecs方式は対応ブラウザが限られるため、
互換性の高いCanvas 2D方式を採用。詳細: docs/04)

## セキュリティ・プライバシー(要約)

- 全テーブルRLS。学習記録・XP・バッジ・購読状態はクライアントから書込不可
  (SECURITY DEFINERのRPCのみが更新し、サーバー時刻で検証)
- 管理者判定はDB側`is_admin()`で行い、`/admin`はサーバーレイアウトでも二重チェック
- 通報・招待はDB側レート制限。決済情報はStripeのみが保持
- 音声は取得しない(`Permissions-Policy: microphone=()`)。録画機能なし。
  管理者にも映像閲覧機能なし
- リスク一覧と残存リスク: `docs/07_risks.md`

## 本番公開

- **はじめての方向けの画面操作つき手順**: `docs/12_deploy_guide.md`(約30分で公開できます)
- 技術者向けの詳細(Stripe・TURN・cron・バックアップ・障害対応): `docs/09_operations.md`

> **注意**: 本リポジトリの開発環境にはVercel/Supabaseの認証情報がないため、
> **公開URLの発行は未実施**です(上記手順書でユーザー側の操作が必要)。
> 一方、認証〜自習室〜2ブラウザWebRTC相互接続〜履歴保存までのE2E 10テストは、
> ローカル実行スタック上で**実行済み・全パス**です(`docs/11_test_results.md`)。

## 開発で置いた主な仮定

1. 参考サービスの会員専用機能は外部から確認できないため「要確認」とし(docs/01)、要件定義書を正として独自設計した
2. 無料プランの「1日2コマ」は完了/途中退出を問わず**入室2回**でカウント(乱用防止)。体験セッションは対象外
3. 予約の「欠席」は開始時刻+10分までに入室がない場合に記録
4. XPは完了時のみ付与(分×2+完了ボーナス10)。途中退出は時間の記録のみ
5. 応援者への**自動通知**と**繰り返し予約**はプレミアム限定(無料でも応援者の登録・招待は可能)
6. 予約作成時の日時入力はブラウザのタイムゾーンで解釈(表示はプロフィールのタイムゾーン)
7. DBはすべてUTC(timestamptz)で保持
8. メール確認はローカルでは無効(config.toml)。本番では必須化する(docs/09)

## ディレクトリ構成

```
docs/                    設計・運用ドキュメント (01〜11)
supabase/
  migrations/            0001 schema / 0002 functions(RPC) / 0003 RLS
  seed.sql               開発用シード (本番では使わない)
  tests/rls.test.sql     RLS検証テスト
src/
  app/                   画面 (App Router)。(marketing)/(app)/admin/room/...
  components/            UI部品・案内役「ともしび」・カメラプレビュー・グラフ
  lib/
    media/blur-pipeline.ts   強制ぼかし
    webrtc/mesh.ts           メッシュ接続 (SFU移行時の差し替え境界)
    timer.ts / xp.ts / history.ts / validation.ts  (ユニットテスト対象)
    supabase/                クライアント (browser/server/service-role)
tests/                   Vitest
e2e/                     Playwright
```

## ブランド

- サービス名: **MokuTomo(モクトモ)** — 「黙々」+「友」
- 案内役: **ともしび** — 小さなランタンの精。勉強する人の手元をそっと照らす存在
  (`src/components/tomoshibi.tsx`。SVGで実装したロゴ仮案を兼ねる)
- 配色: 深緑(安心・集中)×ランタンの暖色(親しみ)。参考サービスとは無関係の
  完全オリジナルデザイン

## ライセンス・出自について

参考サービスの名称・ロゴ・キャラクター・文章・配色・レイアウト・コードは
一切使用していません。機能・ユーザーフロー・集中を促す仕組みの考え方のみを
参考にした、完全な新規実装です。

## 同梱デモ: AI Virtual Office

`ai-office/` に、AI社員19名が並列で働く様子を可視化するバーチャルオフィスの
スタンドアロンデモ（ビルド不要・単一HTML）を同梱しています。
詳細は [ai-office/README.md](ai-office/README.md) を参照してください。
