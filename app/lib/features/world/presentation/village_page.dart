import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes_clean.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// みぽりん村の村内マップ(SC-31 町ビューの核心)。
/// 「全体マップ提案」の配置を再現: 中央の噴水広場を囲んで
/// 城・カフェ・ショップ・掲示板・コミュニティハウス・工房・ガーデンが建つ。
/// 施設をタップするとアバターがそこまで歩いてから、施設の機能が開く。
class VillagePage extends ConsumerStatefulWidget {
  const VillagePage({super.key});

  @override
  ConsumerState<VillagePage> createState() => _VillagePageState();
}

/// 村の施設定義(位置は 0.0-1.0 の正規化座標)。
class _Facility {
  const _Facility(this.id, this.name, this.role, this.pos);
  final String id;
  final String name;
  final String role;
  final Offset pos;
}

const _facilities = [
  _Facility('castle', 'みぽりん先生の城', '学びの拠点', Offset(0.50, 0.13)),
  _Facility('cafe', 'みぽりんカフェ', 'ひとやすみ', Offset(0.15, 0.16)),
  _Facility('shop', 'デザインショップ', 'アイテム・素材屋', Offset(0.85, 0.18)),
  _Facility('board', 'クエスト掲示板', 'ミッション受付', Offset(0.13, 0.44)),
  _Facility('community', 'コミュニティハウス', '仲間とつながる場所', Offset(0.87, 0.46)),
  _Facility('studio', 'みぽりん工房', '制作・練習の場所', Offset(0.50, 0.66)),
  _Facility('garden', 'みぽりんガーデン', '癒しの庭', Offset(0.84, 0.78)),
  _Facility('gate', '冒険への入り口', 'ワールドマップへ', Offset(0.13, 0.80)),
];

// 噴水広場(アバターの初期位置)
const _plaza = Offset(0.50, 0.40);

class _VillagePageState extends ConsumerState<VillagePage> {
  // 噴水のすこし手前(広場の石畳の上)からスタート
  Offset _avatar = _plaza + const Offset(0, 0.055);
  bool _walking = false;

  Future<void> _visit(_Facility f) async {
    if (_walking) return;
    setState(() {
      _walking = true;
      // 建物の少し手前に立つ
      _avatar = f.pos + const Offset(0, 0.055);
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _walking = false);
    _openFacility(f);
  }

  void _openFacility(_Facility f) {
    switch (f.id) {
      case 'castle':
        context.push('/area/area_01_hajimari'); // エリアガイド = 学びの拠点
      case 'gate':
        context.go('/map');
      case 'board':
        context.go('/home'); // きょうの依頼リストへ
      case 'studio':
        // いま挑戦できる依頼があれば工房から直行
        final offers = ref.read(todayOffersProvider).valueOrNull;
        final delivered = ref.read(userProgressProvider).deliveredQuestIds;
        final next = offers?.where((q) => !delivered.contains(q.questId));
        if (next != null && next.isNotEmpty) {
          context.push('/quest/${next.first.questId}');
        } else {
          _message('きょうのお仕事はぜんぶ完了！工房はまた明日ひらくよ♪');
        }
      case 'cafe':
        _message('カフェでひとやすみ♪ あったかいココアをどうぞ♡');
      case 'shop':
        _message('デザインショップは v1.1 で開店するよ！おたのしみに♪');
      case 'community':
        _message('コミュニティハウスは v1.1 で仲間とつながれるよ♪');
      case 'garden':
        _message('お花のいい香り…ガーデンで気分転換できたよ♪');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('はじまりの街（みぽりん村）')),
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = math.max(constraints.maxHeight, 640.0);

        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _VillagePainter(
                    facilities: {
                      for (final f in _facilities) f.id: f.pos,
                    },
                    plaza: _plaza,
                  ),
                ),
              ),
              // 施設ラベル(タップでアバターが移動)
              for (final f in _facilities)
                Positioned(
                  left: f.pos.dx * w - 78,
                  top: f.pos.dy * h + 26,
                  child: SizedBox(
                    width: 156,
                    child: Center(child: _FacilityLabel(f: f, onTap: () => _visit(f))),
                  ),
                ),
              // 施設の建物部分もタップできるように(ラベルの上の透明領域)
              for (final f in _facilities)
                Positioned(
                  left: f.pos.dx * w - 45,
                  top: f.pos.dy * h - 50,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _visit(f),
                    child: const SizedBox(width: 90, height: 76),
                  ),
                ),
              // アバター(タップした施設まで歩く)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOut,
                left: _avatar.dx * w - 17,
                top: _avatar.dy * h - 17,
                child: _Avatar(walking: _walking),
              ),
              // 案内チップ
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KdColors.pink500, width: 2),
                    ),
                    child: Text('いきたい場所をタップしてね♪',
                        style: KdTheme.dot(size: 12, color: KdColors.pink700)),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

