import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// エリア定義(Phase 8 §1.2 の確定マッピング)。
/// 本番は areas コレクション(Phase 5 §2.1)から取得 — DEMO は静的定義。
class AreaDef {
  const AreaDef({
    required this.id,
    required this.order,
    required this.name,
    required this.mindTheme,
    required this.skillLabel,
    required this.icon,
    required this.color,
  });
  final String id;
  final int order;
  final String name;
  final String mindTheme;
  final String skillLabel;
  final IconData icon;
  final Color color;
}

const kAreas = [
  AreaDef(
      id: 'area_01_hajimari',
      order: 1,
      name: 'はじまりの街（みぽりん村）',
      mindTheme: '冒険のスタート',
      skillLabel: '仕事の型',
      icon: Icons.home_work,
      color: KdColors.pink500),
  AreaDef(
      id: 'area_02_migaki',
      order: 2,
      name: 'みがき上げの森',
      mindTheme: '自分磨き・習慣化',
      skillLabel: '自己管理',
      icon: Icons.forest,
      color: KdColors.forest700),
  AreaDef(
      id: 'area_03_commu',
      order: 3,
      name: 'コミュ力の湖',
      mindTheme: '対話力・伝え方',
      skillLabel: 'ヒアリング',
      icon: Icons.water,
      color: KdColors.ocean500),
  AreaDef(
      id: 'area_04_jishin',
      order: 4,
      name: '自信の塔',
      mindTheme: '自己肯定感',
      skillLabel: '提案力',
      icon: Icons.castle,
      color: KdColors.gold500),
  AreaDef(
      id: 'area_05_yaruki',
      order: 5,
      name: 'やる気の火山',
      mindTheme: '行動力・継続力',
      skillLabel: '継続',
      icon: Icons.local_fire_department,
      color: KdColors.lava500),
  AreaDef(
      id: 'area_06_nakama',
      order: 6,
      name: '仲間の大草原',
      mindTheme: '仲間・チームワーク',
      skillLabel: 'コミュニティ',
      icon: Icons.grass,
      color: KdColors.grass500),
  AreaDef(
      id: 'area_07_shiren',
      order: 7,
      name: '試練の洞窟',
      mindTheme: '壁を乗り越える',
      skillLabel: '改善力',
      icon: Icons.landscape,
      color: KdColors.wood700),
  AreaDef(
      id: 'area_08_miporin',
      order: 8,
      name: 'みぽりん城',
      mindTheme: '理想の未来・ゴール',
      skillLabel: '王国認定',
      icon: Icons.favorite,
      color: KdColors.pink700),
];

/// SC-30 世界マップ = 海に浮かぶ王国の島々。
/// レトロRPGのワールドマップ様式: 青い海の上に8つの島が並び、
/// 各島にエリアのランドマーク(村・森・湖・塔・火山・草原・洞窟・城)が建つ。
class WorldMapPage extends ConsumerWidget {
  const WorldMapPage({super.key});

  // 島の蛇行(左右への振れ幅の並び)
  static const _sway = [-0.30, 0.30, -0.32, 0.32, -0.30, 0.28, 0.32, -0.05];
  static const _rowH = 200.0;
  static const _topPad = 64.0;
  static const _bottomPad = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ワールドマップ')),
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final totalH = _topPad + kAreas.length * _rowH + _bottomPad;
        final centers = <Offset>[
          for (var i = 0; i < kAreas.length; i++)
            Offset(
              w / 2 + _sway[i % _sway.length] * (w * 0.5),
              _topPad + i * _rowH + _rowH / 2 - 20,
            ),
        ];

        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            height: totalH,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WorldMapPainter(centers: centers),
                ),
              ),
              for (var i = 0; i < kAreas.length; i++)
                _positionedArea(
                  context,
                  kAreas[i],
                  centers[i],
                  // DEMO: エリア①のみ解放。②以降は①クリア(12件)で解放(Phase 5 §2.1)
                  unlocked: kAreas[i].order == 1 ||
                      (progress.areaDelivered['area_01_hajimari'] ?? 0) >= 12,
                  stage: progress.stageOf(kAreas[i].id),
                ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _positionedArea(BuildContext context, AreaDef area, Offset center,
      {required bool unlocked, required int stage}) {
    const boxW = 210.0;
    const boxH = 190.0;
    return Positioned(
      left: center.dx - boxW / 2,
      top: center.dy - boxH / 2,
      child: SizedBox(
        width: boxW,
        height: boxH,
        child: _MapNode(
          area: area,
          unlocked: unlocked,
          stage: stage,
          // エリア①は村の中へ、その他はエリアガイドへ
          onTap: () => context.push(
              area.order == 1 ? '/village' : '/area/${area.id}'),
        ),
      ),
    );
  }
}

/// 島のタップ領域 + 地名ラベル(白ピル + 番号の丸 = 参考マップのラベル様式)。
/// 島とランドマークの絵は _WorldMapPainter が背景に描く。
class _MapNode extends StatelessWidget {
  const _MapNode(
      {required this.area,
      required this.unlocked,
      required this.stage,
      required this.onTap});
  final AreaDef area;
  final bool unlocked;
  final int stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: area.name,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent, // 島のどこを押しても反応
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          // 地名ラベル(白ピル + 番号)
          Container(
            padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KdColors.wood900, width: 2),
              boxShadow: const [
                BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked ? KdColors.pink700 : const Color(0xFF8E8471),
                  shape: BoxShape.circle,
                ),
                child: unlocked
                    ? Text('${area.order}',
                        style: KdTheme.dot(size: 11, color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w700))
                    : const Icon(Icons.lock, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(area.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KdTheme.dot(size: 12, color: KdColors.ink900)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          if (unlocked) ...[
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 3; i++)
                Icon(Icons.local_florist,
                    size: 12,
                    color: i <= stage
                        ? KdColors.pink500
                        : Colors.white.withOpacity(0.7)),
            ]),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// 王国の地方マップ: ひと続きの大陸の上に8つの街が道路でつながる
/// (レトロRPGの「タウンマップ」様式)。海には渦巻き・小島・帆船。
/// 乱数は固定シード = 毎フレーム同じ絵(ちらつき防止)。
class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter({required this.centers});
  final List<Offset> centers;

  // タウンマップのパレット(参考画像の実測系: やわらかいフラットカラー)
  static const _sea = Color(0xFF7EC4EA);
  static const _seaLight = Color(0xFF9AD4F2);
  static const _seaDark = Color(0xFF69B4E0);
  static const _sand = Color(0xFFE8DCA8);
  static const _land = Color(0xFF8CC868);
  static const _landDark = Color(0xFF7DBA58);
  static const _landLight = Color(0xFF9DD378);
  static const _road = Color(0xFFF2ECCB);
  static const _roadEdge = Color(0xFFD9CFA0);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(21);
    final p = Paint();

