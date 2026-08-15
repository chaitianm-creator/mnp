import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:design_kingdom/features/onboarding/presentation/pixel_ui.dart'
    show RoomMode;
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// 第1話のシーン背景(クリーンイラスト版)。
/// 背景はドットのグリッドを使わず、なめらかなグラデーションと
/// 丸いシルエットで描く。キャラクター(主人公・みぽりん・パン屋さん・
/// 眠る女の子)だけはドット絵のまま重ねる。
/// 構図(主要な座標の比率)はドット版と揃えてあり、
/// 吹き出し・看板文字・地名ラベルなどのオーバーレイ位置がそのまま使える。
Widget buildCleanScene(String scene) {
  switch (scene) {
    case 'light_burst':
      return const _Fill(_CleanLightBurstPainter());
    case 'island_overview':
      return const _Fill(_CleanIslandPainter(withHeroine: true));
    case 'island_map':
      return const _Fill(_CleanIslandPainter(withHeroine: false));
    case 'signboard':
      return const _Fill(_CleanSignboardPainter());
    case 'miporin_welcome':
      return const _CleanCharacterScene(pose: 0);
    case 'miporin_point':
      return const _CleanCharacterScene(pose: 1);
    case 'heroine_think':
      return const _CleanCharacterScene(pose: 2);
    case 'village_path':
      return const _Fill(_CleanVillagePathPainter());
    case 'village_path_plain':
      return const _Fill(_CleanVillagePathPainter(withHeroine: false));
    case 'bakery':
    case 'mission':
      return _Fill(_CleanBakeryPainter(dim: scene == 'mission'));
    case 'bakery_front': // カード用: 店を真正面・全体が見える構図
      return const _Fill(_CleanBakeryPainter(dim: false, centered: true));
    case 'studio_front': // カード用: デザイン工房の店先
      return const _Fill(_CleanStudioFrontPainter());
    case 'cafe_front': // カード用: カフェの店先
      return const _Fill(_CleanFrontPainter(kind: 'cafe'));
    case 'grocery_front': // カード用: 八百屋さんの店先
      return const _Fill(_CleanFrontPainter(kind: 'grocery'));
    case 'museum_front': // カード用: 資料館の正面
      return const _Fill(_CleanFrontPainter(kind: 'museum'));
    case 'board_front': // カード用: クエスト掲示板
      return const _Fill(_CleanBoardFrontPainter());
    case 'event_front': // カード用: イベント会場
      return const _Fill(_CleanEventFrontPainter());
    default:
      return const ColoredBox(color: Color(0xFF1B2440));
  }
}

/// 寝室(p1/p3)。クリーン背景 + ドットの女の子。
class CleanRoomBackground extends StatelessWidget {
  const CleanRoomBackground({super.key, required this.mode});
  final RoomMode mode;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CleanRoomPainter(mode: mode), size: Size.infinite);
}

/// 机(p2)。スマホUIはウィジェット側で重ねる。
class CleanDeskScene extends StatelessWidget {
  const CleanDeskScene({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _CleanDeskPainter(), size: Size.infinite);
}

class _Fill extends StatelessWidget {
  const _Fill(this.painter);
  final CustomPainter painter;
  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: CustomPaint(painter: painter));
}

// ─────────────────────────────────────────────────────────────
// 共通ヘルパー
// ─────────────────────────────────────────────────────────────

void acSkyGradient(Canvas canvas, Size size, List<Color> colors,
    {List<double>? stops, double heightFactor = 1.0}) {
  final rect = Rect.fromLTWH(0, 0, size.width, size.height * heightFactor);
  canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect));
}

void acCloud(Canvas canvas, double cx, double cy, double s, double opacity) {
  // どうぶつの森風: 底が平らなもこもこ雲
  final p = Paint()..color = Colors.white.withOpacity(opacity);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, cy + 4 * s), width: 110 * s, height: 22 * s),
          Radius.circular(11 * s)),
      p);
  canvas.drawCircle(Offset(cx - 24 * s, cy - 4 * s), 15 * s, p);
  canvas.drawCircle(Offset(cx + 2 * s, cy - 12 * s), 20 * s, p);
  canvas.drawCircle(Offset(cx + 28 * s, cy - 4 * s), 13 * s, p);
}

/// 芝生の紙吹雪パターン(小さな三角と点をゆるいグリッドで散らす)。
void acGrassSpeckle(Canvas canvas, Rect area, math.Random rng,
    {Color color = const Color(0x14204D18), double step = 30}) {
  final p = Paint()..color = color;
  for (var y = area.top; y < area.bottom; y += step) {
    for (var x = area.left + ((y / step).floor().isEven ? 0 : step / 2);
        x < area.right;
        x += step) {
      final jx = x + (rng.nextDouble() - 0.5) * step * 0.5;
      final jy = y + (rng.nextDouble() - 0.5) * step * 0.5;
      if (rng.nextBool()) {
        final a = rng.nextDouble() * math.pi * 2;
        final path = Path();
        for (var i = 0; i < 3; i++) {
          final t = a + i / 3 * math.pi * 2;
          final px = jx + math.cos(t) * 3.4, py = jy + math.sin(t) * 3.4;
          i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        canvas.drawPath(path..close(), p);
      } else {
        canvas.drawCircle(Offset(jx, jy), 1.6, p);
      }
    }
  }
}

/// もみの木(3段の針葉樹 + 落ち影)。
void acConifer(Canvas canvas, double cx, double groundY, double s) {
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY), width: 26 * s, height: 7 * s),
      Paint()..color = const Color(0x22304018));
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 2.5 * s, groundY - 8 * s, 5 * s, 8 * s),
          Radius.circular(2 * s)),
      Paint()..color = const Color(0xFF8A5A38));
  final dark = Paint()..color = const Color(0xFF3E7D53);
  final light = Paint()..color = const Color(0xFF4E9463);
  for (var i = 0; i < 3; i++) {
    final tw = (16 - i * 4) * s;
    final ty = groundY - 6 * s - i * 11 * s;
    final tier = Path()
      ..moveTo(cx - tw, ty)
      ..quadraticBezierTo(cx - tw * 0.5, ty + 2 * s, cx, ty + 1 * s)
      ..quadraticBezierTo(cx + tw * 0.5, ty + 2 * s, cx + tw, ty)
      ..lineTo(cx, ty - 13 * s)
      ..close();
    canvas.drawPath(tier, i == 2 ? light : dark);
  }
}

/// 遠景の雪山と針葉樹の帯(どうぶつの森風の地平線)。
void acMountainRange(Canvas canvas, Size size, double baseY) {
  final w = size.width;
  void peak(double cx, double pw, double ph, Color body) {
    final mtn = Path()
      ..moveTo(cx - pw, baseY)
      ..lineTo(cx, baseY - ph)
      ..lineTo(cx + pw, baseY)
      ..close();
    canvas.drawPath(mtn, Paint()..color = body);
    // 雪の帽子(裾を波に)
    final st = 0.42; // 雪の割合
    final snow = Path()
      ..moveTo(cx - pw * st, baseY - ph * (1 - st))
      ..lineTo(cx, baseY - ph)
      ..lineTo(cx + pw * st, baseY - ph * (1 - st))
      ..quadraticBezierTo(cx + pw * st * 0.5, baseY - ph * (1 - st) + 6,
          cx, baseY - ph * (1 - st))
      ..quadraticBezierTo(cx - pw * st * 0.5, baseY - ph * (1 - st) + 6,
          cx - pw * st, baseY - ph * (1 - st))
      ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
  }

  peak(w * 0.1, w * 0.09, size.height * 0.075, const Color(0xFF9DB3A4));
  peak(w * 0.3, w * 0.11, size.height * 0.095, const Color(0xFF8AA697));
  peak(w * 0.58, w * 0.1, size.height * 0.08, const Color(0xFF9DB3A4));
  peak(w * 0.82, w * 0.12, size.height * 0.1, const Color(0xFF8AA697));
  // 針葉樹の帯(丸い峰の連なり)
  final forest = Path()..moveTo(0, baseY);
  for (var x = 0.0; x < w; x += w * 0.06) {
    forest.quadraticBezierTo(x + w * 0.03, baseY - size.height * 0.028,
        x + w * 0.06, baseY);
  }
  forest
    ..lineTo(w, baseY + 10)
    ..lineTo(0, baseY + 10)
    ..close();
  canvas.drawPath(forest, Paint()..color = const Color(0xFF3E7D67));
}

void acTree(Canvas canvas, double cx, double groundY, double s) {
  // 落ち影(どうぶつの森風のやわらかい楕円)
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY), width: 34 * s, height: 9 * s),
      Paint()..color = const Color(0x22304018));
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3 * s, groundY - 22 * s, 6 * s, 22 * s),
          Radius.circular(3 * s)),
      Paint()..color = const Color(0xFF9A6B45));
  // もこもこの樹冠(3層)
  final leafDark = Paint()..color = const Color(0xFF6FAF5C);
  canvas.drawCircle(Offset(cx - 9 * s, groundY - 21 * s), 10 * s, leafDark);
  canvas.drawCircle(Offset(cx + 9 * s, groundY - 21 * s), 10 * s, leafDark);
  final leaf = Paint()..color = const Color(0xFF8CC178);
  canvas.drawCircle(Offset(cx, groundY - 30 * s), 14 * s, leaf);
  canvas.drawCircle(Offset(cx - 10 * s, groundY - 25 * s), 10 * s, leaf);
  canvas.drawCircle(Offset(cx + 10 * s, groundY - 25 * s), 10 * s, leaf);
  canvas.drawCircle(Offset(cx - 4 * s, groundY - 35 * s), 8 * s,
      Paint()..color = const Color(0xFFA9D494));
  canvas.drawCircle(Offset(cx + 6 * s, groundY - 33 * s), 5 * s,
      Paint()..color = const Color(0xFFA9D494));
}

/// 草の房(どうぶつの森風の小さな3本草)。
void acTuft(Canvas canvas, double x, double y, double s,
    [Color color = const Color(0x4D3E7A2E)]) {
  final p = Paint()
    ..color = color
    ..strokeWidth = 1.8 * s
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(Offset(x, y), Offset(x - 2.4 * s, y - 4 * s), p);
  canvas.drawLine(Offset(x, y), Offset(x + 0.4 * s, y - 5 * s), p);
  canvas.drawLine(Offset(x, y), Offset(x + 2.8 * s, y - 3.6 * s), p);
}

void acFlower(Canvas canvas, double cx, double cy, Color color) {
  final p = Paint()..color = color;
  for (var i = 0; i < 5; i++) {
    final a = i / 5 * math.pi * 2;
    canvas.drawCircle(Offset(cx + math.cos(a) * 3, cy + math.sin(a) * 3), 2, p);
  }
  canvas.drawCircle(Offset(cx, cy), 2,
      Paint()..color = const Color(0xFFF6D96B));
}

