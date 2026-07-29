import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 第1話の各シーンをコード描画(ドット仕様)するPainter群。
/// story.json の "scene" 名 → 背景ウィジェットを返す。
/// キャラクターは文字列マップのピクセルスプライト(編集しやすい)。
Widget buildStoryScene(String scene) {
  switch (scene) {
    case 'bedroom_sleep':
      return const _Fill(_BedroomPainter(mode: 0));
    case 'bedroom_awake':
      return const _Fill(_BedroomPainter(mode: 1));
    case 'light_burst':
      return const _Fill(_LightBurstPainter());
    case 'phone':
      return const _PhoneScene();
    case 'island_overview':
      return const _Fill(_IslandOverviewPainter(withHeroine: true));
    case 'island_map':
      return const _Fill(_IslandOverviewPainter(withHeroine: false));
    case 'signboard':
      return const _Fill(_SignboardPainter());
    case 'miporin_welcome':
      return const _CharacterScene(pose: 0);
    case 'miporin_point':
      return const _CharacterScene(pose: 1);
    case 'heroine_think':
      return const _CharacterScene(pose: 2);
    case 'village_path':
      return const _Fill(_VillagePathPainter());
    case 'bakery':
    case 'mission':
      return _Fill(_BakeryPainter(dim: scene == 'mission'));
    default:
      return const ColoredBox(color: Color(0xFF1B2440));
  }
}

class _Fill extends StatelessWidget {
  const _Fill(this.painter);
  final CustomPainter painter;
  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: CustomPaint(painter: painter));
}

// ─────────────────────────────────────────────────────────────
// ピクセルスプライト(1文字=1ドット)。
// ─────────────────────────────────────────────────────────────
class PixelSprite extends StatelessWidget {
  const PixelSprite(
      {super.key,
      required this.rows,
      required this.palette,
      required this.width});
  final List<String> rows;
  final Map<String, Color> palette;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * rows.length / rows[0].length;
    return CustomPaint(
      size: Size(width, h),
      painter: _SpritePainter(rows, palette),
    );
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter(this.rows, this.palette);
  final List<String> rows;
  final Map<String, Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / rows[0].length;
    final p = Paint();
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final c = palette[rows[y][x]];
        if (c == null) continue;
        p.color = c;
        canvas.drawRect(Rect.fromLTWH(x * u, y * u, u + 0.3, u + 0.3), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) => old.rows != rows;
}

// 共通パレット
const _skin = Color(0xFFF6D7B8);
const _eye = Color(0xFF3E2410);
const _blush = Color(0xFFF0A8A0);

/// みぽりん(ピンクのポニーテール)。pose 0=にっこり 1=指さし
List<String> miporinRows(int pose) => [
      '......pppppp..PP',
      '.....pppppppp.PP',
      '....pppppppppPPP',
      '....pPPPPPPpp.PP',
      '....pffffffpp.PP',
      '....pfeffefpp.PP',
      '....pffffffp..PP',
      '....pffmmffp..P.',
      '.....ffffff...P.',
      '....wwwwwwww..P.',
      '...wwwwrrwwww...',
      pose == 1 ? '..awwwwwwwwwwfa.' : '..awwwwwwwwwwa..',
      pose == 1 ? '..a.wwwwwwww.f..' : '..awwwwwwwwwwa..',
      '....wwwwwwww....',
      '....RRRRRRRR....',
      '...RRRRRRRRRR...',
      '...RRRRRRRRRR...',
      '....ff....ff....',
      '....ff....ff....',
      '....ss....ss....',
    ];

const miporinPalette = {
  'p': Color(0xFFE8607A),
  'P': Color(0xFFF08CA0),
  'f': _skin,
  'a': _skin,
  'e': _eye,
  'm': Color(0xFFC44E52),
  'w': Colors.white,
  'r': Color(0xFFD9494F),
  'R': Color(0xFFB33A4E),
  's': Color(0xFF5A3A1E),
};

/// 主人公(正面・考え中)。
const heroineFrontRows = [
  '....hhhhhhhh....',
  '...hhhhhhhhhh...',
  '..hhhhhhhhhhhh..',
  '..hhHHHHHHHHhh..',
  '..hhffffffffhh..',
  '..hfeffffffefh..',
  '..hffffffffffh..',
  '..hfbffffffbfh..',
  '..hffffmmffffh..',
  '..h.ffffffff.h..',
  '....wwwwwwww....',
  '...wwwwwwwwwwf..',
  '..awwwwwwwwwwf..',
  '..awwwwwwwwww...',
  '....RRRRRRRR....',
  '...RRRRRRRRRR...',
  '...RRRRRRRRRR...',
  '....ff....ff....',
  '....ff....ff....',
  '....ss....ss....',
];

/// 主人公(後ろ姿)。
const heroineBackRows = [
  '....hhhhhhhh....',
  '...hhhhhhhhhh...',
  '..hhhhhhhhhhhh..',
  '..hhhhhhhhhhhh..',
  '..hhhhhhhhhhhh..',
  '..hhhhhhhhhhhh..',
  '..hhhhhhhhhhhh..',
  '...hhhhhhhhhh...',
  '....hhhhhhhh....',
  '....wwwwwwww....',
  '...wwwwwwwwww...',
  '..awwwwwwwwwwa..',
  '..awwwwwwwwwwa..',
  '....wwwwwwww....',
  '....RRRRRRRR....',
  '...RRRRRRRRRR...',
  '...RRRRRRRRRR...',
  '....ff....ff....',
  '....ff....ff....',
  '....ss....ss....',
];

const heroinePalette = {
  'h': Color(0xFF7A4A22),
  'H': Color(0xFF9A6534),
  'f': _skin,
  'a': _skin,
  'e': _eye,
  'b': _blush,
  'm': Color(0xFFB3583F),
  'w': Colors.white,
  'R': Color(0xFFB33A4E),
  's': Color(0xFF5A3A1E),
};