/// プレイヤーのアバター(ピンクの円 + 影。本番はドット絵キャラに差し替え)。
class _Avatar extends StatelessWidget {
  const _Avatar({required this.walking});
  final bool walking;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: KdColors.pink100,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.wood900, width: 2.5),
          boxShadow: const [
            BoxShadow(color: KdColors.pink700, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(walking ? Icons.directions_walk : Icons.person,
            size: 18, color: KdColors.pink700),
      ),
    ]);
  }
}

/// 施設ラベル(全体マップ提案の深ピンクのプレート様式)。
class _FacilityLabel extends StatelessWidget {
  const _FacilityLabel({required this.f, required this.onTap});
  final _Facility f;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: KdColors.pink700,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: KdColors.gold500, width: 1.5),
          boxShadow: const [
            BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(f.name,
              style: KdTheme.dot(size: 11, color: Colors.white)
                  .copyWith(fontWeight: FontWeight.w700)),
          Text('（${f.role}）', style: KdTheme.dot(size: 9, color: Colors.white)),
        ]),
      ),
    );
  }
}

/// 村の絵: 草地・川・石畳の道・噴水広場・各施設の建物(ドット絵の作法)。
class _VillagePainter extends CustomPainter {
  const _VillagePainter({required this.facilities, required this.plaza});
  final Map<String, Offset> facilities;
  final Offset plaza;

  static const _grass = Color(0xFF77B94C);
  static const _grassLight = Color(0xFF85C55C);
  static const _river = Color(0xFF85C4E8);
  static const _riverLight = Colors.white;
  static const _stone = Color(0xFFE3C99A);
  static const _stoneEdge = Color(0xFFC2A26B);

  Offset _p(Size s, Offset n) => Offset(n.dx * s.width, n.dy * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(5);
    final p = Paint();

    // ── 草地(どうぶつの森風の紙吹雪パターン) ──
    p.color = _grass;
    canvas.drawRect(Offset.zero & size, p);
    acGrassSpeckle(canvas, Offset.zero & size, math.Random(75),
        step: (size.width / 24).clamp(30.0, 64.0),
        color: const Color(0x161E5216));
    // 草の房
    for (var i = 0; i < 24; i++) {
      acTuft(canvas, rng.nextDouble() * size.width,
          rng.nextDouble() * size.height, 1.2, const Color(0x40295C1E));
    }

    // ── 村を囲む川(左下と右の縁・どうぶつの森風の明るい水色) ──
    final left = Path()
      ..moveTo(-10, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.66,
          size.width * 0.06, size.height * 0.98);
    final right = Path()
      ..moveTo(size.width + 10, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.86, size.height * 0.58,
          size.width + 10, size.height * 0.88);
    final foam = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round;
    final river = Paint()
      ..color = _river
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(left, foam);
    canvas.drawPath(right, foam);
    canvas.drawPath(left, river);
    canvas.drawPath(right, river);
    // 「^」の波マーク
    final wave = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final t = 0.1 + 0.8 * (i / 8);
      for (final c in [
        Offset(size.width * (0.035 + 0.11 * t), size.height * (0.58 + 0.37 * t)),
        Offset(size.width * (0.965 - 0.095 * t), size.height * (0.33 + 0.5 * t)),
      ]) {
        canvas.drawPath(
            Path()
              ..moveTo(c.dx - 5, c.dy + 3.5)
              ..lineTo(c.dx, c.dy)
              ..lineTo(c.dx + 5, c.dy + 3.5),
            wave);
      }
    }

