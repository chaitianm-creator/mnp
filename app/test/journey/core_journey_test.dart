import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/main.dart';

/// Phase 12: コアジャーニーテスト(Phase 2 付録A ジャーニー1の自動化)。
/// DEMOモード(Firebase不要)で flutter test として実行できる。
///
/// 検証するユーザーストーリー:
///  US-E2-01(2タップ開始) / US-E2-04(受注→ヒアリング→制作→提出→添削→納品)
///  US-E3-02(良い点が先) / US-E1-07(受注予約) / Phase 4 §3(あと1クエスト1回制限)
///  + 練習クエスト3つクリア済み状態からの「今日の依頼」導線
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 練習クエスト3つクリア済み = 「今日の依頼」解放済みの状態
  const practiceDone = UserProgress(
    streak: 1,
    xp: 45,
    deliveredQuestIds: {'q_practice_01', 'q_practice_02', 'q_practice_03'},
    areaDelivered: {'area_01_hajimari': 3},
  );

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'daily_unlock_celebrated': true});
    // ホームの常時ゆれアニメーションを止める(reduce motion対応を利用)
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [initialProgressProvider.overrideWithValue(practiceDone)],
      child: const DesignKingdomApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('ジャーニー1: 初回納品 → 予約 → あと1クエスト → 2回目は非表示',
      (tester) async {
    await pumpApp(tester);

    // ── SC-10 ホームメニュー(キャラ中心のゲーム様式) ──
    expect(find.text('練習クエスト'), findsOneWidget);
    expect(find.text('今日の依頼'), findsOneWidget);
    expect(find.text('みぽりん先生'), findsOneWidget);

    // タップ1: メニュー「今日の依頼」 → 依頼リスト(エリアバンドはここで確認)
    await tapAndSettle(tester, find.text('今日の依頼'));
    expect(find.text('きょうの依頼'), findsOneWidget);
    expect(find.text('はじまりの街（みぽりん村）'), findsOneWidget);
    expect(find.textContaining('もちもち王国パン'), findsOneWidget);

    // タップ2: 依頼リストの行 → SC-20 依頼詳細
    await tapAndSettle(tester, find.textContaining('もちもち王国パン'));
    expect(find.text('この仕事を引き受ける'), findsOneWidget);

    // 受注 → SC-21 ヒアリング
    await tapAndSettle(tester, find.text('この仕事を引き受ける'));
    expect(find.text('まずマルコさんに何を聞く？'), findsOneWidget);

    // s1: ベストな質問を選ぶ → みぽりん先生のフィードバック
    await tapAndSettle(tester, find.text('誰に買ってほしいパンですか？'));
    expect(find.textContaining('ターゲットの確認は最初の一歩'), findsOneWidget);

    // s2: キャッチコピー選択
    await tapAndSettle(tester, find.text('のび〜る幸せ、もっちもち。'));

    // s3: 並び替え(そのまま決定 → 「おしい」フィードバックでも前進する)
    await tapAndSettle(tester, find.text('これでけってい！'));

    // s4: 提出(DEMO=テキスト)
    await tester.enterText(
        find.byType(TextField), 'キャッチコピーを大きく、価格を白抜きにしたPOPです');
    await tester.tap(find.text('みぽりん先生に提出する'));
    await tester.pump(); // 遷移直後のフレーム(pumpAndSettleだと添削完了まで進んでしまう)

    // SC-25 添削待ち(Fakeは2秒) → SC-26 添削結果
    expect(find.textContaining('ふむふむ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // US-E3-02: 「よかったところ」が「もっと良くなるところ」より先に表示
    final goodY = tester.getTopLeft(find.text('よかったところ')).dy;
    final impY = tester.getTopLeft(find.text('もっと良くなるところ')).dy;
    expect(goodY < impY, isTrue, reason: '良い点が先(US-E3-02)');
    await tester.scrollUntilVisible(find.textContaining('リテイク'), 200);
    expect(find.textContaining('リテイク'), findsOneWidget);

    // 納品 → SC-27 演出(deliverQuest の擬似遅延 400ms を明示的に進める)
    await tester.ensureVisible(find.text('納品する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('納品する'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('納品完了！'), findsOneWidget);
    expect(find.textContaining('XP +50'), findsOneWidget);

    // 演出タップスキップ → SC-28 セッション終了
    await tapAndSettle(tester, find.text('タップしてつづける'));
    expect(find.text('きょうのまとめ'), findsOneWidget);
    expect(find.text('あしたの予告'), findsOneWidget);

    // US-E1-07: 受注予約
    await tapAndSettle(tester, find.text('この依頼を受注予約する'));
    expect(find.textContaining('予約したよ'), findsOneWidget);

    // あと1クエスト(1回目は表示される)
    expect(find.text('あと1クエストだけやる（3分）'), findsOneWidget);
    await tapAndSettle(tester, find.text('あと1クエストだけやる（3分）'));

    // リナの3分依頼を最後まで(最終ステップが選択式でも添削へ進む=修正済みバグの回帰)
    await tapAndSettle(tester, find.text('この仕事を引き受ける'));
    await tapAndSettle(tester, find.text('太めの丸ゴシック・濃い色文字'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('納品する'), 200);
    await tester.ensureVisible(find.text('納品する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('納品する'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('タップしてつづける'));

    // Phase 4 §3: 2回目のSC-28には「あと1クエスト」ボタン自体が存在しない
    expect(find.text('きょうのまとめ'), findsOneWidget);
    expect(find.text('あと1クエストだけやる（3分）'), findsNothing);

    // ホームメニューへ → 「今日の依頼」を開き直すと予約バナー + 2件チェック済み
    await tapAndSettle(tester, find.text('きょうはここまで！ホームへ'));
    await tapAndSettle(tester, find.text('今日の依頼'));
    expect(find.textContaining('予約したお仕事'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3)); // サマリー1 + 依頼2
  });

  testWidgets('中断確認ダイアログは1タップで抜けられる(Phase 4 §7-2)', (tester) async {
    await pumpApp(tester);
    await tapAndSettle(tester, find.text('今日の依頼'));
    await tapAndSettle(tester, find.textContaining('もちもち王国パン'));
    await tapAndSettle(tester, find.byIcon(Icons.close));
    expect(find.text('ここまでにする？'), findsOneWidget);
    await tapAndSettle(tester, find.text('あとで'));
    expect(find.text('練習クエスト'), findsOneWidget); // ホームメニューへ戻れた
  });

  testWidgets('練習クエスト未クリアでは「今日の依頼」はロックされる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(const ProviderScope(child: DesignKingdomApp()));
    await tester.pumpAndSettle();

    // ロック中の案内文
    expect(find.text('練習3つで解放'), findsOneWidget);
    await tapAndSettle(tester, find.text('今日の依頼'));
    expect(find.textContaining('練習クエストを3つクリアすると解放'), findsOneWidget);
  });
}