/// パン屋さん(コック帽・くたびれ顔)。
const bakerRows = [
  '....CCCCCCCC....',
  '...CCCCCCCCCC...',
  '...CCCCCCCCCC...',
  '....cccccccc....',
  '....ffffffff....',
  '...ffeffffeff...',
  '...ffffffffff...',
  '...fMMMMMMMMf...',
  '....fMMMMMMf....',
  '.....ffffff.....',
  '...rrwwwwwwrr...',
  '..awWWWWWWWWwa..',
  '..awWWWWWWWWwa..',
  '..a.WWWWWWWW.a..',
  '....WWWWWWWW....',
  '....WWWWWWWW....',
  '....bb....bb....',
  '....bb....bb....',
  '....ss....ss....',
];

const bakerPalette = {
  'C': Colors.white,
  'c': Color(0xFFE4E0D8),
  'f': Color(0xFFE8C49A),
  'e': _eye,
  'M': Color(0xFF5A4632),
  'r': Color(0xFFC44E52),
  'w': Colors.white,
  'W': Color(0xFFF2EFE8),
  'a': Color(0xFFE8C49A),
  'b': Color(0xFF6E5138),
  's': Color(0xFF3E2E1C),
};

// ─────────────────────────────────────────────────────────────
// 寝室(mode 0=就寝 1=目覚め)。仮想96x168をcontainで表示。
// ─────────────────────────────────────────────────────────────
class _BedroomPainter extends CustomPainter {
  const _BedroomPainter({required this.mode});
  final int mode;

  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width / 96, size.height / 168);
    final ox = (size.width - 96 * u) / 2;
    final oy = (size.height - 168 * u) / 2;
    final p = Paint();
    final rng = math.Random(9);
    Rect r(num x, num y, num w, num h) =>
        Rect.fromLTWH(ox + x * u, oy + y * u, w * u + 0.4, h * u + 0.4);

    // 外周も塗る(レターボックス部)
    p.color = const Color(0xFF6B5A40);
    canvas.drawRect(Offset.zero & size, p);

    // 壁
    p.color = const Color(0xFF8F7A57);
    canvas.drawRect(r(-8, -20, 112, 84), p);
    for (var i = 0; i < 120; i++) {
      p.color = rng.nextBool()
          ? const Color(0xFF7C6949)
          : const Color(0xFF9A8562);
      canvas.drawRect(r(-8 + rng.nextInt(112), -20 + rng.nextInt(84), 1, 1), p);
    }
    // 床
    for (var i = 0; i < 14; i++) {
      p.color = i.isEven ? const Color(0xFF8A5F33) : const Color(0xFF7C5329);
      canvas.drawRect(r(-8, 64 + i * 8, 112, 8), p);
      p.color = const Color(0xFF64431F);
      canvas.drawRect(r(-8, 64 + i * 8, 112, 0.8), p);
      for (var j = 0; j < 3; j++) {
        canvas.drawRect(
            r(-8 + ((i * 37 + j * 41) % 110), 64 + i * 8 + 2, 0.8, 4), p);
      }
    }
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(-8, 62, 112, 2.4), p);

    // 窓(夜空)
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(14, 2, 34, 30), p);
    p.color = const Color(0xFF16244E);
    canvas.drawRect(r(16, 4, 30, 26), p);
    p.color = Colors.white;
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(r(17 + rng.nextInt(27), 5 + rng.nextInt(12), 1, 1), p);
    }
    p.color = const Color(0xFFF2D96B);
    canvas.drawCircle(Offset(ox + 27 * u, oy + 11 * u), 4.2 * u, p);
    p.color = const Color(0xFF16244E);
    canvas.drawCircle(Offset(ox + 29 * u, oy + 9.6 * u), 3.6 * u, p);
    p.color = const Color(0xFF1E4A32);
    canvas.drawOval(r(16, 22, 12, 9), p);
    canvas.drawOval(r(30, 24, 16, 8), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawRect(r(30.4, 4, 1.4, 26), p);
    canvas.drawRect(r(16, 16, 30, 1.4), p);
    // カーテン
    for (final cx in [10.0, 46.0]) {
      p.color = const Color(0xFFF2B7C6);
      canvas.drawRect(r(cx, 1, 6, 34), p);
      p.color = const Color(0xFFE898AF);
      canvas.drawRect(r(cx + 1.6, 1, 1.4, 34), p);
      canvas.drawRect(r(cx + 4.2, 1, 1.2, 34), p);
      canvas.drawRect(r(cx - 0.6, 20, 7.2, 3), p);
    }
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(8, 0, 46, 1.6), p);

    // 本棚(右)
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(66, -2, 28, 74), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawRect(r(67.4, -0.5, 25.2, 71), p);
    for (var shelf = 0; shelf < 3; shelf++) {
      final sy = 6 + shelf * 22;
      p.color = const Color(0xFF54371A);
      canvas.drawRect(r(68, sy, 24, 16), p);
      p.color = const Color(0xFF6E4A22);
      canvas.drawRect(r(67.4, sy + 16, 25.2, 2.4), p);
      var bx = 69.0;
      final colors = [
        const Color(0xFFB84C5C),
        const Color(0xFF4C7AB8),
        const Color(0xFF54A05A),
        const Color(0xFF8A5CA8),
        const Color(0xFFD8A44C),
      ];
      var k = shelf * 3;
      while (bx < 90) {
        if ((k + shelf).isEven || shelf == 0) {
          final bw = 2.2 + (k % 3) * 0.8;
          p.color = colors[k % colors.length];
          canvas.drawRect(r(bx, sy + 4 - (k % 2), bw, 12 + (k % 2)), p);
          p.color = Colors.white24;
          canvas.drawRect(r(bx + 0.4, sy + 5, bw - 0.8, 1), p);
          bx += bw + 0.8;
        } else {
          p.color = const Color(0xFF4C7AB8);
          canvas.drawRect(r(bx, sy + 10, 5, 6), p);
          p.color = const Color(0xFF54A05A);
          canvas.drawRect(r(bx + 1, sy + 5, 3, 5), p);
          bx += 7;
        }
        k++;
      }
    }

    // ベッド
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(18, 40, 40, 20), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawRect(r(19.4, 41.4, 37.2, 17), p);
    p.color = const Color(0xFFB07B3E);
    canvas.drawRect(r(19.4, 41.4, 37.2, 3), p);
    for (final px in [17.0, 56.5]) {
      p.color = const Color(0xFF6E4A22);
      canvas.drawRect(r(px, 38, 2.6, 24), p);
      canvas.drawCircle(Offset(ox + (px + 1.3) * u, oy + 37.5 * u), 2.2 * u, p);
    }
    p.color = const Color(0xFFE9E4EF);
    canvas.drawRect(r(18, 58, 40, 26), p);
    p.color = Colors.white;
    canvas.drawRRect(
        RRect.fromRectAndRadius(r(21, 55, 20, 10), Radius.circular(3 * u)), p);
    // 布団(ギンガム)
    for (var cy = 0; cy < 7; cy++) {
      for (var cx = 0; cx < 10; cx++) {
        p.color = ((cx + cy) % 2 == 0)
            ? const Color(0xFFF0A8BC)
            : const Color(0xFFF7CBD6);
        canvas.drawRect(r(18 + cx * 4, 84 + cy * 4, 4, 4), p);
      }
    }
    p.color = const Color(0xFFE898AF);
    canvas.drawRect(r(18, 84, 40, 2), p);
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(17, 112, 42, 4), p);

    // ── 主人公 ──
    if (mode == 0) {
      // 就寝
      p.color = const Color(0xFF6E4423);
      canvas.drawOval(r(24, 52, 16, 12), p);
      canvas.drawOval(r(22, 57, 8, 8), p);
      canvas.drawOval(r(35, 57, 7, 8), p);
      p.color = _skin;
      canvas.drawOval(r(27, 55.5, 10, 8.5), p);
      p.color = const Color(0xFF7A4A22);
      canvas.drawOval(r(26.4, 53.4, 11, 4.6), p);
      p.color = _eye;
      canvas.drawRect(r(29, 60, 2.2, 0.9), p);
      canvas.drawRect(r(33, 60, 2.2, 0.9), p);
      p.color = _blush;
      canvas.drawRect(r(28, 61.4, 1.8, 1.2), p);
      canvas.drawRect(r(34.2, 61.4, 1.8, 1.2), p);
      p.color = const Color(0xFF6FB3E8);
      canvas.drawRect(r(40, 80, 7, 4), p);
      p.color = _skin;
      canvas.drawRect(r(46, 80.6, 3, 2.8), p);
    } else {
      // 目覚めて上体を起こす
      p.color = const Color(0xFF6FB3E8); // パジャマ
      canvas.drawRect(r(28, 66, 20, 18), p);
      p.color = const Color(0xFF5A9FD4);
      canvas.drawRect(r(37.4, 66, 1.2, 18), p);
      // 腕(ほおに手)
      canvas.drawRect(r(45, 70, 4, 10), p);
      p.color = _skin;
      canvas.drawRect(r(45.4, 66.5, 3.2, 4), p);
      // 顔
      p.color = const Color(0xFF7A4A22);
      canvas.drawOval(r(27, 46, 22, 20), p);
      p.color = _skin;
      canvas.drawOval(r(30, 51, 16, 13), p);
      p.color = const Color(0xFF7A4A22);
      canvas.drawOval(r(29, 47, 18, 7), p);
      p.color = _eye;
      canvas.drawOval(r(33, 55, 2.6, 3), p);
      canvas.drawOval(r(40, 55, 2.6, 3), p);
      p.color = _blush;
      canvas.drawRect(r(31.6, 58.6, 2, 1.4), p);
      canvas.drawRect(r(42, 58.6, 2, 1.4), p);
      p.color = const Color(0xFFB3583F);
      canvas.drawOval(r(36.6, 59.6, 2.6, 2), p); // 「？」の口
      // はてなの吹き出し飾り
      p.color = Colors.white;
      canvas.drawCircle(Offset(ox + 53 * u, oy + 46 * u), 3.4 * u, p);
      canvas.drawCircle(Offset(ox + 50 * u, oy + 51 * u), 1.6 * u, p);
      p.color = const Color(0xFF3A2C1A);
      canvas.drawRect(r(52, 43.6, 2, 3), p);
      canvas.drawRect(r(52.4, 47.4, 1.2, 1.2), p);
    }

    // ナイトスタンド + ランプ
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(r(60, 66, 13, 18), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawRect(r(60.8, 66.8, 11.4, 16.4), p);
    p.color = const Color(0x33FFD98A);
    canvas.drawCircle(Offset(ox + 66.5 * u, oy + 58 * u), 12 * u, p);
    p.color = const Color(0xFFB07B3E);
    canvas.drawRect(r(65.6, 60, 1.8, 6), p);
    final shade = Path()
      ..moveTo(ox + 61.5 * u, oy + 60 * u)
      ..lineTo(ox + 71.5 * u, oy + 60 * u)
      ..lineTo(ox + 69.5 * u, oy + 53 * u)
      ..lineTo(ox + 63.5 * u, oy + 53 * u)
      ..close();
    p.color = const Color(0xFFE898AF);
    canvas.drawPath(shade, p);

    // ラグ・鉢植え
    p.color = const Color(0xFFD87A8C);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r(4, 128, 26, 14), Radius.circular(2 * u)), p);
    p.color = const Color(0xFFE8E4DC);
    canvas.drawRect(r(74, 128, 9, 8), p);
    p.color = const Color(0xFF3B9A31);
    canvas.drawRect(r(77.6, 121, 2, 7), p);
    for (final (dx, dy) in const [(-3.2, -1.0), (2.6, -1.4), (-1.4, -4.0)]) {
      canvas.drawOval(r(77.6 + dx, 122 + dy, 3.4, 2.2), p);
    }

    // 夜のトーン
    p.color = const Color(0x1A16244E);
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(covariant _BedroomPainter old) => old.mode != mode;
}

