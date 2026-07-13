import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';

/// 王国の風景画: 空・雲・丘の上のピンクの城・草原・タイルの道(ドット絵の作法)。
/// 乱数は固定シード = 毎フレーム同じ絵。
class KdSceneryPainter extends CustomPainter {
  const KdSceneryPainter({this.showCastle = true});
  final bool showCastle;

  static const _sky = Color(0xFFA8D8F0);
  static const _skyLight = Color(0xFFC8E8F8);
  static const _grass = Color(0xFF77B94C);
  static const _grassDark = Color(0xFF69AC41);
  static const _grassLight = Color(0xFF85C55C);
  static const _hill = Color(0xFF5E9C3B);
  static const _castle = Color(0xFFF2699C);
  static const _castleDark = Color(0xFFDD3D76);
  static const _tile = Color(0xFFE3C27E);
  static const _tileEdge = Color(0xFFB98F4E);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final p = Paint();
    final horizon = size.height * 0.30;

    // ── 空と雲 ──
    p.color = _sky;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, horizon), p);
    p.color = _skyLight;
    for (var i = 0; i < 4; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = 20 + rng.nextDouble() * (horizon - 70);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, cy), width: 64, height: 16),
              const Radius.circular(8)),
          p);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx + 14, cy - 9), width: 36, height: 14),
              const Radius.circular(7)),
          p);
    }

    // ── 草原(ピクセル調のむら) + 空との市松ディザ ──
    p.color = _grass;
    canvas.drawRect(
        Rect.fromLTRB(0, horizon, size.width, size.height), p);
    p.color = _sky;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, horizon, 8, 8), p);
    }
    for (var i = 0; i < 70; i++) {
      final x = rng.nextDouble() * size.width;
      final y = horizon + rng.nextDouble() * (size.height - horizon);
      p.color = rng.nextBool() ? _grassDark : _grassLight;
      canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 6, 6), p);
    }

    // ── 丘の上のピンクの城 ──
    if (showCastle) {
      final castleBase = Offset(size.width / 2, horizon + 6);
      p.color = _hill;
      canvas.drawOval(
          Rect.fromCenter(
              center: castleBase.translate(0, 6), width: 230, height: 44),
          p);
      _castleShape(canvas, castleBase);
    }

    // ── タイルの道(城から手前へ) ──
    for (var i = 0; i < 6; i++) {
      final y = horizon + 60 + i * ((size.height - horizon - 100) / 5);
      final wobble = math.sin(i * 1.2) * 26;
      _diamond(canvas, Offset(size.width / 2 + wobble, y), 24 + i * 2.0,
          15 + i * 1.2);
    }

    // ── 木々(左右の縁)と花 ──
    for (double y = horizon + 40; y < size.height - 40; y += 120) {
      final jitter = rng.nextDouble() * 16 - 8;
      _tree(canvas, Offset(26 + jitter, y));
      _tree(canvas, Offset(size.width - 42 + jitter * 0.5, y + 60));
    }
    for (var i = 0; i < 26; i++) {
      final x = rng.nextDouble() * size.width;
      final y = horizon + 20 + rng.nextDouble() * (size.height - horizon - 40);
      _flower(canvas, Offset(x, y),
          rng.nextBool() ? KdColors.pink100 : Colors.white);
    }
  }

  /// ピンクの城(ドット絵): 本体 + 3塔 + 旗 + ハートの紋章。
  void _castleShape(Canvas canvas, Offset base) {
    final body = Paint()..color = _castle;
    final dark = Paint()..color = _castleDark;
    final outline = Paint()
      ..color = KdColors.wood900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter;

    // 本体
    final bodyRect = Rect.fromCenter(
        center: base.translate(0, -30), width: 96, height: 56);
    canvas.drawRect(bodyRect, body);
    // 城壁の凹凸
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
          Rect.fromLTWH(bodyRect.left + 4 + i * 19, bodyRect.top - 8, 12, 8),
          body);
    }
    // 左右の塔
    for (final dx in [-58.0, 58.0]) {
      final tower = Rect.fromCenter(
          center: base.translate(dx, -38), width: 26, height: 72);
      canvas.drawRect(tower, body);
      // 屋根(三角)
      final roof = Path()
        ..moveTo(tower.left - 5, tower.top)
        ..lineTo(tower.right + 5, tower.top)
        ..lineTo(tower.center.dx, tower.top - 20)
        ..close();
      canvas.drawPath(roof, dark);
      canvas.drawPath(roof, outline);
      canvas.drawRect(tower, outline);
      // 窓
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(tower.center.dx, tower.center.dy - 6),
              width: 7,
              height: 10),
          Paint()..color = Colors.white);
    }
    // 中央の塔
    final center = Rect.fromCenter(
        center: base.translate(0, -66), width: 30, height: 52);
    canvas.drawRect(center, body);
    final centerRoof = Path()
      ..moveTo(center.left - 6, center.top)
      ..lineTo(center.right + 6, center.top)
      ..lineTo(center.center.dx, center.top - 24)
      ..close();
    canvas.drawPath(centerRoof, dark);
    canvas.drawPath(centerRoof, outline);
    canvas.drawRect(center, outline);
    canvas.drawRect(bodyRect, outline);
    // 旗(中央の塔のてっぺん)
    final flagBase = Offset(center.center.dx, center.top - 24);
    canvas.drawLine(flagBase, flagBase.translate(0, -16),
        Paint()
          ..color = KdColors.wood900
          ..strokeWidth = 2);
    final flag = Path()
      ..moveTo(flagBase.dx, flagBase.dy - 16)
      ..lineTo(flagBase.dx + 16, flagBase.dy - 12)
      ..lineTo(flagBase.dx, flagBase.dy - 8)
      ..close();
    canvas.drawPath(flag, dark);
    // 門とハートの紋章
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(base.dx, bodyRect.bottom - 11),
            width: 18,
            height: 22),
        Paint()..color = KdColors.wood900);
    final heartC = Offset(base.dx, bodyRect.top + 12);
    final heart = Paint()..color = Colors.white;
    canvas.drawCircle(heartC.translate(-3, -1.5), 3.4, heart);
    canvas.drawCircle(heartC.translate(3, -1.5), 3.4, heart);
    final heartTip = Path()
      ..moveTo(heartC.dx - 6.2, heartC.dy - 0.6)
      ..lineTo(heartC.dx + 6.2, heartC.dy - 0.6)
      ..lineTo(heartC.dx, heartC.dy + 7)
      ..close();
    canvas.drawPath(heartTip, heart);
  }

  void _diamond(Canvas canvas, Offset c, double w, double h) {
    final path = Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx, c.dy + h)
      ..lineTo(c.dx - w, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _tile);
    canvas.drawPath(
      path,
      Paint()
        ..color = _tileEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  void _tree(Canvas canvas, Offset base) {
    canvas.drawRect(
        Rect.fromCenter(center: base.translate(0, 22), width: 8, height: 12),
        Paint()..color = const Color(0xFF6D4C2F));
    final leaf = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base.translate(0, 8), width: 34, height: 18),
            const Radius.circular(5)),
        leaf);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base.translate(0, -6), width: 26, height: 18),
            const Radius.circular(5)),
        leaf);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base.translate(-4, -8), width: 10, height: 6),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF43A047));
  }

  void _flower(Canvas canvas, Offset c, Color color) {
    final p = Paint()..color = color;
    canvas.drawRect(Rect.fromCenter(center: c, width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(-3, 0), width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(3, 0), width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, -3), width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, 3), width: 3, height: 3), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