/// ドット絵の行データをそのまま(輪郭込みで)描く。
void _drawRows(Canvas canvas, List<String> rows, Map<String, Color> pal,
    double left, double top, double cell) {
  final p = Paint();
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final ch = rows[y][x];
      if (ch == '.') continue;
      p.color = pal[ch]!;
      canvas.drawRect(
          Rect.fromLTWH(left + x * cell, top + y * cell, cell + 0.4, cell + 0.4),
          p);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 寝室(クリーン版)。構図はドット版に合わせる。
// ─────────────────────────────────────────────────────────────
class _CleanRoomPainter extends CustomPainter {
  const _CleanRoomPainter({required this.mode});
  final RoomMode mode;

  static const _ink = Color(0xFF3A2C1A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wallH = h * 0.58;
    // 家具は高さ基準のスケールで上限をかけ、横長画面でも巨大化させない
    final u = math.min(w / 160, h / 200);
    final cx = w / 2;
    double ox(double units) => cx + units * u; // 中心からのオフセット

    // 壁(あたたかいグラデーション + どうぶつの森風の水玉の壁紙)
    final wallRect = Rect.fromLTWH(0, 0, w, wallH);
    canvas.drawRect(
        wallRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2D8B4), Color(0xFFF9E8CC), Color(0xFFF3DFC0)],
            stops: [0.0, 0.4, 1.0],
          ).createShader(wallRect));
    final dot = Paint()..color = const Color(0x2EFFFFFF);
    final step = 9.5 * u;
    for (var y = step * 0.6; y < wallH - 4 * u; y += step) {
      final off = ((y / step).floor().isEven) ? 0.0 : step / 2;
      for (var x = off; x < w; x += step) {
        canvas.drawCircle(Offset(x, y), 1.9 * u, dot);
      }
    }
    // 幅木(2段)
    canvas.drawRect(Rect.fromLTWH(0, wallH - 4 * u, w, 4 * u),
        Paint()..color = const Color(0xFFC79B62));
    canvas.drawRect(Rect.fromLTWH(0, wallH - 4 * u, w, 1.2 * u),
        Paint()..color = const Color(0xFFDDB37E));

    // 床(木のグラデーション + 板のライン)
    final floorRect = Rect.fromLTWH(0, wallH, w, h - wallH);
    canvas.drawRect(
        floorRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9A76E), Color(0xFFC08A55)],
          ).createShader(floorRect));
    final seam = Paint()
      ..color = const Color(0x338A5A30)
      ..strokeWidth = 2;
    for (var y = wallH + 8 * u; y < h; y += 8 * u) {
      canvas.drawLine(Offset(0, y), Offset(w, y), seam);
    }
    // 縦の継ぎ目(互い違い)
    var row = 0;
    for (var y = wallH; y < h; y += 8 * u, row++) {
      final off2 = (row % 2) * 26 * u;
      for (var x = off2 + 12 * u; x < w; x += 52 * u) {
        canvas.drawLine(Offset(x, y + 1), Offset(x, y + 8 * u - 1), seam);
      }
    }

    // ラグ(楕円2トーン)
    final rugC = Offset(cx, wallH + (h - wallH) * 0.62);
    canvas.drawOval(
        Rect.fromCenter(
            center: rugC, width: 118 * u, height: (h - wallH) * 0.62),
        Paint()..color = const Color(0xFFE8A88C));
    canvas.drawOval(
        Rect.fromCenter(
            center: rugC, width: 100 * u, height: (h - wallH) * 0.5),
        Paint()..color = const Color(0xFFDD9478));

    // 窓(夜空 + 三日月 + 星 + カーテン) — ベッドの真上
    final ww = 56 * u, wh = wallH * 0.46;
    final wx = ox(-28), wy = wallH * 0.08;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(wx - 6 * u, wy - 6 * u, ww + 12 * u, wh + 12 * u),
            Radius.circular(5 * u)),
        Paint()..color = const Color(0xFF8A5A30));
    final skyRect = Rect.fromLTWH(wx, wy, ww, wh);
    canvas.drawRect(
        skyRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2650), Color(0xFF33437F)],
          ).createShader(skyRect));
    final rng = math.Random(5);
    final starP = Paint()..color = const Color(0xFFF6E8A8);
    for (var i = 0; i < 16; i++) {
      canvas.drawCircle(
          Offset(wx + 3 * u + rng.nextDouble() * (ww - 6 * u),
              wy + 3 * u + rng.nextDouble() * wh * 0.7),
          i % 4 == 0 ? 1.6 : 1.0,
          starP);
    }
    final moonC = Offset(wx + ww - 13 * u, wy + wh * 0.28);
    canvas.drawCircle(moonC, 6.5 * u, Paint()..color = const Color(0xFFF6E7A0));
    canvas.drawCircle(moonC.translate(-2.8 * u, -1.8 * u), 5.5 * u,
        Paint()..color = const Color(0xFF25336A));
    final barP = Paint()..color = const Color(0xFFB07845);
    canvas.drawRect(Rect.fromLTWH(wx + ww / 2 - u, wy, 2 * u, wh), barP);
    canvas.drawRect(Rect.fromLTWH(wx, wy + wh / 2 - u, ww, 2 * u), barP);
    // カーテン + 上飾り
    final curt = Paint()..color = const Color(0xFFF2A0B4);
    for (final left in [true, false]) {
      final cxx = left ? wx - 10 * u : wx + ww - 4 * u;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cxx, wy - 6 * u, 14 * u, wh * 0.9),
              Radius.circular(5 * u)),
          curt);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cxx - u, wy + wh * 0.5, 16 * u, 3 * u),
              Radius.circular(1.5 * u)),
          Paint()..color = const Color(0xFFB95672));
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(wx - 12 * u, wy - 8 * u, ww + 24 * u, 5 * u),
            Radius.circular(2.5 * u)),
        Paint()..color = const Color(0xFFD97A94));

    // 本棚(左) + 落ち影
    final bx = ox(-76), bh = wallH * 0.42, by = wallH - bh;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(bx + 14 * u, wallH + 2 * u),
            width: 34 * u,
            height: 5 * u),
        Paint()..color = const Color(0x22304018));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, 28 * u, bh), Radius.circular(3 * u)),
        Paint()..color = const Color(0xFFB07845));
    const spineColors = [
      Color(0xFFD95C5C), Color(0xFF5C7ED9), Color(0xFF6FAF62),
      Color(0xFFE8C25A), Color(0xFF9C6FC7), Color(0xFFE08A4E),
    ];
    for (var s0 = 0; s0 < 3; s0++) {
      final sy = by + 3 * u + s0 * (bh - 6 * u) / 3;
      final sh = (bh - 6 * u) / 3 - 2 * u;
      canvas.drawRect(Rect.fromLTWH(bx + 2 * u, sy, 24 * u, sh),
          Paint()..color = const Color(0xFF6E4522));
      var xx = bx + 3 * u;
      var i = 0;
      while (xx < bx + 22 * u) {
        final bwd = (3 + (i % 2)) * u;
        final c = spineColors[(s0 * 3 + i) % spineColors.length];
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(xx, sy + 2 * u, bwd, sh - 2 * u),
                Radius.circular(u)),
            Paint()..color = c);
        xx += bwd + u;
        i++;
      }
    }

    // ベッド(中央) + 落ち影
    final bedX = ox(-36), bedW = 72 * u;
    final headTop = wallH - 16 * u;
    final bedBottom = wallH + (h - wallH) * 0.58;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, bedBottom + 6 * u),
            width: bedW + 18 * u,
            height: 8 * u),
        Paint()..color = const Color(0x33304018));
    // ヘッドボード
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                bedX - 3 * u, headTop - 10 * u, bedW + 6 * u, 26 * u),
            Radius.circular(8 * u)),
        Paint()..color = const Color(0xFFB07845));
    // 枕
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, headTop + 12 * u),
            width: 34 * u,
            height: 14 * u),
        Paint()..color = const Color(0xFFFBF2DC));
    // 掛け布団(ピンク + やわらかいチェック)
    final qy = headTop + 17 * u;
    final quiltRect =
        Rect.fromLTWH(bedX - 3 * u, qy, bedW + 6 * u, bedBottom - qy);
    canvas.drawRRect(
        RRect.fromRectAndCorners(quiltRect,
            bottomLeft: Radius.circular(6 * u),
            bottomRight: Radius.circular(6 * u)),
        Paint()..color = const Color(0xFFF4A8BC));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndCorners(quiltRect,
        bottomLeft: Radius.circular(6 * u),
        bottomRight: Radius.circular(6 * u)));
    final check = Paint()..color = const Color(0x2EFFFFFF);
    for (var x = quiltRect.left; x < quiltRect.right; x += 16 * u) {
      canvas.drawRect(
          Rect.fromLTWH(x, quiltRect.top, 8 * u, quiltRect.height), check);
    }
    for (var y = quiltRect.top; y < quiltRect.bottom; y += 16 * u) {
      canvas.drawRect(
          Rect.fromLTWH(quiltRect.left, y, quiltRect.width, 8 * u), check);
    }
    canvas.restore();
    // シーツの折り返し
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bedX - 3 * u, qy, bedW + 6 * u, 5 * u),
            Radius.circular(2.5 * u)),
        Paint()..color = const Color(0xFFFBF2DC));
    // フットボード
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bedX - 4 * u, bedBottom, bedW + 8 * u, 6 * u),
            Radius.circular(3 * u)),
        Paint()..color = const Color(0xFF9A6B45));

    // ナイトスタンド + ランプ(右) + 落ち影
    final nx = ox(46), ny = wallH - 6 * u;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(nx + 11 * u, ny + 21 * u),
            width: 28 * u,
            height: 5 * u),
        Paint()..color = const Color(0x22304018));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(nx, ny, 22 * u, 20 * u), Radius.circular(3 * u)),
        Paint()..color = const Color(0xFFB07845));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(nx + 3 * u, ny + 6 * u, 16 * u, 7 * u),
            Radius.circular(2 * u)),
        Paint()..color = const Color(0xFF8A5A30));
    final lx = nx + 11 * u, ly = ny - 14 * u;
    canvas.drawCircle(Offset(lx, ly + 3 * u), 16 * u,
        Paint()..color = const Color(0x1FFFE9A0));
    canvas.drawCircle(Offset(lx, ly + 3 * u), 9 * u,
        Paint()..color = const Color(0x2EFFE9A0));
    final shade = Path()
      ..moveTo(lx, ly - 6 * u)
      ..lineTo(lx - 7 * u, ly + 3 * u)
      ..lineTo(lx + 7 * u, ly + 3 * u)
      ..close();
    canvas.drawPath(shade, Paint()..color = const Color(0xFFF7D488));
    canvas.drawRect(Rect.fromLTWH(lx - u, ly + 3 * u, 2 * u, 9 * u),
        Paint()..color = const Color(0xFF8A5A30));

    // 観葉植物(右下) + 落ち影
    final gx = ox(70), gy = wallH + 12 * u;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(gx, gy + 10 * u), width: 20 * u, height: 4 * u),
        Paint()..color = const Color(0x22304018));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(gx - 6 * u, gy, 12 * u, 9 * u),
            Radius.circular(3 * u)),
        Paint()..color = const Color(0xFFA85C32));
    final leafP = Paint()..color = const Color(0xFF5E9B4E);
    canvas.drawCircle(Offset(gx, gy - 8 * u), 7 * u, leafP);
    canvas.drawCircle(Offset(gx - 4 * u, gy - 4 * u), 4.5 * u, leafP);
    canvas.drawCircle(Offset(gx + 3 * u, gy - 12 * u), 4.5 * u,
        Paint()..color = const Color(0xFF77B562));

    // ── 女の子(ドット絵のまま) ──
    if (mode == RoomMode.awake) {
      _drawRows(canvas, _girlSittingRows, _girlSittingPal,
          cx - 7 * 2.5 * u, headTop - 3 * u, 2.5 * u);
      final exP = Paint()..color = const Color(0xFFE8C25A);
      canvas.drawRect(
          Rect.fromLTWH(cx + 20 * u, headTop - 9 * u, 2.5 * u, 6 * u), exP);
      canvas.drawRect(
          Rect.fromLTWH(cx + 20 * u, headTop - u, 2.5 * u, 2.5 * u), exP);
    } else {
      _drawRows(canvas, _girlSleepRows, _girlSleepPal,
          cx - 7 * 1.25 * u, headTop + 8 * u, 1.25 * u);
      // 布団の上に出た腕
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 13 * u, qy + 3 * u, 10 * u, 5 * u),
              Radius.circular(2.5 * u)),
          Paint()..color = _ink);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 12 * u, qy + 4 * u, 8 * u, 3 * u),
              Radius.circular(1.5 * u)),
          Paint()..color = const Color(0xFFFFDDC2));
      // すやすやの「Z」
      final zP = TextPainter(
        text: const TextSpan(
            text: 'Z z',
            style: TextStyle(
                color: Color(0xAA8A5A30),
                fontSize: 16,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      zP.paint(canvas, Offset(cx + 12 * u, headTop - 2 * u));
    }
  }

  static const _girlSleepRows = [
    '....######....',
    '..##HHHHHH##..',
    '.#HHLLHHHHHH#.',
    '.#HLHHHHHHHHH#',
    '#HHHHSSSSSHHH#',
    '#HHSSSSSSSSH#.',
    '#HSCCSSSSCCS#.', // 目を閉じてすやすや(まつ毛の線)
    '#HSSSSSSSSSS#.',
    '.#SBSSSSSSBS#.',
    '.#SSSSMMSSSS#.',
    '..#SSSSSSSS#..',
    '...########...',
  ];
  static const _girlSleepPal = {
    '#': _ink,
    'H': Color(0xFF9C6234),
    'L': Color(0xFFC08A50),
    'S': Color(0xFFFFDDC2),
    'C': Color(0xFF5A3A24),
    'B': Color(0xFFF49AA8),
    'M': Color(0xFFE87F6E),
  };
  static const _girlSittingRows = [
    '....######....',
    '..##HHHHHH##..',
    '.#HHLLHHHHHH#.',
    '.#HLHHHHHHHHH#',
    '#HHHHSSSSSHHH#',
    '#HHSSSSSSSSH#.',
    '#HSWESSSSWES#.',
    '#HSSSSSSSSSS#.',
    '.#SBSSooSSBS#.',
    '.#SSSSSSSSSS#.',
    '..#SSSSSSSS#..',
    '..##PPPPPP##..',
    '.#PPPPPPPPPP#.',
    '#SSPPPPPPPPSS#',
    '#SSPPFFFFPPSS#',
    '.##SSFFFFSS##.',
    '..###PPPP###..',
  ];
  static const _girlSittingPal = {
    '#': _ink,
    'H': Color(0xFF9C6234),
    'L': Color(0xFFC08A50),
    'S': Color(0xFFFFDDC2),
    'W': Colors.white,
    'E': Color(0xFF5A3A24),
    'B': Color(0xFFF49AA8),
    'o': Color(0xFFC96A5E),
    'P': Color(0xFFF9C7D3),
    'F': Color(0xFFBFE8FF),
  };

  @override
  bool shouldRepaint(covariant _CleanRoomPainter old) => old.mode != mode;
}