// ─────────────────────────────────────────────────────────────
// 光に吸い込まれる(暗い部屋 + 金色の放射光 + 後ろ姿)。
// ─────────────────────────────────────────────────────────────
class _LightBurstPainter extends CustomPainter {
  const _LightBurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final rng = math.Random(21);
    p.color = const Color(0xFF241B12);
    canvas.drawRect(Offset.zero & size, p);
    // うっすら床板
    for (var i = 0; i < 12; i++) {
      p.color = i.isEven ? const Color(0xFF2E2216) : const Color(0xFF291E13);
      canvas.drawRect(
          Rect.fromLTWH(0, size.height * (0.4 + i * 0.05), size.width,
              size.height * 0.05),
          p);
    }
    final c = Offset(size.width / 2, size.height * 0.44);
    // 放射光
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18 + 0.08;
      final len = size.height * (0.5 + rng.nextDouble() * 0.25);
      final w = 0.02 + rng.nextDouble() * 0.05;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - w) * len, c.dy + math.sin(a - w) * len)
        ..lineTo(c.dx + math.cos(a + w) * len, c.dy + math.sin(a + w) * len)
        ..close();
      p.color = i % 3 == 0
          ? const Color(0x66F7D774)
          : (i % 3 == 1 ? const Color(0x44F2C14E) : const Color(0x33E8A83C));
      canvas.drawPath(path, p);
    }
    // 中心のまばゆい玉
    p.color = const Color(0xFFFFF3C9);
    canvas.drawCircle(c, size.width * 0.16, p);
    p.color = const Color(0xCCF7D774);
    canvas.drawCircle(c, size.width * 0.24, p..style = PaintingStyle.stroke..strokeWidth = size.width * 0.02);
    p.style = PaintingStyle.fill;
    // きらめき(+字)
    for (var i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final s = 2.0 + rng.nextDouble() * 4;
      p.color = rng.nextBool()
          ? const Color(0xFFF7E9AE)
          : const Color(0xAAF2C14E);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: s, height: s / 3), p);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: s / 3, height: s), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 島の全景(海 + 山 + 家々 + 灯台)。withHeroine で手前の崖と後ろ姿。
