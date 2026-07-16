# AI CREATIVE OFFICE

> **AI社員と一緒に働く、次世代のWeb制作会社。**

複数のAI社員(エージェント)が営業・Web制作・管理業務を並列で進める「AIバーチャル制作会社」のダッシュボードアプリです。
社長(あなた)はCEO AIへ指示を出し、AI社員がバーチャルオフィスで働く様子をリアルタイムで確認できます。

**現在のフェーズ: Phase 1(基盤と画面 + モックデータ + デモモード)**

## 起動方法

```bash
cd ai-creative-office
npm install
npm run dev
# → http://localhost:3100
```

初回アクセス時に初期設定画面(/setup)が表示されます。設定後、バーチャルオフィスへ移動します。

## 主な画面

| パス | 画面 |
|---|---|
| `/dashboard` | 経営ダッシュボード(KPI + 8種のグラフ) |
| `/office` | バーチャルオフィス(AI社員18名の稼働状況、クリックで詳細+個別指示) |
| `/chat` | 社長指示チャット(CEO AIが実行プランを提案 → 承認後に開始) |
| `/approvals` | 承認センター(外部送信は承認なしに実行されない) |
| `/agents` | AI社員一覧 / `/agents/[id]` 詳細 |
| `/tasks` | タスク管理(カンバン / 一覧 / AI社員別) |
| `/sales/leads` | 営業リスト・キャンペーン / `/sales/inquiries` 問い合わせ / `/sales/deals` 商談 |
| `/projects` | 制作案件(16工程の進捗表示) |
| `/marketing/sns` `/marketing/seo` | SNS投稿管理 / SEO・AIO管理 |
| `/reports` | レポート(日報生成・CSV出力) |
| `/billing` | AI利用料金(円換算・為替レート変更可) |
| `/logs` `/errors` `/integrations` `/settings` | 活動ログ / エラー / 外部連携 / 設定 |

## デモモード

- 設定画面(`/settings`)でON/OFFできます(初期状態: ON)
- ONの間、2.5秒ごとにAI社員の状態・タスク進捗・活動ログ・AI利用料金が自動更新されます
- データはlocalStorageに永続化されます。「モックデータを初期化する」でリセットできます

## 安全設計

メール送信・フォーム送信・SNS投稿・公開作業などの外部処理は、
`下書き → 承認待ち → 承認済み → 実行中 → 完了 / 失敗 / 停止` のステータスで管理され、
**承認センターで社長が承認するまで実行されません**。初期版は実在企業への自動送信・自動架電を行いません。

## 技術構成

- Next.js 14 (App Router) / TypeScript / Tailwind CSS
- Zustand(状態管理 + localStorage永続化)
- Framer Motion(オフィスアニメーション)/ Recharts(グラフ)/ lucide-react
- Supabase(Phase 4-5で接続予定。スキーマ設計は `supabase/migrations/0001_schema.sql`)

## 今後のフェーズ

- Phase 2: 営業機能の深掘り(キャンペーン実行・返信管理)
- Phase 3: Web制作機能(原稿・ワイヤーフレーム・レビューの実データ管理)
- Phase 4: AI実行基盤(CEO AIオーケストレーター、Claude API接続、依存タスクの実実行)
- Phase 5: 外部連携(Gmail / Google Calendar / SNS / Vercel / Figma / 電話API)