// ─────────────────────────────────────────────────────────────
// 机(p2)。木目のグラデーション + 小物。
// ─────────────────────────────────────────────────────────────
class _CleanDeskPainter extends CustomPainter {
  const _CleanDeskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC98F5A), Color(0xFFB77E4B)],
          ).createShader(rect));
    // 板の継ぎ目 + 木目の節(どうぶつの森風)
    final seam = Paint()
      ..color = const Color(0x2E6E4522)
      ..strokeWidth = 3;
    for (var y = h * 0.14; y < h; y += h * 0.14) {
      canvas.drawLine(Offset(0, y), Offset(w, y), seam);
    }
    final knot = Paint()..color = const Color(0x266E4522);
    for (final (fx, fy) in [(0.3, 0.3), (0.62, 0.55), (0.42, 0.82), (0.85, 0.72)]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * fx, h * fy), width: w * 0.035, height: w * 0.018),
          knot);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * fx, h * fy), width: w * 0.016, height: w * 0.008),
          Paint()..color = const Color(0x336E4522));
    }
    // 小物の落ち影
    final itemShadow = Paint()..color = const Color(0x1F30301A);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.105, h * 0.115),
            width: w * 0.23,
            height: w * 0.2),
        itemShadow);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.935, h * 0.16), width: w * 0.16, height: w * 0.05),
        itemShadow);
    // コーヒー(左上)
    final cupC = Offset(w * 0.1, h * 0.1);
    canvas.drawCircle(cupC, w * 0.105, Paint()..color = const Color(0xFFF0E6D2));
    canvas.drawCircle(cupC, w * 0.085, Paint()..color = const Color(0xFF6E4522));
    canvas.drawCircle(cupC, w * 0.07, Paint()..color = const Color(0xFF8A5A30));
    canvas.drawOval(
        Rect.fromCenter(
            center: cupC.translate(-w * 0.02, -w * 0.015),
            width: w * 0.05,
            height: w * 0.03),
        Paint()..color = const Color(0x4DFFFFFF));
    // 植物(右上)
    final potC = Offset(w * 0.93, h * 0.09);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: potC.translate(0, w * 0.09),
                width: w * 0.12,
                height: w * 0.09),
            Radius.circular(w * 0.02)),
        Paint()..color = const Color(0xFFA85C32));
    final leafP = Paint()..color = const Color(0xFF5E9B4E);
    canvas.drawCircle(potC, w * 0.075, leafP);
    canvas.drawCircle(potC.translate(-w * 0.06, w * 0.03), w * 0.05, leafP);
    canvas.drawCircle(potC.translate(w * 0.055, w * 0.025), w * 0.05,
        Paint()..color = const Color(0xFF77B562));
    // メモ(左下)
    canvas.save();
    canvas.translate(w * 0.06, h * 0.85);
    canvas.rotate(-0.08);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-w * 0.09, -h * 0.05, w * 0.24, h * 0.16),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFF6EFDD));
    final line = Paint()
      ..color = const Color(0x33555555)
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(-w * 0.06, -h * 0.02 + i * h * 0.03),
          Offset(w * 0.1, -h * 0.02 + i * h * 0.03), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 光に包まれるシーン(p4)。
// ─────────────────────────────────────────────────────────────
class _CleanLightBurstPainter extends CustomPainter {
  const _CleanLightBurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF4A3F2C));
    // 放射状の光(なめらかな扇形)
    final rayP = Paint()..color = const Color(0xFF6E5F41);
    final maxR = math.max(w, h);
    for (var i = 0; i < 28; i += 2) {
      final a1 = i / 28 * math.pi * 2;
      final a2 = (i + 1) / 28 * math.pi * 2;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a1) * maxR, c.dy + math.sin(a1) * maxR)
        ..lineTo(c.dx + math.cos(a2) * maxR, c.dy + math.sin(a2) * maxR)
        ..close();
      canvas.drawPath(path, rayP);
    }
    // 中心のやわらかい光
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFBF2D2),
        const Color(0xFFEFDFA8),
        const Color(0x66F2E3B4),
        const Color(0x00F2E3B4),
      ], stops: const [
        0.0, 0.35, 0.6, 1.0
      ]).createShader(Rect.fromCircle(center: c, radius: w * 0.38));
    canvas.drawCircle(c, w * 0.38, glow);
    // きらめき
    final rng = math.Random(4);
    final sp = Paint()..color = const Color(0xCCFBF2D2);
    for (var i = 0; i < 36; i++) {
      final sx = rng.nextDouble() * w, sy = rng.nextDouble() * h;
      final s = 2.0 + rng.nextDouble() * 3;
      canvas.drawRect(Rect.fromLTWH(sx - s / 2, sy - s * 1.5, s, s * 3), sp);
      canvas.drawRect(Rect.fromLTWH(sx - s * 1.5, sy - s / 2, s * 3, s), sp);
    }
    // 主人公(後ろ姿・ドットのまま)
    final unit = (w / 160).clamp(1.2, 8.0) * 1.5;
    drawPixelSprite(canvas, heroineBackRows, heroinePalette,
        c.dx - 8 * unit, c.dy - 10 * unit, unit);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 島の全景(p5/p7〜9/p11)。構図はドット版と同じ比率。