// ─────────────────────────────────────────────────────────────
class _IslandOverviewPainter extends CustomPainter {
  const _IslandOverviewPainter({required this.withHeroine});
  final bool withHeroine;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final rng = math.Random(3);
    final w = size.width, h = size.height;

    // 空
    p.color = const Color(0xFF5EA9E8);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.22), p);
    p.color = Colors.white;
    for (var i = 0; i < 5; i++) {
      final x = rng.nextDouble() * w;
      final y = 10 + rng.nextDouble() * h * 0.12;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: 70, height: 18),
              const Radius.circular(9)),
          p);
    }
    // 海(市松)
    final seaTop = h * 0.2;
    const cell = 26.0;
    for (var y = 0; y * cell < h - seaTop; y++) {
      for (var x = 0; x * cell < w; x++) {
        p.color = (x + y).isEven
            ? const Color(0xFF2E6FB0)
            : const Color(0xFF2A66A3);
        canvas.drawRect(
            Rect.fromLTWH(x * cell, seaTop + y * cell, cell + 0.5, cell + 0.5),
            p);
      }
    }
    p.color = const Color(0xFF7FB9E0);
    for (var i = 0; i < 30; i++) {
      canvas.drawRect(
          Rect.fromLTWH(rng.nextDouble() * w,
              seaTop + rng.nextDouble() * (h - seaTop), 12, 3),
          p);
    }

    // 島(中央): 砂の縁 → 緑 → 山
    final island = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.55, h * 0.52), width: w * 0.78, height: h * 0.5));
    p.color = const Color(0xFFD9C488);
    canvas.drawPath(island, p);
    final green = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.55, h * 0.515), width: w * 0.72, height: h * 0.45));
    p.color = const Color(0xFF63AC46);
    canvas.drawPath(green, p);
    canvas.save();
    canvas.clipPath(green);
    // 緑のむら
    for (var i = 0; i < 180; i++) {
      p.color = rng.nextBool()
          ? const Color(0xFF57993D)
          : const Color(0xFF74BD55);
      canvas.drawRect(
          Rect.fromLTWH(w * 0.15 + rng.nextDouble() * w * 0.8,
              h * 0.28 + rng.nextDouble() * h * 0.48, 6, 6),
          p);
    }
    // 道
    p.color = const Color(0xFFD8C08A);
    final road = Path()
      ..moveTo(w * 0.55, h * 0.72)
      ..quadraticBezierTo(w * 0.5, h * 0.6, w * 0.55, h * 0.5)
      ..quadraticBezierTo(w * 0.6, h * 0.42, w * 0.56, h * 0.34);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFD8C08A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);
    // 家々
    void house(double hx, double hy, Color roof) {
      p.color = const Color(0xFFF2E6C8);
      canvas.drawRect(Rect.fromLTWH(hx, hy + 8, 22, 12), p);
      p.color = roof;
      final rp = Path()
        ..moveTo(hx - 3, hy + 9)
        ..lineTo(hx + 11, hy - 2)
        ..lineTo(hx + 25, hy + 9)
        ..close();
      canvas.drawPath(rp, p);
      p.color = const Color(0xFF6E4A22);
      canvas.drawRect(Rect.fromLTWH(hx + 8, hy + 13, 5, 7), p);
    }

    house(w * 0.36, h * 0.46, const Color(0xFFC85C4E));
    house(w * 0.62, h * 0.4, const Color(0xFF4C7AB8));
    house(w * 0.66, h * 0.55, const Color(0xFF54A05A));
    house(w * 0.44, h * 0.6, const Color(0xFF8A5CA8));
    house(w * 0.3, h * 0.56, const Color(0xFFD8A44C));
    // 木
    for (var i = 0; i < 14; i++) {
      final tx = w * (0.22 + rng.nextDouble() * 0.62);
      final ty = h * (0.32 + rng.nextDouble() * 0.4);
      p.color = const Color(0xFF2E7D32);
      canvas.drawOval(Rect.fromCenter(center: Offset(tx, ty), width: 16, height: 14), p);
      p.color = const Color(0xFF43A047);
      canvas.drawOval(Rect.fromCenter(center: Offset(tx - 3, ty - 3), width: 6, height: 4), p);
    }
    canvas.restore();

    // 山 + 滝
    final mtn = Path()
      ..moveTo(w * 0.4, h * 0.36)
      ..lineTo(w * 0.55, h * 0.16)
      ..lineTo(w * 0.7, h * 0.36)
      ..close();
    p.color = const Color(0xFF6E8F5A);
    canvas.drawPath(mtn, p);
    p.color = const Color(0xFF57764A);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.55, h * 0.16)
          ..lineTo(w * 0.7, h * 0.36)
          ..lineTo(w * 0.55, h * 0.36)
          ..close(),
        p);
    p.color = Colors.white;
    final peak = Path()
      ..moveTo(w * 0.51, h * 0.215)
      ..lineTo(w * 0.55, h * 0.16)
      ..lineTo(w * 0.59, h * 0.215)
      ..lineTo(w * 0.565, h * 0.23)
      ..lineTo(w * 0.54, h * 0.22)
      ..close();
    canvas.drawPath(peak, p);
    p.color = const Color(0xFF9CD4F0);
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.27, 6, h * 0.1), p);

    // 灯台(右)
    p.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(w * 0.86, h * 0.4, 12, 26), p);
    p.color = const Color(0xFFC85C4E);
    canvas.drawRect(Rect.fromLTWH(w * 0.855, h * 0.38, 13.5, 6), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.86, h * 0.46, 12, 4), p);

    // 手前の崖 + 主人公は上物ウィジェットではなくここで描く
    if (withHeroine) {
      p.color = const Color(0xFF7C5B36);
      final cliff = Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.68)
        ..quadraticBezierTo(w * 0.16, h * 0.64, w * 0.3, h * 0.74)
        ..quadraticBezierTo(w * 0.34, h * 0.84, w * 0.26, h)
        ..close();
      canvas.drawPath(cliff, p);
      p.color = const Color(0xFF63AC46);
      final grass = Path()
        ..moveTo(0, h * 0.74)
        ..lineTo(0, h * 0.68)
        ..quadraticBezierTo(w * 0.16, h * 0.64, w * 0.3, h * 0.74)
        ..lineTo(w * 0.28, h * 0.78)
        ..quadraticBezierTo(w * 0.14, h * 0.7, 0, h * 0.74)
        ..close();
      canvas.drawPath(grass, p);
      // 花
      for (var i = 0; i < 6; i++) {
        final fx = w * (0.02 + rng.nextDouble() * 0.24);
        final fy = h * (0.7 + rng.nextDouble() * 0.05);
        p.color = [
          Colors.white,
          const Color(0xFFF2A5C0),
          const Color(0xFFF6D96B)
        ][i % 3];
        canvas.drawCircle(Offset(fx, fy), 3, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslandOverviewPainter old) =>
      old.withHeroine != withHeroine;
}

