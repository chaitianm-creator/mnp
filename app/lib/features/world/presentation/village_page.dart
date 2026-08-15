import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';
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
              // アバター(タップした施設まで歩く・ドット絵の主人公)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOut,
                left: _avatar.dx * w - 19,
                top: _avatar.dy * h - 44,
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

/// プレイヤーのアバター(ドット絵の主人公。きせかえの服も反映)。
class _Avatar extends ConsumerWidget {
  const _Avatar({required this.walking});
  final bool walking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfit = ref.watch(outfitProvider);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedRotation(
        turns: walking ? 0.012 : 0,
        duration: const Duration(milliseconds: 250),
        child: PixelSprite(
          rows: heroineFrontRows,
          palette: heroinePaletteFor(outfit),
          width: 38,
        ),
      ),
      const SizedBox(height: 1),
      // 足元のやわらかい影
      Container(
        width: 26,
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0x26304018),
          borderRadius: BorderRadius.circular(999),
        ),
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

  // ── 建物の部品(どうぶつの森風: 丸みのあるシルエット + 落ち影) ──

  void _shadow(Canvas canvas, Offset c, double w, double h) {
    canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h),
        Paint()..color = const Color(0x22304018));
  }

  void _castle(Canvas canvas, Offset c) {
    final body = Paint()..color = const Color(0xFFF2AFC1);
    final roofP = Paint()..color = const Color(0xFFDD7E9B);
    final base = c.translate(0, 22);
    _shadow(canvas, base.translate(0, 3), 112, 14);
    // 両サイドの塔(丸屋根)
    for (final dx in [-42.0, 42.0]) {
      final tower = Rect.fromCenter(
          center: base.translate(dx, -24), width: 22, height: 52);
      canvas.drawRRect(
          RRect.fromRectAndRadius(tower, const Radius.circular(7)), body);
      final roof = Path()
        ..moveTo(tower.left - 6, tower.top + 3)
        ..quadraticBezierTo(
            tower.center.dx, tower.top - 24, tower.right + 6, tower.top + 3)
        ..close();
      canvas.drawPath(roof, roofP);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(tower.center.dx, tower.center.dy + 4),
                  width: 8,
                  height: 12),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFFBDDCF2));
    }
    // 本体 + 中央塔
    final bodyRect =
        Rect.fromCenter(center: base.translate(0, -18), width: 72, height: 40);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(9)), body);
    final centerT =
        Rect.fromCenter(center: base.translate(0, -46), width: 26, height: 38);
    canvas.drawRRect(
        RRect.fromRectAndRadius(centerT, const Radius.circular(8)), body);
    final centerRoof = Path()
      ..moveTo(centerT.left - 7, centerT.top + 3)
      ..quadraticBezierTo(
          centerT.center.dx, centerT.top - 27, centerT.right + 7, centerT.top + 3)
      ..close();
    canvas.drawPath(centerRoof, roofP);
    // 旗(ハート)
    final flagBase = Offset(centerT.center.dx, centerT.top - 22);
    canvas.drawLine(
        flagBase,
        flagBase.translate(0, -10),
        Paint()
          ..color = const Color(0xFF9A6B45)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
    final hp = Paint()..color = const Color(0xFFDD7E9B);
    final hc = flagBase.translate(6, -8);
    canvas.drawCircle(hc.translate(-2.2, -1), 2.4, hp);
    canvas.drawCircle(hc.translate(2.2, -1), 2.4, hp);
    canvas.drawPath(
        Path()
          ..moveTo(hc.dx - 4.4, hc.dy)
          ..lineTo(hc.dx + 4.4, hc.dy)
          ..lineTo(hc.dx, hc.dy + 5)
          ..close(),
        hp);
    // 丸窓と扉(アーチ)
    canvas.drawCircle(centerT.center.translate(0, 3), 5,
        Paint()..color = Colors.white);
    canvas.drawCircle(centerT.center.translate(0, 3), 3.4,
        Paint()..color = const Color(0xFFBDDCF2));
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromCenter(
                center: Offset(base.dx, bodyRect.bottom - 9),
                width: 14,
                height: 18),
            topLeft: const Radius.circular(7),
            topRight: const Radius.circular(7)),
        Paint()..color = const Color(0xFF9A6B45));
  }

  void _house(Canvas canvas, Offset c,
      {required Color roof, bool awning = false, bool sign = false, bool heart = false}) {
    final wall =
        Rect.fromCenter(center: c.translate(0, 7), width: 58, height: 36);
    _shadow(canvas, Offset(c.dx, wall.bottom + 2), 68, 10);
    canvas.drawRRect(
        RRect.fromRectAndRadius(wall, const Radius.circular(7)),
        Paint()..color = const Color(0xFFF6EBD3));
    // 屋根(台形 + 丸い棟)
    final roofPath = Path()
      ..moveTo(wall.left - 9, wall.top + 2)
      ..lineTo(wall.left + 15, wall.top - 22)
      ..lineTo(wall.right - 15, wall.top - 22)
      ..lineTo(wall.right + 9, wall.top + 2)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roof);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, wall.top - 21), width: 32, height: 5),
            const Radius.circular(2.5)),
        Paint()..color = Color.lerp(roof, Colors.black, 0.16)!);
    // ドア(アーチ) + 窓(白枠)
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromCenter(center: c.translate(0, 16), width: 12, height: 17),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6)),
        Paint()..color = const Color(0xFF9A6B45));
    for (final dx in [-17.0, 17.0]) {
      final wr =
          Rect.fromCenter(center: c.translate(dx, 5), width: 11, height: 10);
      canvas.drawRRect(
          RRect.fromRectAndRadius(wr.inflate(1.6), const Radius.circular(4)),
          Paint()..color = Colors.white);
      canvas.drawRRect(
          RRect.fromRectAndRadius(wr, const Radius.circular(3)),
          Paint()..color = const Color(0xFFBDDCF2));
    }
    if (awning) {
      // スカラップのひさし
      for (var i = 0; i < 5; i++) {
        final p = Paint()
          ..color = i.isEven ? Colors.white : const Color(0xFFE8A0A8);
        final sx = wall.left + 4 + i * 10.0;
        canvas.drawRect(Rect.fromLTWH(sx, wall.top + 1, 10, 5), p);
        canvas.drawArc(
            Rect.fromLTWH(sx, wall.top + 3, 10, 6), 0, 3.1416, true, p);
      }
    }
    if (sign) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, -3), width: 34, height: 10),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFFFBF4E2));
    }
    if (heart) {
      final hp = Paint()..color = const Color(0xFFDD7E9B);
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
    _shadow(canvas, c.translate(0, 26), 58, 9);
    // 脚(丸棒)
    for (final dx in [-18.0, 18.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(c.dx + dx - 2.5, c.dy + 8, 5, 16),
              const Radius.circular(2.5)),
          Paint()..color = const Color(0xFF9A6B45));
    }
    // 掲示板(丸角の木板 + 明るい縁)
    final board =
        Rect.fromCenter(center: c.translate(0, -4), width: 54, height: 36);
    canvas.drawRRect(
        RRect.fromRectAndRadius(board, const Radius.circular(8)),
        Paint()..color = const Color(0xFF9A6B45));
    canvas.drawRRect(
        RRect.fromRectAndRadius(board.deflate(4), const Radius.circular(5)),
        Paint()..color = const Color(0xFF7C5B36));
    // 貼り紙(丸角)
    final paper = Paint()..color = const Color(0xFFFFF8EA);
    for (final (dx, dy) in [(-15.0, -8.0), (2.0, -8.0), (-7.0, 4.0), (11.0, 4.0)]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(c.dx + dx, c.dy + dy - 4, 12, 10),
              const Radius.circular(2)),
          paper);
    }
  }

  void _garden(Canvas canvas, Offset c, math.Random rng) {
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 8), width: 92, height: 50),
        Paint()..color = const Color(0x22304018));
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 6), width: 86, height: 46),
        Paint()..color = _grassLight);
    // まわりを白い小花で縁どる
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      canvas.drawCircle(
          c.translate(math.cos(a) * 43, 6 + math.sin(a) * 23), 2.4,
          Paint()..color = Colors.white70);
    }
    for (var i = 0; i < 12; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = rng.nextDouble() * 30;
      _flower(canvas, c.translate(math.cos(a) * r, 6 + math.sin(a) * r * 0.5),
          [KdColors.pink500, KdColors.pink100, Colors.white][i % 3]);
    }
  }

  void _dock(Canvas canvas, Offset c) {
    _shadow(canvas, c.translate(0, 21), 58, 9);
    // 桟橋(丸角の板 + 明るい板目)
    final deck =
        Rect.fromCenter(center: c.translate(0, 6), width: 54, height: 26);
    canvas.drawRRect(
        RRect.fromRectAndRadius(deck, const Radius.circular(7)),
        Paint()..color = const Color(0xFF9A6B45));
    final plank = Paint()
      ..color = const Color(0x40FFF3D6)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(deck.left + 10 + i * 11.0, deck.top + 3),
          Offset(deck.left + 10 + i * 11.0, deck.bottom - 3), plank);
    }
    // 小舟(丸い船体 + 白い帆)
    final boat = Path()
      ..moveTo(c.dx - 20, c.dy - 13)
      ..lineTo(c.dx + 20, c.dy - 13)
      ..quadraticBezierTo(c.dx + 14, c.dy - 2, c.dx + 8, c.dy - 2)
      ..lineTo(c.dx - 8, c.dy - 2)
      ..quadraticBezierTo(c.dx - 14, c.dy - 2, c.dx - 20, c.dy - 13)
      ..close();
    canvas.drawPath(boat, Paint()..color = const Color(0xFFC98A6B));
    final sail = Path()
      ..moveTo(c.dx, c.dy - 30)
      ..quadraticBezierTo(c.dx - 14, c.dy - 22, c.dx - 12, c.dy - 14)
      ..lineTo(c.dx, c.dy - 14)
      ..close();
    canvas.drawPath(sail, Paint()..color = Colors.white);
    canvas.drawLine(
        Offset(c.dx, c.dy - 31),
        Offset(c.dx, c.dy - 13),
        Paint()
          ..color = const Color(0xFF9A6B45)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
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