// ─────────────────────────────────────────────────────────────
class _CleanIslandPainter extends CustomPainter {
  const _CleanIslandPainter({required this.withHeroine});
  final bool withHeroine;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.2);
    acCloud(canvas, w * 0.2, h * 0.06, w / 900, 0.95);
    acCloud(canvas, w * 0.55, h * 0.1, w / 1100, 0.9);
    acCloud(canvas, w * 0.85, h * 0.05, w / 1300, 0.85);

    // 海(どうぶつの森風の明るいターコイズ)
    final seaTop = h * 0.18;
    final seaRect = Rect.fromLTWH(0, seaTop, w, h - seaTop);
    canvas.drawRect(
        seaRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7CC9D8), Color(0xFF3E9CC0)],
          ).createShader(seaRect));
    // さざ波(白い波線)ときらめき
    final rng = math.Random(3);
    final wave = Paint()
      ..color = const Color(0x59FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 34; i++) {
      final wx = rng.nextDouble() * w;
      final wy = seaTop + h * 0.02 + rng.nextDouble() * (h - seaTop) * 0.94;
      final s = 0.7 + rng.nextDouble() * 0.9;
      final p = Path()
        ..moveTo(wx - 11 * s, wy)
        ..quadraticBezierTo(wx - 5.5 * s, wy - 5 * s, wx, wy)
        ..quadraticBezierTo(wx + 5.5 * s, wy - 5 * s, wx + 11 * s, wy);
      canvas.drawPath(p, wave);
    }
    final sparkle = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
          Offset(rng.nextDouble() * w,
              seaTop + rng.nextDouble() * (h - seaTop)),
          1.6,
          sparkle);
    }

    // 島(浅瀬のリング → 砂浜 → 明るい芝生)
    final icx = w * 0.55, icy = h * 0.52;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(icx, icy), width: w * 0.9, height: h * 0.585),
        Paint()..color = const Color(0x55BDEBE3));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(icx, icy), width: w * 0.8, height: h * 0.52),
        Paint()..color = const Color(0xFFEFDDA6));
    final islandOval = Rect.fromCenter(
        center: Offset(icx, icy), width: w * 0.72, height: h * 0.456);
    canvas.drawOval(islandOval, Paint()..color = const Color(0xFF7EC55E));
    canvas.save();
    canvas.clipPath(Path()..addOval(islandOval));
    // 下側をやや濃くして立体感を出す
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(icx, icy + h * 0.12),
            width: w * 0.72,
            height: h * 0.42),
        Paint()..color = const Color(0x2E3E8F2C));
    // 芝生の紙吹雪パターン
    acGrassSpeckle(canvas, islandOval, math.Random(31),
        step: w / 17, color: const Color(0x16204D18));
    canvas.restore();

    // 道(なめらかなカーブ + 小石)
    final road = Path()
      ..moveTo(icx, icy + h * 0.2)
      ..quadraticBezierTo(icx - w * 0.05, icy + h * 0.02, icx + w * 0.02,
          icy - h * 0.16);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFE3CE9A)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.024);
    final stoneP = Paint()..color = const Color(0x33A08662);
    for (var i = 0; i < 7; i++) {
      final t = i / 6.0;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  icx - w * 0.02 * math.sin(t * math.pi) +
                      (rng.nextDouble() - 0.5) * w * 0.012,
                  icy + h * 0.18 - t * h * 0.32),
              width: 8 + rng.nextDouble() * 6,
              height: 4 + rng.nextDouble() * 2),
          stoneP);
    }

    // 山(丸みのある峰 + 波型の雪 + すその針葉樹帯)
    final mbY = h * 0.365, apexX = w * 0.55, apexY = h * 0.15;
    final mtn = Path()
      ..moveTo(w * 0.4, mbY)
      ..quadraticBezierTo(w * 0.47, h * 0.24, apexX - w * 0.02, apexY + h * 0.01)
      ..quadraticBezierTo(apexX, apexY - h * 0.012, apexX + w * 0.02,
          apexY + h * 0.01)
      ..quadraticBezierTo(w * 0.63, h * 0.24, w * 0.7, mbY)
      ..close();
    canvas.drawPath(mtn, Paint()..color = const Color(0xFF83A98E));
    canvas.save();
    canvas.clipPath(mtn);
    // 右半分の陰
    canvas.drawRect(Rect.fromLTWH(apexX, apexY - h * 0.02, w * 0.16, h * 0.24),
        Paint()..color = const Color(0x2E4A6B54));
    // 雪の帽子(裾を波型に)
    final snowY = h * 0.225;
    final snow = Path()..moveTo(w * 0.47, snowY);
    for (var i = 0; i < 4; i++) {
      final x0 = w * (0.47 + i * 0.04);
      snow.quadraticBezierTo(
          x0 + w * 0.02, snowY + h * (i.isEven ? 0.022 : 0.014),
          x0 + w * 0.04, snowY);
    }
    snow
      ..lineTo(w * 0.63, apexY - h * 0.05)
      ..lineTo(w * 0.47, apexY - h * 0.05)
      ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
    canvas.restore();
    // すその針葉樹の帯(丸い峰の連なり)
    final band = Path()..moveTo(w * 0.395, mbY);
    for (var x = w * 0.395; x < w * 0.705; x += w * 0.031) {
      band.quadraticBezierTo(
          x + w * 0.0155, mbY - h * 0.024, x + w * 0.031, mbY);
    }
    band
      ..lineTo(w * 0.705, mbY + h * 0.012)
      ..lineTo(w * 0.395, mbY + h * 0.012)
      ..close();
    canvas.drawPath(band, Paint()..color = const Color(0xFF3E7D67));

    // 家々(どうぶつの森風: 落ち影 + 白い窓枠 + 花箱)
    void house(double hx, double hy, Color roof) {
      final s = w / 640;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(hx + 13 * s, hy + 24 * s),
              width: 34 * s,
              height: 7 * s),
          Paint()..color = const Color(0x22304018));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(hx, hy + 8 * s, 26 * s, 15 * s),
              Radius.circular(3 * s)),
          Paint()..color = const Color(0xFFF6EBD3));
      final roofPath = Path()
        ..moveTo(hx - 4 * s, hy + 9 * s)
        ..quadraticBezierTo(hx + 4 * s, hy + 1 * s, hx + 13 * s, hy - 5 * s)
        ..quadraticBezierTo(hx + 22 * s, hy + 1 * s, hx + 30 * s, hy + 9 * s)
        ..close();
      canvas.drawPath(roofPath, Paint()..color = roof);
      // 扉
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(hx + 10 * s, hy + 14 * s, 6 * s, 9 * s),
              Radius.circular(2 * s)),
          Paint()..color = const Color(0xFF9A6B45));
      // 窓(白枠 + 水色ガラス)
      for (final wx in [3.0, 19.0]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(hx + wx * s, hy + 12 * s, 5 * s, 5 * s),
                Radius.circular(1.6 * s)),
            Paint()..color = Colors.white);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(
                    hx + (wx + 0.8) * s, hy + 12.8 * s, 3.4 * s, 3.4 * s),
                Radius.circular(1.2 * s)),
            Paint()..color = const Color(0xFFBDDCF2));
        // 花箱
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(hx + (wx - 0.6) * s, hy + 17 * s, 6.2 * s,
                    1.8 * s),
                Radius.circular(0.9 * s)),
            Paint()..color = const Color(0xFF9A6B45));
      }
    }

    house(w * 0.36, h * 0.46, const Color(0xFFC98A6B));
    house(w * 0.62, h * 0.40, const Color(0xFF7FA3CB));
    house(w * 0.66, h * 0.55, const Color(0xFF8CC178));
    house(w * 0.44, h * 0.60, const Color(0xFFA98BC6));
    house(w * 0.30, h * 0.56, const Color(0xFFE0B268));
    house(w * 0.52, h * 0.44, const Color(0xFFE8A0A8));
    // 木(広葉樹ともみの木を混ぜる)
    for (var i = 0; i < 16; i++) {
      final tx = w * (0.24 + rng.nextDouble() * 0.58);
      final ty = h * (0.34 + rng.nextDouble() * 0.36);
      if (i % 3 == 0) {
        acConifer(canvas, tx, ty, w / 2100);
      } else {
        acTree(canvas, tx, ty, w / 1500);
      }
    }
    // 花(島のあちこちに)
    for (var i = 0; i < 14; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = rng.nextDouble();
      acFlower(
          canvas,
          icx + math.cos(a) * w * 0.32 * r,
          icy + math.sin(a) * h * 0.2 * r,
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)]
              [i % 3]);
    }

    // 灯台(赤い丸屋根)
    final ltX = w * 0.89, ltTop = h * 0.365, ltH = h * 0.16;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(ltX, ltTop + ltH),
            width: w * 0.055,
            height: h * 0.014),
        Paint()..color = const Color(0x22304018));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(ltX, ltTop + ltH / 2),
                width: w * 0.035,
                height: ltH),
            Radius.circular(w * 0.008)),
        Paint()..color = Colors.white);
    final stripe = Paint()..color = const Color(0xFFE0796A);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(ltX, ltTop + ltH * 0.35),
            width: w * 0.035,
            height: ltH * 0.14),
        stripe);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(ltX, ltTop + ltH * 0.7),
            width: w * 0.035,
            height: ltH * 0.14),
        stripe);
    // 明かりの部屋 + 丸屋根
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(ltX, ltTop - h * 0.008),
                width: w * 0.026,
                height: h * 0.018),
            Radius.circular(w * 0.004)),
        Paint()..color = const Color(0xFFF6D96B));
    final dome = Path()
      ..moveTo(ltX - w * 0.02, ltTop - h * 0.016)
      ..quadraticBezierTo(
          ltX, ltTop - h * 0.052, ltX + w * 0.02, ltTop - h * 0.016)
      ..close();
    canvas.drawPath(dome, stripe);

    // 小島(砂浜 + 芝生 + 木)
    void islet(double cx, double cy, double s, bool conifer) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy), width: w * 0.12 * s, height: h * 0.05 * s),
          Paint()..color = const Color(0xFFEFDDA6));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy - h * 0.004),
              width: w * 0.095 * s,
              height: h * 0.038 * s),
          Paint()..color = const Color(0xFF7EC55E));
      if (conifer) {
        acConifer(canvas, cx, cy, w / 2400 * s);
      } else {
        acTree(canvas, cx + w * 0.01, cy, w / 1800 * s);
      }
      acTuft(canvas, cx - w * 0.028 * s, cy + h * 0.004, w / 600,
          const Color(0x40295C1E));
    }

    islet(w * 0.08, h * 0.3, 1.0, false);
    islet(w * 0.92, h * 0.72, 1.1, true);

    if (withHeroine) {
      // 手前の崖 + 草縁 + 花
      final cliff = Path()
        ..moveTo(0, h * 0.66)
        ..lineTo(w * 0.3, h * 0.66)
        ..quadraticBezierTo(w * 0.27, h * 0.83, w * 0.24, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(cliff, Paint()..color = const Color(0xFF7C5B36));
      final grassEdge = Path()
        ..moveTo(0, h * 0.66)
        ..lineTo(w * 0.3, h * 0.66)
        ..lineTo(w * 0.295, h * 0.715)
        ..quadraticBezierTo(w * 0.15, h * 0.73, 0, h * 0.715)
        ..close();
      canvas.drawPath(grassEdge, Paint()..color = const Color(0xFF7EC55E));
      for (var i = 0; i < 7; i++) {
        acFlower(canvas, rng.nextDouble() * w * 0.24,
            h * (0.67 + rng.nextDouble() * 0.035),
            [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
      }
      // 主人公(後ろ姿・ドットのまま + 足元の影)
      final unit = math.max(1.6, 160 / 84) * (w / 160);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.08 + 8 * unit, h * 0.56 + 20.4 * unit),
              width: 13 * unit,
              height: 3 * unit),
          Paint()..color = const Color(0x26304018));
      drawPixelSprite(
          canvas, heroineBackRows, heroinePalette, w * 0.08, h * 0.56, unit);
    }
  }

  @override
  bool shouldRepaint(covariant _CleanIslandPainter old) =>
      old.withHeroine != withHeroine;
}

