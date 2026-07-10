# デザイン王国 — Phase 11: AI添削 本稼働 README

## 実装内容

### 1. 添削パイプライン本稼働版(`functions/src/review/pipeline.ts`)
```
review_jobs onCreate
 → 0. 提出物取得: Storage画像ダウンロード(base64/mediaType判定) or テキスト隔離
      + SHA-256ハッシュキャッシュ(同一提出はAPI呼び出しゼロで再返却)
 → 1. モデレーション(Haiku・fail-closed): 不適切/無関係は優しく差し戻し
 → 2. プロンプト取得(review_prompts/{id}、なければ既定みぽりん先生)
      + クエスト文脈注入(brief + ユーザーのヒアリング回答 → hearing軸の評価材料)
 → 3. 添削生成(Sonnet・画像入力対応): パース失敗/トーン違反は再生成(最大2回)
 → 4. reviewed反映 + キャッシュ保存 + promptVersion記録(👍率のバージョン別監視用)
```

### 2. 品質防衛の純関数化(`quality.ts` + テスト13ケース)
- `violatesTone`: 禁止語12語+命令形パターン+**goodPoints空は違反**(良い点が先の担保)
- `clampScores`: 範囲外/非数値/欠損のクランプ(注入対策)
- `isolateSubmissionText`: **提出物内のデリミタ偽装(`</submission>`)を除去**してから隔離
- `parseModeration`: 判定不能は**fail-closed**(安全でない扱い)

### 3. みぽりん先生プロンプト(`content/review_prompts/`)
- `rp_pop_basic.yaml`: POP専用。3秒ルール/ジャンプ率/ターゲット適合/可読性/優先順位の5観点、初学者向けスコア較正(0-1原則不使用、deadline提出時点4以上)、口調規則、注入無視の明示
- `rp_default.yaml`: 汎用フォールバック
- publish.tsがreview_promptsコレクションへ投入(version自動加算)

### 4. 品質評価の仕組み
- `docs/phase11_review_quality.md`: **L1形式/L2トーン=自動100%、L3有用性=人手4.0、L4=👍率80%**の4層ゲートと、プロンプト変更のリリースフロー(評価→PR添付→段階公開→バージョン別👍監視→ロールバック)
- `eval_harness.ts`: ゴールデンセットを3回ずつ実行しL1/L2自動判定+Markdownレポート。**注入耐性ケースと典型ミスケースの初期2件を同梱**(残り18件は§2の設計に沿って運用整備)

### 5. 運用系
- `costGuard`(毎時): 当日の添削数×概算単価が予算超過→reviewDailyLimitを半減(**最低3回/日は死守**)+ops_alertsへ記録
- `redeliverReview`: review_failed案件の再添削(モデレーション差し戻しは再提出必須)

### 6. Flutter側
- `SubmissionUploader`: 画像選択→**1280px/80%圧縮→Storage**(users/{uid}/submissions/)
- 提出ステップUI: 本番モード=画像選択(未選択は提出ボタン無効)/DEMO=従来のテキスト。エラーも世界観文言

## 検証手順

```bash
cd functions && npm install && npm test        # quality含む27テスト
ANTHROPIC_API_KEY=... npm run eval -- --prompt rp_pop_basic   # 実API評価(要キー)
cd ../app && flutter analyze                    # 画像提出UIの型検証
```

## 次フェーズ
Phase 12(テスト): コアジャーニーE2E(integration_test)、Firestoreルールのエミュレータテスト、deliverQuestの結合テスト。その後Phase 13(リリース準備)。