    // ── 石畳の道(広場から各施設へ) + 中央広場 ──
    final plazaC = _p(size, plaza);
    final road = Paint()
      ..color = _stone
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    for (final pos in facilities.values) {
      canvas.drawLine(plazaC, _p(size, pos).translate(0, 14), road);
    }
    canvas.drawCircle(plazaC, 66, Paint()..color = _stone);
    canvas.drawCircle(
        plazaC,
        66,
        Paint()
          ..color = _stoneEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    // 石畳の目地
    p.color = _stoneEdge.withOpacity(0.6);
    for (var i = 0; i < 40; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = rng.nextDouble() * 58;
      canvas.drawRect(
          Rect.fromCenter(
              center: plazaC + Offset(math.cos(a) * r, math.sin(a) * r),
              width: 8,
              height: 3),
          p);
    }
    // 花の輪 + 噴水
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2;
      _flower(canvas, plazaC + Offset(math.cos(a) * 46, math.sin(a) * 46),
          i.isEven ? KdColors.pink100 : Colors.white);
    }
    canvas.drawCircle(plazaC, 20, Paint()..color = const Color(0xFFBFC9CC));
    canvas.drawCircle(
        plazaC,
        20,
        Paint()
          ..color = const Color(0xFF8F9BA0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(plazaC, 13, Paint()..color = _river);
    canvas.drawCircle(plazaC.translate(0, -4), 4, Paint()..color = _riverLight);
    canvas.drawRect(
        Rect.fromCenter(center: plazaC.translate(0, -10), width: 6, height: 10),
        Paint()..color = const Color(0xFFDCE4E6));

    // ── 施設の建物 ──
    _castle(canvas, _p(size, facilities['castle']!));
    _house(canvas, _p(size, facilities['cafe']!),
        roof: KdColors.pink500, awning: true);
    _house(canvas, _p(size, facilities['shop']!),
        roof: KdColors.gold500, awning: true);
    _board(canvas, _p(size, facilities['board']!));
    _house(canvas, _p(size, facilities['community']!),
        roof: KdColors.pink500, heart: true);
    _house(canvas, _p(size, facilities['studio']!),
        roof: KdColors.pink700, sign: true);
    _garden(canvas, _p(size, facilities['garden']!), rng);
    _dock(canvas, _p(size, facilities['gate']!));

    // ── 木と花とランプ ──
    for (var i = 0; i < 10; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      // 施設や広場と重ならない位置だけに植える
      final ok = (Offset(x, y) - plazaC).distance > 95 &&
          facilities.values
              .every((f) => (Offset(x, y) - _p(size, f)).distance > 80);
      if (ok) {
        if (i % 3 == 0) {
          acConifer(canvas, x, y, 0.8);
        } else {
          _tree(canvas, Offset(x, y));
        }
      }
    }
    for (var i = 0; i < 30; i++) {
      _flower(
          canvas,
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
          rng.nextBool() ? KdColors.pink100 : Colors.white);
    }
    _lamp(canvas, plazaC.translate(-84, -30));
    _lamp(canvas, plazaC.translate(86, 26));
  }

  // ── 建物の部品 ──────────────────────────────

  void _castle(Canvas canvas, Offset c) {
    final body = Paint()..color = KdColors.pink500;
    final dark = Paint()..color = KdColors.pink700;
    final outline = Paint()
      ..color = KdColors.wood900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter;
    final base = c.translate(0, 22);
    final bodyRect =
        Rect.fromCenter(center: base.translate(0, -20), width: 74, height: 40);
    canvas.drawRect(bodyRect, body);
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
          Rect.fromLTWH(bodyRect.left + 3 + i * 18.0, bodyRect.top - 6, 11, 6),
          body);
    }
    for (final dx in [-44.0, 44.0]) {
      final tower =
          Rect.fromCenter(center: base.translate(dx, -25), width: 20, height: 50);
      canvas.drawRect(tower, body);
      final roof = Path()
        ..moveTo(tower.left - 4, tower.top)
        ..lineTo(tower.right + 4, tower.top)
        ..lineTo(tower.center.dx, tower.top - 15)
        ..close();
      canvas.drawPath(roof, dark);
      canvas.drawPath(roof, outline);
      canvas.drawRect(tower, outline);
    }
    final center =
        Rect.fromCenter(center: base.translate(0, -46), width: 24, height: 36);
    canvas.drawRect(center, body);
    final centerRoof = Path()
      ..moveTo(center.left - 5, center.top)
      ..lineTo(center.right + 5, center.top)
      ..lineTo(center.center.dx, center.top - 16)
      ..close();
    canvas.drawPath(centerRoof, dark);
    canvas.drawPath(centerRoof, outline);
    canvas.drawRect(center, outline);
    canvas.drawRect(bodyRect, outline);
    canvas.drawLine(Offset(center.center.dx, center.top - 16),
        Offset(center.center.dx, center.top - 27), outline);
    final flag = Path()
      ..moveTo(center.center.dx, center.top - 27)
      ..lineTo(center.center.dx + 11, center.top - 24)
      ..lineTo(center.center.dx, center.top - 21)
      ..close();
    canvas.drawPath(flag, dark);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(base.dx, bodyRect.bottom - 8), width: 13, height: 16),
        Paint()..color = KdColors.wood900);
  }

  void _house(Canvas canvas, Offset c,
      {required Color roof, bool awning = false, bool sign = false, bool heart = false}) {
    final outline = Paint()
      ..color = KdColors.wood900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final wall =
        Rect.fromCenter(center: c.translate(0, 6), width: 56, height: 34);
    canvas.drawRect(wall, Paint()..color = const Color(0xFFFFF3E0));
    canvas.drawRect(wall, outline);
    final roofPath = Path()
      ..moveTo(wall.left - 8, wall.top)
      ..lineTo(wall.right + 8, wall.top)
      ..lineTo(c.dx, wall.top - 26)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roof);
    canvas.drawPath(roofPath, outline);
    // ドア + 窓
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, 14), width: 11, height: 17),
        Paint()..color = KdColors.wood900);
    for (final dx in [-17.0, 17.0]) {
      canvas.drawRect(
          Rect.fromCenter(center: c.translate(dx, 3), width: 10, height: 9),
          Paint()..color = const Color(0xFF9ED4F5));
      canvas.drawRect(
          Rect.fromCenter(center: c.translate(dx, 3), width: 10, height: 9),
          outline);
    }
    if (awning) {
      // しましまのひさし
      for (var i = 0; i < 5; i++) {
        canvas.drawRect(
            Rect.fromLTWH(wall.left + 4 + i * 10.0, wall.top + 2, 10, 6),
            Paint()..color = i.isEven ? Colors.white : KdColors.pink500);
      }
    }
    if (sign) {
      final signRect =
          Rect.fromCenter(center: c.translate(0, -2), width: 34, height: 9);
      canvas.drawRect(signRect, Paint()..color = Colors.white);
      canvas.drawRect(signRect, outline);
    }
    if (heart) {
      final hp = Paint()..color = KdColors.pink700;
      final hc = c.translate(0, -8);
      canvas.drawCircle(hc.translate(-2.4, -1), 2.6, hp);
      canvas.drawCircle(hc.translate(2.4, -1), 2.6, hp);
      final tip = Path()
        ..moveTo(hc.dx - 4.8, hc.dy)
        ..lineTo(hc.dx + 4.8, hc.dy)
        ..lineTo(hc.dx, hc.dy + 5.4)
        ..close();
      canvas.drawPath(tip, hp);
    }
  }

  void _board(Canvas canvas, Offset c) {
    final outline = Paint()
      ..color = KdColors.wood900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final board =
        Rect.fromCenter(center: c.translate(0, -4), width: 52, height: 34);
    canvas.drawRect(board, Paint()..color = const Color(0xFF8A5A2B));
    canvas.drawRect(board, outline);
    // 貼り紙
    final paper = Paint()..color = const Color(0xFFFFF8EA);
    for (final (dx, dy) in [(-15.0, -8.0), (2.0, -8.0), (-7.0, 4.0), (11.0, 4.0)]) {
      canvas.drawRect(
          Rect.fromLTWH(c.dx + dx, c.dy + dy - 4, 12, 10), paper);
    }
    // 脚
    for (final dx in [-18.0, 18.0]) {
      canvas.drawRect(
          Rect.fromLTWH(c.dx + dx - 2, board.bottom, 5, 12),
          Paint()..color = const Color(0xFF6D4C2F));
    }
  }

  void _garden(Canvas canvas, Offset c, math.Random rng) {
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 6), width: 86, height: 46),
        Paint()..color = _grassLight);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 6), width: 86, height: 46),
        Paint()
          ..color = KdColors.grass500
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    for (var i = 0; i < 12; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = rng.nextDouble() * 30;
      _flower(canvas, c.translate(math.cos(a) * r, 6 + math.sin(a) * r * 0.5),
          [KdColors.pink500, KdColors.pink100, Colors.white][i % 3]);
    }
  }

  void _dock(Canvas canvas, Offset c) {
    final outline = Paint()
      ..color = KdColors.wood900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // 桟橋
    final deck =
        Rect.fromCenter(center: c.translate(0, 6), width: 52, height: 26);
    canvas.drawRect(deck, Paint()..color = const Color(0xFF8A5A2B));
    canvas.drawRect(deck, outline);
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(deck.left + 10 + i * 11.0, deck.top),
          Offset(deck.left + 10 + i * 11.0, deck.bottom), outline);
    }
    // 小舟
    final boat = Path()
      ..moveTo(c.dx - 20, c.dy - 12)
      ..lineTo(c.dx + 20, c.dy - 12)
      ..lineTo(c.dx + 12, c.dy - 3)
      ..lineTo(c.dx - 12, c.dy - 3)
      ..close();
    canvas.drawPath(boat, Paint()..color = const Color(0xFFA9714B));
    canvas.drawPath(boat, outline);
    final sail = Path()
      ..moveTo(c.dx, c.dy - 30)
      ..lineTo(c.dx - 13, c.dy - 13)
      ..lineTo(c.dx, c.dy - 13)
      ..close();
    canvas.drawPath(sail, Paint()..color = Colors.white);
    canvas.drawLine(Offset(c.dx, c.dy - 30), Offset(c.dx, c.dy - 12), outline);
  }

  void _tree(Canvas canvas, Offset base) =>
      acTree(canvas, base.dx, base.dy + 21, 0.85);

  void _lamp(Canvas canvas, Offset base) {
    canvas.drawLine(base, base.translate(0, 26),
        Paint()
          ..color = const Color(0xFF3A4A3C)
          ..strokeWidth = 3);
    canvas.drawRect(
        Rect.fromCenter(center: base, width: 9, height: 11),
        Paint()..color = const Color(0xFFF7E3A8));
    canvas.drawRect(
        Rect.fromCenter(center: base, width: 9, height: 11),
        Paint()
          ..color = const Color(0xFF3A4A3C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void _flower(Canvas canvas, Offset c, Color color) =>
      acFlower(canvas, c.dx, c.dy, color);

  @override
  bool shouldRepaint(covariant _VillagePainter old) => false;
}