    // ── 海(むら + 渦巻き + 小島 + 船) ──
    p.color = _sea;
    canvas.drawRect(Offset.zero & size, p);
    for (var i = 0; i < (size.width * size.height) / 1600; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      p.color = rng.nextBool() ? _seaDark : _seaLight;
      canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 7, 7), p);
    }

    // ── 大陸(街をつなぐひと続きの陸地): 砂浜の縁 → 草地 ──
    Path landAt(double inflate) {
      final path = Path();
      for (var i = 0; i < centers.length; i++) {
        final c = centers[i];
        path.addOval(Rect.fromCenter(
            center: c,
            width: math.min(size.width * 0.92, 360) + inflate * 2,
            height: 210 + inflate * 2));
        if (i < centers.length - 1) {
          final a = centers[i];
          final b = centers[i + 1];
          final mid = Offset.lerp(a, b, 0.5)!;
          path.addOval(Rect.fromCenter(
              center: mid,
              width: size.width * 0.62 + inflate * 2,
              height: (b.dy - a.dy).abs() * 0.9 + inflate * 2));
        }
      }
      return path;
    }

    canvas.drawPath(landAt(16), Paint()..color = _sand);
    final land = landAt(0);
    canvas.drawPath(land, Paint()..color = _land);

    // 陸地の中の飾り(むら・木立・山脈)はクリップして描く
    canvas.save();
    canvas.clipPath(land);
    for (var i = 0; i < (size.width * size.height) / 1500; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      p.color = rng.nextBool() ? _landDark : _landLight;
      canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 7, 7), p);
    }
    // 山脈(バンドの縁に交互に)と木立
    for (var i = 0; i < centers.length; i++) {
      final c = centers[i];
      final side = i.isEven ? 1.0 : -1.0;
      _mountains(canvas,
          Offset(size.width / 2 + side * size.width * 0.34, c.dy - 60), rng);
      for (var t = 0; t < 4; t++) {
        _pine(
            canvas,
            Offset(size.width / 2 - side * size.width * (0.24 + rng.nextDouble() * 0.12),
                c.dy - 40 + rng.nextDouble() * 110),
            dark: rng.nextBool());
      }
    }
    canvas.restore();

    // ── 道路(街から街へ。淡いクリーム色の道) ──
    final roadEdge = Paint()
      ..color = _roadEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final road = Paint()
      ..color = _road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final route = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      route.quadraticBezierTo(
          a.dx, (a.dy + b.dy) / 2, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      route.quadraticBezierTo(b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
    }
    canvas.drawPath(route, roadEdge);
    canvas.drawPath(route, road);

    // ── 海の飾り: 渦巻き・小島・帆船 ──
    for (var i = 0; i < centers.length; i += 2) {
      final side = i.isEven ? -1.0 : 1.0;
      _whirl(
          canvas,
          Offset(size.width / 2 + side * size.width * 0.465,
              centers[i].dy + 130 + rng.nextDouble() * 30));
    }
    _islet(canvas, Offset(size.width * 0.08, centers[2].dy + 60), rng);
    _islet(canvas, Offset(size.width * 0.93, centers[5].dy + 90), rng);
    _ship(canvas, Offset(size.width * 0.12, size.height - 70));

    // ── 各街のランドマーク ──
    for (var i = 0; i < centers.length; i++) {
      final c = centers[i].translate(0, -6);
      switch (i) {
        case 0:
          _village(canvas, c);
        case 1:
          _forest(canvas, c, math.Random(60));
        case 2:
          _lake(canvas, c);
        case 3:
          _tower(canvas, c);
        case 4:
          _volcano(canvas, c);
        case 5:
          _meadow(canvas, c, math.Random(61));
        case 6:
          _cave(canvas, c);
        case 7:
          _castle(canvas, c);
      }
    }
  }

  // ── 地形の部品 ──────────────────────────────

  void _mountains(Canvas canvas, Offset c, math.Random rng) {
    // 三山の山脈(茶の山 + 白い雪帽子)
    for (final (dx, s) in [(-34.0, 0.8), (0.0, 1.0), (32.0, 0.75)]) {
      final peak = c.translate(dx, 0);
      final h = 44 * s;
      final w = 42 * s;
      final tri = Path()
        ..moveTo(peak.dx - w, peak.dy + h * 0.5)
        ..lineTo(peak.dx, peak.dy - h * 0.5)
        ..lineTo(peak.dx + w, peak.dy + h * 0.5)
        ..close();
      canvas.drawPath(tri, Paint()..color = const Color(0xFF9C7A50));
      final shade = Path()
        ..moveTo(peak.dx, peak.dy - h * 0.5)
        ..lineTo(peak.dx + w, peak.dy + h * 0.5)
        ..lineTo(peak.dx + w * 0.25, peak.dy + h * 0.5)
        ..close();
      canvas.drawPath(shade, Paint()..color = const Color(0xFF836540));
      final snow = Path()
        ..moveTo(peak.dx - w * 0.28, peak.dy - h * 0.5 + h * 0.28)
        ..lineTo(peak.dx, peak.dy - h * 0.5)
        ..lineTo(peak.dx + w * 0.28, peak.dy - h * 0.5 + h * 0.28)
        ..lineTo(peak.dx + w * 0.14, peak.dy - h * 0.5 + h * 0.2)
        ..lineTo(peak.dx, peak.dy - h * 0.5 + h * 0.3)
        ..lineTo(peak.dx - w * 0.14, peak.dy - h * 0.5 + h * 0.2)
        ..close();
      canvas.drawPath(snow, Paint()..color = Colors.white);
    }
  }

  void _whirl(Canvas canvas, Offset c) {
    final p = Paint()
      ..color = _seaLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: 13), 0.4, 4.6, false, p);
    canvas.drawArc(Rect.fromCircle(center: c, radius: 8), 2.2, 4.4, false, p);
    canvas.drawArc(Rect.fromCircle(center: c, radius: 3.6), 4.0, 4.0, false, p);
  }

  void _islet(Canvas canvas, Offset c, math.Random rng) {
    canvas.drawOval(Rect.fromCenter(center: c, width: 66, height: 36),
        Paint()..color = _sand);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -3), width: 52, height: 26),
        Paint()..color = _land);
    _pine(canvas, c.translate(-8, -8), dark: rng.nextBool());
    _flowerDot(canvas, c.translate(12, -4), Colors.white);
  }

  void _flowerDot(Canvas canvas, Offset c, Color color) {
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

  // ── 街のランドマーク ────────────────────────

  void _house(Canvas canvas, Offset base, double s, {Color? roof}) {
    canvas.drawRect(
        Rect.fromCenter(center: base, width: 24 * s, height: 16 * s),
        Paint()..color = const Color(0xFFFFF3E0));
    canvas.drawRect(
        Rect.fromCenter(center: base, width: 24 * s, height: 16 * s),
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final roofPath = Path()
      ..moveTo(base.dx - 15 * s, base.dy - 8 * s)
      ..lineTo(base.dx + 15 * s, base.dy - 8 * s)
      ..lineTo(base.dx, base.dy - 21 * s)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roof ?? KdColors.pink500);
    canvas.drawPath(
        roofPath,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawRect(
        Rect.fromCenter(
            center: base.translate(0, 4 * s), width: 5 * s, height: 8 * s),
        Paint()..color = KdColors.wood900);
  }

  void _village(Canvas canvas, Offset c) {
    _house(canvas, c.translate(-42, 0), 0.85);
    _house(canvas, c.translate(0, -12), 1.0);
    _house(canvas, c.translate(42, 2), 0.85, roof: KdColors.gold500);
    canvas.drawCircle(c.translate(0, 14), 8,
        Paint()..color = const Color(0xFFBFC9CC));
    canvas.drawCircle(c.translate(0, 14), 5, Paint()..color = _sea);
  }

  void _forest(Canvas canvas, Offset c, math.Random rng) {
    for (var i = 0; i < 9; i++) {
      final dx = (rng.nextDouble() - 0.5) * 140;
      final dy = (rng.nextDouble() - 0.5) * 60 - 4;
      _pine(canvas, c.translate(dx, dy), dark: rng.nextBool());
    }
  }

  void _pine(Canvas canvas, Offset base, {bool dark = false}) {
    canvas.drawRect(
        Rect.fromCenter(center: base.translate(0, 14), width: 5, height: 8),
        Paint()..color = const Color(0xFF6D4C2F));
    final leaf = Paint()
      ..color = dark ? const Color(0xFF2F7D33) : const Color(0xFF48A04C);
    for (var t = 0; t < 3; t++) {
      final w = 24.0 - t * 6;
      final y = 8.0 - t * 9;
      final tri = Path()
        ..moveTo(base.dx - w / 2, base.dy + y)
        ..lineTo(base.dx + w / 2, base.dy + y)
        ..lineTo(base.dx, base.dy + y - 12)
        ..close();
      canvas.drawPath(tri, leaf);
    }
  }

  void _lake(Canvas canvas, Offset c) {
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 2), width: 120, height: 50),
        Paint()..color = _sand);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 2), width: 108, height: 40),
        Paint()..color = _sea);
    for (final dx in [-24.0, 20.0]) {
      final s = c.translate(dx, 2);
      canvas.drawOval(Rect.fromCenter(center: s, width: 13, height: 8),
          Paint()..color = Colors.white);
      canvas.drawLine(
          s.translate(4, -2),
          s.translate(4, -8),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3);
      canvas.drawCircle(s.translate(4, -8), 2.2, Paint()..color = Colors.white);
    }
    _pine(canvas, c.translate(-70, -6));
    _pine(canvas, c.translate(68, -2), dark: true);
  }

  void _tower(Canvas canvas, Offset c) {
    final body =
        Rect.fromCenter(center: c.translate(0, -12), width: 36, height: 58);
    canvas.drawRect(body, Paint()..color = const Color(0xFFF2E6D0));
    canvas.drawRect(
        body,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (var t = 0; t < 3; t++) {
      final y = body.top + 12.0 + t * 16;
      canvas.drawRect(Rect.fromLTWH(body.left, y, body.width, 3),
          Paint()..color = const Color(0xFFD9C4A0));
      canvas.drawRect(
          Rect.fromCenter(center: Offset(c.dx, y + 8), width: 6, height: 8),
          Paint()..color = const Color(0xFFE8B84B));
    }
    final roof = Path()
      ..moveTo(body.left - 6, body.top)
      ..lineTo(body.right + 6, body.top)
      ..lineTo(c.dx, body.top - 20)
      ..close();
    canvas.drawPath(roof, Paint()..color = KdColors.pink500);
    canvas.drawPath(
        roof,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    _heart(canvas, Offset(c.dx, body.top - 27), 6, KdColors.pink700);
  }

  void _volcano(Canvas canvas, Offset c) {
    final mountain = Path()
      ..moveTo(c.dx - 76, c.dy + 30)
      ..lineTo(c.dx - 36, c.dy - 22)
      ..lineTo(c.dx - 14, c.dy - 38)
      ..lineTo(c.dx + 14, c.dy - 38)
      ..lineTo(c.dx + 38, c.dy - 19)
      ..lineTo(c.dx + 76, c.dy + 30)
      ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF5C5049));
    canvas.drawPath(
        mountain,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -36), width: 26, height: 9),
        Paint()..color = KdColors.lava500);
    final lava = Paint()
      ..color = KdColors.lava500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;
    for (final (dx, wob) in [(-14.0, 7.0), (4.0, -6.0), (18.0, 5.0)]) {
      final crack = Path()
        ..moveTo(c.dx + dx, c.dy - 32)
        ..lineTo(c.dx + dx + wob, c.dy - 12)
        ..lineTo(c.dx + dx - wob * 0.5, c.dy + 8)
        ..lineTo(c.dx + dx + wob * 0.8, c.dy + 26);
      canvas.drawPath(crack, lava);
    }
    final smoke = Paint()..color = const Color(0xFFCFD2D4);
    canvas.drawCircle(c.translate(-5, -50), 7, smoke);
    canvas.drawCircle(c.translate(5, -58), 9, smoke);
  }

  void _meadow(Canvas canvas, Offset c, math.Random rng) {
    for (var i = 0; i < 12; i++) {
      final dx = (rng.nextDouble() - 0.5) * 150;
      final dy = (rng.nextDouble() - 0.5) * 56;
      _flowerDot(canvas, c.translate(dx, dy),
          rng.nextBool() ? KdColors.pink100 : Colors.white);
    }
    final base = c.translate(0, -4);
    final towerP = Path()
      ..moveTo(base.dx - 11, base.dy + 24)
      ..lineTo(base.dx + 11, base.dy + 24)
      ..lineTo(base.dx + 7, base.dy - 16)
      ..lineTo(base.dx - 7, base.dy - 16)
      ..close();
    canvas.drawPath(towerP, Paint()..color = const Color(0xFFD9B36A));
    canvas.drawPath(
        towerP,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final hub = base.translate(0, -18);
    final blade = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5;
    for (final a in [0.8, 2.37, 3.94, 5.51]) {
      canvas.drawLine(
          hub, hub.translate(math.cos(a) * 20, math.sin(a) * 20), blade);
    }
    canvas.drawCircle(hub, 3, Paint()..color = KdColors.wood900);
  }

  void _cave(Canvas canvas, Offset c) {
    final mountain = Path()
      ..moveTo(c.dx - 74, c.dy + 30)
      ..lineTo(c.dx - 34, c.dy - 26)
      ..lineTo(c.dx, c.dy - 42)
      ..lineTo(c.dx + 36, c.dy - 22)
      ..lineTo(c.dx + 74, c.dy + 30)
      ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF6E6258));
    canvas.drawPath(
        mountain,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final arch = Path()
      ..moveTo(c.dx - 12, c.dy + 28)
      ..lineTo(c.dx - 12, c.dy + 8)
      ..arcToPoint(Offset(c.dx + 12, c.dy + 8),
          radius: const Radius.circular(12))
      ..lineTo(c.dx + 12, c.dy + 28)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFF1E1826));
    for (final (dx, col) in [
      (-30.0, Color(0xFF7FB9F0)),
      (28.0, Color(0xFFB388FF)),
    ]) {
      final k = c.translate(dx, 20);
      final crystal = Path()
        ..moveTo(k.dx, k.dy - 9)
        ..lineTo(k.dx + 5, k.dy)
        ..lineTo(k.dx, k.dy + 7)
        ..lineTo(k.dx - 5, k.dy)
        ..close();
      canvas.drawPath(crystal, Paint()..color = col);
    }
  }

  void _castle(Canvas canvas, Offset c) {
    final body = Paint()..color = KdColors.pink500;
    final dark = Paint()..color = KdColors.pink700;
    final outline = Paint()
      ..color = KdColors.wood900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter;
    final base = c.translate(0, 26);
    final bodyRect =
        Rect.fromCenter(center: base.translate(0, -22), width: 80, height: 42);
    canvas.drawRect(bodyRect, body);
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
          Rect.fromLTWH(bodyRect.left + 3 + i * 16.0, bodyRect.top - 6, 10, 6),
          body);
    }
    for (final dx in [-46.0, 46.0]) {
      final tower =
          Rect.fromCenter(center: base.translate(dx, -28), width: 22, height: 54);
      canvas.drawRect(tower, body);
      final roof = Path()
        ..moveTo(tower.left - 5, tower.top)
        ..lineTo(tower.right + 5, tower.top)
        ..lineTo(tower.center.dx, tower.top - 16)
        ..close();
      canvas.drawPath(roof, dark);
      canvas.drawPath(roof, outline);
      canvas.drawRect(tower, outline);
      canvas.drawLine(Offset(tower.center.dx, tower.top - 16),
          Offset(tower.center.dx, tower.top - 27), outline);
      final flag = Path()
        ..moveTo(tower.center.dx, tower.top - 27)
        ..lineTo(tower.center.dx + 10, tower.top - 24)
        ..lineTo(tower.center.dx, tower.top - 21)
        ..close();
      canvas.drawPath(flag, dark);
    }
    final center =
        Rect.fromCenter(center: base.translate(0, -50), width: 26, height: 42);
    canvas.drawRect(center, body);
    final centerRoof = Path()
      ..moveTo(center.left - 5, center.top)
      ..lineTo(center.right + 5, center.top)
      ..lineTo(center.center.dx, center.top - 18)
      ..close();
    canvas.drawPath(centerRoof, dark);
    canvas.drawPath(centerRoof, outline);
    canvas.drawRect(center, outline);
    canvas.drawRect(bodyRect, outline);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(base.dx, bodyRect.bottom - 8), width: 14, height: 16),
        Paint()..color = KdColors.wood900);
    _heart(canvas, Offset(base.dx, bodyRect.top + 9), 5.5, Colors.white);
  }

  void _heart(Canvas canvas, Offset c, double s, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(c.translate(-s * 0.45, -s * 0.25), s * 0.52, p);
    canvas.drawCircle(c.translate(s * 0.45, -s * 0.25), s * 0.52, p);
    final tip = Path()
      ..moveTo(c.dx - s * 0.95, c.dy - s * 0.08)
      ..lineTo(c.dx + s * 0.95, c.dy - s * 0.08)
      ..lineTo(c.dx, c.dy + s)
      ..close();
    canvas.drawPath(tip, p);
  }

  void _ship(Canvas canvas, Offset c) {
    final hull = Path()
      ..moveTo(c.dx - 24, c.dy)
      ..lineTo(c.dx + 24, c.dy)
      ..lineTo(c.dx + 15, c.dy + 13)
      ..lineTo(c.dx - 15, c.dy + 13)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFF8A5A2B));
    canvas.drawPath(
        hull,
        Paint()
          ..color = KdColors.wood900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawLine(c, c.translate(0, -32),
        Paint()
          ..color = KdColors.wood900
          ..strokeWidth = 2.5);
    final sail = Path()
      ..moveTo(c.dx - 2, c.dy - 30)
      ..lineTo(c.dx - 20, c.dy - 8)
      ..lineTo(c.dx - 2, c.dy - 8)
      ..close();
    canvas.drawPath(sail, Paint()..color = Colors.white);
    final sail2 = Path()
      ..moveTo(c.dx + 2, c.dy - 26)
      ..lineTo(c.dx + 16, c.dy - 8)
      ..lineTo(c.dx + 2, c.dy - 8)
      ..close();
    canvas.drawPath(sail2, Paint()..color = Colors.white);
    final flag = Path()
      ..moveTo(c.dx, c.dy - 32)
      ..lineTo(c.dx + 9, c.dy - 29)
      ..lineTo(c.dx, c.dy - 26)
      ..close();
    canvas.drawPath(flag, Paint()..color = KdColors.pink700);
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter old) =>
      old.centers != centers;
}

