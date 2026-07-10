# デザイン王国 — Phase 12: テスト README

## 追加されたもの

| 種別 | ファイル | 内容 |
|---|---|---|
| ジャーニーテスト | `app/test/journey/core_journey_test.dart` | ジャーニー1の完全自動化(2タップ開始→全ステップ→良い点が先の検証→納品演出→受注予約→あと1クエスト→**2回目非表示の検証**→ホーム反映)+中断確認。DEMOモードで`flutter test`のみで実行可能 |
| ルールテスト | `firebase/tests/firestore_rules.test.ts` | 9ケース: XP/コイン/ストリーク直接改ざん拒否、設定と報酬の混在更新拒否、delivered/reviewed直接遷移拒否、自作添削の注入拒否、review_prompts読み取り拒否、実績の自己付与拒否 |
| 結合テスト | `functions/test/deliverQuest.test.ts` | 4ケース: 報酬・実績・進捗の全更新検証、**2回呼んでも報酬が増えない冪等性**、not-reviewed拒否、未認証拒否 |
| CI | `.github/workflows/ci.yml` | flutter / functions / emulator-tests / content の4ジョブ。PRごとに全自動実行 |
| テスト計画書 | `docs/phase12_test_plan.md` | テストピラミッド(自動48ケース)、★★★38ストーリーのカバレッジ対応表、実機QAチェックリスト、Phase 13への申し送り |

## テスト作成中に発見・修正したバグ

**最終ステップがSubmitStep以外のクエスト(3分ミニ依頼)が添削に到達できず進行が止まる** — `quest_play_page.dart`のonAnsweredを修正し、ジャーニーテストに回帰ケースとして固定化済み。「あと1クエスト」の主役である3分依頼が完走できないという、リテンション設計に直撃する不具合でした。テストを書く価値の実証です。

## 実行方法

```bash
# ネットワーク不要(DEMOモード)
cd app && flutter test                    # 状態機械6 + ジャーニー2
cd ../functions && npm install && npm test # domain 14 + quality 13

# エミュレータ必要
firebase emulators:exec --only firestore --project design-kingdom-test '
  (cd firebase/tests && npm install && npm test) &&
  (cd functions && npm run test:integration)'
```

## リリース判定への申し送り(詳細: docs/phase12_test_plan.md §5)
1. オンボーディング(SC-01〜06)未実装 — D1の生命線、Phase 13最優先
2. v1.0スコープ再判断の提案: エリア①のみの「先行体験版」+ストア審査必須の設定/退会実装
3. ゴールデンセット20件への拡充(現在2件)・ドット絵アセット
