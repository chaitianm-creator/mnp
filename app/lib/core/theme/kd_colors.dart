import 'package:flutter/material.dart';

/// デザイン王国 カラートークン (Phase 8 §3 — 世界マップ画像からの実測値)
///
/// 原則:
///  - 画面の土台は羊皮紙(parchment) + 木枠(wood)。白背景・グレーは使わない
///  - ピンクは「ご褒美と愛情」の色。報酬・祝福・みぽりん先生に限定
///  - 黒チップは「情報」、リボンは「感情」
abstract final class KdColors {
  // ── プリミティブ ──────────────────────────
  static const parchment = Color(0xFFF0D9A8); // 羊皮紙(実測 #F0D0A0系)
  static const parchmentLight = Color(0xFFF7E8C6);
  static const wood900 = Color(0xFF301500); // 額縁の焦げ茶(実測 #301000系)
  static const wood700 = Color(0xFF4A2A10);
  static const pink500 = Color(0xFFF06292); // リボン・城
  static const pink700 = Color(0xFFD01055); // 濃ピンク(実測 #D01050)
  static const pink100 = Color(0xFFFBD5E2);
  static const gold500 = Color(0xFFE8B84B); // 金装飾・XP
  static const ocean500 = Color(0xFF0A63DE); // 海(実測 #0060E0)
  static const grass500 = Color(0xFF8AA700); // 草原(実測 #80A000)
  static const forest700 = Color(0xFF14501E);
  static const lava500 = Color(0xFFF2571D); // 「危険」ではなく「熱量」の語彙で使う
  static const ink900 = Color(0xFF2E1F14); // 本文墨色
  static const chipBlack = Color(0xFF141414); // 地名・情報チップ

  // ── セマンティック ────────────────────────
  static const background = parchment;
  static const surface = parchmentLight;
  static const border = wood700;
  static const textPrimary = ink900;
  static Color get textSecondary => ink900.withOpacity(0.70);
  static const primaryAction = pink500;
  static const primaryActionPressed = pink700;
  static const reward = gold500;
  static const success = grass500;
}
