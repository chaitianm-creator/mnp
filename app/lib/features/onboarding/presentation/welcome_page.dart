import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-02 タイトル画面。
/// 参考: 経営シミュレーション系の「賑わう町並み + 立体ロゴ看板 + 四隅のキャラ」様式。
/// ※レイアウトの考え方のみ参考。キャラクター・ロゴ・名称は王国オリジナル。
/// 町並みはCustomPainter(固定シード)で描画し、本番はドット絵アセットに差し替え可能。
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── 賑わう王国の町並み ──
        const Positioned.fill(
          child: CustomPaint(painter: _TownScenePainter()),
        ),
        // ── 四隅のキャラクター(みぽりん先生と見習いさん) ──
        const Positioned(left: 14, bottom: 96, child: _CornerMascot(
          color: KdColors.pink100,
          icon: Icons.favorite,
          iconColor: KdColors.pink500,
          label: 'みぽりん先生',
        )),
        const Positioned(right: 14, bottom: 96, child: _CornerMascot(
          color: Color(0xFFFFF3C9),
          icon: Icons.person,
          iconColor: KdColors.pink700,
          label: 'デザイン見習い',
        )),
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            // ── ロゴ看板(木の看板 + ひさし + 縁取り文字) ──
            const _TitleSignboard(),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KdColors.pink500, width: 2),
              ),
              child: Text('デザインの力で、みんなを笑顔に',
                  style: KdTheme.dot(size: 12, color: KdColors.pink700)),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 56, 6),
              child: SizedBox(
                width: double.infinity,
                child: KdPrimaryButton(
                  label: 'はじめる',
                  onPressed: () => context.go('/meeting'),
                ),
              ),
            ),
            // 先生・スタッフ用の入り口(生徒フローの邪魔をしない控えめな導線)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.go('/teacher-login'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: Colors.white.withOpacity(0.75),
                  child: Text('先生・スタッフの方はこちら',
                      style: KdTheme.dot(size: 11, color: KdColors.ink900)
                          .copyWith(decoration: TextDecoration.underline)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// ロゴ看板: ピンクのひさし + 木の看板 + 白抜き縁取りロゴ。
class _TitleSignboard extends StatelessWidget {
  const _TitleSignboard();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ひさし(スカラップ)
      CustomPaint(
        size: const Size(300, 26),
        painter: _AwningPainter(),
      ),
      // 木の看板
      Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: KdColors.wood700,
          border: Border.all(color: KdColors.wood900, width: 3),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: KdColors.wood900, offset: Offset(0, 5)),
          ],
        ),
        child: Column(children: [
          _OutlinedTitle('デザイン王国',
              fontSize: 40, fill: Colors.white, outline: KdColors.wood900),
          const SizedBox(height: 6),
          _OutlinedTitle('ものがたり',
              fontSize: 20, fill: KdColors.pink100, outline: KdColors.pink700),
        ]),
      ),
    ]);
  }
}

/// 縁取り文字(ドット絵ロゴの作法: 白抜き + 太い輪郭 + 下に落ち影)。
class _OutlinedTitle extends StatelessWidget {
  const _OutlinedTitle(this.text,
      {required this.fontSize, required this.fill, required this.outline});
  final String text;
  final double fontSize;
  final Color fill;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final base = KdTheme.dot(size: fontSize, color: fill)
        .copyWith(fontWeight: FontWeight.w700, height: 1.0);
    return Stack(children: [
      // 落ち影
      Transform.translate(
        offset: const Offset(0, 3),
        child: Text(text,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.22
                ..color = Colors.black26,
            )),
      ),
      // 輪郭
      Text(text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.22
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          )),
      // 本体
      Text(text, style: base),
    ]);
  }
}

/// ひさし(赤白…ではなく桜ピンクのスカラップ)。
class _AwningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const n = 7;
    final seg = w / n;
    final body = Paint()..color = KdColors.pink500;
    final alt = Paint()..color = Colors.white;
    final edge = Paint()
      ..color = KdColors.pink700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    // 屋根板
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), body);
    // スカラップ
    for (var i = 0; i < n; i++) {
      final r = Rect.fromLTWH(i * seg, h * 0.1, seg, h * 0.9);
      canvas.drawArc(r, 0, math.pi, true, i.isEven ? body : alt);
      canvas.drawArc(r, 0, math.pi, false, edge);
    }
    canvas.drawLine(Offset(0, 0), Offset(w, 0), edge);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 四隅のマスコット(円形ポートレート + 名札。本番はドット絵に差し替え)。
