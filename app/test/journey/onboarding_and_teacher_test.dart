import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/main.dart';

/// 初回起動フロー(出会い→入団手続き→完了→ホーム)と先生用管理画面のテスト。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('表紙 → オンボーディング1〜17 → 実践デザイナー島(マップ)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(const ProviderScope(
      child: DesignKingdomApp(initialLocation: '/welcome'),
    ));
    await tester.pumpAndSettle();

    // SC-02 表紙(全画面イラスト) → 「スタート」でオンボーディングへ
    expect(find.text('スタート ▶'), findsOneWidget);
    await tapAndSettle(tester, find.text('スタート ▶'));

    // 1〜13ページを全画面タップで進む
    expect(find.text('1 / 15'), findsOneWidget);
    for (var i = 1; i < 14; i++) {
      await tapAndSettle(tester, find.bySemanticsLabel('次へ'));
      expect(find.text('${i + 1} / 15'), findsOneWidget);
      if (i + 1 == 10) {
        // ページ10には「島へ行く」ボタンが表示される
        expect(find.text('島へ行く'), findsOneWidget);
      }
    }
    // 14: 選択肢ページ(全画面タップでは進まない)
    expect(find.bySemanticsLabel('次へ'), findsNothing);
    expect(find.text('どう答える？'), findsOneWidget);
    // 不正解 → フィードバックが出て前進しない
    await tapAndSettle(
        tester, find.text('パンがおいしくないんじゃないですか？'));
    expect(find.text('14 / 15'), findsOneWidget);
    expect(find.textContaining('しょんぼり'), findsOneWidget);
    // 正解 → 15へ
    await tapAndSettle(
        tester, find.text('そんなの大変ですね！一緒に考えます！'));
    expect(find.text('15 / 15'), findsOneWidget);
    // 最終ページ(15 ミッション発生)のみ「ゲーム開始」ボタン
    expect(find.text('ミッション発生！'), findsOneWidget);
    await tapAndSettle(tester, find.text('ゲーム開始'));

    // 実践デザイナー島(マップ)へ遷移
    expect(find.text('はじまりの街（みぽりん村）'), findsOneWidget);
  });

  testWidgets('出会い → 入団手続き → 入団完了 → ホームメニュー',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(const ProviderScope(
      child: DesignKingdomApp(initialLocation: '/meeting'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('はじめまして'), findsOneWidget);

    // セリフをタップ送り(4行目で入団手続きボタンが出る)
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
    }
    await tapAndSettle(tester, find.text('入団手続きへすすむ'));

    // SC-04 入団手続き
    expect(find.textContaining('入団手続き'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'てすとちゃん');
    await tester.enterText(find.byType(TextField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(2), '2026');
    await tester.pumpAndSettle(); // 配布パスワードの照合を待つ

    // 診断: つよみ=戦士 / にがて=商人
    await tapAndSettle(tester, find.text('戦士').first);
    await tapAndSettle(tester, find.text('商人').last);
    // 経験
    await tapAndSettle(tester, find.text('デザインは はじめて'));
    // 学びたい分野(複数選択)
    await tapAndSettle(tester, find.text('POP'));
    await tapAndSettle(tester, find.text('バナー'));

    // 入団する → SC-05 入団完了
    await tapAndSettle(tester, find.text('この内容で入団する'));
    expect(find.textContaining('入団が完了しました'), findsOneWidget);
    expect(find.text('てすとちゃん'), findsOneWidget);

    // 冒険へ行く → ホーム(ヘッダーにニックネーム + ロック中の今日の依頼)
    await tapAndSettle(tester, find.text('冒険へ行く'));
    expect(find.text('てすとちゃん'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('練習3つで解放'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('練習クエスト'), findsOneWidget);
    expect(find.text('練習3つで解放'), findsOneWidget);
  });

  testWidgets('先生ロール: ダッシュボード → 生徒一覧 → 詳細(一時停止は確認ダイアログ)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    final teacher = UserAccount(
      role: UserRole.teacher,
      nickname: 'みぽりん',
      email: 'teacher@example.com',
      onboardingCompleted: true,
      createdAt: DateTime(2026, 7, 1),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(teacher)],
      child: const DesignKingdomApp(initialLocation: '/teacher'),
    ));
    await tester.pumpAndSettle();

    // ダッシュボード集計
    expect(find.text('先生ダッシュボード'), findsOneWidget);
    expect(find.text('生徒数'), findsOneWidget);
    expect(find.text('添削待ち'), findsOneWidget);

    // 生徒一覧 → 検索(ダッシュボードはGridも持つため対象スクロールを明示)
    await tester.scrollUntilVisible(find.text('生徒一覧を見る'), 200,
        scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('生徒一覧を見る'));
    expect(find.text('さくらこ'), findsOneWidget);
    expect(find.text('ゆうた'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'さくら');
    await tester.pumpAndSettle();
    expect(find.text('さくらこ'), findsOneWidget);
    expect(find.text('ゆうた'), findsNothing);

    // 生徒詳細(メールはマスク表示 = PII保護)
    await tapAndSettle(tester, find.text('さくらこ'));
    expect(find.text('s***@example.com'), findsOneWidget);
    expect(find.text('提出物'), findsOneWidget);

    // 一時停止: 確認ダイアログを経由し、キャンセルできる
    // (メモのTextFieldもScrollableを持つため対象を明示)
    await tester.scrollUntilVisible(find.text('アカウントを一時停止する'), 300,
        scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('アカウントを一時停止する'));
    expect(find.text('ほんとうに一時停止する？'), findsOneWidget);
    await tapAndSettle(tester, find.text('やめる'));
    expect(find.text('一時停止中'), findsNothing);

    // 実行すると停止状態になる(バッジは上部プロフィールにあるので上へスクロール)
    await tapAndSettle(tester, find.text('アカウントを一時停止する'));
    await tapAndSettle(tester, find.text('一時停止する'));
    await tester.scrollUntilVisible(find.text('一時停止中'), -300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('一時停止中'), findsOneWidget);
  });

  testWidgets('生徒ロールでは先生ページが見えない(表示ガード)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final student = UserAccount(
      role: UserRole.student,
      nickname: 'せいと',
      email: 'student@example.com',
      onboardingCompleted: true,
      createdAt: DateTime(2026, 7, 1),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(student)],
      child: const DesignKingdomApp(initialLocation: '/teacher'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('このページは先生専用だよ'), findsOneWidget);
    expect(find.text('先生ダッシュボード'), findsNothing);
  });
}
