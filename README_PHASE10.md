# デザイン王国 — Phase 10: Firebase実装 README

## 実装内容

### 1. セキュリティルール(`firebase/`)
- **firestore.rules**: Phase 5 §6 の「進行と設定はクライアント、報酬と実績はFunctionsのみ」を`diff().affectedKeys().hasOnly()`で厳密に実装。`review_prompts`は完全非公開(添削プロンプト流出防止)。`quest_progress`のdelivered/reviewed遷移はクライアント書き込み不可
- **storage.rules**: 提出画像は本人のみ・5MB上限・image/*のみ
- **firestore.indexes.json**: Phase 5 §8 の複合インデックス3本

### 2. Cloud Functions(`functions/`、TypeScript strict)
| 関数 | 内容 |
|---|---|
| `deliverQuest` | **報酬付与の唯一の入口**。1トランザクションでXP/レベル/ストリーク/ドロップ/エリア発展/絆/バッジ/daily_log。冪等キー`{questId}_{retakeCount}`、既納品は保存済みoutcomeを再返却(安全リトライ) |
| `acceptQuest` | 解放検証+同時InProgress 1件制約(ボス例外)+予約消化 |
| `submitForReview` | 日次添削上限(コスト防衛)→review_jobs作成→status:reviewing |
| `processReview` | 添削パイプライン骨格: プロンプト取得→Claude API(注入対策の隔離デリミタ)→JSONパース→スコアclamp→**トーン検査**(禁止語で再生成)→失敗時はreview_failed(進行を止めない) |
| `initUser` | 初期ユーザードキュメント(冪等) |
| `dailyBatch` | 04:00 JST。ストリーク判定(お守り自動消費→手紙/リセット→復帰フラグ)。ページング処理 |

**domain/game_logic.ts は純関数**(時刻・乱数は引数注入)で、vitestテスト14ケース付き: レベル曲線の境界値、ストリークの連続/同日/途切れ、お守り消費、ドロップの決定的検証、バッジ冪等。

### 3. コンテンツパイプライン(`content/`)
- `q_marco_01.yaml`(アプリのFakeと同一内容 — 本番はYAMLが正)
- `validate.ts`: JSONスキーマ+「isDeliveryStep必須」「hearing必須(3分ミニ以外)」+参照整合性 → **CIでPRマージ前に機械検証**
- `publish.ts`: 内容ハッシュで差分検知、変更時のみversion自動加算(進行中クエストはquestVersion固定で保護)

### 4. Flutter側
- `FirestoreQuestRepository`: Callable呼び出し+DTOマッピング(Phase 5スキーマ1:1)。**submitForReviewはquest_progressをポーリング**(60秒打ち切り→reviewFailed) — 強制終了→復帰と同じ経路(Phase 4)
- `firebase_bootstrap.dart`: 匿名認証(登録前体験→後で本認証リンク)+initUser
- **切替は `--dart-define=USE_FIREBASE=true` のProviderオーバーライドのみ**。DEMOモードは今まで通りFirebaseなしで動作

## セットアップ手順(お手元で)

```bash
# 1. Firebaseプロジェクト作成後
firebase login && firebase use <project-id>
flutterfire configure   # → firebase_options.dart 生成、bootstrapのTODOを差し替え

# 2. ルール・インデックスのデプロイ
firebase deploy --only firestore,storage

# 3. Functions
cd functions && npm install && npm test && npm run build
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase deploy --only functions

# 4. コンテンツ投入
cd ../content && npm install && npm run validate
GOOGLE_APPLICATION_CREDENTIALS=sa.json npm run publish

# 5. アプリ(本番モード)
cd ../app && flutter run --dart-define=USE_FIREBASE=true
```

**エミュレータでの統合確認**: `firebase emulators:start` → アプリ側でuseFunctionsEmulator/useFirestoreEmulatorを向ける(次マイルストーンでdart-define化)。

## 未検証事項(この環境の制約)
ネットワーク・SDKなしのため npm install / tsc / vitest / flutter analyze は未実行。お手元でのエラーはそのまま貼っていただければ即修正します。特にfirebase-functions v2のimportパスとFieldValue.arrayUnionの空配列回避(__noop__)は実機確認を推奨。

## 次フェーズ
Phase 11(AI添削の本稼働): 画像入力接続・モデレーション実装・rp_pop_basicプロンプトのチューニング・添削品質評価基準・costGuard。
