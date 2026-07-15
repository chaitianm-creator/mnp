# 公開手順書(はじめての方向け・画面操作つき)

この手順どおりに操作すると、MokuTomoがインターネット上に公開されます。
所要時間はおよそ30〜40分です。プログラミングの知識は不要です。
無料プランの範囲で公開できます(クレジットカード登録も不要です)。

作業は3つだけです:
**① Supabase(データベース)を作る → ② Vercel(サーバー)に載せる → ③ お互いのURLを設定し合う**

---

## 準備するもの

- GitHubアカウント(このリポジトリが見られる状態)
- メールアドレス(SupabaseとVercelの登録用)

---

## ① Supabaseプロジェクトを作る(約15分)

1. https://supabase.com を開き、「Start your project」→ GitHubでサインイン
2. 「New project」をクリックし、次のとおり入力:
   - **Name**: `mokutomo`(何でも可)
   - **Database Password**: 「Generate a password」を押して、**表示されたパスワードをメモ帳に控える**
   - **Region**: `Northeast Asia (Tokyo)`
   - 「Create new project」をクリック(1〜2分待つ)
3. **データベースを作る**: 左メニューの「SQL Editor」→「New query」を開き、
   このリポジトリの次の3ファイルの中身を**この順番で**1つずつ全文コピーして貼り付け、
   それぞれ「Run」を押す(すべて「Success. No rows returned」と出ればOK):
   1. `supabase/migrations/0001_schema.sql`
   2. `supabase/migrations/0002_functions.sql`
   3. `supabase/migrations/0003_rls.sql`

   ⚠️ `supabase/seed.sql` は**実行しないでください**(開発用のテストデータです)
4. **メール確認を有効にする**: 左メニュー「Authentication」→「Sign In / Up」→
   「Email」の設定で **Confirm email がON** になっていることを確認(通常は最初からON)
5. **鍵をメモする**: 左メニュー「Project Settings」(歯車)→「API」を開き、
   次の3つをメモ帳にコピーする:

   | 画面上の名前 | あとで使う場所 |
   |---|---|
   | Project URL(`https://xxxx.supabase.co`) | Vercelの `NEXT_PUBLIC_SUPABASE_URL` |
   | `anon` `public` と書かれたキー | Vercelの `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
   | `service_role` `secret` と書かれたキー | Vercelの `SUPABASE_SERVICE_ROLE_KEY` ⚠️絶対に他人に見せない |

---

## ② Vercelで公開する(約10分)

1. https://vercel.com を開き、「Sign Up」→ **GitHubでサインイン**
2. 「Add New...」→「Project」→ このリポジトリ(`mnp`)の「Import」をクリック
   - ブランチを選べる場合は `claude/online-study-room-app-p6po9t`(または統合済みのmain)を選ぶ
3. 「Configure Project」画面で **Environment Variables** を開き、次の表のとおり1行ずつ追加する
   (NameとValueをコピーして「Add」):

   | Name | Value(値の取得場所) |
   |---|---|
   | `NEXT_PUBLIC_SUPABASE_URL` | ①-5でメモした Project URL |
   | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | ①-5でメモした anonキー |
   | `SUPABASE_SERVICE_ROLE_KEY` | ①-5でメモした service_roleキー |
   | `NEXT_PUBLIC_APP_URL` | いったん `https://example.com` (④で正しい値に直します) |
   | `NEXT_PUBLIC_STUN_URLS` | `stun:stun.l.google.com:19302` |

   ※ Stripe(有料プラン)とResend(メール)は後からでも追加できます。未設定でも
   決済・メール以外のすべての機能が動きます。
4. 「Deploy」をクリックして2〜3分待つ。「Congratulations!」と出たら
   表示されたURL(例: `https://mokutomo-xxxx.vercel.app`)をメモする。**これが公開URLです。**

---

## ③ お互いのURLを設定し合う(約5分)

**Vercel側:**
1. Vercelのプロジェクト画面 →「Settings」→「Environment Variables」
2. `NEXT_PUBLIC_APP_URL` の値を、②-4でメモした公開URLに変更して保存
3. 「Deployments」タブ → 一番上のデプロイの「…」→「Redeploy」

**Supabase側:**
1. Supabaseの画面 →「Authentication」→「URL Configuration」
2. **Site URL** に公開URL(例: `https://mokutomo-xxxx.vercel.app`)を入力
3. **Redirect URLs** に `https://mokutomo-xxxx.vercel.app/auth/callback` を追加して保存

---

## ④ 動作確認と管理者の作成(約10分)

1. 公開URLをブラウザで開く → 「無料ではじめる」から自分のアカウントを登録
   (確認メールが届くのでリンクをクリック)
2. オンボーディングを完了し、「今すぐ入室」で自習室に入れることを確認
3. **管理者にする**: SupabaseのSQL Editorで次を実行
   (メールアドレスは自分のものに置き換える):

   ```sql
   update public.profiles set role = 'admin' where id = (
     select id from auth.users where email = 'あなたのメールアドレス'
   );
   ```
4. 公開URLの末尾に `/admin` を付けて開くと、管理者画面が表示される
5. 複数端末での確認は README の「手動テスト手順(複数端末)」に沿って行う

---

## ⑤ あとから追加できる設定(任意)

| 機能 | 手順の場所 |
|---|---|
| TURNサーバー(異なるネットワーク間の接続安定化。**本格運用前に推奨**) | `docs/04_architecture.md` の比較表 → 選んだサービスのURL/ID/パスワードをVercelの `NEXT_PUBLIC_TURN_URL` / `NEXT_PUBLIC_TURN_USERNAME` / `NEXT_PUBLIC_TURN_CREDENTIAL` に設定して再デプロイ |
| Stripe(有料プラン・テストモード) | `docs/09_operations.md` の「1-3」 |
| Resend(招待・通知メール) | https://resend.com でAPIキーを発行し、Vercelに `RESEND_API_KEY` と `EMAIL_FROM` を追加 |
| WebRTC診断ページを本番でも使う | Vercelに `NEXT_PUBLIC_ENABLE_DIAGNOSTICS` = `1` を追加(管理者のみ `/debug/webrtc` を開ける) |

---

## 設定が終わったら

公開URLをこのプロジェクトの担当者(またはClaude Code)に伝えてください。
以降の作業(本番環境での動作確認・E2Eの本番向け実行・不具合修正)を引き継げます。

## うまくいかないとき

| 症状 | 対処 |
|---|---|
| デプロイが失敗する | Vercelの「Deployments」→ 失敗したデプロイ → ログの赤い行を確認。環境変数の入力ミス(前後の空白など)が最多 |
| 登録メールが届かない | Supabase無料プランのメールは1時間数通の制限あり。迷惑メールフォルダも確認 |
| ログイン後に真っ白/ループする | ③のSite URL・Redirect URLsの設定漏れ |
| 自習室で相手の映像が「接続中…」のまま | 異なるネットワーク間ではTURN未設定が原因のことが多い(⑤参照) |