// ─────────────────────────────────────────────────────────────
// 島の看板(p6)。文字はウィジェット側で重ねる(位置比率はドット版と同じ)。
// ─────────────────────────────────────────────────────────────
class _CleanSignboardPainter extends CustomPainter {
  const _CleanSignboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.42);
    acCloud(canvas, w * 0.18, h * 0.08, w / 900, 0.95);
    acCloud(canvas, w * 0.78, h * 0.12, w / 1100, 0.85);

    final land = w > h;
    // 遠景の雪山 + 針葉樹の帯
    acMountainRange(canvas, size, h * 0.40);

    // 芝生(紙吹雪パターン + 草の房)
    final bushRect = Rect.fromLTWH(0, h * 0.38, w, h * 0.62);
    canvas.drawRect(
        bushRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC55E), Color(0xFF5FA843)],
          ).createShader(bushRect));
    final rng = math.Random(7);
    acGrassSpeckle(canvas, bushRect, math.Random(41),
        step: w / 13, color: const Color(0x14204D18));
    // 道(まるい先端 + 小石)
    final roadHalf = w * (land ? 0.045 : 0.09);
    final road = Path()
      ..moveTo(w * 0.5 - w * 0.02, h * 0.74)
      ..quadraticBezierTo(w * 0.5, h * 0.70, w * 0.5 + w * 0.02, h * 0.74)
      ..lineTo(w * 0.5 + roadHalf, h)
      ..lineTo(w * 0.5 - roadHalf, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFFCDB388));
    final stoneP = Paint()..color = const Color(0x33A08662);
    for (var i = 0; i < 8; i++) {
      final t = 0.1 + rng.nextDouble() * 0.85;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  w * 0.5 + (rng.nextDouble() * 2 - 1) * roadHalf * t * 0.7,
                  h * (0.75 + t * 0.23)),
              width: 14 + t * 10,
              height: 6 + t * 4),
          stoneP);
    }
    // 木(もこもこ広葉樹ともみの木)
    acTree(canvas, w * 0.09, h * 0.64, w / (land ? 900 : 430));
    acConifer(canvas, w * 0.16, h * 0.5, w / (land ? 1100 : 560));
    acConifer(canvas, w * 0.86, h * 0.48, w / (land ? 1100 : 620));
    acTree(canvas, w * 0.92, h * 0.68, w / (land ? 820 : 400));
    for (var i = 0; i < 18; i++) {
      acTuft(canvas, rng.nextDouble() * w, h * (0.45 + rng.nextDouble() * 0.5),
          w / 430, const Color(0x40295C1E));
    }

    // 大看板(丸角の木板 + 支柱 + つた + 花)。横長画面では幅を抑える
    final bw = w * (land ? 0.38 : 0.66);
    final bx = w / 2 - bw / 2, by = h * 0.27, bh = h * 0.3;
    final post = Paint()..color = const Color(0xFF5A3A1E);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx + bw * 0.16, by + bh, w * 0.014, h * 0.28),
            const Radius.circular(4)),
        post);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx + bw * 0.78, by + bh, w * 0.014, h * 0.28),
            const Radius.circular(4)),
        post);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx - 4, by - 4, bw + 8, bh + 8),
            const Radius.circular(14)),
        post);
    final board = Rect.fromLTWH(bx, by, bw, bh);
    canvas.drawRRect(
        RRect.fromRectAndRadius(board, const Radius.circular(12)),
        Paint()..color = const Color(0xFF9C6B35));
    final plank = Paint()
      ..color = const Color(0x33875A2B)
      ..strokeWidth = 2;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(bx, by + i * bh / 4),
          Offset(bx + bw, by + i * bh / 4), plank);
    }
    // つた + 花
    for (var i = 0; i < 30; i++) {
      final t = i / 30 * math.pi * 2;
      final ex = bx + bw / 2 + math.cos(t) * (bw / 2 + 4);
      final ey = by + bh / 2 + math.sin(t) * (bh / 2 + 4);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(ex, ey),
              width: (bw * 0.045).clamp(12.0, 24.0),
              height: (bw * 0.03).clamp(8.0, 16.0)),
          Paint()
            ..color =
                i % 2 == 0 ? const Color(0xFF3B9A31) : const Color(0xFF2E8226));
    }
    for (var i = 0; i < 8; i++) {
      final t = i / 8 * math.pi * 2 + 0.4;
      acFlower(canvas, bx + bw / 2 + math.cos(t) * (bw / 2 + 8),
          by + bh / 2 + math.sin(t) * (bh / 2 + 8),
          i.isEven ? const Color(0xFFF2A5C0) : Colors.white);
    }
    // 下草の花
    for (var i = 0; i < 12; i++) {
      acFlower(canvas, rng.nextDouble() * w, h * (0.8 + rng.nextDouble() * 0.17),
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 村の道(p10)。奥へ続く道 + 家々。
// ─────────────────────────────────────────────────────────────
class _CleanVillagePathPainter extends CustomPainter {
  const _CleanVillagePathPainter({this.withHeroine = true});
  final bool withHeroine;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 横長画面でも家や木が大きくなりすぎないための基準寸法
    final base = math.min(w, h * 0.62);
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFDDE9F5)], heightFactor: 0.4);
    acCloud(canvas, w * 0.22, h * 0.08, w / 900, 0.95);
    acCloud(canvas, w * 0.7, h * 0.13, w / 1100, 0.85);
    // 遠景の雪山 + 針葉樹の帯(どうぶつの森風)
    acMountainRange(canvas, size, h * 0.395);

    // 草地(まるい丘の稜線 — どうぶつの森風)
    final grassRect = Rect.fromLTWH(0, h * 0.33, w, h * 0.67);
    final grassPath = Path()
      ..moveTo(0, h * 0.385)
      ..quadraticBezierTo(w * 0.5, h * 0.335, w, h * 0.38)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        grassPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC55E), Color(0xFF5FA843)],
          ).createShader(grassRect));
    // 芝生の紙吹雪パターン
    canvas.save();
    canvas.clipPath(grassPath);
    acGrassSpeckle(canvas, Rect.fromLTWH(0, h * 0.33, w, h * 0.67),
        math.Random(21), step: w / 14);
    canvas.restore();

    // 奥へ続く道(なめらかな台形)
    final road = Path()
      ..moveTo(w / 2 - w * 0.045, h * 0.38)
      ..lineTo(w / 2 + w * 0.045, h * 0.38)
      ..lineTo(w / 2 + w * 0.205, h)
      ..lineTo(w / 2 - w * 0.205, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFFCDB388));
    final rng = math.Random(11);
    final stone = Paint()..color = const Color(0x33A08662);
    for (var i = 0; i < 20; i++) {
      final t = rng.nextDouble();
      final half = w * (0.04 + t * 0.15);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  w / 2 + (rng.nextDouble() * 2 - 1) * half,
                  h * (0.42 + t * 0.55)),
              width: 16 + t * 14,
              height: 6 + t * 5),
          stone);
    }

    // 柵
    final fenceP = Paint()..color = const Color(0xFF9A6B45);
    for (final fy in [h * 0.56, h * 0.74]) {
      for (final side in [0.0, w * 0.66]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(side + w * 0.01, fy, w * 0.32, 5),
                const Radius.circular(2.5)),
            fenceP);
        for (var i = 0; i < 5; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(side + w * 0.02 + i * w * 0.07, fy - 12, 6, 26),
                  const Radius.circular(3)),
              fenceP);
        }
      }
    }

    // 家(クリーンな洋風ハウス + やわらかい落ち影)
    void house(double hx, double hy, double s, Color roof) {
      final bw = base * 0.21 * s, bh = bw * 0.62;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(hx + bw / 2, hy + bh),
              width: bw * 1.15,
              height: bh * 0.16),
          Paint()..color = const Color(0x22304018));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(hx, hy, bw, bh), Radius.circular(bw * 0.05)),
          Paint()..color = const Color(0xFFF6EBD3));
      final roofPath = Path()
        ..moveTo(hx - bw * 0.14, hy + 3)
        ..lineTo(hx + bw / 2, hy - bh * 0.62)
        ..lineTo(hx + bw * 1.14, hy + 3)
        ..close();
      canvas.drawPath(roofPath, Paint()..color = roof);
      // 扉と窓
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(hx + bw * 0.4, hy + bh * 0.42, bw * 0.2, bh * 0.58),
              Radius.circular(bw * 0.08)),
          Paint()..color = const Color(0xFF9A6B45));
      for (final wxx in [0.1, 0.68]) {
        final wr = Rect.fromLTWH(
            hx + bw * wxx, hy + bh * 0.24, bw * 0.22, bh * 0.3);
        canvas.drawRRect(
            RRect.fromRectAndRadius(wr.inflate(2), const Radius.circular(5)),
            Paint()..color = Colors.white);
        canvas.drawRRect(
            RRect.fromRectAndRadius(wr, const Radius.circular(4)),
            Paint()..color = const Color(0xFFBDDCF2));
        // 花箱
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(hx + bw * wxx - 2, hy + bh * 0.54, bw * 0.22 + 4,
                    bh * 0.08),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFF9A6B45));
      }
    }

    house(w * 0.02, h * 0.42, 1.5, const Color(0xFF7FA3CB));
    house(w * 0.7, h * 0.44, 1.4, const Color(0xFFD97A6A));
    house(w * 0.17, h * 0.365, 0.8, const Color(0xFFE0B268));
    house(w * 0.63, h * 0.365, 0.75, const Color(0xFF8CC178));

    // 街路樹(左はもみの木、右は広葉樹)
    acConifer(canvas, w * 0.06, h * 0.55, base / 430);
    acTree(canvas, w * 0.94, h * 0.585, base / 430);
    acConifer(canvas, w * 0.3, h * 0.425, base / 700);

    // 丸い茂み(どうぶつの森風の生け垣)
    void bush(double bx, double by, double s) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(bx, by + 10 * s), width: 46 * s, height: 9 * s),
          Paint()..color = const Color(0x22304018));
      final dark = Paint()..color = const Color(0xFF5FA843);
      final light = Paint()..color = const Color(0xFF7EC55E);
      canvas.drawCircle(Offset(bx - 13 * s, by + 3 * s), 10 * s, dark);
      canvas.drawCircle(Offset(bx + 13 * s, by + 3 * s), 10 * s, dark);
      canvas.drawCircle(Offset(bx, by), 12 * s, light);
      canvas.drawCircle(Offset(bx - 6 * s, by - 5 * s), 7 * s,
          Paint()..color = const Color(0xFFA9D494));
    }

    bush(w * 0.12, h * 0.585, base / 900);
    bush(w * 0.87, h * 0.62, base / 850);
    bush(w * 0.26, h * 0.78, base / 700);
    bush(w * 0.76, h * 0.8, base / 720);

    // 花・草の房
    for (var i = 0; i < 20; i++) {
      final fx = rng.nextDouble() * w;
      if (fx > w * 0.32 && fx < w * 0.68) continue;
      acFlower(canvas, fx, h * (0.5 + rng.nextDouble() * 0.46),
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
    }
    for (var i = 0; i < 26; i++) {
      final fx = rng.nextDouble() * w;
      if (fx > w * 0.34 && fx < w * 0.66) continue;
      acTuft(canvas, fx, h * (0.44 + rng.nextDouble() * 0.52), base / 430);
    }

    // 主人公(後ろ姿・ドットのまま + 足元の影)
    if (withHeroine) {
      final unit = 1.5 * (math.min(w, h * 0.75) / 160);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w / 2, h * 0.68 + 20.4 * unit),
              width: 13 * unit,
              height: 3 * unit),
          Paint()..color = const Color(0x26304018));
      drawPixelSprite(canvas, heroineBackRows, heroinePalette,
          w / 2 - 8 * unit, h * 0.68, unit);
    }
  }

  @override
  bool shouldRepaint(covariant _CleanVillagePathPainter old) =>
      old.withHeroine != withHeroine;
}

// ─────────────────────────────────────────────────────────────
// パン屋の店先(p12〜15)。dim=ミッション用に暗く。
// ─────────────────────────────────────────────────────────────
class _CleanBakeryPainter extends CustomPainter {
  const _CleanBakeryPainter({required this.dim, this.centered = false});
  final bool dim;
  final bool centered; // true: 店を中央に丸ごと収める(カード用)

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.3);
    acCloud(canvas, w * 0.75, h * 0.05, w / 1000, 0.95);
    acCloud(canvas, w * 0.45, h * 0.11, w / 1400, 0.8);

    // 奥の緑
    canvas.drawRect(Rect.fromLTWH(0, h * 0.28, w, h * 0.2),
        Paint()..color = const Color(0xFF6DB84E));
    final rng = math.Random(13);
    final bushShade = Paint()..color = const Color(0x2E2E7D32);
    for (var i = 0; i < 10; i++) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(rng.nextDouble() * w,
                  h * (0.3 + rng.nextDouble() * 0.15)),
              width: w * (0.03 + rng.nextDouble() * 0.05),
              height: h * 0.03),
          bushShade);
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.85, h * 0.34), width: w * 0.18, height: h * 0.1),
        Paint()..color = const Color(0xFF5CA649));
    // 生け垣の草の房 + 紙吹雪パターン
    for (var i = 0; i < 10; i++) {
      acTuft(canvas, rng.nextDouble() * w, h * (0.34 + rng.nextDouble() * 0.12),
          w / 500, const Color(0x40295C1E));
    }
    acGrassSpeckle(canvas, Rect.fromLTWH(0, h * 0.28, w, h * 0.2),
        math.Random(51), step: w / 14, color: const Color(0x14173D10));

    // 地面(土)
    final groundRect = Rect.fromLTWH(0, h * 0.46, w, h * 0.54);
    canvas.drawRect(
        groundRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD0B584), Color(0xFFC0A375)],
          ).createShader(groundRect));
    final stone = Paint()..color = const Color(0x33A08662);
    for (var i = 0; i < 16; i++) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(rng.nextDouble() * w,
                  h * (0.5 + rng.nextDouble() * 0.48)),
              width: 18 + rng.nextDouble() * 14,
              height: 7 + rng.nextDouble() * 5),
          stone);
    }

    // ── 店舗(横長画面では幅を抑える。centered=中央に丸ごと収める) ──
    final land = w > h;
    final u = w / 160;
    final double sx, sy, sw, sh;
    if (centered) {
      sh = h * 0.60;
      sw = sh * 1.3;
      sx = w / 2 - sw / 2;
      sy = h * 0.27;
    } else {
      sx = -6 * u;
      sy = h * 0.14;
      sw = w * (land ? 0.45 : 0.72);
      sh = h * 0.36;
    }
    // 看板はカード用(centered)では店のサイズに合わせて大きく描く
    final us = centered ? sh / 42 : u;
    // 店の落ち影
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(sx + sw / 2, sy + sh + 4),
            width: sw * 1.06,
            height: h * 0.03),
        Paint()..color = const Color(0x1F30301A));
    // 壁
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(sx, sy, sw, sh),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6)),
        Paint()..color = const Color(0xFFEFE3C4));
    // レンガの表情(うっすら)
    final brick = Paint()..color = const Color(0x26C79B62);
    final brickH = sh / 12;
    for (var r0 = 0; r0 < 12; r0 += 2) {
      for (var bxx = sx + (r0 % 4 == 0 ? 0.0 : brickH * 1.4);
          bxx < sx + sw;
          bxx += brickH * 3.4) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(bxx, sy + r0 * brickH + 1, brickH * 2.2,
                    brickH - 2),
                const Radius.circular(2)),
            brick);
      }
    }
    // 屋根(赤茶の帯)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx - 8, sy - h * 0.045, sw + 16, h * 0.05),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFB84C40));
    canvas.drawRect(Rect.fromLTWH(sx - 8, sy - 2, sw + 16, 4),
        Paint()..color = const Color(0xFF8A3229));
    // 看板(木板) — 「パン屋」の文字はウィジェット側
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + sw * 0.18, sy - 9 * us, sw * 0.5, 15 * us),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFF6E4A22));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + sw * 0.2, sy - 7 * us, sw * 0.46, 11 * us),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFEDD9A5));
    if (centered) {
      // カード用は看板の文字も描き込む
      final tp = TextPainter(
        text: TextSpan(
            text: 'パン屋',
            style: TextStyle(
                color: const Color(0xFF5A3A1E),
                fontSize: (6.5 * us).clamp(11.0, 26.0),
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final signRect =
          Rect.fromLTWH(sx + sw * 0.2, sy - 7 * us, sw * 0.46, 11 * us);
      tp.paint(canvas, signRect.center - Offset(tp.width / 2, tp.height / 2));
    }
    // ひさし(赤白スカラップ)
    final ay = sy + sh * 0.28, ah = h * 0.045;
    const n = 10;
    for (var i = 0; i < n; i++) {
      final c = i.isEven ? const Color(0xFFC85C4E) : Colors.white;
      final sxx = sx + i * sw / n;
      canvas.drawRect(Rect.fromLTWH(sxx, ay, sw / n, ah), Paint()..color = c);
      canvas.drawArc(
          Rect.fromLTWH(sxx, ay + ah - sw / n * 0.3, sw / n, sw / n * 0.6),
          0, 3.1416, true, Paint()..color = c);
    }
    // ショーウィンドウ(棚2段 + パン)
    final wx = sx + sw * 0.08, wy = sy + sh * 0.44, ww = sw * 0.48,
        wh = sh * 0.42;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(wx - 4, wy - 4, ww + 8, wh + 8),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFF54371A));
    canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh),
        Paint()..color = const Color(0xFF7C5B36));
    canvas.drawRect(Rect.fromLTWH(wx, wy + wh / 2 - 2, ww, 4),
        Paint()..color = const Color(0xFF54371A));
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 4; i++) {
        final bc = Offset(wx + ww * (0.14 + i * 0.24),
            wy + wh * (0.28 + row * 0.5));
        canvas.drawOval(
            Rect.fromCenter(
                center: bc, width: ww * 0.18, height: wh * 0.24),
            Paint()..color = const Color(0xFFD8A055));
        canvas.drawOval(
            Rect.fromCenter(
                center: bc.translate(-ww * 0.02, -wh * 0.03),
                width: ww * 0.08,
                height: wh * 0.1),
            Paint()..color = const Color(0xFFF2CB8E));
      }
    }
    // ドア(緑のアーチ)
    final dx = sx + sw * 0.66, dy = sy + sh * 0.4, dw = sw * 0.16,
        dh = sh * 0.6;
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(dx - 3, dy, dw + 6, dh),
            topLeft: Radius.circular(dw / 2 + 3),
            topRight: Radius.circular(dw / 2 + 3)),
        Paint()..color = const Color(0xFF2E5234));
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(dx, dy + 3, dw, dh - 3),
            topLeft: Radius.circular(dw / 2),
            topRight: Radius.circular(dw / 2)),
        Paint()..color = const Color(0xFF3E6B44));
    canvas.drawCircle(Offset(dx + dw * 0.78, dy + dh * 0.5), 3,
        Paint()..color = const Color(0xFFE8C46B));
    // 黒板
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + 8 * u * 0.6, sy + sh + 6, w * 0.14, h * 0.13),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFF6E4A22));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + 8 * u * 0.6 + 4, sy + sh + 10, w * 0.14 - 8,
                h * 0.13 - 8),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF2E3230));
    final chalk = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(sx + 8 * u * 0.6 + 8, sy + sh + 18),
        Offset(sx + 8 * u * 0.6 + w * 0.08, sy + sh + 18),
        chalk);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(sx + 8 * u * 0.6 + w * 0.05, sy + sh + h * 0.09),
            width: w * 0.05,
            height: h * 0.025),
        Paint()..color = const Color(0xFFD8A055));

    if (dim) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0x66101C3A));
    }
  }

  @override
  bool shouldRepaint(covariant _CleanBakeryPainter old) => old.dim != dim;
}

