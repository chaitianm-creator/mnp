import 'package:flutter/material.dart';

/// デザイン王国 カラートークン (みぽりん王国 素材パック準拠)
///
/// 原則:
///  - 画面の土台はクリーム地(cream) + あたたかい木枠(wood)。白背景・グレーは使わない
///  - 桜ピンクは世界観の主役。見出し・リボン・ご褒美・みぽりん先生に使う
///  - 黒チップは「情報」、リボンは「感情」
abstract final class KdColors {
  // ── プリミティブ ──────────────────────────
  static const parchment = Color(0xFFF9EED8); // クリーム地(素材パック台紙)
  static const parchmentLight = Color(0xFFFFF8EA);
  static const wood900 = Color(0xFF3E2410); // 額縁の焦げ茶
  static const wood700 = Color(0xFF7A4A22); // 木枠(あたたかいブラウン)
  static const pink500 = Color(0xFFF2699C); // 桜ピンク(リボン・城)
  static const pink700 = Color(0xFFDD3D76); // 深いローズ(見出し・縁取り)
  static const pink100 = Color(0xFFFBDCE7);
  static const pink50 = Color(0xFFFDEFF4);
  static const gold500 = Color(0xFFE8B84B); // 金装飾・XP・レベル枠
  static const ocean500 = Color(0xFF5FA8E8); // 湖・MPバーの空色
  static const grass500 = Color(0xFF7CB151); // 草原・EXPバーの若葉色
  static const forest700 = Color(0xFF3E7A46);
  static const lava500 = Color(0xFFEF6A35); // 「危険」ではなく「熱量」の語彙で使う
  static const ink900 = Color(0xFF43301E); // 本文墨色(あたたかい焦げ茶)
  static const chipBlack = Color(0xFF141414); // 地名・情報チップ

  // ── セマンティック ────────────────────────
  static const background = parchment;
  static const surface = parchmentLight;
  static const border = wood700;
  static const textPrimary = ink900;
  static Color get textSecondary => ink900.withOpacity(0.70);
  static const heading = pink700; // セクション見出し(❀ 付き)
  static const primaryAction = pink500;
  static const primaryActionPressed = pink700;
  static const reward = gold500;
  static const success = grass500;
}
