import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';

/// Phase 8 §4 タイポグラフィ / §5 レイアウト・形状
///  - 本文: Zen Maru Gothic(丸ゴシック) 最小17sp・行間1.6
///  - 数値・チップ: DotGothic16(ドット絵世界との接続)
///  - ダークモード非対応(羊皮紙の世界観維持のためライト固定)
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
        headlineSmall: body.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        bodyLarge: body.bodyLarge?.copyWith(fontSize: 17, height: 1.6),
        bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: KdColors.background,
        foregroundColor: KdColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.zenMaruGothic(
          fontSize: 18, fontWeight: FontWeight.w700, color: KdColors.textPrimary),
      ),
      dividerColor: KdColors.border,
    );
  }

  /// 数値・XP・地名チップ用 (DotGothic16)
  static TextStyle dot({double size = 14, Color color = Colors.white}) =>
      GoogleFonts.dotGothic16(fontSize: size, color: color);
}