// ─────────────────────────────────────────────────────────────
// デザイン工房の店先(カード用・正面構図)。
// ─────────────────────────────────────────────────────────────
class _CleanStudioFrontPainter extends CustomPainter {
  const _CleanStudioFrontPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.3);
    acCloud(canvas, w * 0.78, h * 0.1, w / 1200, 0.95);
    acCloud(canvas, w * 0.2, h * 0.14, w / 1600, 0.85);
    // 奥の緑と地面
    canvas.drawRect(Rect.fromLTWH(0, h * 0.28, w, h * 0.2),
        Paint()..color = const Color(0xFF6DB84E));
    final rng = math.Random(17);
    acGrassSpeckle(canvas, Rect.fromLTWH(0, h * 0.28, w, h * 0.2),
        math.Random(23), step: w / 14, color: const Color(0x14173D10));
    final groundRect = Rect.fromLTWH(0, h * 0.46, w, h * 0.54);
    canvas.drawRect(
        groundRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD0B584), Color(0xFFC0A375)],
          ).createShader(groundRect));
    final stone = Paint()..color = const Color(0x33A08662);
    for (var i = 0; i < 12; i++) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  rng.nextDouble() * w, h * (0.5 + rng.nextDouble() * 0.48)),
              width: 18 + rng.nextDouble() * 14,
              height: 7 + rng.nextDouble() * 5),
          stone);
    }

    // ── 店舗(右寄り・正面。左に掲示板を置く) ──
    final sh = h * 0.60, sw = sh * 1.3;
    final sx = w * 0.62 - sw / 2, sy = h * 0.27;
    final us = sh / 42;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(sx + sw / 2, sy + sh + 4),
            width: sw * 1.08,
            height: h * 0.03),
        Paint()..color = const Color(0x1F30301A));
    // 壁(クリーム)
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(sx, sy, sw, sh),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6)),
        Paint()..color = const Color(0xFFF1EAD8));
    // 屋根(紫の帯)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx - 8, sy - h * 0.045, sw + 16, h * 0.05),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFA98BC6));
    canvas.drawRect(Rect.fromLTWH(sx - 8, sy - 2, sw + 16, 4),
        Paint()..color = const Color(0xFF83659E));
    // 看板(デザイン会社 — 文字が長いので幅広の板にする)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + sw * 0.08, sy - 9 * us, sw * 0.84, 15 * us),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFF6E4A22));
    final signRect =
        Rect.fromLTWH(sx + sw * 0.11, sy - 7 * us, sw * 0.78, 11 * us);
    canvas.drawRRect(
        RRect.fromRectAndRadius(signRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFFEDD9A5));
    final signFont = math.min(
        (6.5 * us).clamp(11.0, 26.0), signRect.width / 7.0);
    final tp = TextPainter(
      text: TextSpan(
          text: 'デザイン会社',
          style: TextStyle(
              color: const Color(0xFF5A3A1E),
              fontSize: signFont,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, signRect.center - Offset(tp.width / 2, tp.height / 2));
    // 大きなショーウィンドウ(中にイーゼルとキャンバス)
    final wx = sx + sw * 0.08, wy = sy + sh * 0.3, ww = sw * 0.5,
        wh = sh * 0.52;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(wx - 4, wy - 4, ww + 8, wh + 8),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFF83659E));
    canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh),
        Paint()..color = const Color(0xFFDCEBF5));
    // デスク(パソコンでデザイン制作中)
    canvas.drawRect(
        Rect.fromLTWH(wx, wy + wh * 0.68, ww, wh * 0.32),
        Paint()..color = const Color(0xFF9A6B45));
    canvas.drawRect(
        Rect.fromLTWH(wx, wy + wh * 0.68, ww, wh * 0.05),
        Paint()..color = const Color(0xFFB0855C));
    // モニター(スタンド + デザインツールの画面)
    final mon = Rect.fromCenter(
        center: Offset(wx + ww * 0.44, wy + wh * 0.38),
        width: ww * 0.56,
        height: wh * 0.46);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(mon.center.dx, mon.bottom + wh * 0.09),
                width: ww * 0.2,
                height: wh * 0.05),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF5A4E44));
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(mon.center.dx, mon.bottom + wh * 0.05),
            width: ww * 0.05,
            height: wh * 0.1),
        Paint()..color = const Color(0xFF5A4E44));
    canvas.drawRRect(
        RRect.fromRectAndRadius(mon.inflate(3), const Radius.circular(5)),
        Paint()..color = const Color(0xFF44403A));
    canvas.drawRect(mon, Paint()..color = Colors.white);
    // 画面の中: ツールバー + 描きかけのデザイン
    canvas.drawRect(
        Rect.fromLTWH(mon.left, mon.top, mon.width, mon.height * 0.16),
        Paint()..color = const Color(0xFFE8E2D2));
    canvas.drawRect(
        Rect.fromLTWH(mon.left, mon.top + mon.height * 0.16, mon.width * 0.14,
            mon.height * 0.84),
        Paint()..color = const Color(0xFFD8D2C2));
    canvas.drawCircle(
        Offset(mon.left + mon.width * 0.5, mon.top + mon.height * 0.48),
        mon.width * 0.12,
        Paint()..color = const Color(0xFFF2A5C0));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(mon.left + mon.width * 0.66,
                mon.top + mon.height * 0.36, mon.width * 0.24,
                mon.height * 0.12),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF7FA3CB));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(mon.left + mon.width * 0.34,
                mon.top + mon.height * 0.72, mon.width * 0.44,
                mon.height * 0.1),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFF6D96B));
    // キーボードとマウスとマグ
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(wx + ww * 0.42, wy + wh * 0.76),
                width: ww * 0.4,
                height: wh * 0.07),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFFE8E2D2));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(wx + ww * 0.72, wy + wh * 0.76),
            width: ww * 0.08,
            height: wh * 0.08),
        Paint()..color = const Color(0xFFE8E2D2));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(wx + ww * 0.12, wy + wh * 0.73),
                width: ww * 0.1,
                height: wh * 0.12),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFE8A0A8));
    // ドア(青緑のアーチ)
    final dx = sx + sw * 0.68, dy = sy + sh * 0.34, dw = sw * 0.17,
        dh = sh * 0.66;
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(dx - 3, dy, dw + 6, dh),
            topLeft: Radius.circular(dw / 2 + 3),
            topRight: Radius.circular(dw / 2 + 3)),
        Paint()..color = const Color(0xFF3E6273));
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(dx, dy + 3, dw, dh - 3),
            topLeft: Radius.circular(dw / 2),
            topRight: Radius.circular(dw / 2)),
        Paint()..color = const Color(0xFF588DBE));
    canvas.drawCircle(Offset(dx + dw * 0.78, dy + dh * 0.5), 3,
        Paint()..color = const Color(0xFFE8C46B));
    // 店先の鉢植えと大きな鉛筆のオブジェ
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(sx - w * 0.045, sy + sh - h * 0.02),
                width: w * 0.05,
                height: h * 0.05),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFFA85C32));
    final leafP = Paint()..color = const Color(0xFF5E9B4E);
    canvas.drawCircle(Offset(sx - w * 0.045, sy + sh - h * 0.06), w * 0.025, leafP);
    canvas.drawCircle(
        Offset(sx - w * 0.06, sy + sh - h * 0.045), w * 0.018, leafP);
    // 鉛筆オブジェ(右側)
    final px = sx + sw + w * 0.045;
    final pw = w * 0.028, phh = h * 0.22;
    final pTop = sy + sh - phh;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(px - pw / 2, pTop, pw, phh * 0.8),
            Radius.circular(pw * 0.3)),
        Paint()..color = const Color(0xFFF6D96B));
    final tip = Path()
      ..moveTo(px - pw / 2, pTop + phh * 0.8)
      ..lineTo(px + pw / 2, pTop + phh * 0.8)
      ..lineTo(px, pTop + phh)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFF4D29C));
    canvas.drawPath(
        Path()
          ..moveTo(px - pw * 0.18, pTop + phh * 0.93)
          ..lineTo(px + pw * 0.18, pTop + phh * 0.93)
          ..lineTo(px, pTop + phh)
          ..close(),
        Paint()..color = const Color(0xFF5A4E44));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(px - pw / 2, pTop - phh * 0.08, pw, phh * 0.08),
            Radius.circular(pw * 0.3)),
        Paint()..color = const Color(0xFFE8A0A8));

    // ── 店先の掲示板(お困りごと・プチ実務案件) ──
    final bbw = w * 0.26, bbh = h * 0.24;
    final bbx = w * 0.16 - bbw / 2, bby = h * 0.44;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(bbx + bbw / 2, bby + bbh + h * 0.15),
            width: bbw * 0.95,
            height: h * 0.025),
        Paint()..color = const Color(0x22304018));
    for (final fx in [0.22, 0.78]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bbx + bbw * fx - 4, bby + bbh, 8, h * 0.15),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFF9A6B45));
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bbx - 6, bby - h * 0.035, bbw + 12, h * 0.04),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFFC98A6B));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bbx, bby, bbw, bbh), const Radius.circular(8)),
        Paint()..color = const Color(0xFF9A6B45));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bbx + 5, bby + 5, bbw - 10, bbh - 10),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFF7C5B36));
    const bbPins = [
      Color(0xFFDF5A4E), Color(0xFF7FA3CB), Color(0xFF74B858),
      Color(0xFFF6D96B),
    ];
    var bbi = 0;
    for (final (fx, fy) in [(0.14, 0.14), (0.55, 0.18), (0.18, 0.55), (0.56, 0.52)]) {
      final paper = Rect.fromLTWH(bbx + bbw * fx, bby + bbh * fy,
          bbw * 0.32, bbh * 0.32);
      canvas.drawRRect(
          RRect.fromRectAndRadius(paper, const Radius.circular(3)),
          Paint()..color = const Color(0xFFFFF8EA));
      canvas.drawCircle(
          Offset(paper.center.dx, paper.top + 2.5), 2.2,
          Paint()..color = bbPins[bbi % bbPins.length]);
      bbi++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// カフェ / 八百屋さんの店先(カード用・正面構図)。
// ─────────────────────────────────────────────────────────────
class _CleanFrontPainter extends CustomPainter {
  const _CleanFrontPainter({required this.kind});
  final String kind; // 'cafe' | 'grocery' | 'museum'

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cafe = kind == 'cafe';
    final museum = kind == 'museum';
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.3);
    acCloud(canvas, w * 0.78, h * 0.1, w / 1200, 0.95);
    acCloud(canvas, w * 0.2, h * 0.14, w / 1600, 0.85);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.28, w, h * 0.2),
        Paint()..color = const Color(0xFF6DB84E));
    acGrassSpeckle(canvas, Rect.fromLTWH(0, h * 0.28, w, h * 0.2),
        math.Random(23), step: w / 14, color: const Color(0x14173D10));
    final rng = math.Random(19);
    final groundRect = Rect.fromLTWH(0, h * 0.46, w, h * 0.54);
    canvas.drawRect(
        groundRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD0B584), Color(0xFFC0A375)],
          ).createShader(groundRect));
    final stone = Paint()..color = const Color(0x33A08662);
    for (var i = 0; i < 12; i++) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  rng.nextDouble() * w, h * (0.5 + rng.nextDouble() * 0.48)),
              width: 18 + rng.nextDouble() * 14,
              height: 7 + rng.nextDouble() * 5),
          stone);
    }

    // ── 店舗(中央・正面) ──
    final sh = h * 0.60, sw = sh * 1.3;
    final sx = w / 2 - sw / 2, sy = h * 0.27;
    final us = sh / 42;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, sy + sh + 4),
            width: sw * 1.08,
            height: h * 0.03),
        Paint()..color = const Color(0x1F30301A));
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(sx, sy, sw, sh),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6)),
        Paint()
          ..color = cafe ? const Color(0xFFF7E9E0) : const Color(0xFFF1EAD8));
    // 屋根の帯
    final roof = cafe
        ? const Color(0xFFE8A0A8)
        : museum
            ? const Color(0xFF7FA3CB)
            : const Color(0xFF8CC178);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx - 8, sy - h * 0.045, sw + 16, h * 0.05),
            const Radius.circular(6)),
        Paint()..color = roof);
    canvas.drawRect(Rect.fromLTWH(sx - 8, sy - 2, sw + 16, 4),
        Paint()..color = Color.lerp(roof, Colors.black, 0.22)!);
    // 看板
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + sw * 0.18, sy - 9 * us, sw * 0.5, 15 * us),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFF6E4A22));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + sw * 0.2, sy - 7 * us, sw * 0.46, 11 * us),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFEDD9A5));
    final tp = TextPainter(
      text: TextSpan(
          text: cafe
              ? 'カフェ'
              : museum
                  ? '図書館'
                  : '八百屋',
          style: TextStyle(
              color: const Color(0xFF5A3A1E),
              fontSize: (6.5 * us).clamp(11.0, 26.0),
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    final signRect =
        Rect.fromLTWH(sx + sw * 0.2, sy - 7 * us, sw * 0.46, 11 * us);
    tp.paint(canvas, signRect.center - Offset(tp.width / 2, tp.height / 2));
    // ひさし(スカラップ・資料館はなし)
    if (!museum) {
      final ay = sy + sh * 0.26, ah = h * 0.05;
      const n = 8;
      final awningA = cafe ? const Color(0xFFE8A0A8) : const Color(0xFF8CC178);
      for (var i = 0; i < n; i++) {
        final p = Paint()..color = i.isEven ? awningA : Colors.white;
        final sxx = sx + i * sw / n;
        canvas.drawRect(Rect.fromLTWH(sxx, ay, sw / n, ah), p);
        canvas.drawArc(
            Rect.fromLTWH(sxx, ay + ah - sw / n * 0.3, sw / n, sw / n * 0.6),
            0, 3.1416, true, p);
      }
    }

    if (cafe) {
      // 大きな窓(カウンターとコーヒー)
      final wx = sx + sw * 0.08, wy = sy + sh * 0.42, ww = sw * 0.5,
          wh = sh * 0.4;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(wx - 4, wy - 4, ww + 8, wh + 8),
              const Radius.circular(8)),
          Paint()..color = const Color(0xFFB9848C));
      canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh),
          Paint()..color = const Color(0xFFDCEBF5));
      // カウンターとマグカップ
      canvas.drawRect(Rect.fromLTWH(wx, wy + wh * 0.62, ww, wh * 0.38),
          Paint()..color = const Color(0xFF9A6B45));
      final mug = Offset(wx + ww * 0.36, wy + wh * 0.5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: mug, width: ww * 0.2, height: wh * 0.26),
              const Radius.circular(4)),
          Paint()..color = Colors.white);
      canvas.drawRect(
          Rect.fromCenter(
              center: mug.translate(0, -wh * 0.06),
              width: ww * 0.16,
              height: wh * 0.08),
          Paint()..color = const Color(0xFF8A5A30));
      // 取っ手と湯気
      canvas.drawArc(
          Rect.fromCenter(
              center: mug.translate(ww * 0.13, 0),
              width: ww * 0.09,
              height: wh * 0.14),
          -1.57, 3.14, false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      final steam = Paint()
        ..color = const Color(0x88FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
          Path()
            ..moveTo(mug.dx - 4, mug.dy - wh * 0.22)
            ..quadraticBezierTo(mug.dx - 9, mug.dy - wh * 0.34, mug.dx - 4,
                mug.dy - wh * 0.46),
          steam);
      canvas.drawPath(
          Path()
            ..moveTo(mug.dx + 5, mug.dy - wh * 0.22)
            ..quadraticBezierTo(mug.dx + 10, mug.dy - wh * 0.34, mug.dx + 5,
                mug.dy - wh * 0.46),
          steam);
      // メニューの立て看板(店先)
      final bx = sx - w * 0.055, by = sy + sh - h * 0.115;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx - w * 0.032, by, w * 0.064, h * 0.1),
              const Radius.circular(5)),
          Paint()..color = const Color(0xFF6E4A22));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx - w * 0.026, by + 4, w * 0.052, h * 0.082),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFF2E3230));
      final chalk = Paint()
        ..color = Colors.white70
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(bx - w * 0.016, by + h * 0.03),
          Offset(bx + w * 0.016, by + h * 0.03), chalk);
      canvas.drawLine(Offset(bx - w * 0.016, by + h * 0.05),
          Offset(bx + w * 0.01, by + h * 0.05), chalk);
      canvas.drawCircle(Offset(bx, by + h * 0.075), 4,
          Paint()..color = const Color(0xFFE8A0A8));
    } else if (museum) {
      // 資料館: 本棚の見える大きな窓 + 白い柱
      final wx = sx + sw * 0.08, wy = sy + sh * 0.34, ww = sw * 0.5,
          wh = sh * 0.5;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(wx - 4, wy - 4, ww + 8, wh + 8),
              const Radius.circular(8)),
          Paint()..color = const Color(0xFF5F7FA6));
      canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh),
          Paint()..color = const Color(0xFFF7EFDC));
      const spineColors = [
        Color(0xFFDF5A4E), Color(0xFF7FA3CB), Color(0xFF74B858),
        Color(0xFFF6D96B), Color(0xFFA98BC6), Color(0xFFF0913C),
      ];
      for (var row = 0; row < 2; row++) {
        final ry = wy + wh * (0.12 + row * 0.46);
        canvas.drawRect(
            Rect.fromLTWH(wx + ww * 0.06, ry + wh * 0.32, ww * 0.88, 3),
            Paint()..color = const Color(0xFF9A6B45));
        var bx2 = wx + ww * 0.08;
        var k = row * 4;
        while (bx2 < wx + ww * 0.88) {
          final bw2 = ww * (0.06 + (k % 3) * 0.015);
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(bx2, ry + wh * (0.02 + (k % 2) * 0.04),
                      bw2, wh * 0.3 - (k % 2) * wh * 0.04),
                  const Radius.circular(2)),
              Paint()..color = spineColors[k % spineColors.length]);
          bx2 += bw2 + ww * 0.015;
          k++;
        }
      }
      // 白い柱(入口の両脇)
      for (final fx in [0.64, 0.9]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(sx + sw * fx - 5, sy + sh * 0.3, 10, sh * 0.7),
                const Radius.circular(4)),
            Paint()..color = Colors.white);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(sx + sw * fx - 8, sy + sh * 0.27, 16, 6),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFFE8E2D2));
      }
    } else {
      // 八百屋: 開放的な店先に野菜の陳列台(2段)
      final cx0 = sx + sw * 0.08, cw = sw * 0.56;
      for (var row = 0; row < 2; row++) {
        final cy = sy + sh * (0.46 + row * 0.27);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx0 - 3, cy - 3, cw + 6, sh * 0.22 + 6),
                const Radius.circular(6)),
            Paint()..color = const Color(0xFF9A6B45));
        canvas.drawRect(Rect.fromLTWH(cx0, cy, cw, sh * 0.22),
            Paint()..color = const Color(0xFF7C5B36));
        // 野菜(トマト・にんじん・キャベツ)
        final colors = row == 0
            ? [const Color(0xFFDF5A4E), const Color(0xFFF0913C), const Color(0xFF74B858)]
            : [const Color(0xFF74B858), const Color(0xFFDF5A4E), const Color(0xFFF6D96B)];
        for (var i = 0; i < 6; i++) {
          final vc = Offset(
              cx0 + cw * (0.1 + i * 0.16), cy + sh * 0.12);
          final c = colors[i % 3];
          canvas.drawCircle(vc, sh * 0.055, Paint()..color = c);
          canvas.drawCircle(vc.translate(-2, -2), sh * 0.018,
              Paint()..color = Colors.white38);
          if (i % 3 == 1) {
            // にんじんの葉
            canvas.drawCircle(vc.translate(0, -sh * 0.055), 2.6,
                Paint()..color = const Color(0xFF3E7D53));
          }
        }
      }
      // 木箱(店先)
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(sx - w * 0.075, sy + sh - h * 0.07, w * 0.06,
                  h * 0.055),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFF9A6B45));
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
            Offset(sx - w * 0.06 + i * w * 0.016, sy + sh - h * 0.075),
            w * 0.009,
            Paint()..color = const Color(0xFFF0913C));
      }
    }

    // ドア(右側のアーチ)
    final dx = sx + sw * 0.7, dy = sy + sh * 0.4, dw = sw * 0.16,
        dh = sh * 0.6;
    final doorC =
        cafe ? const Color(0xFF8E5B52) : const Color(0xFF3E6B44);
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(dx - 3, dy, dw + 6, dh),
            topLeft: Radius.circular(dw / 2 + 3),
            topRight: Radius.circular(dw / 2 + 3)),
        Paint()..color = Color.lerp(doorC, Colors.black, 0.25)!);
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(dx, dy + 3, dw, dh - 3),
            topLeft: Radius.circular(dw / 2),
            topRight: Radius.circular(dw / 2)),
        Paint()..color = doorC);
    canvas.drawCircle(Offset(dx + dw * 0.78, dy + dh * 0.5), 3,
        Paint()..color = const Color(0xFFE8C46B));
  }

  @override
  bool shouldRepaint(covariant _CleanFrontPainter old) => old.kind != kind;
}

