import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';

/// タイポグラフィ / レイアウト・形状 (PRO NAVI クリーンスタイル)
///  - 本文・見出しとも Zen Maru Gothic(丸ゴシック)で統一
///  - UIはシンプル(白カード+薄枠+パステル)。ドット体はキャラ世界の演出用に残す
///  - ダークモード非対応(ライト固定)
abstract final class KdTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final body = GoogleFonts.zenMaruGothicTextTheme(base.textTheme)
        .apply(bodyColor: KdColors.textPrimary, displayColor: KdColors.textPrimary);

    return base.copyWith(
      scaffoldBackgroundColor: KdColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: KdColors.primaryAction,
        secondary: KdColors.gold500,
        surface: KdColors.surface,
        onSurface: KdColors.textPrimary,
        error: KdColors.lava500,
      ),
      textTheme: body.copyWith(
        headlineSmall: body.headlineSmall?.copyWith(
            fontSize: 19, fontWeight: FontWeight.w800, color: KdColors.textPrimary),
        bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.65),
        bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.65),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: KdColors.background,
        foregroundColor: KdColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: body.titleMedium?.copyWith(
            fontSize: 16, fontWeight: FontWeight.w800, color: KdColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFDF3E3),
        indicatorColor: KdColors.pink100,
        labelTextStyle: WidgetStatePropertyAll(body.labelMedium?.copyWith(
            fontSize: 12, color: KdColors.ink900, fontWeight: FontWeight.w700)),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: KdColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: KdColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KdColors.grass500,
          foregroundColor: const Color(0xFF3E5C33),
          textStyle: body.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KdColors.textPrimary,
          side: const BorderSide(color: KdColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      dividerColor: KdColors.border,
    );
  }

  /// 数値・XP・地名チップ用 (DotGothic16 — ドット演出を残したい箇所だけで使用)
  static TextStyle dot({double size = 14, Color color = Colors.white}) =>
      GoogleFonts.zenMaruGothic(
          fontSize: size, color: color, fontWeight: FontWeight.w800);
}
