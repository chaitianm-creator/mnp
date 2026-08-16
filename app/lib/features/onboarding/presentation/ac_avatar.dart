import 'package:flutter/material.dart';

/// どうぶつの森風のなめらかなアバター(主人公の女の子)。
/// ドット絵ではなく、丸みのあるベクター描画。
/// [outfitTop] はワンピースの色(きせかえ連動用)。
class AcAvatarPainter extends CustomPainter {
  const AcAvatarPainter({
    this.outfitTop = const Color(0xFFAECBEB),
    this.hair = const Color(0xFF5A3A24),
    this.skin = const Color(0xFFF9E4D0),
  });
  final Color outfitTop;
  final Color hair;
  final Color skin;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final hairDark = Color.lerp(hair, Colors.black, 0.18)!;

    // ── 落ち影 ──
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, h * 0.965), width: w * 0.52, height: h * 0.05),
        Paint()..color = const Color(0x22304018));

    // ── 足(靴) ──
    final shoe = Paint()..color = const Color(0xFF6E4A3A);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - w * 0.1, h * 0.94),
            width: w * 0.14,
            height: h * 0.055),
        shoe);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + w * 0.1, h * 0.94),
            width: w * 0.14,
            height: h * 0.055),
        shoe);

    // ── ワンピース(台形+すそ広がり) ──
    final dress = Path()
      ..moveTo(cx - w * 0.14, h * 0.60)
      ..quadraticBezierTo(cx - w * 0.24, h * 0.82, cx - w * 0.21, h * 0.90)
      ..quadraticBezierTo(cx, h * 0.945, cx + w * 0.21, h * 0.90)
      ..quadraticBezierTo(cx + w * 0.24, h * 0.82, cx + w * 0.14, h * 0.60)
      ..close();
    canvas.drawPath(dress, Paint()..color = outfitTop);
    // すそのライン
    canvas.drawPath(
        Path()
          ..moveTo(cx - w * 0.205, h * 0.885)
          ..quadraticBezierTo(cx, h * 0.93, cx + w * 0.205, h * 0.885),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.015
          ..color = Colors.white.withOpacity(0.7));
    // 花柄(白い5枚花)
    void flower(double fx, double fy, double s) {
      final p = Paint()..color = Colors.white;
      for (var i = 0; i < 5; i++) {
        final a = i * 3.1416 * 2 / 5 - 1.57;
        canvas.drawCircle(
            Offset(fx + s * 0.8 * _cos(a), fy + s * 0.8 * _sin(a)),
            s * 0.42,
            p);
      }
      canvas.drawCircle(
          Offset(fx, fy), s * 0.34, Paint()..color = const Color(0xFFF6D96B));
    }

    flower(cx - w * 0.1, h * 0.74, w * 0.035);
    flower(cx + w * 0.09, h * 0.82, w * 0.03);
    flower(cx + w * 0.13, h * 0.68, w * 0.026);
    flower(cx - w * 0.16, h * 0.85, w * 0.026);

    // ── 腕 ──
    final arm = Paint()..color = skin;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - w * 0.20, h * 0.68),
            width: w * 0.09,
            height: h * 0.16),
        arm);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + w * 0.20, h * 0.68),
            width: w * 0.09,
            height: h * 0.16),
        arm);

    // ── 頭(大きな丸顔) ──
    final headC = Offset(cx, h * 0.36);
    final headR = w * 0.30;
    canvas.drawCircle(headC, headR, Paint()..color = skin);

    // ── 髪(ボブ+ぱっつん前髪) ──
    final hairPath = Path()
      // 外周(頭より少し大きく、下がすぼまるボブ)
      ..moveTo(cx - headR * 1.12, h * 0.40)
      ..quadraticBezierTo(
          cx - headR * 1.22, h * 0.13, cx, h * 0.085)
      ..quadraticBezierTo(
          cx + headR * 1.22, h * 0.13, cx + headR * 1.12, h * 0.40)
      ..quadraticBezierTo(
          cx + headR * 1.08, h * 0.52, cx + headR * 0.82, h * 0.545)
      // 前髪の下端(ゆるいスカラップ)
      ..quadraticBezierTo(cx + headR * 0.62, h * 0.30, cx + headR * 0.3,
          h * 0.275)
      ..quadraticBezierTo(cx, h * 0.255, cx - headR * 0.3, h * 0.275)
      ..quadraticBezierTo(cx - headR * 0.62, h * 0.30, cx - headR * 0.82,
          h * 0.545)
      ..quadraticBezierTo(
          cx - headR * 1.08, h * 0.52, cx - headR * 1.12, h * 0.40)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);
    // 髪のハイライト(髪の内側だけに描く)
    canvas.save();
    canvas.clipPath(hairPath);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, h * 0.335), radius: headR * 0.92),
        -2.35,
        0.75,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.028
          ..color = Color.lerp(hair, Colors.white, 0.25)!);
    canvas.restore();
    // サイドの毛先(内巻き)
    final tuft = Paint()..color = hairDark;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - headR * 0.95, h * 0.50),
            width: w * 0.10,
            height: h * 0.10),
        tuft);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + headR * 0.95, h * 0.50),
            width: w * 0.10,
            height: h * 0.10),
        tuft);

    // ── 目(大きな瞳+白ハイライト) ──
    void eye(double ex) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(ex, h * 0.375),
              width: w * 0.085,
              height: h * 0.075),
          Paint()..color = const Color(0xFF3A2A1E));
      canvas.drawCircle(Offset(ex + w * 0.018, h * 0.36), w * 0.018,
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(ex - w * 0.012, h * 0.39), w * 0.009,
          Paint()..color = Colors.white70);
    }

    eye(cx - headR * 0.42);
    eye(cx + headR * 0.42);

    // ── まゆ ──
    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.014
      ..color = hairDark;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - headR * 0.42, h * 0.335),
            width: w * 0.08,
            height: h * 0.04),
        3.3, 0.8, false, brow);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx + headR * 0.42, h * 0.335),
            width: w * 0.08,
            height: h * 0.04),
        -0.9, 0.8, false, brow);

    // ── ほっぺ ──
    final blush = Paint()..color = const Color(0x59F2919E);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - headR * 0.62, h * 0.425),
            width: w * 0.09,
            height: h * 0.04),
        blush);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + headR * 0.62, h * 0.425),
            width: w * 0.09,
            height: h * 0.04),
        blush);

    // ── 鼻と口 ──
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, h * 0.415), width: w * 0.028, height: h * 0.016),
        Paint()..color = const Color(0xFFE8B08E));
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, h * 0.445), width: w * 0.05, height: h * 0.03),
        0.3, 2.5, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.013
          ..color = const Color(0xFFB86A5E));
  }

  @override
  bool shouldRepaint(covariant AcAvatarPainter old) =>
      old.outfitTop != outfitTop || old.hair != hair || old.skin != skin;
}

// 軽量なcos/sin(花柄用)
double _cos(double a) => _sinApprox(a + 1.5708);
double _sin(double a) => _sinApprox(a);
double _sinApprox(double a) {
  const pi = 3.14159265;
  var x = a % (2 * pi);
  if (x < 0) x += 2 * pi;
  final sign = x > pi ? -1.0 : 1.0;
  if (x > pi) x -= pi;
  final t = x * (pi - x);
  return sign * 16 * t / (5 * pi * pi - 4 * t);
}
