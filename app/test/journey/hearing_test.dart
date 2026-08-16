import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/main.dart';

/// パン屋さんヒアリング(/hearing)のシナリオ通しテスト。
/// GOODの選択肢を選びながら最後まで進み、完了フォームが出ることを確認。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ヒアリング: 会話と選択肢を進めて完了フォームに到達する',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(const ProviderScope(
      child: DesignKingdomApp(initialLocation: '/hearing'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('チラシ制作のヒアリングをしてみよう！'), findsOneWidget);

    // GOOD選択肢(出現順)
    const goods = [
      '「チラシを作ろうと思ったきっかけから、お聞きしてもいいですか？」',
      '「では、これから増えたら嬉しいお客様はいますか？」',
      '「お客様からもクリームパンについて何か言われますか？」',
      '「では、今回は実際にお店へ来てもらうことを一番の目的にしましょう」',
      '「ちなみに、初めての方が「行ってみよう」と思えるような特典を付けることはできますか？」',
      '「では、“近所に住んでいるけれど、まだこのパン屋さんを知らない子育て世代”を中心に考えて制作しますね。」',
    ];
    var g = 0;

    // BADを1回選んでフィードバックが出ることも確認
    await tester.ensureVisible(
        find.text('「どんなデザインのチラシにしたいですか？」'));
    await tester.tap(find.text('「どんなデザインのチラシにしたいですか？」'));
    await tester.pumpAndSettle();
    expect(find.text('BAD △'), findsOneWidget);
    expect(find.text('次へ'), findsNothing); // BADでは進めない

    for (var i = 0; i < 80; i++) {
      // 完了時は最下部の「次に進む」ボタンが見える
      if (tester.any(find.text('次に進む'))) break;
      if (tester.any(find.text('次へ'))) {
        await tester.tap(find.text('次へ'));
      } else {
        // 選択肢: GOODを選ぶ → 次へが出る
        final good = find.text(goods[g]);
        await tester.ensureVisible(good.last);
        await tester.tap(good.last);
        g++;
      }
      await tester.pumpAndSettle();
    }

    // 完了フォームと次のクエスト(上に遡って確認)
    expect(find.text('次に進む'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('来店のきっかけ'), -200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('来店のきっかけ'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('パン屋のお困りごとは？'), -200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('パン屋のお困りごとは？'), findsOneWidget);
  });
}