/// エリアガイドの静的コンテンツ(エリア紹介ページ)。
/// 本番は areas コレクションから取得 — DEMO は全8エリアを静的定義。
class _Facility {
  const _Facility(this.icon, this.color, this.name, this.desc, {this.role = ''});
  final IconData icon;
  final Color color;
  final String name;
  final String desc;
  final String role;
}

class _Reward {
  const _Reward(this.icon, this.color, this.label, this.value);
  final IconData icon;
  final Color color;
  final String label;
  final String value;
}

class _AreaGuide {
  const _AreaGuide({
    required this.subtitle,
    required this.concept,
    required this.facilities,
    required this.teacherMessage,
    this.header,
    this.highlights = const [],
    this.todos = const [],
    this.facilityTitle = 'この街でできること',
    this.powersTitle = '',
    this.powers = const [],
    this.quests = const [],
    this.rewards = const [],
    this.items = const [],
    this.footer,
  });
  final String subtitle;
  final String concept;
  final String? header;
  final List<String> highlights; // 見どころ(エリア①)
  final List<String> todos; // シンプルなできること(エリア①)
  final String facilityTitle;
  final List<_Facility> facilities;
  final String powersTitle;
  final List<(String, String)> powers; // (力の名前, 効果)
  final List<(String, String)> quests; // (クエスト名, EXP表記)
  final List<_Reward> rewards;
  final List<(String, String)> items; // (アイテム名, 効果)
  final String teacherMessage;
  final String? footer;
}