class _CornerMascot extends StatelessWidget {
  const _CornerMascot({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
  });
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.wood900, width: 3),
          boxShadow: const [
            BoxShadow(color: KdColors.wood900, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, size: 42, color: iconColor),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: KdColors.border, width: 1.5),
        ),
        child: Text(label,
            style: KdTheme.dot(size: 10, color: KdColors.ink900)),
      ),
    ]);
  }
}

/// 賑わう王国の町並み(固定シード = ちらつきなし)。
/// お店・道・広場・木々・住民たちで「営みのある町」を描く。
class _TownScenePainter extends CustomPainter {
  const _TownScenePainter();

  static const _grass = Color(0xFF8CC868);
  static const _grassDark = Color(0xFF7CB151);
  static const _grassLight = Color(0xFF9AD478);
  static const _road = Color(0xFFF2ECCB);
  static const _roadEdge = Color(0xFFD9CFA0);
  static const _wall = Color(0xFFFFF4E0);
  static const _wood = Color(0xFF7A4A22);
  static const _woodDark = Color(0xFF3E2410);
  static const _skin = Color(0xFFF6D7B8);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(12);
    final p = Paint();
    final w = size.width;
    final h = size.height;

    // ── 空と城(上 16%) ──
    final horizon = h * 0.16;
    p.color = const Color(0xFFBFE3F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon), p);
    p.color = Colors.white;
    for (var i = 0; i < 4; i++) {
      final x = rng.nextDouble() * w;
      final y = 12 + rng.nextDouble() * horizon * 0.5;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: 56, height: 14),
              const Radius.circular(7)),
          p);
    }
    _castle(canvas, Offset(w / 2, horizon), scale: 1.0);
    // 地平線のギザギザ
    p.color = _grassDark;
    for (double x = 0; x < w; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x, horizon - 6, 6, 6), p);
    }

    // ── 草地 ──
    p.color = _grass;
    canvas.drawRect(Rect.fromLTWH(0, horizon, w, h - horizon), p);
    for (var i = 0; i < (w * (h - horizon)) / 800; i++) {
      final x = rng.nextDouble() * w;
      final y = horizon + rng.nextDouble() * (h - horizon);
      p.color = rng.nextBool() ? _grassDark : _grassLight;
      canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 5, 5), p);
    }

    // ── 道(十字 + 外周) ──
    final roadY = h * 0.62; // 横道
    _roadRect(canvas, Rect.fromLTWH(0, roadY, w, 44));
    _roadRect(canvas, Rect.fromLTWH(w * 0.5 - 24, horizon + 10, 48, h)); // 縦道
    _roadRect(canvas, Rect.fromLTWH(0, h * 0.87, w, 40));

    // ── お店たち(中央はロゴのため空ける) ──
    _shop(canvas, Offset(w * 0.10, h * 0.235), roof: KdColors.pink500,
        awning: true, sign: KdColors.gold500);
    _shop(canvas, Offset(w * 0.72, h * 0.235), roof: KdColors.ocean500,
        awning: true, sign: KdColors.pink100);
    _shop(canvas, Offset(w * 0.06, h * 0.66), roof: KdColors.gold500,
        awning: false, sign: KdColors.ocean500);
    _shop(canvas, Offset(w * 0.70, h * 0.66), roof: KdColors.grass500,
        awning: true, sign: KdColors.pink500);
    _shop(canvas, Offset(w * 0.40, h * 0.88), roof: KdColors.lava500,
        awning: true, sign: Colors.white);

    // ── 池(左下) ──
    p.color = const Color(0xFF5FA8E8);
    final pond = Rect.fromCenter(
        center: Offset(w * 0.16, h * 0.945), width: w * 0.2, height: 34);
    canvas.drawRRect(
        RRect.fromRectAndRadius(pond, const Radius.circular(12)), p);
    p.color = const Color(0xFF9CC9F2);
    canvas.drawRect(
        Rect.fromLTWH(pond.left + 8, pond.top + 6, 14, 3), p);
    canvas.drawRect(
        Rect.fromLTWH(pond.left + 30, pond.top + 14, 10, 3), p);

    // ── 木・花だん・生けがき ──
    for (final t in [
      Offset(w * 0.05, h * 0.20),
      Offset(w * 0.93, h * 0.20),
      Offset(w * 0.90, h * 0.50),
      Offset(w * 0.08, h * 0.50),
      Offset(w * 0.93, h * 0.93),
    ]) {
      _tree(canvas, t);
    }
    for (var i = 0; i < 26; i++) {
      final x = rng.nextDouble() * w;
      final y = horizon + 8 + rng.nextDouble() * (h - horizon - 16);
      _flower(canvas, Offset(x, y),
          rng.nextBool() ? KdColors.pink100 : Colors.white);
    }
    // 花だん(ロゴ下の広場を飾る)
    _flowerBed(canvas, Offset(w * 0.28, h * 0.545));
    _flowerBed(canvas, Offset(w * 0.60, h * 0.545));

    // ── 住民たち(道の上ににぎわい) ──
    final shirts = [
      KdColors.pink500,
      KdColors.ocean500,
      KdColors.gold500,
      KdColors.grass500,
      KdColors.lava500,
      KdColors.pink700,
    ];
    final spots = <Offset>[
      Offset(w * 0.18, roadY + 14),
      Offset(w * 0.34, roadY + 26),
      Offset(w * 0.62, roadY + 10),
      Offset(w * 0.80, roadY + 24),
      Offset(w * 0.48, h * 0.30),
      Offset(w * 0.52, h * 0.46),
      Offset(w * 0.47, h * 0.76),
      Offset(w * 0.55, h * 0.80),
      Offset(w * 0.24, h * 0.885),
      Offset(w * 0.70, h * 0.90),
      Offset(w * 0.86, h * 0.885),
    ];
    for (final (i, s) in spots.indexed) {
      _villager(canvas, s, shirts[i % shirts.length],
          hair: i.isEven ? _woodDark : _wood);
    }
  }

  void _roadRect(Canvas canvas, Rect r) {
    final p = Paint()..color = _road;
    canvas.drawRect(r, p);
    p.color = _roadEdge;
    // タイルの目地
    if (r.width > r.height) {
      for (double x = r.left; x < r.right; x += 22) {
        canvas.drawRect(Rect.fromLTWH(x, r.top, 2, r.height), p);
      }
    } else {
      for (double y = r.top; y < r.bottom; y += 22) {
        canvas.drawRect(Rect.fromLTWH(r.left, y, r.width, 2), p);
      }
    }
  }

  void _castle(Canvas canvas, Offset base, {required double scale}) {
    final p = Paint();
    void tower(double dx, double tw, double th) {
      p.color = KdColors.pink500;
      canvas.drawRect(
          Rect.fromLTWH(base.dx + dx - tw / 2, base.dy - th, tw, th), p);
      p.color = KdColors.pink700;
      final roof = Path()
        ..moveTo(base.dx + dx - tw * 0.7, base.dy - th)
        ..lineTo(base.dx + dx + tw * 0.7, base.dy - th)
        ..lineTo(base.dx + dx, base.dy - th - tw * 1.1)
        ..close();
      canvas.drawPath(roof, p);
    }

    tower(-34 * scale, 20 * scale, 34 * scale);
    tower(34 * scale, 20 * scale, 34 * scale);
    tower(0, 26 * scale, 48 * scale);
    // 旗
    p.color = KdColors.lava500;
    canvas.drawRect(
        Rect.fromLTWH(base.dx - 1, base.dy - 48 * scale - 40, 2, 14), p);
    final flag = Path()
      ..moveTo(base.dx + 1, base.dy - 48 * scale - 40)
      ..lineTo(base.dx + 14, base.dy - 48 * scale - 35)
      ..lineTo(base.dx + 1, base.dy - 48 * scale - 30)
      ..close();
    canvas.drawPath(flag, p);
  }

  void _shop(Canvas canvas, Offset topLeft,
      {required Color roof, required bool awning, required Color sign}) {
    final p = Paint();
    const bw = 78.0; // 建物幅
    const bh = 54.0;
    final r = Rect.fromLTWH(topLeft.dx, topLeft.dy, bw, bh);
    // 壁
    p.color = _wall;
    canvas.drawRect(r, p);
    // 屋根
    p.color = roof;
    canvas.drawRect(Rect.fromLTWH(r.left - 5, r.top - 14, bw + 10, 16), p);
    p.color = _woodDark;
    canvas.drawRect(Rect.fromLTWH(r.left - 5, r.top - 14, bw + 10, 3), p);
    // ひさし(スカラップ簡略: 交互の四角)
    if (awning) {
      for (var i = 0; i < 6; i++) {
        p.color = i.isEven ? roof : Colors.white;
        canvas.drawRect(
            Rect.fromLTWH(r.left + i * (bw / 6), r.top + 16, bw / 6, 7), p);
      }
    }
    // 窓とドア
    p.color = const Color(0xFFBDE3F8);
    canvas.drawRect(Rect.fromLTWH(r.left + 8, r.top + 28, 16, 14), p);
    canvas.drawRect(Rect.fromLTWH(r.left + bw - 24, r.top + 28, 16, 14), p);
    p.color = _wood;
    canvas.drawRect(
        Rect.fromLTWH(r.left + bw / 2 - 8, r.top + bh - 20, 16, 20), p);
    // 看板
    p.color = sign;
    canvas.drawRect(Rect.fromLTWH(r.left + bw / 2 - 12, r.top + 4, 24, 9), p);
    // 輪郭
    final edge = Paint()
      ..color = _woodDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(r, edge);
  }

  void _tree(Canvas canvas, Offset base) {
    final p = Paint()..color = _wood;
    canvas.drawRect(
        Rect.fromCenter(center: base.translate(0, 16), width: 7, height: 12),
        p);
    p.color = const Color(0xFF2E7D32);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base, width: 30, height: 26),
            const Radius.circular(6)),
        p);
    p.color = const Color(0xFF43A047);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base.translate(-5, -6), width: 10, height: 6),
            const Radius.circular(2)),
        p);
  }

  void _flowerBed(Canvas canvas, Offset c) {
    final p = Paint()..color = _wood;
    final r = Rect.fromCenter(center: c, width: 52, height: 20);
    canvas.drawRect(r.inflate(3), p);
    p.color = const Color(0xFF5D8A3C);
    canvas.drawRect(r, p);
    for (var i = 0; i < 4; i++) {
      _flower(canvas, Offset(r.left + 8 + i * 12, c.dy),
          i.isEven ? KdColors.pink100 : Colors.white);
    }
  }

  void _flower(Canvas canvas, Offset c, Color color) {
    final p = Paint()..color = color;
    for (final d in const [
      Offset(0, 0),
      Offset(-3, 0),
      Offset(3, 0),
      Offset(0, -3),
      Offset(0, 3),
    ]) {
      canvas.drawRect(
          Rect.fromCenter(center: c + d, width: 3, height: 3), p);
    }
  }

  /// ちいさな住民(頭・髪・服・足)。本番は歩行ドット絵に差し替え。
  void _villager(Canvas canvas, Offset c, Color shirt, {required Color hair}) {
    final p = Paint();
    // 影
    p.color = Colors.black12;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, 9), width: 12, height: 4),
            const Radius.circular(2)),
        p);
    // 足
    p.color = _woodDark;
    canvas.drawRect(Rect.fromLTWH(c.dx - 4, c.dy + 4, 3, 5), p);
    canvas.drawRect(Rect.fromLTWH(c.dx + 1, c.dy + 4, 3, 5), p);
    // 服
    p.color = shirt;
    canvas.drawRect(Rect.fromLTWH(c.dx - 5, c.dy - 4, 10, 9), p);
    // 頭
    p.color = _skin;
    canvas.drawRect(Rect.fromLTWH(c.dx - 4, c.dy - 12, 8, 8), p);
    // 髪
    p.color = hair;
    canvas.drawRect(Rect.fromLTWH(c.dx - 4, c.dy - 13, 8, 3), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
