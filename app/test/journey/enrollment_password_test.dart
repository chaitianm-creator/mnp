import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/config/enrollment_config.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/main.dart';

/// 入団手続きの「配布パスワード」照合(固定: kDistributedPassword)のテスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FixedEnrollmentCodeVerifier(照合ロジック単体)', () {
    const verifier = FixedEnrollmentCodeVerifier();

    test('完全一致で true', () async {
      expect(await verifier.verify('2026'), isTrue);
    });

    test('前後の空白は除去してから判定する', () async {
      expect(await verifier.verify('  2026  '), isTrue);
      expect(await verifier.verify('\t2026\n'), isTrue);
    });

    test('不一致・部分一致・空欄は false', () async {
      expect(await verifier.verify('2027'), isFalse);
      expect(await verifier.verify('20 26'), isFalse);
      expect(await verifier.verify('20262026'), isFalse);
      expect(await verifier.verify(''), isFalse);
      expect(await verifier.verify('   '), isFalse);
    });
  });

  group('入団手続き画面の配布パスワード照合', () {
    Future<void> pumpRegister(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(
        child: DesignKingdomApp(initialLocation: '/student-register'),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// 配布パスワード以外の必須項目をすべて埋める
    Future<void> fillOtherRequiredFields(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'てすとちゃん');
      await tester.enterText(find.byType(TextField).at(1), 'test@example.com');
      await tapAndSettle(tester, find.text('戦士').first);
      await tapAndSettle(tester, find.text('商人').last);
      await tapAndSettle(tester, find.text('デザインは はじめて'));
      await tapAndSettle(tester, find.text('POP'));
      await tester.pumpAndSettle();
    }

    bool submitEnabled(WidgetTester tester) =>
        tester
            .widget<KdPrimaryButton>(find.byType(KdPrimaryButton))
            .onPressed !=
        null;

    testWidgets('空欄: 「配布パスワードを入力してください」が表示され、入団できない',
        (tester) async {
      await pumpRegister(tester);

      // 初期状態(未入力)からメッセージが出ている
      expect(find.text('配布パスワードを入力してください'), findsOneWidget);

      // 他の必須項目をすべて入力してもボタンは無効のまま
      await fillOtherRequiredFields(tester);
      await tester.ensureVisible(find.text('この内容で入団する'));
      await tester.pumpAndSettle();
      expect(submitEnabled(tester), isFalse,
          reason: '他の必須項目がすべて入力済みでも空欄なら無効');
    });

    testWidgets('間違い: 「配布パスワードが正しくありません」が表示され、入団できない',
        (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.byType(TextField).at(2), '9999');
      await tester.pumpAndSettle();
      expect(find.text('配布パスワードが正しくありません'), findsOneWidget);

      // 空欄に戻すと空欄メッセージに切り替わる
      await tester.enterText(find.byType(TextField).at(2), '');
      await tester.pumpAndSettle();
      expect(find.text('配布パスワードを入力してください'), findsOneWidget);

      // 間違いのまま他の必須項目をすべて入力してもボタンは無効
      await tester.enterText(find.byType(TextField).at(2), '9999');
      await tester.pumpAndSettle();
      await fillOtherRequiredFields(tester);
      await tester.ensureVisible(find.text('この内容で入団する'));
      await tester.pumpAndSettle();
      expect(submitEnabled(tester), isFalse);
    });

    testWidgets('正しい: エラーが消えて入団でき、入団完了画面へ進む', (tester) async {
      await pumpRegister(tester);

      // 前後に空白があっても判定は通る
      await tester.enterText(find.byType(TextField).at(2), ' 2026 ');
      await tester.pumpAndSettle();
      expect(find.text('配布パスワードが正しくありません'), findsNothing);
      expect(find.text('配布パスワードを入力してください'), findsNothing);

      await fillOtherRequiredFields(tester);
      await tester.ensureVisible(find.text('この内容で入団する'));
      await tester.pumpAndSettle();
      expect(submitEnabled(tester), isTrue);

      await tapAndSettle(tester, find.text('この内容で入団する'));
      expect(find.textContaining('入団が完了しました'), findsOneWidget);
    });

    testWidgets('間違い→正しい入力でエラーが消えてボタンが有効になる', (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.byType(TextField).at(2), '2027');
      await tester.pumpAndSettle();
      expect(find.text('配布パスワードが正しくありません'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), '2026');
      await tester.pumpAndSettle();
      expect(find.text('配布パスワードが正しくありません'), findsNothing);

      await fillOtherRequiredFields(tester);
      await tester.ensureVisible(find.text('この内容で入団する'));
      await tester.pumpAndSettle();
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('パスワードは伏字表示で、目のアイコンで表示/非表示を切り替えられる',
        (tester) async {
      await pumpRegister(tester);

      TextField passwordField() =>
          tester.widget<TextField>(find.byType(TextField).at(2));

      expect(passwordField().obscureText, isTrue, reason: '初期状態は伏字');
      await tapAndSettle(tester, find.byIcon(Icons.visibility));
      expect(passwordField().obscureText, isFalse, reason: '目アイコンで表示');
      await tapAndSettle(tester, find.byIcon(Icons.visibility_off));
      expect(passwordField().obscureText, isTrue, reason: 'もう一度押すと伏字に戻る');
    });
  });
}