// ─────────────────────────────────────────────────────────────
// クエスト掲示板(カード用・正面構図)。
// ─────────────────────────────────────────────────────────────
class _CleanBoardFrontPainter extends CustomPainter {
  const _CleanBoardFrontPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.34);
    acCloud(canvas, w * 0.78, h * 0.1, w / 1200, 0.95);
    acCloud(canvas, w * 0.2, h * 0.14, w / 1600, 0.85);
    // 芝生
    final grassRect = Rect.fromLTWH(0, h * 0.32, w, h * 0.68);
    canvas.drawRect(
        grassRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC55E), Color(0xFF5FA843)],
          ).createShader(grassRect));
    acGrassSpeckle(canvas, grassRect, math.Random(29),
        step: w / 14, color: const Color(0x14204D18));
    acTree(canvas, w * 0.08, h * 0.6, w / 700);
    acConifer(canvas, w * 0.93, h * 0.56, w / 780);

    // ── 掲示板(中央・正面) ──
    final bw = w * 0.56, bh = h * 0.42;
    final bx = w / 2 - bw / 2, by = h * 0.2;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, by + bh + h * 0.24),
            width: bw * 0.9,
            height: h * 0.035),
        Paint()..color = const Color(0x22304018));
    // 脚
    for (final fx in [0.2, 0.8]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx + bw * fx - 6, by + bh, 12, h * 0.26),
              const Radius.circular(6)),
          Paint()..color = const Color(0xFF9A6B45));
    }
    // 屋根つきの板(丸角 + 明るい縁)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx - 10, by - h * 0.05, bw + 20, h * 0.055),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFC98A6B));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(12)),
        Paint()..color = const Color(0xFF9A6B45));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx + 8, by + 8, bw - 16, bh - 16),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFF7C5B36));
    // 貼り紙(依頼のチラシ + カラフルなピン)
    final rng = math.Random(31);
    const pins = [
      Color(0xFFDF5A4E), Color(0xFF7FA3CB), Color(0xFF74B858),
      Color(0xFFF6D96B), Color(0xFFE8A0A8),
    ];
    for (final (fx, fy, tilt) in [
      (0.16, 0.18, -0.06), (0.42, 0.14, 0.04), (0.68, 0.2, -0.03),
      (0.2, 0.55, 0.05), (0.5, 0.52, -0.05), (0.72, 0.58, 0.06),
    ]) {
      canvas.save();
      canvas.translate(bx + bw * fx + bw * 0.09, by + bh * fy + bh * 0.14);
      canvas.rotate(tilt);
      final paper = Rect.fromCenter(
          center: Offset.zero, width: bw * 0.19, height: bh * 0.3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(paper, const Radius.circular(4)),
          Paint()..color = const Color(0xFFFFF8EA));
      final line = Paint()
        ..color = const Color(0x408A744A)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
            Offset(-paper.width * 0.32, -paper.height * 0.16 + i * paper.height * 0.24),
            Offset(paper.width * (0.32 - (i == 2 ? 0.2 : 0)),
                -paper.height * 0.16 + i * paper.height * 0.24),
            line);
      }
      canvas.drawCircle(Offset(0, -paper.height * 0.38), 3.4,
          Paint()..color = pins[rng.nextInt(pins.length)]);
      canvas.restore();
    }
    // 足元の花
    for (var i = 0; i < 8; i++) {
      acFlower(
          canvas,
          w * (0.1 + rng.nextDouble() * 0.8),
          h * (0.82 + rng.nextDouble() * 0.14),
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
    }
    for (var i = 0; i < 8; i++) {
      acTuft(canvas, w * rng.nextDouble(), h * (0.5 + rng.nextDouble() * 0.45),
          w / 500, const Color(0x40295C1E));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// イベント会場(カード用・正面構図)。
// ─────────────────────────────────────────────────────────────
class _CleanEventFrontPainter extends CustomPainter {
  const _CleanEventFrontPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    acSkyGradient(canvas, size,
        const [Color(0xFFAECBEB), Color(0xFFD7E7F5)], heightFactor: 0.34);
    acCloud(canvas, w * 0.8, h * 0.09, w / 1200, 0.95);
    acCloud(canvas, w * 0.16, h * 0.13, w / 1600, 0.85);
    // 芝生
    final grassRect = Rect.fromLTWH(0, h * 0.32, w, h * 0.68);
    canvas.drawRect(
        grassRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC55E), Color(0xFF5FA843)],
          ).createShader(grassRect));
    acGrassSpeckle(canvas, grassRect, math.Random(37),
        step: w / 14, color: const Color(0x14204D18));
    acTree(canvas, w * 0.06, h * 0.62, w / 750);
    acConifer(canvas, w * 0.95, h * 0.58, w / 820);

    // ── 大テント(赤白ストライプ) ──
    final tw = w * 0.52, th = h * 0.34;
    final tx = w / 2 - tw / 2, ty = h * 0.36;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, ty + th + h * 0.22),
            width: tw * 1.05,
            height: h * 0.035),
        Paint()..color = const Color(0x22304018));
    // テントの壁(下半分)
    canvas.drawRect(Rect.fromLTWH(tx + tw * 0.08, ty + th * 0.5,
            tw * 0.84, th * 0.5 + h * 0.2),
        Paint()..color = const Color(0xFFF7EFDC));
    // 入口(三角にめくれた幕)
    final door = Path()
      ..moveTo(w / 2 - tw * 0.12, ty + th + h * 0.2)
      ..lineTo(w / 2, ty + th * 0.62)
      ..lineTo(w / 2 + tw * 0.12, ty + th + h * 0.2)
      ..close();
    canvas.drawPath(door, Paint()..color = const Color(0xFF8E5B52));
    // 屋根(ストライプのドーム)
    final roof = Path()
      ..moveTo(tx - tw * 0.06, ty + th * 0.52)
      ..quadraticBezierTo(w / 2, ty - th * 0.5, tx + tw * 1.06, ty + th * 0.52)
      ..close();
    canvas.save();
    canvas.clipPath(roof);
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
          Rect.fromLTWH(tx - tw * 0.06 + i * tw * 1.12 / 8, ty - th * 0.5,
              tw * 1.12 / 8, th * 1.1),
          Paint()
            ..color =
                i.isEven ? const Color(0xFFDF6A5E) : Colors.white);
    }
    canvas.restore();
    // 頂上の旗
    canvas.drawLine(
        Offset(w / 2, ty - th * 0.0),
        Offset(w / 2, ty - th * 0.34),
        Paint()
          ..color = const Color(0xFF9A6B45)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        Path()
          ..moveTo(w / 2, ty - th * 0.34)
          ..lineTo(w / 2 + tw * 0.1, ty - th * 0.27)
          ..lineTo(w / 2, ty - th * 0.2)
          ..close(),
        Paint()..color = const Color(0xFFF6D96B));

    // ガーランド(三角の旗の連なり)
    final garland = Path()
      ..moveTo(w * 0.06, h * 0.2)
      ..quadraticBezierTo(w / 2, h * 0.34, w * 0.94, h * 0.2);
    canvas.drawPath(
        garland,
        Paint()
          ..color = const Color(0xFF9A6B45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);
    const flagColors = [
      Color(0xFFDF6A5E), Color(0xFFF6D96B), Color(0xFF74B858),
      Color(0xFF7FA3CB), Color(0xFFE8A0A8),
    ];
    for (var i = 0; i < 9; i++) {
      final t = 0.06 + i * 0.11;
      final gx = w * t;
      final gy = h * (0.2 + 0.14 * (1 - (2 * (t - 0.5)).abs() * (2 * (t - 0.5)).abs()));
      canvas.drawPath(
          Path()
            ..moveTo(gx - 7, gy)
            ..lineTo(gx + 7, gy)
            ..lineTo(gx, gy + 13)
            ..close(),
          Paint()..color = flagColors[i % flagColors.length]);
    }

    // 風船(左右)
    for (final (fx, colors) in [
      (0.14, [const Color(0xFFE8A0A8), const Color(0xFF7FA3CB)]),
      (0.86, [const Color(0xFFF6D96B), const Color(0xFF74B858)]),
    ]) {
      for (var i = 0; i < 2; i++) {
        final bc = Offset(w * fx + (i == 0 ? -8.0 : 9.0),
            h * (0.55 - i * 0.05));
        canvas.drawLine(
            Offset(bc.dx, bc.dy + 10),
            Offset(w * fx, h * 0.74),
            Paint()
              ..color = const Color(0x669A6B45)
              ..strokeWidth = 1.6);
        canvas.drawOval(
            Rect.fromCenter(center: bc, width: 18, height: 22),
            Paint()..color = colors[i]);
        canvas.drawOval(
            Rect.fromCenter(
                center: bc.translate(-3, -4), width: 5, height: 7),
            Paint()..color = Colors.white38);
      }
    }
    // 足元の花
    final rng = math.Random(41);
    for (var i = 0; i < 8; i++) {
      acFlower(
          canvas,
          w * (0.08 + rng.nextDouble() * 0.84),
          h * (0.82 + rng.nextDouble() * 0.13),
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// キャラクター付きシーン(島の全景 + ドットスプライト)。
// ─────────────────────────────────────────────────────────────
class _CleanCharacterScene extends StatelessWidget {
  const _CleanCharacterScene({required this.pose});
  final int pose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, c) {
        final spriteW = math.min(c.maxWidth * 0.42, 230.0);
        return Stack(children: [
          const Positioned.fill(
            child:
                CustomPaint(painter: _CleanIslandPainter(withHeroine: false)),
          ),
          // 足元のやわらかい影
          Positioned(
            right: pose == 2 ? null : c.maxWidth * 0.03 + spriteW * 0.1,
            left: pose == 2 ? c.maxWidth * 0.05 + spriteW * 0.1 : null,
            bottom: (pose == 2 ? 0 : c.maxHeight * 0.155) - 5,
            child: Container(
              width: spriteW * 0.8,
              height: (spriteW * 0.13).clamp(8.0, 18.0),
              decoration: BoxDecoration(
                color: const Color(0x26304018),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            right: pose == 2 ? null : c.maxWidth * 0.03,
            left: pose == 2 ? c.maxWidth * 0.05 : null,
            bottom: pose == 2 ? 0 : c.maxHeight * 0.155,
            child: pose == 2
                ? PixelSprite(
                    rows: heroineFrontRows,
                    palette: heroinePalette,
                    width: spriteW)
                : PixelSprite(
                    rows: miporinRows(pose),
                    palette: miporinPalette,
                    width: spriteW),
          ),
        ]);
      }),
    );
  }
}