// ─────────────────────────────────────────────────────────────
// 島の看板(木の大看板 + つた + ヤシ)。文字はウィジェットで重ねる。
// ─────────────────────────────────────────────────────────────
class _SignboardPainter extends CustomPainter {
  const _SignboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final rng = math.Random(7);
    final w = size.width, h = size.height;

    // 空と茂みの背景
    p.color = const Color(0xFF5EA9E8);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.4), p);
    p.color = Colors.white;
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(rng.nextDouble() * w, 20 + rng.nextDouble() * h * 0.2),
                  width: 70,
                  height: 18),
              const Radius.circular(9)),
          p);
    }
    p.color = const Color(0xFF3E8A34);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.38, w, h * 0.62), p);
    for (var i = 0; i < 260; i++) {
      p.color = rng.nextBool()
          ? const Color(0xFF347628)
          : const Color(0xFF4B9C3E);
      canvas.drawRect(
          Rect.fromLTWH(rng.nextDouble() * w, h * 0.38 + rng.nextDouble() * h * 0.62, 6, 6),
          p);
    }
    // 道
    p.color = const Color(0xFFCDB388);
    final road = Path()
      ..moveTo(w * 0.42, h)
      ..lineTo(w * 0.58, h)
      ..lineTo(w * 0.54, h * 0.72)
      ..lineTo(w * 0.46, h * 0.72)
      ..close();
    canvas.drawPath(road, p);

    // ヤシの木(左右)
    void palm(double px, double py, double s) {
      p.color = const Color(0xFF8A5F33);
      canvas.drawRect(Rect.fromLTWH(px - 3 * s, py - 40 * s, 6 * s, 40 * s), p);
      p.color = const Color(0xFF2E8226);
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.55;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(px + math.cos(a) * 16 * s,
                    py - 40 * s + math.sin(a) * 10 * s),
                width: 30 * s,
                height: 9 * s),
            p);
      }
    }

    palm(w * 0.09, h * 0.62, 1.2);
    palm(w * 0.91, h * 0.66, 1.4);

    // 大きな木の看板(支柱2本 + 板 + つた + 花)
    final board = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.42), width: w * 0.66, height: h * 0.3);
    p.color = const Color(0xFF5A3A1E);
    canvas.drawRect(Rect.fromLTWH(board.left + board.width * 0.16, board.bottom,
        w * 0.035, h * 0.28), p);
    canvas.drawRect(Rect.fromLTWH(board.right - board.width * 0.2, board.bottom,
        w * 0.035, h * 0.28), p);
    p.color = const Color(0xFF6E4A22);
    canvas.drawRRect(
        RRect.fromRectAndRadius(board.inflate(6), const Radius.circular(10)), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawRRect(
        RRect.fromRectAndRadius(board, const Radius.circular(8)), p);
    // 板目
    p.color = const Color(0xFF875A2B);
    for (var i = 1; i < 4; i++) {
      canvas.drawRect(Rect.fromLTWH(board.left, board.top + i * board.height / 4,
          board.width, 2), p);
    }
    // つた(縁を這う)
    p.color = const Color(0xFF3B9A31);
    for (var i = 0; i < 26; i++) {
      final t = i / 26 * math.pi * 2;
      final ex = board.center.dx + math.cos(t) * (board.width / 2 + 4);
      final ey = board.center.dy + math.sin(t) * (board.height / 2 + 4);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, ey), width: 12, height: 8), p);
    }
    p.color = const Color(0xFF54B848);
    for (var i = 0; i < 12; i++) {
      final t = i / 12 * math.pi * 2 + 0.2;
      final ex = board.center.dx + math.cos(t) * (board.width / 2 + 2);
      final ey = board.center.dy + math.sin(t) * (board.height / 2 + 2);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, ey), width: 7, height: 5), p);
    }
    // 花
    for (var i = 0; i < 8; i++) {
      final t = i / 8 * math.pi * 2 + 0.4;
      final ex = board.center.dx + math.cos(t) * (board.width / 2 + 6);
      final ey = board.center.dy + math.sin(t) * (board.height / 2 + 6);
      p.color = i.isEven ? const Color(0xFFF2A5C0) : Colors.white;
      canvas.drawCircle(Offset(ex, ey), 3.4, p);
    }
    // 下草と花
    for (var i = 0; i < 14; i++) {
      final fx = rng.nextDouble() * w;
      final fy = h * (0.8 + rng.nextDouble() * 0.18);
      p.color = [
        Colors.white,
        const Color(0xFFF2A5C0),
        const Color(0xFFF6D96B)
      ][i % 3];
      canvas.drawCircle(Offset(fx, fy), 3, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 村の道(奥へ続く道 + 家々)。主人公の後ろ姿はウィジェット側で重ねる。
// ─────────────────────────────────────────────────────────────
class _VillagePathPainter extends CustomPainter {
  const _VillagePathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final rng = math.Random(11);
    final w = size.width, h = size.height;

    p.color = const Color(0xFF5EA9E8);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.34), p);
    p.color = Colors.white;
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center:
                      Offset(rng.nextDouble() * w, 16 + rng.nextDouble() * h * 0.16),
                  width: 66,
                  height: 16),
              const Radius.circular(8)),
          p);
    }
    // 遠くの山なみ
    p.color = const Color(0xFF7FA8C9);
    canvas.drawOval(Rect.fromLTWH(-w * 0.2, h * 0.24, w * 0.8, h * 0.16), p);
    canvas.drawOval(Rect.fromLTWH(w * 0.4, h * 0.26, w * 0.9, h * 0.14), p);

    // 草地
    p.color = const Color(0xFF6DB84E);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.34, w, h * 0.66), p);
    for (var i = 0; i < 300; i++) {
      p.color = rng.nextBool()
          ? const Color(0xFF5FA843)
          : const Color(0xFF7EC55E);
      canvas.drawRect(
          Rect.fromLTWH(rng.nextDouble() * w, h * 0.34 + rng.nextDouble() * h * 0.66,
              6, 6),
          p);
    }
    // 奥へ続く道
    p.color = const Color(0xFFCDB388);
    final road = Path()
      ..moveTo(w * 0.3, h)
      ..lineTo(w * 0.7, h)
      ..lineTo(w * 0.56, h * 0.36)
      ..lineTo(w * 0.44, h * 0.36)
      ..close();
    canvas.drawPath(road, p);
    p.color = const Color(0xFFBBA073);
    for (var i = 0; i < 20; i++) {
      final t = rng.nextDouble();
      final rw = w * (0.06 + 0.2 * t);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(w * 0.5 + (rng.nextDouble() - 0.5) * rw * 2,
                  h * (0.38 + t * 0.6)),
              width: 8,
              height: 4),
          p);
    }
    // 柵
    p.color = const Color(0xFF9C6B35);
    for (final fy in [h * 0.55, h * 0.72]) {
      canvas.drawRect(Rect.fromLTWH(0, fy, w * 0.32, 4), p);
      canvas.drawRect(Rect.fromLTWH(w * 0.68, fy, w * 0.32, 4), p);
      for (var i = 0; i < 5; i++) {
        canvas.drawRect(Rect.fromLTWH(w * 0.03 + i * w * 0.07, fy - 6, 4, 16), p);
        canvas.drawRect(Rect.fromLTWH(w * 0.7 + i * w * 0.07, fy - 6, 4, 16), p);
      }
    }
    // 家々(左右)
    void house(double hx, double hy, double s, Color roof) {
      p.color = const Color(0xFFF2E6C8);
      canvas.drawRect(Rect.fromLTWH(hx, hy, 60 * s, 40 * s), p);
      p.color = const Color(0xFFD8CBA8);
      canvas.drawRect(Rect.fromLTWH(hx, hy + 34 * s, 60 * s, 6 * s), p);
      p.color = roof;
      final rp = Path()
        ..moveTo(hx - 8 * s, hy + 2 * s)
        ..lineTo(hx + 30 * s, hy - 22 * s)
        ..lineTo(hx + 68 * s, hy + 2 * s)
        ..close();
      canvas.drawPath(rp, p);
      p.color = const Color(0xFF6E4A22);
      canvas.drawRect(Rect.fromLTWH(hx + 24 * s, hy + 16 * s, 14 * s, 24 * s), p);
      p.color = const Color(0xFFBDE3F8);
      canvas.drawRect(Rect.fromLTWH(hx + 6 * s, hy + 10 * s, 12 * s, 10 * s), p);
      canvas.drawRect(Rect.fromLTWH(hx + 44 * s, hy + 10 * s, 12 * s, 10 * s), p);
    }

    house(w * 0.02, h * 0.4, 1.0, const Color(0xFF4C7AB8));
    house(w * 0.72, h * 0.42, 0.9, const Color(0xFFC85C4E));
    house(w * 0.16, h * 0.35, 0.55, const Color(0xFFD8A44C));
    house(w * 0.62, h * 0.35, 0.5, const Color(0xFF54A05A));
    // 花
    for (var i = 0; i < 16; i++) {
      final fx = rng.nextDouble() * w;
      final fy = h * (0.5 + rng.nextDouble() * 0.45);
      if (fx > w * 0.3 && fx < w * 0.7) continue;
      p.color = [
        Colors.white,
        const Color(0xFFF2A5C0),
        const Color(0xFFF6D96B)
      ][i % 3];
      canvas.drawCircle(Offset(fx, fy), 3, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// パン屋の店先(レンガ + ひさし + 看板 + パンの陳列)。dim=ミッション用に暗く。
// ─────────────────────────────────────────────────────────────
class _BakeryPainter extends CustomPainter {
  const _BakeryPainter({required this.dim});
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final rng = math.Random(13);
    final w = size.width, h = size.height;

    // 空と遠景の緑
    p.color = const Color(0xFF5EA9E8);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.3), p);
    p.color = Colors.white;
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center:
                      Offset(rng.nextDouble() * w, 14 + rng.nextDouble() * h * 0.14),
                  width: 64,
                  height: 16),
              const Radius.circular(8)),
          p);
    }
    p.color = const Color(0xFF4B9C3E);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.28, w, h * 0.2), p);
    // 地面(土)
    p.color = const Color(0xFFC9AE7E);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.46, w, h * 0.54), p);
    for (var i = 0; i < 160; i++) {
      p.color = rng.nextBool()
          ? const Color(0xFFBBA073)
          : const Color(0xFFD8C08A);
      canvas.drawRect(
          Rect.fromLTWH(rng.nextDouble() * w, h * 0.46 + rng.nextDouble() * h * 0.54,
              6, 6),
          p);
    }

    // 店舗(左 2/3)
    final shop = Rect.fromLTWH(-w * 0.05, h * 0.16, w * 0.72, h * 0.36);
    // レンガ壁
    p.color = const Color(0xFFEADFC2);
    canvas.drawRect(shop, p);
    p.color = const Color(0xFFD9C9A2);
    final bh = shop.height / 9;
    for (var r0 = 0; r0 < 9; r0++) {
      final by = shop.top + r0 * bh;
      canvas.drawRect(Rect.fromLTWH(shop.left, by + bh - 2, shop.width, 2), p);
      final off = r0.isEven ? 0.0 : bh * 1.5;
      for (var bx = shop.left + off; bx < shop.right; bx += bh * 3) {
        canvas.drawRect(Rect.fromLTWH(bx, by, 2, bh), p);
      }
    }
    // 屋根(赤瓦)
    for (var r0 = 0; r0 < 3; r0++) {
      p.color = r0.isEven ? const Color(0xFFC85C4E) : const Color(0xFFB84C40);
      canvas.drawRect(Rect.fromLTWH(shop.left - 10, shop.top - 26 + r0 * 9,
          shop.width + 20, 9), p);
      p.color = const Color(0xFF9C3E34);
      for (var sx = shop.left - 10 + (r0.isEven ? 0 : 12); sx < shop.right + 10; sx += 24) {
        canvas.drawRect(Rect.fromLTWH(sx, shop.top - 26 + r0 * 9, 2, 9), p);
      }
    }
    // 「パン屋」看板(文字はウィジェット)
    p.color = const Color(0xFF6E4A22);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(shop.left + shop.width * 0.18, shop.top - 16,
                shop.width * 0.5, 30),
            const Radius.circular(6)),
        p);
    p.color = const Color(0xFFEDD9A5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(shop.left + shop.width * 0.2, shop.top - 13,
                shop.width * 0.46, 24),
            const Radius.circular(4)),
        p);
    // ひさし(赤白ストライプ)
    final aw = Rect.fromLTWH(shop.left, shop.top + shop.height * 0.28,
        shop.width, h * 0.05);
    for (var i = 0; i < 10; i++) {
      p.color = i.isEven ? const Color(0xFFC85C4E) : Colors.white;
      canvas.drawRect(Rect.fromLTWH(aw.left + i * aw.width / 10, aw.top,
          aw.width / 10, aw.height), p);
    }
    p.color = const Color(0x30000000);
    canvas.drawRect(Rect.fromLTWH(aw.left, aw.bottom, aw.width, 5), p);
    // ショーウィンドウ(パンの陳列)
    final win = Rect.fromLTWH(shop.left + shop.width * 0.08,
        shop.top + shop.height * 0.42, shop.width * 0.5, shop.height * 0.4);
    p.color = const Color(0xFF54371A);
    canvas.drawRect(win.inflate(4), p);
    p.color = const Color(0xFF7C5B36);
    canvas.drawRect(win, p);
    for (var row = 0; row < 2; row++) {
      p.color = const Color(0xFF54371A);
      canvas.drawRect(Rect.fromLTWH(win.left, win.top + (row + 1) * win.height / 2 - 3,
          win.width, 3), p);
      for (var i = 0; i < 4; i++) {
        p.color = const Color(0xFFD8A055);
        canvas.drawOval(Rect.fromLTWH(win.left + 6 + i * win.width / 4,
            win.top + 6 + row * win.height / 2, win.width / 5.4, win.height / 4), p);
        p.color = const Color(0xFFF2CB8E);
        canvas.drawRect(Rect.fromLTWH(win.left + 10 + i * win.width / 4,
            win.top + 9 + row * win.height / 2, win.width / 9, 3), p);
      }
    }
    // ドア(緑)
    final door = Rect.fromLTWH(shop.left + shop.width * 0.66,
        shop.top + shop.height * 0.4, shop.width * 0.16, shop.height * 0.6);
    p.color = const Color(0xFF3E6B44);
    canvas.drawRRect(
        RRect.fromRectAndCorners(door,
            topLeft: const Radius.circular(10), topRight: const Radius.circular(10)),
        p);
    p.color = const Color(0xFF2E5234);
    canvas.drawRect(Rect.fromLTWH(door.left + door.width / 2 - 1, door.top + 8, 2,
        door.height - 8), p);
    p.color = const Color(0xFFE8C46B);
    canvas.drawCircle(Offset(door.left + door.width * 0.78, door.center.dy), 3, p);
    // 黒板(焼きたてパン)
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(Rect.fromLTWH(shop.left + 6, shop.bottom + 8, w * 0.13, h * 0.12), p);
    p.color = const Color(0xFF2E3230);
    canvas.drawRect(
        Rect.fromLTWH(shop.left + 10, shop.bottom + 12, w * 0.13 - 8, h * 0.12 - 8), p);
    p.color = Colors.white70;
    canvas.drawRect(Rect.fromLTWH(shop.left + 14, shop.bottom + 18, w * 0.08, 2), p);
    canvas.drawRect(Rect.fromLTWH(shop.left + 14, shop.bottom + 26, w * 0.06, 2), p);
    p.color = const Color(0xFFD8A055);
    canvas.drawOval(Rect.fromLTWH(shop.left + 16, shop.bottom + 32, 18, 10), p);
    // ランプ
    p.color = const Color(0xFF3A3A3A);
    canvas.drawRect(Rect.fromLTWH(shop.left + shop.width * 0.06, shop.top + 6, 3, 14), p);
    p.color = const Color(0xFFF2D96B);
    canvas.drawRect(Rect.fromLTWH(shop.left + shop.width * 0.06 - 3, shop.top + 18, 9, 10), p);

    // 右奥: 遠くの島の丘
    p.color = const Color(0xFF63AC46);
    canvas.drawOval(Rect.fromLTWH(w * 0.7, h * 0.24, w * 0.4, h * 0.22), p);
    p.color = const Color(0xFF57993D);
    for (var i = 0; i < 30; i++) {
      canvas.drawRect(
          Rect.fromLTWH(w * 0.72 + rng.nextDouble() * w * 0.26,
              h * 0.26 + rng.nextDouble() * h * 0.16, 5, 5),
          p);
    }

    if (dim) {
      p.color = const Color(0x66101C3A);
      canvas.drawRect(Offset.zero & size, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BakeryPainter old) => old.dim != dim;
}