const _guides = <String, _AreaGuide>{
  // ── エリア① はじまりの街（みぽりん村） ──────────────────
  'area_01_hajimari': _AreaGuide(
    subtitle: '〜すべての冒険の第一歩〜',
    concept: 'みぽりん先生と出会い、夢に向かって一歩を踏み出すための'
        '温かく安心できる"はじまりの場所"。'
        '仲間や学びがそろい、あなたの「やってみたい！」を'
        'やさしく応援してくれる街です。',
    highlights: [
      'みぽりん先生の教えがそろう学びの拠点',
      '仲間とつながる交流の場所',
      '最初のミッションやクエストを受けられる掲示板',
      'おしゃれでかわいいショップやカフェも充実♪',
      'あなたの成長をそっと見守ってくれる街',
    ],
    todos: [
      '初めての学びを受ける（レッスン・クエスト）',
      '仲間と出会い、つながる（コミュニティ）',
      'アイテムやデザイン素材をそろえる（ショップ）',
      '今日のやることを決める（掲示板・ミッション）',
      'ほっと一息ついて、リフレッシュする（カフェ・公園）',
    ],
    facilityTitle: '主な施設紹介',
    facilities: [
      _Facility(Icons.castle, KdColors.pink700, 'みぽりん先生の城',
          'レッスンや教えがそろうこの街の中心。先生がいつも見守ってくれるよ♪',
          role: '学びの拠点'),
      _Facility(Icons.assignment, KdColors.wood700, 'クエスト掲示板',
          '今日のミッションやイベントをチェック！やることが見つかるよ♪',
          role: 'ミッション受付'),
      _Facility(Icons.cottage, KdColors.pink500, 'コミュニティハウス',
          '仲間と交流したり、相談したりできるあたたかいおうち♪',
          role: '仲間とつながる場所'),
      _Facility(Icons.storefront, KdColors.gold500, 'デザインショップ',
          'デザインに役立つアイテムや素材がそろうお店♪',
          role: 'アイテム・素材屋'),
      _Facility(Icons.palette, KdColors.lava500, 'みぽりん工房',
          '制作の練習をしたり、作品を生み出すワクワクの工房♪',
          role: '制作・練習の場所'),
      _Facility(Icons.local_cafe, KdColors.ocean500, 'みぽりんカフェ',
          'ほっと一息つけるカフェでリフレッシュ♪ おしゃべりもOK！',
          role: 'ひとやすみ'),
      _Facility(Icons.local_florist, KdColors.grass500, 'みぽりんガーデン',
          'お花や緑に囲まれた癒しの庭。気分転換にぴったり♪',
          role: '癒しの庭'),
    ],
    teacherMessage: 'ここは、あなたの冒険のはじまりの場所。\n'
        '小さな一歩が、大きな未来につながるよ！\n'
        'みぽりん村で、わくわくする毎日を\n'
        'スタートさせようね♪',
  ),

  // ── エリア② みがき上げの森 ──────────────────────────
  'area_02_migaki': _AreaGuide(
    subtitle: '〜毎日の積み重ねが才能を育てる場所〜',
    header: 'ここでの学びが、自信となり、あなたを勇者へと導くよ！',
    concept: 'デザイナーは、一日で大きく成長するわけではありません。'
        '毎日の小さな挑戦や学びの積み重ねが、やがて大きな自信につながります。'
        'この森では、「続ける力」を育てながら、自分だけの才能を磨いていきます。',
    facilityTitle: 'この森でできること',
    facilities: [
      _Facility(Icons.brush, KdColors.pink500, 'デザイン練習場',
          'バナー制作・模写・配色練習。実践を通して、スキルをみがこう！'),
      _Facility(Icons.menu_book, KdColors.wood700, '学びの図書館',
          'デザイン・Web・AI・マーケティング。知識をインプットして、未来を広げよう！'),
      _Facility(Icons.lightbulb, KdColors.gold500, 'ひらめきスポット',
          'アイデア探し・散歩・インプット。アイデアが降りてくるよ♪'),
      _Facility(Icons.rate_review, KdColors.grass500, '添削の切り株',
          '作品添削・フィードバック・改善ポイント発見。プロのフィードバックで、ぐんぐん成長しよう！'),
      _Facility(Icons.water_drop, KdColors.ocean500, '習慣の泉',
          '毎日5分チャレンジ・投稿習慣・学習記録。毎日の小さな積み重ねが、大きな力になるよ！'),
    ],
    quests: [
      ('デザインを1枚作ろう', 'EXP+100'),
      ('AIを1つ試してみよう', 'EXP+100'),
      ('模写を30分しよう', 'EXP+100'),
      ('今日の学びを記録しよう', 'EXP+100'),
      ('作品を添削に出そう', 'EXP+150'),
      ('Xへアウトプットしよう', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.eco, KdColors.grass500, '継続力', '+10'),
      _Reward(Icons.brush, KdColors.pink500, '制作力', '+10'),
      _Reward(Icons.lightbulb, KdColors.gold500, '発想力', '+5'),
      _Reward(Icons.redeem, KdColors.pink700, 'アイテムがもらえることも♪', ''),
    ],
    teacherMessage: '才能は、生まれつきじゃないよ🌸\n'
        '今日の小さな一歩が、\n'
        '明日の大きな成長になるんだ♪\n'
        '焦らず、一緒に\n'
        'レベルアップしていこうね♡',
    footer: 'この森で「続ける力」を身につけると、あなたの未来がもっと輝き出すよ！',
  ),

  // ── エリア③ コミュ力の湖 ─────────────────────────────
  'area_03_commu': _AreaGuide(
    subtitle: '〜つながりが、未来を広げる場所〜',
    header: 'つながろう、支え合おう、あなたらしい魅力を伝えよう！',
    concept: 'デザイナーは、一人では大きく飛躍できません。'
        '仲間やお客様、応援してくれる人との「つながり」が、'
        'お仕事や夢を叶える力になります。'
        'この湖では、安心して交流し、信頼関係を育てながら、'
        'あなたらしい魅力を発信していきます。',
    facilityTitle: 'この湖でできること',
    facilities: [
      _Facility(Icons.groups, KdColors.ocean500, '交流の桟橋（さんばし）',
          '仲間と気軽に交流できるエリア。あいさつやコメントでつながろう'),
      _Facility(Icons.local_cafe, KdColors.pink500, 'シェアのカフェ',
          '作品や学びをシェアできる場所。自分の想いを発信しよう'),
      _Facility(Icons.beach_access, KdColors.gold500, '相談のテラス',
          '悩みや疑問を相談できるエリア。先輩や仲間からアドバイスがもらえる'),
      _Facility(Icons.park, KdColors.grass500, 'コラボの小島',
          'コラボ企画やチーム活動ができる場所。一緒に作品やイベントをつくろう'),
      _Facility(Icons.flare, KdColors.lava500, '感謝の灯台',
          '感謝を伝え合い、信頼を育てる場所。「ありがとう」が循環するエリア'),
    ],
    powersTitle: 'この湖での行動で育つ力',
    powers: [
      ('コミュニケーション力', '人とつながる力がアップ！'),
      ('発信力', '自分の想いや魅力を伝える力がアップ！'),
      ('信頼力', '信頼関係を築き、応援される力がアップ！'),
      ('チーム力', '協力して成果を出す力がアップ！'),
      ('共感力', '相手の気持ちを理解する力がアップ！'),
    ],
    quests: [
      ('仲間にあいさつしてみよう！', 'EXP+100'),
      ('仲間の投稿にコメントしよう！', 'EXP+100'),
      ('自分の作品をシェアしよう！', 'EXP+150'),
      ('悩みを相談してみよう！', 'EXP+100'),
      ('コラボに参加してみよう！', 'EXP+200'),
      ('誰かに「ありがとう」を伝えよう！', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.favorite, KdColors.pink500, '信頼力', '+10'),
      _Reward(Icons.campaign, KdColors.lava500, '発信力', '+10'),
      _Reward(Icons.volunteer_activism, KdColors.pink700, '共感力', '+10'),
      _Reward(Icons.redeem, KdColors.pink700, '特別なごほうびアイテム', ''),
    ],
    teacherMessage: '一人ではできないことも、\n'
        '仲間とならきっとできるよ♪\n'
        '思いやりのある言葉や行動が、\n'
        'あなたの未来を\n'
        'キラキラ輝かせるの♡',
    footer: 'つながりが、チャンスを連れてくるよ！信じて、勇気を出して一歩踏み出そう！',
  ),

  // ── エリア④ 自信の塔 ────────────────────────────────
  'area_04_jishin': _AreaGuide(
    subtitle: '〜自分を信じて、未来をつかむ場所〜',
    header: '一歩ずつ登っていくたびに、あなたの自信が輝きを増していくよ！',
    concept: 'ここは、自分の成長を振り返り、「できた！」を積み重ねていく場所。'
        'ひとつひとつの階段が、あなたの自信になります。'
        '一番上には、あなたの理想の未来が待っています。',
    facilityTitle: 'この塔でできること',
    facilities: [
      _Facility(Icons.stairs, KdColors.pink500, '成長の階段（1階）',
          'これまでの実績や学びを記録して、自分の成長を見える化しよう！'),
      _Facility(Icons.photo_library, KdColors.gold500, '実績ギャラリー',
          '制作した作品や成果を飾って、自信を育てよう！'),
      _Facility(Icons.track_changes, KdColors.lava500, '目標の部屋',
          '未来の目標を設定して、やりたいことを明確にしよう！'),
      _Facility(Icons.balcony, KdColors.ocean500, '勇気のバルコニー',
          '一歩踏み出した経験を振り返り、「やってよかった！」を増やそう！'),
      _Facility(Icons.redeem, KdColors.pink700, 'ごほうびの間',
          '自分をたくさん褒めてあげよう♪ ごほうびでやる気もアップ！'),
      _Facility(Icons.travel_explore, KdColors.grass500, '未来の展望台（最上階）',
          '理想の未来をイメージして、ワクワクする未来を描こう！'),
    ],
    quests: [
      ('過去の作品を振り返ろう！', 'EXP+100'),
      ('小さな目標を設定しよう！', 'EXP+100'),
      ('できたことリストを作ろう！', 'EXP+150'),
      ('勇気を出して発信してみよう！', 'EXP+150'),
      ('自分をたくさん褒めよう！', 'EXP+100'),
      ('未来の自分に手紙を書こう！', 'EXP+200'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.favorite, KdColors.pink500, '自信力', '+20'),
      _Reward(Icons.campaign, KdColors.lava500, '行動力', '+15'),
      _Reward(Icons.eco, KdColors.grass500, '継続力', '+15'),
      _Reward(Icons.redeem, KdColors.pink700, '魅力アップアイテム', ''),
    ],
    items: [
      ('キラキラの証', '自信力UP'),
      ('勇気のチャーム', '行動力UP'),
      ('未来チケット', '目標達成率UP'),
      ('ごほうびボックス', 'やる気UP'),
    ],
    teacherMessage: '自信は、特別な人だけのものじゃないよ♪\n'
        'あなたが積み重ねてきた努力は、\n'
        'ちゃんと未来につながっているよ！\n'
        '一緒に、もっともっと高い景色を\n'
        '見に行こうね♪',
    footer: '自分を信じることが、あなたの未来を輝かせる一番の魔法だよ！',
  ),

  // ── エリア⑤ やる気の火山 ────────────────────────────
  'area_05_yaruki': _AreaGuide(
    subtitle: '〜心の火を燃やして、行動力を高める場所〜',
    header: 'やる気の炎を燃やし続けて、理想の未来に向かって進もう！',
    concept: 'やる気は、待っていても湧いてきません。'
        '小さな成功体験や仲間の応援が、あなたの心に火をつけます。'
        'この火山で、やる気の炎を燃やし続けて、'
        'どんどん行動力をアップさせていきましょう！',
    facilityTitle: 'この火山でできること',
    facilities: [
      _Facility(Icons.local_fire_department, KdColors.lava500, '炎のスイッチ広場',
          'やる気をONにする習慣づくり。毎日の習慣で火をつけよう！'),
      _Facility(Icons.hiking, KdColors.wood700, 'チャレンジの溶岩道',
          '小さな挑戦を積み重ねるエリア。自信とやる気を積み上げよう！'),
      _Facility(Icons.campaign, KdColors.pink500, '応援の展望台',
          '仲間の声援や応援で、心の火がもっと大きくなる！'),
      _Facility(Icons.flag, KdColors.gold500, '目標のマグマ部屋',
          '自分の目標をいつでも確認！夢への道がはっきり見えるよ！'),
      _Facility(Icons.rocket_launch, KdColors.lava500, '行動の噴火口',
          'ひらめいたアイデアを、すぐに行動に移そう！行動がやる気を加速させるよ！'),
      _Facility(Icons.hot_tub, KdColors.ocean500, 'ごほうびの温泉',
          'がんばった自分をしっかりほめて、心も体もリフレッシュ♪'),
    ],
    powersTitle: 'この火山で育つ力',
    powers: [
      ('行動力', 'すぐに行動する力がUP！'),
      ('継続力', '続けることでやる気が持続！'),
      ('自己肯定感', '小さな成功で自信がつく！'),
      ('目標達成力', '目標に向かう力が強くなる！'),
      ('挑戦力', '新しいことに挑戦できるようになる！'),
    ],
    quests: [
      ('やることリストを作ろう', 'EXP+100'),
      ('今日の目標を設定しよう', 'EXP+100'),
      ('小さなことから始めよう', 'EXP+150'),
      ('新しいことに挑戦しよう', 'EXP+150'),
      ('できたことを記録しよう', 'EXP+100'),
      ('自分をほめてごほうびをあげよう', 'EXP+200'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.local_fire_department, KdColors.lava500, 'やる気', '+20'),
      _Reward(Icons.campaign, KdColors.pink500, '行動力', '+20'),
      _Reward(Icons.eco, KdColors.grass500, '継続力', '+15'),
      _Reward(Icons.bolt, KdColors.gold500, '挑戦力', '+15'),
      _Reward(Icons.redeem, KdColors.pink700, 'やる気アップアイテム', ''),
    ],
    teacherMessage: 'やる気は、あなたの中にちゃんとあるよ！\n'
        '時には、火が小さくなることもあるけど、\n'
        '大丈夫♪この火山で、また火をつければいいの！\n'
        'あなたの夢に向かって、\n'
        '一緒にがんばっていこうね♡',
    footer: '心の火を消さずに、今日も一歩ずつ夢に近づいていこう！',
  ),

  // ── エリア⑥ 仲間の大草原 ────────────────────────────
  'area_06_nakama': _AreaGuide(
    subtitle: '〜つながり、支え合い、一緒に成長する場所〜',
    header: 'つながろう、支え合おう！仲間と一緒に、理想の未来へ♪',
    concept: '一人では、くじけそうになることもあるけれど、'
        '仲間がいるから、がんばれる！'
        'この大草原では、仲間と出会い、刺激し合い、'
        '支え合いながら、理想の未来へ進んでいけます。',
    facilityTitle: 'この草原でできること',
    facilities: [
      _Facility(Icons.groups, KdColors.pink500, '仲間の広場',
          '自己紹介や交流ができる場所。はじめましてのあいさつから、素敵なつながりが生まれるよ！'),
      _Facility(Icons.terrain, KdColors.grass500, 'チームワークの丘',
          'チームを組んで、一緒に目標に向かって進もう！'),
      _Facility(Icons.park, KdColors.forest700, 'シェアの木',
          '作品や学びをシェアして、みんなで成長しよう！'),
      _Facility(Icons.mail, KdColors.pink700, '応援メッセージのポスト',
          '応援のメッセージやいいねで、仲間のやる気を後押ししよう！'),
      _Facility(Icons.assignment, KdColors.wood700, 'みんなの掲示板',
          'イベントやお知らせを見逃さず、チャンスをつかもう！'),
      _Facility(Icons.festival, KdColors.pink500, 'コラボのテント',
          'コラボ企画やイベントで、新しいアイデアが生まれるよ！'),
      _Facility(Icons.local_florist, KdColors.lava500, '感謝の花畑',
          '「ありがとう」を伝え合って、信頼と絆を育てよう！'),
      _Facility(Icons.shopping_basket, KdColors.gold500, 'ピクニックエリア',
          'リラックスしながら、自由におしゃべり＆情報交換♪'),
    ],
    powersTitle: 'この草原で育つ力',
    powers: [
      ('コミュニケーション力', '伝える力がアップ！'),
      ('協調性', '協力して成長できる！'),
      ('信頼力', '信頼関係が深まる！'),
      ('モチベーション', 'やる気が続く！'),
      ('共感力', '相手の気持ちに寄り添える！'),
    ],
    quests: [
      ('仲間に自己紹介をしよう', 'EXP+100'),
      ('仲間の投稿にいいねをしよう', 'EXP+100'),
      ('チームに参加しよう', 'EXP+150'),
      ('コラボイベントに参加しよう', 'EXP+200'),
      ('仲間に応援メッセージを送ろう', 'EXP+100'),
      ('「ありがとう」を伝えよう', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.favorite, KdColors.pink500, 'つながりポイント', '+20'),
      _Reward(Icons.campaign, KdColors.lava500, '信頼度', '+15'),
      _Reward(Icons.local_fire_department, KdColors.gold500, 'やる気', '+20'),
      _Reward(Icons.redeem, KdColors.pink700, '特別なごほうびアイテム', ''),
    ],
    teacherMessage: '一人で頑張ることも大切だけど、\n'
        '仲間と一緒だと、もっともっと\n'
        '大きな未来が待っているよ！\n'
        '支え合い、励まし合いながら、\n'
        'あなたらしく輝いていこうね♡',
    footer: '仲間とのつながりが、あなたの未来をもっと明るく、もっと楽しくしてくれるよ！',
  ),

  // ── エリア⑦ 試練の洞窟 ──────────────────────────────
  'area_07_shiren': _AreaGuide(
    subtitle: '〜自分の限界を超えて、強くなる場所〜',
    header: '試練を乗り越えた先に、新しい自分が待っている！',
    concept: '成長の道のりには、時に壁が立ちはだかります。'
        'でも、その壁を乗り越えた先に、新しい自分が待っています。'
        'ここは、あなたの「挑戦する力」と「乗り越える力」を育てる場所。'
        '試練を乗り越えて、さらにレベルアップしよう！',
    facilityTitle: 'この洞窟でできること',
    facilities: [
      _Facility(Icons.palette, KdColors.pink500, 'デザインの試練',
          '苦手なデザインや新しい表現に挑戦！'),
      _Facility(Icons.hourglass_bottom, KdColors.ocean500, '時間の試練',
          '制限時間内に課題をクリアしよう！'),
      _Facility(Icons.lightbulb, KdColors.gold500, 'アイデアの試練',
          'お題から自由にアイデアを出そう！'),
      _Facility(Icons.calendar_month, KdColors.grass500, '継続の試練',
          '毎日コツコツ取り組む力を試そう！'),
      _Facility(Icons.shield, KdColors.pink700, '自信の試練',
          '自分の作品を公開してみよう！'),
      _Facility(Icons.sports_martial_arts, KdColors.lava500, '総合の試練（ボス戦）',
          'これまでの力をすべて使って、最後のボスに挑め！'),
    ],
    powersTitle: 'この洞窟で育つ力',
    powers: [
      ('挑戦力', '新しいことに挑戦する力がアップ！'),
      ('集中力', '集中して取り組む力がアップ！'),
      ('突破力', '壁を乗り越える力がアップ！'),
      ('自己肯定感', '自分を信じる力がアップ！'),
      ('成長実感', '成長を実感して自信がつく！'),
    ],
    quests: [
      ('苦手なデザインに挑戦しよう', 'EXP+100'),
      ('制限時間内にバナーを作ろう', 'EXP+100'),
      ('お題からアイデアを10個出そう', 'EXP+150'),
      ('7日間、毎日学習しよう', 'EXP+150'),
      ('自分の作品をSNSに投稿しよう', 'EXP+150'),
      ('ボス課題にチャレンジしよう', 'EXP+200'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100〜300'),
      _Reward(Icons.bolt, KdColors.lava500, '挑戦力', '+20'),
      _Reward(Icons.center_focus_strong, KdColors.ocean500, '集中力', '+15'),
      _Reward(Icons.shield, KdColors.grass500, '突破力', '+20'),
      _Reward(Icons.favorite, KdColors.pink500, '自信ポイント', '+20'),
      _Reward(Icons.redeem, KdColors.pink700, '特別なごほうびアイテム', ''),
    ],
    items: [
      ('勇気のブレスレット', '挑戦力UP'),
      ('集中のリング', '集中力UP'),
      ('突破の盾', '突破力UP'),
      ('自信の鏡', '自己肯定感UP'),
      ('試練の鍵', '特別エリア解放'),
    ],
    teacherMessage: '試練があるからこそ、成長できるよ！\n'
        'うまくいかなくても大丈夫。\n'
        'あきらめずに挑戦し続ければ、\n'
        '必ず乗り越えられるから、\n'
        '一緒にがんばっていこうね♡',
    footer: '試練を乗り越えたあなたは、もっと強く、もっと輝ける！未来の自分を信じて進もう！',
  ),

  // ── エリア⑧ みぽりん城 ──────────────────────────────
  'area_08_miporin': _AreaGuide(
    subtitle: '〜理想の自分に、もっと近づける場所〜',
    header: 'ここは、みぽりん先生からたくさんの学びとごほうびがもらえる特別な場所！',
    concept: 'デザインやマーケティングを学び、実践し、'
        '仲間と切磋琢磨しながら、理想の未来を叶えていく場所。'
        'みぽりん先生の想いと、みんなのがんばりがつまった、'
        'デザイン王国のシンボルです。',
    facilityTitle: 'みぽりん城でできること',
    facilities: [
      _Facility(Icons.favorite, KdColors.pink700, 'みぽりん先生の部屋',
          'みぽりん先生から特別なメッセージやアドバイスがもらえるよ♪'),
      _Facility(Icons.school, KdColors.pink500, '特別レッスンホール',
          '限定ライブやセミナー、特別レッスンに参加できるよ！'),
      _Facility(Icons.emoji_events, KdColors.gold500, '実績ギャラリー',
          'みんなのがんばりや成果が展示されるよ！'),
      _Facility(Icons.redeem, KdColors.pink500, 'ごほうび広場',
          'クエストクリアや目標達成でごほうびがもらえるよ！'),
      _Facility(Icons.menu_book, KdColors.wood700, '学びの図書館',
          'デザイン・マーケティング・AIなどの知識がたくさんつまっているよ！'),
      _Facility(Icons.auto_awesome, KdColors.ocean500, '未来の展望テラス',
          '理想の未来を描いて、目標を再確認しよう！'),
    ],
    powersTitle: 'みぽりん城で育つ力',
    powers: [
      ('専門スキル力', 'レベルアップ！'),
      ('実践力', '行動して成果につなげる力！'),
      ('継続力', 'コツコツ続ける力！'),
      ('自己肯定感', '自分を信じられる力！'),
      ('夢実現力', '理想の未来を叶える力！'),
    ],
    quests: [
      ('特別レッスンに参加しよう', 'EXP+200'),
      ('作品を提出してみよう', 'EXP+150'),
      ('仲間に応援メッセージを送ろう', 'EXP+100'),
      ('目標を見直してみよう', 'EXP+100'),
      ('イベントに参加しよう', 'EXP+150'),
      ('実績をギャラリーに追加しよう', 'EXP+200'),
      ('みぽりん先生に質問してみよう', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+200〜500'),
      _Reward(Icons.favorite, KdColors.pink500, 'みぽりんポイント', '+50'),
      _Reward(Icons.shield, KdColors.ocean500, '自信バッジ', '+1'),
      _Reward(Icons.redeem, KdColors.pink700, '特別アイテム', ''),
      _Reward(Icons.emoji_events, KdColors.gold500, '限定称号', ''),
      _Reward(Icons.confirmation_number, KdColors.pink500, 'ごほうびチケット', ''),
    ],
    teacherMessage: 'ここまで本当にがんばってきたね！\n'
        'あなたの努力は、必ず未来につながるよ。\n'
        'みぽりん先生は、あなたのことを\n'
        'いつも応援しているよ♡\n'
        'これからも一緒に、\n'
        '理想の未来を叶えていこうね！',
    footer: 'あなたの努力は、あなたの未来をつくる最高の魔法だよ！',
  ),
};

/// SC-31 エリア詳細(町ビュー)。授かり効果の中心画面。
/// 全エリアに「全体マップ提案」様式の紹介ページを表示。
class AreaDetailPage extends ConsumerWidget {
  const AreaDetailPage({super.key, required this.areaId});
  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = kAreas.firstWhere((a) => a.id == areaId,
        orElse: () => kAreas.first);
    final progress = ref.watch(userProgressProvider);
    final delivered = progress.areaDelivered[areaId] ?? 0;
    final stage = progress.stageOf(areaId);
    final guide = _guides[areaId];

    return Scaffold(
      appBar: AppBar(title: Text(area.name)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (guide != null) ...[
            // ── リボンタイトル + サブタイトル ──
            Center(child: KdRibbonBanner(area.name, fontSize: 17)),
            const SizedBox(height: 6),
            Center(
              child: Text(guide.subtitle,
                  textAlign: TextAlign.center,
                  style: KdTheme.dot(size: 13, color: KdColors.pink700)),
            ),
            const SizedBox(height: 16),
            // ── ヘッダー帯 ──
            if (guide.header != null) ...[
              KdBandMessage(guide.header!),
              const SizedBox(height: 16),
            ],
            // ── コンセプト ──
            const KdSectionHeader('コンセプト'),
            const SizedBox(height: 8),
            KdParchmentCard(
              child: Text(guide.concept,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 20),
            // ── 見どころ(エリア①のみ) ──
            if (guide.highlights.isNotEmpty) ...[
              const KdSectionHeader('見どころ'),
              const SizedBox(height: 8),
              KdParchmentCard(
                child: _IconLines(
                    icon: Icons.local_florist,
                    color: KdColors.pink500,
                    lines: guide.highlights),
              ),
              const SizedBox(height: 20),
            ],
            // ── シンプルなできること(エリア①のみ) ──
            if (guide.todos.isNotEmpty) ...[
              const KdSectionHeader('この街でできること'),
              const SizedBox(height: 8),
              KdParchmentCard(
                child: _IconLines(
                    icon: Icons.auto_awesome,
                    color: KdColors.gold500,
                    lines: guide.todos),
              ),
              const SizedBox(height: 20),
            ],
            // ── 施設一覧 ──
            Center(child: KdRibbonBanner(guide.facilityTitle, fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Column(children: [
                for (final (i, f) in guide.facilities.indexed) ...[
                  if (i > 0) const Divider(height: 18),
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: f.color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: KdColors.wood900, width: 2),
                      ),
                      child: Icon(f.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.ideographic,
                                children: [
                                  Flexible(
                                    child: Text(f.name,
                                        style: KdTheme.dot(
                                                size: 14,
                                                color: KdColors.heading)
                                            .copyWith(
                                                fontWeight: FontWeight.w700)),
                                  ),
                                  if (f.role.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('（${f.role}）',
                                        style: KdTheme.dot(
                                            size: 11, color: KdColors.ink900)),
                                  ],
                                ]),
                            const SizedBox(height: 2),
                            Text(f.desc,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ]),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // ── 育つ力 ──
            if (guide.powers.isNotEmpty) ...[
              Center(child: KdRibbonBanner(guide.powersTitle, fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, p) in guide.powers.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.favorite,
                              size: 16, color: KdColors.pink500),
                          const SizedBox(width: 8),
                          Text(p.$1,
                              style: KdTheme.dot(
                                      size: 13, color: KdColors.ink900)
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(p.$2,
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ),
                        ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── おすすめクエスト ──
            if (guide.quests.isNotEmpty) ...[
              Center(child: KdRibbonBanner('おすすめクエスト', fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, q) in guide.quests.indexed) ...[
                    if (i > 0) const Divider(height: 14),
                    Row(children: [
                      const Icon(Icons.star,
                          size: 18, color: KdColors.gold500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(q.$1,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: KdColors.pink100,
                          borderRadius: BorderRadius.circular(3),
                          border:
                              Border.all(color: KdColors.pink500, width: 1.5),
                        ),
                        child: Text(q.$2,
                            style: KdTheme.dot(
                                size: 12, color: KdColors.pink700)),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── クリア報酬(例) ──
            if (guide.rewards.isNotEmpty) ...[
              Center(child: KdRibbonBanner('クリア報酬（例）', fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, r) in guide.rewards.indexed) ...[
                    if (i > 0) const Divider(height: 14),
                    Row(children: [
                      Icon(r.icon, size: 20, color: r.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.label,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      if (r.value.isNotEmpty)
                        Text(r.value,
                            style:
                                KdTheme.dot(size: 15, color: KdColors.heading)
                                    .copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── 手に入るアイテム(例) ──
            if (guide.items.isNotEmpty) ...[
              Center(child: KdRibbonBanner('手に入るアイテム（例）', fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, item) in guide.items.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.card_giftcard,
                          size: 18, color: KdColors.gold500),
                      const SizedBox(width: 8),
                      Text(item.$1,
                          style: KdTheme.dot(size: 13, color: KdColors.heading)
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('（${item.$2}）',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── みぽりん先生からのメッセージ ──
            Center(
                child: KdRibbonBanner('みぽりん先生からのメッセージ', fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KdColors.pink100,
                        shape: BoxShape.circle,
                        border: Border.all(color: KdColors.pink500, width: 2),
                      ),
                      child: const Icon(Icons.favorite,
                          color: KdColors.pink500, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(guide.teacherMessage,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ]),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // ガイド未定義エリアの骨格(発展stageで色が濃くなる)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: area.color.withOpacity(0.2 + stage * 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: KdColors.border, width: 2),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(area.icon, size: 64, color: area.color),
                  Text('発展レベル $stage / 3',
                      style: KdTheme.dot(size: 14, color: KdColors.ink900)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            KdParchmentCard(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('このエリアで育つもの',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('マインド: ${area.mindTheme}',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('スキル: ${area.skillLabel}',
                    style: Theme.of(context).textTheme.bodyLarge),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          // ── エリアクリアまで(共通) ──
          KdParchmentCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('エリアクリアまで',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                Text('$delivered / 12',
                    style: KdTheme.dot(size: 15, color: KdColors.ink900)),
              ]),
              const SizedBox(height: 8),
              KdProgressBar(value: delivered / 12),
              const SizedBox(height: 8),
              Text('12件納品でボス戦（大型案件）が解放されるよ',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          if (guide != null) ...[
            const SizedBox(height: 20),
            // ── フッター帯 ──
            if (guide.footer != null) ...[
              KdBandMessage(guide.footer!),
              const SizedBox(height: 12),
            ],
            // ── 冒険への入り口(ワールドマップへ) ──
            KdPrimaryButton(
              label: '冒険への入り口（ワールドマップへ）',
              onPressed: () => context.go('/map'),
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

/// アイコン + 1行テキストのリスト(見どころ・できること用)。
class _IconLines extends StatelessWidget {
  const _IconLines(
      {required this.icon, required this.color, required this.lines});
  final IconData icon;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final (i, line) in lines.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ]),
      ],
    ]);
  }
}
