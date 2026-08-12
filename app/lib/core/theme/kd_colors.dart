import 'package:flutter/material.dart';

/// カラートークン (PRO NAVI クリーンスタイル準拠)
///
/// 原則:
///  - 画面の土台は淡いベージュ(background) + 白カード(surface) + 細い薄枠(border)
///  - アクセントは淡いパステル(ピンク/グリーン/パープル/ブルー)
///  - キャラクター・シーンのドット絵はそのまま(UIだけをシンプルに)
abstract final class KdColors {
  // ── プリミティブ ──────────────────────────
  static const parchment = Color(0xFFF7F5EF); // 画面の土台(淡ベージュ)
  static const parchmentLight = Colors.white; // カード面
  static const wood900 = Color(0xFF4A443A); // 濃い文字色(ソフトな墨)
  static const wood700 = Color(0xFFE6E0D2); // 細い薄枠
  static const pink500 = Color(0xFFE98FA9); // ソフトピンク(主ボタン)
  static const pink700 = Color(0xFFD16E8E); // 深めピンク(見出し)
  static const pink100 = Color(0xFFF9E9EE);
  static const pink50 = Color(0xFFFBF2F5);
  static const gold500 = Color(0xFFE3C57C); // ご褒美・XP
  static const ocean500 = Color(0xFF9CC3E8); // 淡ブルー
  static const grass500 = Color(0xFFA8D18F); // 淡グリーン(成功/進捗)
  static const forest700 = Color(0xFF5E8A4E);
  static const lava500 = Color(0xFFE8996E); // 熱量(ソフトオレンジ)
  static const ink900 = Color(0xFF4A443A); // 本文
  static const chipBlack = Color(0xFF6B6455); // 情報チップ(ソフトグレー)

  // ── セマンティック ────────────────────────
  static const background = parchment;
  static const surface = parchmentLight;
  static const border = wood700;
  static const textPrimary = ink900;
  static Color get textSecondary => const Color(0xFF938A78);
  static const heading = pink700; // セクション見出し
  static const primaryAction = pink500;
  static const primaryActionPressed = pink700;
  static const reward = gold500;
  static const success = grass500;
}
