# デザイン王国 — Phase 9(前半): Flutter実装 README

## このマイルストーンで実装したもの

**DEMOモードで動く縦切りの1本**: ホーム(SC-10) → 依頼詳細(SC-20) → ヒアリング(SC-21) → 選択/並び替え(SC-22) → 提出 → 添削待ち(SC-25) → 添削結果(SC-26) → リテイク/納品 → 納品完了+明日の予告(SC-27/28簡易版)。

コンテンツはマルコ第1話(7分)とリナのミニ依頼(3分)を同梱。Firebase不要で全フローを体験できます。

```
app/lib/
├── main.dart                          # ルーター + アプリ(ライトテーマ固定)
├── core/
│   ├── theme/kd_colors.dart           # Phase 8 §3 実測トークン
│   ├── theme/kd_theme.dart            # Zen Maru Gothic / DotGothic16
│   └── widgets/kd_widgets.dart        # KdParchmentCard/KdChip/KdPrimaryButton/KdProgressBar/KdDialogueBubble
└── features/
    ├── home/presentation/home_page.dart
    └── quest/
        ├── domain/entities/quest.dart              # QuestStatus(11状態)/QuestStep(sealed)
        ├── data/quest_repository.dart              # 抽象 + FakeQuestRepository(DEMO)
        └── presentation/
            ├── view_models/quest_play_view_model.dart  # ★Phase 4状態機械の実装体
            ├── pages/quest_play_page.dart              # statusへのswitchで全フェーズ描画
            └── widgets/step_renderer.dart              # sealedへのswitchで問題形式振り分け
app/test/quest_play_view_model_test.dart             # 状態機械の不変条件テスト6本
```

## 動かし方(要 Flutter 3.22+)

```bash
cd app
flutter pub get
flutter test          # 状態機械テスト
flutter run           # DEMOモードで起動(Firebase不要)
```

**注意: この環境ではFlutter SDK・ネットワークが利用できないため、本コードは未コンパイルです。**
`flutter analyze` / `flutter test` をお手元で実行し、エラーがあれば共有してください(次ターンで修正します)。CI(Phase 7 §7)導入後は自動化されます。

## 設計との対応(レビュー観点)

1. **メソッド名 = 状態機械の矢印**: `accept()/submitStep()/submitForReview()/retake()/deliver()`(Phase 7 §4の語彙一致ルール)
2. **状態が画面を決める**: `QuestPlayPage` は `status` への switch のみ。画面遷移ロジックが状態機械の外に漏れていない
3. **防御的遷移**: 不正な状態からの `deliver()` 等は no-op(テストで担保)。本番はさらに Functions 側でも検証(Phase 6)
4. **世界観トークン**: 色は Phase 8 の実測値。影なし・下辺2px段差、黒チップ=情報、エラー文言も世界観内(「荷物が届かなかったみたい」)
5. **UXライティング**: フィードバックは常に励まし+理由(「色はまだ早いかも。まず目的から聞いてみよ？」)

## 簡略化した点(意図的な負債、Phase 9後半〜10で解消)

| 項目 | 現状 | 本実装 |
|---|---|---|
| freezed/riverpod codegen | 手書きimmutable | build_runner導入時に移行 |
| 画像アップロード | テキスト提出で代替 | image_picker+圧縮+Storage(Phase 10) |
| 中断再開の永続化 | メモリのみ | quest_local_source(JSON)+Firestore同期 |
| SC-27/28 | 1画面に統合 | 納品演出オーバーレイ+終了画面を分離、受注予約の実体化 |
| ボトムタブ | ホームのみ実装 | マップ/スキル/私(Phase 9後半) |
| 添削 | Fake(2秒待ち) | Claude APIパイプライン(Phase 11) |

## 次のマイルストーン(Phase 9後半)

1. SC-27/28の分離と納品演出(KdCelebrationOverlay)
2. 世界マップ(SC-30)+エリア詳細(SC-31)の骨格
3. quest_local_source(中断再開)
4. freezed/riverpod_generator への移行 + import_lint 導入

---

# Phase 9(後半) 追加実装

## 追加されたもの

1. **SC-27/28の分離**: 納品演出(`KdCelebrationOverlay`: タップスキップ・reduced motion対応・数値テキスト併記) → セッション終了画面(①今日の成果 ②昨日の自分との比較 ③明日の予告+**受注予約** ④**あと1クエスト**)
2. **「あと1クエスト」1回制限を遷移で強制**: `oneMoreUsedThisSession` により2回目はボタン自体が存在しない(Phase 4 §3)
3. **受注予約(1件制約)**: 予約するとホーム最上部に予約カードが固定表示
4. **世界マップ(SC-30)+エリア詳細(SC-31)骨格**: 8エリア(Phase 8 §1.2確定マッピング)、未解放=雲+ロック、発展3段階(納品0/6/12件)がリアルタイム反映
5. **中断再開の永続化(US-E2-06)**: `quest_local_source`(shared_preferences+JSON)。アプリ強制終了→再起動で「おかえり！つづきからだよ」
6. **4タブシェル**: StatefulShellRoute(ホーム/マップ/スキル/私)。各タブ独立スタック(Phase 4 §7-1)、クエストはシェル外フルスクリーン
7. **UserProgress**: XP/レベル/コイン/ストリーク/鍵/納品履歴/エリア発展のメモリ状態(Phase 10でusers/{uid}購読に差し替え)

## 検証手順(お手元で)

```bash
flutter pub get && flutter analyze && flutter test && flutter run
```

体験シナリオ: マルコ依頼を納品 → 演出をタップ → 受注予約 → 「あと1クエスト」でリナの3分依頼 → 納品 → SC-28に「あと1クエスト」ボタンが**出ない**ことを確認 → マップタブで はじまりの街の発展が進んでいることを確認 → クエスト途中でアプリをkillして再起動 → 続きから再開。

## 未実装(次マイルストーン = Phase 10)

Firebase接続(Auth匿名→本認証/Firestoreリポジトリ実装/App Check)、オンボーディングフロー(SC-01〜06)、手紙ボックス、freezed/riverpod codegen移行。
