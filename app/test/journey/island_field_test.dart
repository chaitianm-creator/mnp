import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/main.dart';

/// 実践デザイナー島の村フィールド試作(/island)のスモークテスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('村フィールドが表示され、タップ移動でパン屋に着くと会話が出る',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: DesignKingdomApp(initialLocation: '/island'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('実践デザイナー島（試作）'), findsOneWidget);
    expect(find.text('タップで移動'), findsOneWidget);

    // マップ(CustomPaint)上のパン屋入口タイル付近をタップ → 歩行 → 会話
    final paintFinder = find.byType(CustomPaint).first;
    final topLeft = tester.getTopLeft(paintFinder);
    final size = tester.getSize(paintFinder);
    final tile = size.width / 13; // cols=13
    // 入口 D は (x=10, y=2)
    await tester.tapAt(topLeft + Offset(tile * 10.5, tile * 2.5));
    // 歩行タイマー(170ms/歩)を進める(最長で 13+18 歩ぶん)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 170));
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('誰も入ってきてくれない'), findsOneWidget);
    expect(find.text('悩みを聞く（クエストへ）'), findsOneWidget);

    // 「また今度」で会話を閉じられる
    await tester.tap(find.text('また今度'));
    await tester.pumpAndSettle();
    expect(find.textContaining('誰も入ってきてくれない'), findsNothing);
  });
}