// ─────────────────────────────────────────────────────────────
// キャラクター付きシーン(島の全景を背景にスプライトを大きく)。
// pose 0=みぽりん(にっこり) 1=みぽりん(指さし) 2=主人公(考え中)
// ─────────────────────────────────────────────────────────────
class _CharacterScene extends StatelessWidget {
  const _CharacterScene({required this.pose});
  final int pose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, c) {
        final spriteW = math.min(c.maxWidth * 0.42, 230.0);
        return Stack(children: [
          const Positioned.fill(
            child: CustomPaint(
                painter: _IslandOverviewPainter(withHeroine: false)),
          ),
          Positioned(
            right: pose == 2 ? null : c.maxWidth * 0.03,
            left: pose == 2 ? c.maxWidth * 0.05 : null,
            bottom: 0,
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

// ─────────────────────────────────────────────────────────────
// スマホ画面(招待状)。部屋の机の上のスマホをコードで描く。
// ─────────────────────────────────────────────────────────────
class _PhoneScene extends StatelessWidget {
  const _PhoneScene();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF8A6A3F),
        child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _DeskPainter())),
          Center(
            child: AspectRatio(
              aspectRatio: 0.52,
              child: FractionallySizedBox(
                heightFactor: 0.86,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF23262B),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFF101215), width: 5),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8ECF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('実践デザイナー島\n招待状',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 22,
                                  height: 1.3,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF23262B))),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: const SizedBox(
                              height: 130,
                              width: double.infinity,
                              child: CustomPaint(
                                  painter:
                                      _IslandOverviewPainter(withHeroine: false)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('あなたを、\n実践デザイナー島へ\nご招待します。',
                              style: TextStyle(
                                  fontSize: 17,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF23262B))),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E5AC8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF0D2F73), width: 2.5),
                            ),
                            child: const Center(
                              child: Text('くわしく見る',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DeskPainter extends CustomPainter {
  const _DeskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final rng = math.Random(31);
    // 木目の机
    for (var i = 0; i < 10; i++) {
      p.color = i.isEven ? const Color(0xFF9C7040) : const Color(0xFF8F6438);
      canvas.drawRect(
          Rect.fromLTWH(0, i * size.height / 10, size.width, size.height / 10 + 1),
          p);
      p.color = const Color(0xFF7A5530);
      canvas.drawRect(
          Rect.fromLTWH(0, i * size.height / 10, size.width, 2), p);
      for (var j = 0; j < 3; j++) {
        canvas.drawRect(
            Rect.fromLTWH(rng.nextDouble() * size.width,
                i * size.height / 10 + rng.nextDouble() * size.height / 10, 14, 2),
            p);
      }
    }
    // コーヒーと観葉植物(隅の小物)
    p.color = const Color(0xFFE8E4DC);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.12), 26, p);
    p.color = const Color(0xFF5A3A1E);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.12), 18, p);
    p.color = const Color(0xFFB56A4A);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.86, size.height * 0.04, 44, 30), p);
    p.color = const Color(0xFF3B9A31);
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
          Rect.fromLTWH(size.width * 0.86 + i * 8, size.height * 0.02 - i % 2 * 8,
              16, 10),
          p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
