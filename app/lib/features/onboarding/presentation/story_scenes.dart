import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 第1話の各シーンをコード描画(細かいドット仕様)するPainter群。
/// すべての図形を「仮想ピクセルグリッド」にラスタライズして描く:
///  ・楕円/三角も1ドット単位の段々(row-scan)
///  ・面には2〜3色のノイズ(むら)
///  ・スプライトは自動アウトライン付き
/// story.json の "scene" 名 → 背景ウィジェットを返す。
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
// AAP-64 固定64色パレット(Adigun A. Polack)。
// シーン描画とスプライトの色はすべて最近傍のAAP-64色に量子化する。
// 64色あるため、PICO-8のような色相ルールは不要で最近傍探索がきれいに決まる。
// ─────────────────────────────────────────────────────────────
const kAap64 = <Color>[
  Color(0xFF060608), Color(0xFF141013), Color(0xFF3B1725), Color(0xFF73172D),
  Color(0xFFB4202A), Color(0xFFDF3E23), Color(0xFFFA6A0A), Color(0xFFF9A31B),
  Color(0xFFFFD541), Color(0xFFFFFC40), Color(0xFFD6F264), Color(0xFF9CDB43),
  Color(0xFF59C135), Color(0xFF14A02E), Color(0xFF1A7A3E), Color(0xFF24523B),
  Color(0xFF122020), Color(0xFF143464), Color(0xFF285CC4), Color(0xFF249FDE),
  Color(0xFF20D6C7), Color(0xFFA6FCDB), Color(0xFFFFFFFF), Color(0xFFFEF3C0),
  Color(0xFFFAD6B8), Color(0xFFF5A097), Color(0xFFE86A73), Color(0xFFBC4A9B),
  Color(0xFF793A80), Color(0xFF403353), Color(0xFF242234), Color(0xFF221C1A),
  Color(0xFF322B28), Color(0xFF71413B), Color(0xFFBB7547), Color(0xFFDBA463),
  Color(0xFFF4D29C), Color(0xFFDAE0EA), Color(0xFFB3B9D1), Color(0xFF8B93AF),
  Color(0xFF6D758D), Color(0xFF4A5462), Color(0xFF333941), Color(0xFF422433),
  Color(0xFF5B3138), Color(0xFF8E5252), Color(0xFFBA756A), Color(0xFFE9B5A3),
  Color(0xFFE3E6FF), Color(0xFFB9BFFB), Color(0xFF849BE4), Color(0xFF588DBE),
  Color(0xFF477D85), Color(0xFF23674E), Color(0xFF328464), Color(0xFF5DAF8D),
  Color(0xFF92DCBA), Color(0xFFCDF7E2), Color(0xFFE4D2AA), Color(0xFFC7B08B),
  Color(0xFFA08662), Color(0xFF796755), Color(0xFF5A4E44), Color(0xFF423934),
];

final Map<int, Color> _aapCache = {};

/// 最近傍のAAP-64色へ量子化する(redmean加重RGB距離)。
Color aap64(Color c) {
  final key = c.value & 0x00FFFFFF;
  final cached = _aapCache[key];
  if (cached != null) return cached.withAlpha(c.alpha);
  final r = c.red, g = c.green, b = c.blue;
  var best = kAap64[0];
  // Web(JS)では大きなビットシフトが使えないため、比較初期値はdoubleにする
  num bestD = double.infinity;
  for (final p in kAap64) {
    final dr = r - p.red, dg = g - p.green, db = b - p.blue;
    final rm = (r + p.red) >> 1;
    final d = (2 * 256 + rm) * dr * dr + 4 * 256 * dg * dg +
        (2 * 256 + 255 - rm) * db * db;
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  _aapCache[key] = best;
  return best.withAlpha(c.alpha);
}

// ─────────────────────────────────────────────────────────────
// 仮想ピクセルラスタライザ。すべての描画をドット単位に揃える。
// ─────────────────────────────────────────────────────────────
class Px {
  Px(this.canvas, this.u, {this.snap = 1, this.quantize = true});
  final Canvas canvas;
  final double u; // 1仮想ピクセルの実サイズ
  final double snap; // 64pxルール: この倍数にスナップ(粗いドット)
  final bool quantize; // false: 独自パレットのまま描く(16bit風ページ用)
  final Paint _p = Paint();

  /// 矩形(スナップした粗ドット格子に揃える)
  void r(num x, num y, num w, num h, Color c) {
    _p.color = quantize ? aap64(c) : c;
    final x0 = (x / snap).floorToDouble() * snap;
    final y0 = (y / snap).floorToDouble() * snap;
    var x1 = ((x + w) / snap).ceilToDouble() * snap;
    var y1 = ((y + h) / snap).ceilToDouble() * snap;
    if (x1 <= x0) x1 = x0 + snap;
    if (y1 <= y0) y1 = y0 + snap;
    canvas.drawRect(
        Rect.fromLTWH(x0 * u, y0 * u, (x1 - x0) * u + 0.3, (y1 - y0) * u + 0.3),
        _p);
  }

  /// 1ドット(スナップ幅)
  void dot(num x, num y, Color c) => r(x, y, snap, snap, c);

  /// 楕円(粗ドットのrow-scan)
  void oval(num cx, num cy, num rx, num ry, Color c) {
    for (var iy = -(ry / snap).ceil(); iy <= (ry / snap).ceil(); iy++) {
      final yy = iy * snap;
      final t = yy / ry;
      if (t.abs() > 1) continue;
      final dx = rx * math.sqrt(math.max(0, 1 - t * t));
      r(cx - dx, cy + yy, dx * 2, snap, c);
    }
  }

  /// 三角形(粗ドットのrow-scan)
  void tri(num x1, num y1, num x2, num y2, num x3, num y3, Color c) {
    final pts = [
      Offset(x1.toDouble(), y1.toDouble()),
      Offset(x2.toDouble(), y2.toDouble()),
      Offset(x3.toDouble(), y3.toDouble()),
    ]..sort((a, b) => a.dy.compareTo(b.dy));
    final a = pts[0], b = pts[1], d = pts[2];
    double xAt(Offset p1, Offset p2, double y) => p2.dy == p1.dy
        ? p1.dx
        : p1.dx + (p2.dx - p1.dx) * (y - p1.dy) / (p2.dy - p1.dy);
    for (var y = (a.dy / snap).floor(); y <= (d.dy / snap).ceil(); y++) {
      final yy = y * snap + snap / 2;
      if (yy < a.dy || yy > d.dy) continue;
      final e1 = xAt(a, d, yy);
      final e2 = yy < b.dy ? xAt(a, b, yy) : xAt(b, d, yy);
      final lo = math.min(e1, e2), hi = math.max(e1, e2);
      r(lo, y * snap, hi - lo, snap, c);
    }
  }

  /// 面のむらノイズ(粗ドット)
  void noise(num x, num y, num w, num h, List<Color> colors, int count,
      math.Random rng, {int dotW = 1, int dotH = 1}) {
    final n = (count / (snap * snap)).ceil();
    for (var i = 0; i < n; i++) {
      r(x + rng.nextInt(math.max(1, w.toInt())),
          y + rng.nextInt(math.max(1, h.toInt())), snap * dotW, snap * dotH,
          colors[rng.nextInt(colors.length)]);
    }
  }

  /// 楕円の内側にむらノイズ
  void ovalNoise(num cx, num cy, num rx, num ry, List<Color> colors, int count,
      math.Random rng) {
    final n = (count / (snap * snap)).ceil();
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = math.sqrt(rng.nextDouble());
      dot(cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d,
          colors[rng.nextInt(colors.length)]);
    }
  }

  /// 花(十字5ドット)
  void flower(num x, num y, Color petal, [Color center = const Color(0xFFF6D96B)]) {
    dot(x - snap, y, petal);
    dot(x + snap, y, petal);
    dot(x, y - snap, petal);
    dot(x, y + snap, petal);
    dot(x, y, center);
  }

  /// きらめき(+字)
  void sparkle(num x, num y, num s, Color c) {
    r(x - s, y, s * 2 + snap, snap, c);
    r(x, y - s, snap, s * 2 + snap, c);
  }
}

/// スプライトを直接キャンバスに描く(自動アウトライン付き)。
void drawPixelSprite(Canvas canvas, List<String> rows,
    Map<String, Color> palette, double left, double top, double unit,
    {Color outline = const Color(0xFF3A2C1A)}) {
  final p = Paint();
  bool filled(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      y < rows.length &&
      x < rows[y].length &&
      palette.containsKey(rows[y][x]);
  // アウトライン(塗りの周囲1ドット)
  p.color = aap64(outline);
  for (var y = -1; y <= rows.length; y++) {
    for (var x = -1; x <= rows[0].length; x++) {
      if (filled(x, y)) continue;
      final near = filled(x - 1, y) ||
          filled(x + 1, y) ||
          filled(x, y - 1) ||
          filled(x, y + 1);
      if (near) {
        canvas.drawRect(
            Rect.fromLTWH(left + x * unit, top + y * unit, unit + 0.3, unit + 0.3),
            p);
      }
    }
  }
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final c = palette[rows[y][x]];
      if (c == null) continue;
      p.color = aap64(c);
      canvas.drawRect(
          Rect.fromLTWH(left + x * unit, top + y * unit, unit + 0.3, unit + 0.3),
          p);
    }
  }
}

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
    drawPixelSprite(canvas, rows, palette, 0, 0, u);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) => old.rows != rows;
}

// 共通パレット(MOTHER風・AAP-64の色を直接使用)
const _skin = Color(0xFFFAD6B8);
const _eye = Color(0xFF141013);
const _blush = Color(0xFFF5A097);
const _mouth = Color(0xFFE86A73);

/// みぽりん(ピンクのボブ+ポニーテール)。pose 0=にっこり 1=指さし
/// 頭が全身の約6割のちびキャラ比率。
List<String> miporinRows(int pose) => [
      '.....PPPPPP.....',
      '...PPPPPPPPPP...',
      '..PPPPPPPPPPPP..',
      '..PppPPPPPPPPPq.',
      '.PPppPPPPPPPPPqq',
      '.PPPPPPPPPPPPPqq',
      '.PPffffffffffPq.',
      '.PffffffffffffP.',
      '.PfeeffffffeefP.',
      '.PffffffffffffP.',
      '.PbbfffmmfffbbP.',
      '..PffffffffffP..',
      '..PPffffffffPP..',
      pose == 1 ? '....wwwwwwww.ff.' : '....wwwwwwww....',
      pose == 1 ? '...fwwwwwwwwff..' : '...fwwwwwwwwf...',
      pose == 1 ? '...fwwwrrwww....' : '...fwwwrrwwwf...',
      '....RRRRRRRR....',
      '...RRRRRRRRRR...',
      '....ff....ff....',
      '...sss....sss...',
    ];

const miporinPalette = {
  'P': Color(0xFFE86A73),
  'p': Color(0xFFF5A097),
  'q': Color(0xFFE86A73),
  'f': _skin,
  'e': _eye,
  'b': _blush,
  'm': _mouth,
  'w': Colors.white,
  'r': Color(0xFFB4202A),
  'R': Color(0xFFB4202A),
  's': Color(0xFF422433),
};

/// 主人公(正面)。茶髪ボブ+白トップス+赤スカート。
const heroineFrontRows = [
  '.....hhhhhh.....',
  '...hhhhhhhhhh...',
  '..hhhhhhhhhhhh..',
  '..hHHhhhhhhhhh..',
  '.hhHHhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '.hhffffffffffhh.',
  '.hffffffffffffh.',
  '.hfeeffffffeefh.',
  '.hffffffffffffh.',
  '.hbbfffmmfffbbh.',
  '..hffffffffffh..',
  '..hhffffffffhh..',
  '....wwwwwwww....',
  '...fwwwwwwwwf...',
  '...fwwwrrwwwf...',
  '....RRRRRRRR....',
  '...RRRRRRRRRR...',
  '....ff....ff....',
  '...sss....sss...',
];

/// 主人公(後ろ姿)。
const heroineBackRows = [
  '.....hhhhhh.....',
  '...hhhhhhhhhh...',
  '..hhhhhhhhhhhh..',
  '..hHHhhhhhhhhh..',
  '.hhHHhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '.hhhhhhhhhhhhhh.',
  '..hhhhhhhhhhhh..',
  '..hhhhhhhhhhhh..',
  '....wwwwwwww....',
  '...fwwwwwwwwf...',
  '...fwwwwwwwwf...',
  '....RRRRRRRR....',
  '...RRRRRRRRRR...',
  '....ff....ff....',
  '...sss....sss...',
];

const heroinePalette = {
  'h': Color(0xFF71413B),
  'H': Color(0xFFBB7547),
  'f': _skin,
  'e': _eye,
  'b': _blush,
  'm': _mouth,
  'w': Colors.white,
  'r': Color(0xFFE86A73),
  'R': Color(0xFFB4202A),
  's': Color(0xFF422433),
};

/// パン屋さん(コック帽・ひげ・エプロン)。
const bakerRows = [
  '...CCCCCCCCCC...',
  '..CCCCCCCCCCCC..',
  '..CCCCCCCCCCCC..',
  '..cCCCCCCCCCCc..',
  '...cccccccccc...',
  '..ffffffffffff..',
  '.ffffffffffffff.',
  '.ffeeffffffeeff.',
  '.ffffffffffffff.',
  '.fbbMMMMMMMMbbf.',
  '.ffMMMMMMMMMMff.',
  '..ffffMMMMffff..',
  '..ffffffffffff..',
  '....UUUUUUUU....',
  '...fUAAAAAAUf...',
  '...fUAAAAAAUf...',
  '....AAAAAAAA....',
  '...AAAAaaAAAA...',
  '....VV....VV....',
  '...sss....sss...',
];

const bakerPalette = {
  'C': Colors.white,
  'c': Color(0xFFDAE0EA),
  'f': Color(0xFFF4D29C),
  'e': _eye,
  'b': Color(0xFFE9B5A3),
  'M': Color(0xFF5A4E44),
  'U': Color(0xFF588DBE),
  'A': Colors.white,
  'a': Color(0xFFDAE0EA),
  'V': Color(0xFF4A5462),
  's': Color(0xFF322B28),
};

// ─────────────────────────────────────────────────────────────
// 寝室(mode 0=就寝 1=目覚め)。仮想128x224ピクセル。
// ─────────────────────────────────────────────────────────────
class _BedroomPainter extends CustomPainter {
  const _BedroomPainter({required this.mode});
  final int mode;

  @override
  void paint(Canvas canvas, Size size) {
    const vw = 128.0, vh = 224.0;
    final u = math.min(size.width / vw, size.height / vh);
    canvas.save();
    canvas.translate((size.width - vw * u) / 2, (size.height - vh * u) / 2);
    final px = Px(canvas, u, snap: vw / 256);
    final rng = math.Random(9);

    // レターボックス部も含めた下地
    canvas.drawColor(const Color(0xFF4E3E28), BlendMode.srcOver);

    // ── 壁(むら + 巾木) ──
    px.r(-30, -30, vw + 60, 116, const Color(0xFF8F7A57));
    px.noise(-30, -30, vw + 60, 116,
        [const Color(0xFF7C6949), const Color(0xFF9A8562), const Color(0xFF867352)],
        420, rng);
    px.r(-30, 84, vw + 60, 3, const Color(0xFF6E4A22));
    px.r(-30, 84, vw + 60, 1, const Color(0xFF8A5F33));

    // ── 床(板 + 木目 + 節) ──
    for (var i = 0; i < 14; i++) {
      final y = 87 + i * 10;
      px.r(-30, y, vw + 60, 10,
          i.isEven ? const Color(0xFF8A5F33) : const Color(0xFF815728));
      px.r(-30, y, vw + 60, 1, const Color(0xFF64431F));
      for (var j = 0; j < 6; j++) {
        px.r(-20 + ((i * 43 + j * 29) % 150), y + 2 + (j % 3) * 2, 6, 1,
            const Color(0xFF6E4A22));
      }
      if (i % 3 == 1) {
        px.oval(((i * 53) % 110).toDouble(), y + 5, 2, 1,
            const Color(0xFF64431F));
      }
    }
    px.noise(-30, 87, vw + 60, 137,
        [const Color(0xFF7C5329), const Color(0xFF966B3B)],
        260, rng);

    // ── 窓(夜空・星・三日月・木立) ──
    px.r(18, 2, 46, 42, const Color(0xFF6E4A22));
    px.r(19, 3, 44, 40, const Color(0xFF8A5F33));
    px.r(21, 5, 40, 36, const Color(0xFF16244E));
    px.noise(21, 5, 40, 20,
        [const Color(0xFF23346B), const Color(0xFF1B2B5C)], 60, rng);
    for (var i = 0; i < 12; i++) {
      px.dot(22 + rng.nextInt(38), 6 + rng.nextInt(16), Colors.white);
    }
    px.sparkle(56, 9, 1, Colors.white);
    // 三日月(段々)
    px.oval(34, 14, 6, 6, const Color(0xFFF2D96B));
    px.oval(37, 12, 5.4, 5.4, const Color(0xFF16244E));
    // 木立
    px.oval(27, 36, 8, 6, const Color(0xFF1E4A32));
    px.oval(42, 38, 12, 6, const Color(0xFF234F38));
    px.oval(56, 37, 7, 5, const Color(0xFF1E4A32));
    // 桟
    px.r(40, 5, 2, 36, const Color(0xFF9C6B35));
    px.r(21, 22, 40, 2, const Color(0xFF9C6B35));

    // ── カーテン(ひだ + スカラップ裾 + タッセル) ──
    for (final cx in [12.0, 62.0]) {
      px.r(cx, 1, 8, 46, const Color(0xFFF2B7C6));
      for (var i = 0; i < 3; i++) {
        px.r(cx + 1 + i * 2.6, 2, 1, 44, const Color(0xFFE898AF));
      }
      // 裾のスカラップ
      for (var i = 0; i < 4; i++) {
        px.oval(cx + 1 + i * 2.2, 47, 1.4, 2, const Color(0xFFF2B7C6));
      }
      px.r(cx - 1, 26, 10, 3, const Color(0xFFD9749B));
      px.dot(cx + 4, 27, const Color(0xFFF6D96B));
    }
    px.r(9, 0, 64, 2, const Color(0xFF6E4A22));
    for (var i = 0; i < 6; i++) {
      px.dot(11 + i * 11, 1, const Color(0xFF9C6B35));
    }

    // ── 壁の額(島の絵/花の絵) ──
    _frame(px, 1, 10, 12, 10, sea: true);
    _frame(px, 1, 28, 12, 10, sea: false);

    // ── 本棚(右) ──
    px.r(88, -4, 38, 98, const Color(0xFF5A3A1E));
    px.r(90, -2, 34, 94, const Color(0xFF9C6B35));
    px.noise(90, -2, 34, 94,
        [const Color(0xFF8A5F33), const Color(0xFFB07B3E)], 90, rng);
    final bookColors = [
      const Color(0xFFB84C5C),
      const Color(0xFF4C7AB8),
      const Color(0xFF54A05A),
      const Color(0xFF8A5CA8),
      const Color(0xFFD8A44C),
      const Color(0xFF3E8A8A),
    ];
    for (var shelf = 0; shelf < 4; shelf++) {
      final sy = 4 + shelf * 23;
      px.r(92, sy, 30, 17, const Color(0xFF54371A));
      px.r(90, sy + 17, 34, 3, const Color(0xFF6E4A22));
      px.r(90, sy + 17, 34, 1, const Color(0xFFB07B3E));
      var bx = 93.0;
      var k = shelf * 5;
      while (bx < 118) {
        if (k % 4 == 3 && shelf > 0) {
          // 植木鉢/小箱
          px.r(bx, sy + 10, 6, 7, const Color(0xFF4C7AB8));
          px.r(bx + 1, sy + 11, 4, 1, const Color(0xFF6E9AD0));
          px.oval(bx + 3, sy + 7, 3, 3, const Color(0xFF3B9A31));
          px.dot(bx + 2, sy + 6, const Color(0xFF54B848));
          bx += 8;
        } else {
          final bw = 3 + (k % 3);
          final c = bookColors[k % bookColors.length];
          px.r(bx, sy + 3 + (k % 2), bw, 14 - (k % 2), c);
          px.r(bx, sy + 3 + (k % 2), 1, 14 - (k % 2),
              Color.lerp(c, Colors.black, 0.25)!);
          px.r(bx + 1, sy + 5, bw - 2, 1, Colors.white38);
          bx += bw + 1;
        }
        k++;
      }
    }

    // ── ベッド ──
    // ヘッドボード
    px.r(24, 52, 52, 26, const Color(0xFF6E4A22));
    px.r(26, 54, 48, 22, const Color(0xFF9C6B35));
    px.r(26, 54, 48, 4, const Color(0xFFB07B3E));
    px.noise(26, 58, 48, 18,
        [const Color(0xFF8A5F33), const Color(0xFFA9743C)], 40, rng);
    for (final bx in [22.0, 74.0]) {
      px.r(bx, 50, 4, 30, const Color(0xFF6E4A22));
      px.oval(bx + 2, 49, 3, 3, const Color(0xFF8A5F33));
      px.dot(bx + 1, 48, const Color(0xFFB07B3E));
    }
    // マットレス・シーツ
    px.r(24, 76, 52, 34, const Color(0xFFE9E4EF));
    px.noise(24, 76, 52, 20,
        [const Color(0xFFDDD6E6), const Color(0xFFF4F0F8)], 60, rng);
    // 枕
    px.oval(40, 74, 13, 6, Colors.white);
    px.oval(40, 76, 13, 5, const Color(0xFFEFEAF4));
    px.r(28, 79, 25, 1, const Color(0xFFD5CEDF));
    // 掛け布団(細かいギンガム 3px + ステッチ)
    for (var cy = 0; cy < 12; cy++) {
      for (var cx = 0; cx < 18; cx++) {
        final even = (cx + cy) % 2 == 0;
        px.r(24 + cx * 3, 110 + cy * 3, 3, 3,
            even ? const Color(0xFFF0A8BC) : const Color(0xFFF7CBD6));
        if (!even && (cx + cy) % 4 == 1) {
          px.dot(25 + cx * 3, 111 + cy * 3, Colors.white70);
        }
      }
    }
    px.r(24, 110, 54, 2, const Color(0xFFE898AF));
    for (var i = 0; i < 13; i++) {
      px.dot(26 + i * 4, 111, Colors.white);
    }
    // 布団の谷折り陰
    px.r(24, 124, 54, 1, const Color(0xFFDF8FA6));
    px.r(24, 136, 54, 1, const Color(0xFFDF8FA6));
    // 足元ボード
    px.r(22, 146, 56, 5, const Color(0xFF6E4A22));
    px.r(23, 147, 54, 3, const Color(0xFF9C6B35));

    // ── 主人公 ──
    if (mode == 0) {
      // 就寝(髪を枕に広げて)
      px.oval(38, 70, 11, 8, const Color(0xFF6E4423));
      px.oval(30, 76, 6, 6, const Color(0xFF6E4423));
      px.oval(49, 76, 5, 6, const Color(0xFF6E4423));
      px.oval(40, 74, 7, 6, _skin);
      px.oval(40, 70.5, 8, 3.4, const Color(0xFF7A4A22));
      for (var i = 0; i < 4; i++) {
        px.dot(34 + i * 4, 69, const Color(0xFF9A6534));
      }
      // 閉じた目・ほお・口
      px.r(37, 75, 2, 1, _eye);
      px.r(42, 75, 2, 1, _eye);
      px.dot(36, 77, _blush);
      px.dot(44, 77, _blush);
      px.dot(40, 78, const Color(0xFFB3583F));
      // パジャマの腕
      px.r(52, 104, 9, 5, const Color(0xFF6FB3E8));
      px.r(52, 104, 9, 1, const Color(0xFF5A9FD4));
      px.r(60, 105, 4, 3, _skin);
    } else {
      // 目覚めて上体を起こす
      px.r(36, 88, 26, 24, const Color(0xFF6FB3E8));
      px.noise(36, 88, 26, 24,
          [const Color(0xFF5A9FD4), const Color(0xFF85C3F0)], 40, rng);
      for (var i = 0; i < 4; i++) {
        px.dot(48, 90 + i * 5, Colors.white);
      }
      // ほおに手
      px.r(58, 92, 5, 13, const Color(0xFF6FB3E8));
      px.r(58.5, 88, 4, 5, _skin);
      // 顔
      px.oval(48, 74, 14, 12, const Color(0xFF7A4A22));
      px.oval(48, 78, 10, 8.4, _skin);
      px.oval(48, 70.6, 12, 4.6, const Color(0xFF7A4A22));
      for (var i = 0; i < 5; i++) {
        px.dot(40 + i * 4, 68, const Color(0xFF9A6534));
      }
      px.oval(38, 78, 3, 5, const Color(0xFF7A4A22));
      px.oval(58, 78, 3, 5, const Color(0xFF7A4A22));
      // 目(ぱっちり)・ほお・口
      px.r(44, 77, 2, 3, _eye);
      px.r(52, 77, 2, 3, _eye);
      px.dot(44, 77, Colors.white70);
      px.dot(52, 77, Colors.white70);
      px.dot(42, 81, _blush);
      px.dot(55, 81, _blush);
      px.oval(48.5, 83, 1.4, 1.2, const Color(0xFFB3583F));
      // ？マーク
      px.oval(67, 62, 4.4, 4.4, Colors.white);
      px.oval(64, 69, 1.6, 1.6, Colors.white);
      px.r(66, 59.6, 2.4, 1, const Color(0xFF3A2C1A));
      px.r(68.4, 60.4, 1, 2, const Color(0xFF3A2C1A));
      px.r(66.4, 62.6, 2, 1, const Color(0xFF3A2C1A));
      px.r(66.4, 63.6, 1, 1.6, const Color(0xFF3A2C1A));
      px.dot(66.6, 66.4, const Color(0xFF3A2C1A));
    }

    // ── ナイトスタンド + ランプ ──
    px.r(80, 88, 17, 23, const Color(0xFF6E4A22));
    px.r(81, 89, 15, 21, const Color(0xFF9C6B35));
    px.r(82, 96, 13, 1, const Color(0xFF6E4A22));
    px.r(82, 103, 13, 1, const Color(0xFF6E4A22));
    px.oval(88.5, 99.5, 1.4, 1.4, const Color(0xFF6E4A22));
    // ランプの灯り(2重グロー)
    px.oval(88, 76, 17, 14, const Color(0x22FFD98A));
    px.oval(88, 77, 11, 9, const Color(0x33FFD98A));
    px.r(87, 80, 3, 8, const Color(0xFFB07B3E));
    // シェード(台形を段々に)
    px.tri(80, 79, 96, 79, 88, 68, const Color(0xFFE898AF));
    px.r(82, 71, 3, 8, const Color(0xFFF2B7C6));
    px.r(81, 79, 15, 1, const Color(0xFFD9749B));

    // ── ラグ(縁飾り) + 鉢植え ──
    px.oval(20, 172, 17, 8, const Color(0xFFD87A8C));
    px.oval(20, 172, 13, 6, const Color(0xFFE39AA9));
    px.oval(20, 172, 9, 4, const Color(0xFFD87A8C));
    // 鉢植え
    px.r(98, 168, 12, 10, const Color(0xFFE8E4DC));
    px.r(98, 176, 12, 2, const Color(0xFFCFC9BE));
    px.r(103, 158, 2, 10, const Color(0xFF2E8226));
    px.oval(100, 158, 4, 3, const Color(0xFF3B9A31));
    px.oval(107, 156, 4, 3, const Color(0xFF3B9A31));
    px.oval(103.5, 153, 4, 3, const Color(0xFF54B848));

    // 夜のトーン
    canvas.restore();
    final t = Paint()..color = const Color(0x1A16244E);
    canvas.drawRect(Offset.zero & size, t);
  }

  void _frame(Px px, num x, num y, num w, num h, {required bool sea}) {
    px.r(x, y, w, h, const Color(0xFF6E4A22));
    px.r(x + 1, y + 1, w - 2, h - 2, const Color(0xFF9C6B35));
    if (sea) {
      px.r(x + 2, y + 2, w - 4, h - 4, const Color(0xFF6FB3E8));
      px.oval(x + w / 2, y + h / 2 + 1, (w - 6) / 2, 1.6,
          const Color(0xFF54A05A));
      px.dot(x + 3, y + 3, Colors.white70);
    } else {
      px.r(x + 2, y + 2, w - 4, h - 4, const Color(0xFFEFE7D5));
      px.flower(x + w / 2, y + h / 2, const Color(0xFFE86E9A));
      px.dot(x + w / 2, y + h - 3, const Color(0xFF54A05A));
    }
  }

  @override
  bool shouldRepaint(covariant _BedroomPainter old) => old.mode != mode;
}

// ─────────────────────────────────────────────────────────────
// 光に吸い込まれる(段々の放射光 + ドットのきらめき + 後ろ姿)。
// ─────────────────────────────────────────────────────────────
class _LightBurstPainter extends CustomPainter {
  const _LightBurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 160;
    final px = Px(canvas, u, snap: 0.625);
    final rng = math.Random(21);
    final vw = size.width / u, vh = size.height / u;

    px.r(0, 0, vw, vh, const Color(0xFF241B12));
    // うっすら床板
    for (var i = 0; i < 10; i++) {
      px.r(0, vh * 0.4 + i * vh * 0.06, vw, 1, const Color(0xFF2E2216));
    }
    px.noise(0, 0, vw, vh, [const Color(0xFF2A2015), const Color(0xFF201810)],
        300, rng);

    final cx = vw / 2, cy = vh * 0.42;
    // 放射光(三角を段々に)
    for (var i = 0; i < 30; i++) {
      final a = i * math.pi / 15 + 0.1;
      final len = vh * (0.45 + rng.nextDouble() * 0.25);
      final w = 0.03 + rng.nextDouble() * 0.05;
      final c = i % 3 == 0
          ? const Color(0x77F7D774)
          : (i % 3 == 1 ? const Color(0x55F2C14E) : const Color(0x44E8A83C));
      px.tri(
          cx,
          cy,
          cx + math.cos(a - w) * len,
          cy + math.sin(a - w) * len,
          cx + math.cos(a + w) * len,
          cy + math.sin(a + w) * len,
          c);
    }
    // 中心の光球(3段)
    px.oval(cx, cy, vw * 0.17, vw * 0.17, const Color(0x88F7D774));
    px.oval(cx, cy, vw * 0.12, vw * 0.12, const Color(0xFFF7E9AE));
    px.oval(cx, cy, vw * 0.07, vw * 0.07, const Color(0xFFFFF8DC));
    // 主人公(後ろ姿・浮かぶ)
    drawPixelSprite(canvas, heroineBackRows, heroinePalette,
        (cx - 12) * u, (cy - 6) * u, 1.6 * u);
    // きらめき
    for (var i = 0; i < 60; i++) {
      final x = rng.nextDouble() * vw;
      final y = rng.nextDouble() * vh;
      final s = 1 + rng.nextInt(3);
      px.sparkle(x, y, s,
          rng.nextBool() ? const Color(0xFFF7E9AE) : const Color(0xAAF2C14E));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 島の全景。仮想160幅。withHeroine で手前の崖と後ろ姿。
// ─────────────────────────────────────────────────────────────
class _IslandOverviewPainter extends CustomPainter {
  const _IslandOverviewPainter({required this.withHeroine});
  final bool withHeroine;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 160;
    final px = Px(canvas, u, snap: 0.625);
    final rng = math.Random(3);
    final vw = 160.0, vh = size.height / u;

    // 空
    px.r(0, 0, vw, vh * 0.2, const Color(0xFF5EA9E8));
    px.noise(0, 0, vw, vh * 0.18,
        [const Color(0xFF6FB3EE), const Color(0xFF54A0E2)], 120, rng);
    for (var i = 0; i < 5; i++) {
      final x = rng.nextDouble() * vw;
      final y = 4 + rng.nextDouble() * vh * 0.1;
      px.oval(x, y, 10, 3, Colors.white);
      px.oval(x + 6, y - 2, 6, 2.4, Colors.white);
      px.oval(x - 6, y + 1, 5, 2, const Color(0xFFEFF6FC));
    }
    // 海(市松 + 波 + きらめき)
    final seaTop = vh * 0.18;
    for (var y = 0; y * 4 < vh - seaTop + 4; y++) {
      for (var x = 0; x * 4 < vw; x++) {
        px.r(x * 4, seaTop + y * 4, 4, 4,
            (x + y).isEven ? const Color(0xFF2E6FB0) : const Color(0xFF2A66A3));
      }
    }
    for (var i = 0; i < 60; i++) {
      final wx = rng.nextDouble() * vw;
      final wy = seaTop + rng.nextDouble() * (vh - seaTop);
      px.r(wx, wy, 3 + rng.nextInt(3), 1, const Color(0xFF6FA8D8));
      px.r(wx + 1, wy + 1, 2, 1, const Color(0xFF244F86));
    }

    // 島: 砂の縁 → 緑(むら・道・家・木)
    final icx = vw * 0.55, icy = vh * 0.52;
    px.oval(icx, icy, vw * 0.4, vh * 0.26, const Color(0xFFC9B27A));
    px.oval(icx, icy, vw * 0.385, vh * 0.248, const Color(0xFFD9C488));
    px.oval(icx, icy, vw * 0.36, vh * 0.228, const Color(0xFF63AC46));
    // 緑のむら(楕円内ノイズ)
    px.ovalNoise(icx, icy, vw * 0.35, vh * 0.22,
        [const Color(0xFF57993D), const Color(0xFF74BD55), const Color(0xFF4E8C36)],
        700, rng);
    // 道(ベジェをドット刻みに)
    for (var t = 0.0; t <= 1.0; t += 0.02) {
      final x = _bez(icx, icx - vw * 0.05, icx + 0.02 * vw, t);
      final y = icy + vh * 0.2 - t * vh * 0.36;
      px.r(x - 2, y, 5, 2, const Color(0xFFD8C08A));
      if ((t * 50).round() % 3 == 0) {
        px.dot(x - 2 + rng.nextInt(5), y + 1, const Color(0xFFC0A870));
      }
    }
    // 家々(壁むら・屋根の棟・窓灯り)
    void house(double hx, double hy, Color roof) {
      px.r(hx, hy + 4, 12, 7, const Color(0xFFF2E6C8));
      px.dot(hx + 2, hy + 6, const Color(0xFFE2D4AE));
      px.dot(hx + 9, hy + 8, const Color(0xFFE2D4AE));
      px.tri(hx - 2, hy + 5, hx + 6, hy - 2, hx + 14, hy + 5, roof);
      px.r(hx - 2, hy + 4, 16, 1, Color.lerp(roof, Colors.black, 0.25)!);
      px.r(hx + 5, hy + 7, 3, 4, const Color(0xFF6E4A22));
      px.dot(hx + 2, hy + 6, const Color(0xFFF9E9A8));
      px.dot(hx + 10, hy + 6, const Color(0xFFF9E9A8));
    }

    house(vw * 0.36, vh * 0.46, const Color(0xFFC85C4E));
    house(vw * 0.62, vh * 0.4, const Color(0xFF4C7AB8));
    house(vw * 0.66, vh * 0.55, const Color(0xFF54A05A));
    house(vw * 0.44, vh * 0.6, const Color(0xFF8A5CA8));
    house(vw * 0.3, vh * 0.56, const Color(0xFFD8A44C));
    house(vw * 0.52, vh * 0.44, const Color(0xFFC85C4E));
    // 木(2段 + ハイライト)
    for (var i = 0; i < 18; i++) {
      final tx = vw * (0.24 + rng.nextDouble() * 0.58);
      final ty = vh * (0.32 + rng.nextDouble() * 0.38);
      px.r(tx - 0.5, ty + 2, 1, 2, const Color(0xFF6E4A22));
      px.oval(tx, ty, 3.4, 2.8, const Color(0xFF2E7D32));
      px.oval(tx - 0.6, ty - 0.8, 1.8, 1.2, const Color(0xFF43A047));
      px.dot(tx + 1, ty - 1, const Color(0xFF5FBE4C));
    }

    // 山(2面 + 雪 + 滝)
    px.tri(vw * 0.4, vh * 0.36, vw * 0.55, vh * 0.15, vw * 0.7, vh * 0.36,
        const Color(0xFF6E8F5A));
    px.tri(vw * 0.55, vh * 0.15, vw * 0.7, vh * 0.36, vw * 0.55, vh * 0.36,
        const Color(0xFF57764A));
    px.tri(vw * 0.51, vh * 0.215, vw * 0.55, vh * 0.15, vw * 0.59, vh * 0.215,
        Colors.white);
    px.dot(vw * 0.53, vh * 0.21, const Color(0xFFE8F2F8));
    for (var i = 0; i < 8; i++) {
      px.r(vw * 0.6, vh * (0.26 + i * 0.014), 2, 1,
          i.isEven ? const Color(0xFF9CD4F0) : Colors.white);
    }

    // 灯台(白赤ストライプ + 光)
    px.r(vw * 0.86, vh * 0.38, 6, 15, Colors.white);
    px.r(vw * 0.86, vh * 0.4, 6, 2, const Color(0xFFC85C4E));
    px.r(vw * 0.86, vh * 0.45, 6, 2, const Color(0xFFC85C4E));
    px.tri(vw * 0.855, vh * 0.38, vw * 0.89, vh * 0.345, vw * 0.925, vh * 0.38,
        const Color(0xFFC85C4E));
    px.dot(vw * 0.885, vh * 0.375, const Color(0xFFF2D96B));

    // 小島
    px.oval(vw * 0.08, vh * 0.3, 8, 3, const Color(0xFF63AC46));
    px.oval(vw * 0.92, vh * 0.72, 9, 3.4, const Color(0xFF63AC46));

    if (withHeroine) {
      // 手前の崖(row-scan) + 草縁 + 花
      for (var y = (vh * 0.66).floor(); y < vh; y++) {
        final t = (y - vh * 0.66) / (vh * 0.34);
        final w = vw * (0.3 - t * 0.06);
        px.r(0, y, w, 1, const Color(0xFF7C5B36));
      }
      px.noise(0, vh * 0.7, vw * 0.26, vh * 0.28,
          [const Color(0xFF6E4E2C), const Color(0xFF8A6A3F)], 160, rng);
      for (var y = (vh * 0.66).floor(); y < (vh * 0.72).ceil(); y++) {
        final t = (y - vh * 0.66) / (vh * 0.06);
        px.r(0, y, vw * (0.3 - t * 0.02), 1,
            t < 0.5 ? const Color(0xFF74BD55) : const Color(0xFF63AC46));
      }
      for (var i = 0; i < 8; i++) {
        px.flower(rng.nextDouble() * vw * 0.24, vh * (0.665 + rng.nextDouble() * 0.04),
            [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
      }
      // 主人公(後ろ姿)
      drawPixelSprite(canvas, heroineBackRows, heroinePalette, vw * 0.08 * u,
          vh * 0.56 * u, math.max(1.6, vw / 84) * u);
    }
  }

  double _bez(double p0, double p1, double p2, double t) =>
      (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;

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
    final u = size.width / 160;
    final px = Px(canvas, u, snap: 0.625);
    final rng = math.Random(7);
    final vw = 160.0, vh = size.height / u;

    // 空
    px.r(0, 0, vw, vh * 0.42, const Color(0xFF5EA9E8));
    px.noise(0, 0, vw, vh * 0.4,
        [const Color(0xFF6FB3EE), const Color(0xFF54A0E2)], 140, rng);
    for (var i = 0; i < 4; i++) {
      final x = rng.nextDouble() * vw;
      final y = 6 + rng.nextDouble() * vh * 0.18;
      px.oval(x, y, 10, 3, Colors.white);
      px.oval(x + 6, y - 2, 6, 2.4, Colors.white);
    }
    // 茂み(むら)
    px.r(0, vh * 0.38, vw, vh * 0.62, const Color(0xFF3E8A34));
    px.noise(0, vh * 0.38, vw, vh * 0.62,
        [const Color(0xFF347628), const Color(0xFF4B9C3E), const Color(0xFF2C6620)],
        900, rng);
    // 道(台形)
    px.tri(vw * 0.42, vh, vw * 0.5, vh * 0.7, vw * 0.58, vh,
        const Color(0xFFCDB388));
    px.r(vw * 0.46, vh * 0.72, vw * 0.08, vh * 0.28, const Color(0xFFCDB388));
    px.noise(vw * 0.44, vh * 0.72, vw * 0.12, vh * 0.28,
        [const Color(0xFFBBA073), const Color(0xFFD8C08A)], 60, rng);

    // ヤシの木
    void palm(double pxx, double pyy, double s) {
      for (var i = 0; i < 5; i++) {
        px.r(pxx - 1.6 * s, pyy - (i + 1) * 5 * s, 3.2 * s, 5 * s,
            i.isEven ? const Color(0xFF8A5F33) : const Color(0xFF7C5329));
      }
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.55;
        px.oval(pxx + math.cos(a) * 9 * s, pyy - 25 * s + math.sin(a) * 5 * s,
            8 * s, 2.6 * s, i.isEven ? const Color(0xFF2E8226) : const Color(0xFF3B9A31));
      }
      px.dot(pxx, pyy - 25 * s, const Color(0xFF6E4A22));
    }

    palm(vw * 0.09, vh * 0.62, 1.1);
    palm(vw * 0.91, vh * 0.66, 1.3);

    // 大看板
    final bx = vw * 0.17, by = vh * 0.27, bw = vw * 0.66, bh = vh * 0.3;
    px.r(bx + bw * 0.16, by + bh, 5, vh * 0.28, const Color(0xFF5A3A1E));
    px.r(bx + bw * 0.16, by + bh, 2, vh * 0.28, const Color(0xFF6E4A22));
    px.r(bx + bw * 0.78, by + bh, 5, vh * 0.28, const Color(0xFF5A3A1E));
    px.r(bx + bw * 0.78, by + bh, 2, vh * 0.28, const Color(0xFF6E4A22));
    px.r(bx - 2, by - 2, bw + 4, bh + 4, const Color(0xFF5A3A1E));
    px.r(bx, by, bw, bh, const Color(0xFF9C6B35));
    // 板目 + 節 + 釘
    for (var i = 1; i < 4; i++) {
      px.r(bx, by + i * bh / 4, bw, 1, const Color(0xFF875A2B));
    }
    px.noise(bx, by, bw, bh,
        [const Color(0xFF8A5F33), const Color(0xFFA9743C)], 180, rng);
    px.oval(bx + bw * 0.12, by + bh * 0.6, 2, 1.4, const Color(0xFF6E4A22));
    px.oval(bx + bw * 0.88, by + bh * 0.3, 2, 1.4, const Color(0xFF6E4A22));
    for (final (nx, ny) in [(0.04, 0.08), (0.96, 0.08), (0.04, 0.9), (0.96, 0.9)]) {
      px.dot(bx + bw * nx, by + bh * ny, const Color(0xFF5A3A1E));
    }
    // つた(縁を段々に這う) + 花
    for (var i = 0; i < 40; i++) {
      final t = i / 40 * math.pi * 2;
      final ex = bx + bw / 2 + math.cos(t) * (bw / 2 + 2);
      final ey = by + bh / 2 + math.sin(t) * (bh / 2 + 2);
      px.oval(ex, ey, 3, 2,
          i % 2 == 0 ? const Color(0xFF3B9A31) : const Color(0xFF2E8226));
      if (i % 5 == 0) px.dot(ex, ey - 1, const Color(0xFF54B848));
    }
    for (var i = 0; i < 8; i++) {
      final t = i / 8 * math.pi * 2 + 0.4;
      px.flower(bx + bw / 2 + math.cos(t) * (bw / 2 + 4),
          by + bh / 2 + math.sin(t) * (bh / 2 + 4),
          i.isEven ? const Color(0xFFF2A5C0) : Colors.white);
    }
    // 下草の花
    for (var i = 0; i < 16; i++) {
      px.flower(rng.nextDouble() * vw, vh * (0.78 + rng.nextDouble() * 0.2),
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// 村の道(奥へ続く道 + 家々)。
// ─────────────────────────────────────────────────────────────
class _VillagePathPainter extends CustomPainter {
  const _VillagePathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 160;
    final px = Px(canvas, u, snap: 0.625);
    final rng = math.Random(11);
    final vw = 160.0, vh = size.height / u;

    // 空 + 雲 + 遠山
    px.r(0, 0, vw, vh * 0.36, const Color(0xFF5EA9E8));
    px.noise(0, 0, vw, vh * 0.3,
        [const Color(0xFF6FB3EE), const Color(0xFF54A0E2)], 120, rng);
    for (var i = 0; i < 4; i++) {
      final x = rng.nextDouble() * vw;
      final y = 5 + rng.nextDouble() * vh * 0.14;
      px.oval(x, y, 9, 2.8, Colors.white);
      px.oval(x + 5, y - 1.6, 5, 2, Colors.white);
    }
    px.oval(vw * 0.14, vh * 0.34, vw * 0.26, vh * 0.07, const Color(0xFF7FA8C9));
    px.oval(vw * 0.8, vh * 0.35, vw * 0.3, vh * 0.06, const Color(0xFF8FB4D2));

    // 草地(むら + 花)
    px.r(0, vh * 0.36, vw, vh * 0.64, const Color(0xFF6DB84E));
    px.noise(0, vh * 0.36, vw, vh * 0.64,
        [const Color(0xFF5FA843), const Color(0xFF7EC55E), const Color(0xFF539A39)],
        1000, rng);
    // 奥へ続く道(row-scan台形 + 小石)
    for (var y = (vh * 0.38).floor(); y < vh; y++) {
      final t = (y - vh * 0.38) / (vh * 0.62);
      final half = vw * (0.045 + t * 0.16);
      px.r(vw / 2 - half, y, half * 2, 1,
          y % 7 == 0 ? const Color(0xFFC2A87C) : const Color(0xFFCDB388));
    }
    for (var i = 0; i < 30; i++) {
      final t = rng.nextDouble();
      final half = vw * (0.04 + t * 0.15);
      px.r(vw / 2 + (rng.nextDouble() * 2 - 1) * half, vh * (0.4 + t * 0.58),
          2, 1, const Color(0xFFBBA073));
    }
    // 柵(影付き)
    for (final fy in [vh * 0.56, vh * 0.74]) {
      for (final side in [0.0, vw * 0.66]) {
        px.r(side + 2, fy, vw * 0.32, 2, const Color(0xFF9C6B35));
        px.r(side + 2, fy + 2, vw * 0.32, 1, const Color(0xFF6E4A22));
        for (var i = 0; i < 5; i++) {
          px.r(side + 4 + i * vw * 0.07, fy - 4, 2, 10, const Color(0xFF9C6B35));
          px.dot(side + 4 + i * vw * 0.07, fy - 5, const Color(0xFFB07B3E));
        }
      }
    }
    // 家(壁むら + ハーフティンバー + 屋根の段)
    void house(double hx, double hy, double s, Color roof) {
      px.r(hx, hy, 34 * s, 22 * s, const Color(0xFFF2E6C8));
      px.noise(hx, hy, 34 * s, 22 * s,
          [const Color(0xFFE2D4AE), const Color(0xFFF8EFD8)], (26 * s).round(), rng);
      px.r(hx, hy + 18 * s, 34 * s, 4 * s, const Color(0xFFD8CBA8));
      // 柱
      for (final lx in [0.0, 15.0, 31.0]) {
        px.r(hx + lx * s, hy, 3 * s, 22 * s, const Color(0xFF8A5F33));
      }
      // 屋根(2段 + 棟)
      px.tri(hx - 5 * s, hy + 1 * s, hx + 17 * s, hy - 13 * s, hx + 39 * s,
          hy + 1 * s, roof);
      px.tri(hx + 1 * s, hy + 1 * s, hx + 17 * s, hy - 9 * s, hx + 33 * s,
          hy + 1 * s, Color.lerp(roof, Colors.black, 0.15)!);
      px.r(hx - 5 * s, hy, 44 * s, 1.4 * s, Color.lerp(roof, Colors.black, 0.3)!);
      // 扉・窓(桟と花箱)
      px.r(hx + 13 * s, hy + 9 * s, 8 * s, 13 * s, const Color(0xFF6E4A22));
      px.r(hx + 14 * s, hy + 10 * s, 6 * s, 11 * s, const Color(0xFF8A5F33));
      for (final wxx in [4.0, 24.0]) {
        px.r(hx + wxx * s, hy + 6 * s, 7 * s, 6 * s, const Color(0xFFBDE3F8));
        px.r(hx + wxx * s + 3 * s, hy + 6 * s, 1 * s, 6 * s, Colors.white70);
        px.r(hx + wxx * s, hy + 12 * s, 7 * s, 2 * s, const Color(0xFF8A5F33));
        px.dot(hx + wxx * s + 1 * s, hy + 12.6 * s, const Color(0xFFF2A5C0));
        px.dot(hx + wxx * s + 4 * s, hy + 12.6 * s, const Color(0xFFF6D96B));
      }
    }

    house(vw * 0.02, vh * 0.42, 1.5, const Color(0xFF4C7AB8));
    house(vw * 0.7, vh * 0.44, 1.4, const Color(0xFFC85C4E));
    house(vw * 0.17, vh * 0.365, 0.8, const Color(0xFFD8A44C));
    house(vw * 0.63, vh * 0.365, 0.75, const Color(0xFF54A05A));
    // 花・草の房
    for (var i = 0; i < 26; i++) {
      final fx = rng.nextDouble() * vw;
      if (fx > vw * 0.32 && fx < vw * 0.68) continue;
      final fy = vh * (0.5 + rng.nextDouble() * 0.46);
      if (i % 2 == 0) {
        px.flower(fx, fy,
            [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
      } else {
        px.r(fx, fy, 1, 2, const Color(0xFF539A39));
        px.r(fx + 1, fy - 1, 1, 2, const Color(0xFF7EC55E));
      }
    }
    // 主人公(後ろ姿・道の上)
    drawPixelSprite(canvas, heroineBackRows, heroinePalette, (vw / 2 - 11) * u,
        vh * 0.68 * u, 1.5 * u);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// パン屋の店先。dim=ミッション用に暗く。
// ─────────────────────────────────────────────────────────────
class _BakeryPainter extends CustomPainter {
  const _BakeryPainter({required this.dim});
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 160;
    final px = Px(canvas, u, snap: 0.625);
    final rng = math.Random(13);
    final vw = 160.0, vh = size.height / u;

    // 空 + 雲
    px.r(0, 0, vw, vh * 0.3, const Color(0xFF5EA9E8));
    px.noise(0, 0, vw, vh * 0.26,
        [const Color(0xFF6FB3EE), const Color(0xFF54A0E2)], 100, rng);
    for (var i = 0; i < 3; i++) {
      final x = rng.nextDouble() * vw;
      final y = 5 + rng.nextDouble() * vh * 0.12;
      px.oval(x, y, 9, 2.6, Colors.white);
      px.oval(x + 5, y - 1.6, 5, 2, Colors.white);
    }
    // 奥の緑
    px.r(0, vh * 0.28, vw, vh * 0.2, const Color(0xFF4B9C3E));
    px.noise(0, vh * 0.28, vw, vh * 0.2,
        [const Color(0xFF3E8A34), const Color(0xFF5CAD4C)], 380, rng);
    px.oval(vw * 0.85, vh * 0.34, 14, 9, const Color(0xFF3B9A31));
    px.ovalNoise(vw * 0.85, vh * 0.34, 13, 8,
        [const Color(0xFF2E8226), const Color(0xFF54B848)], 90, rng);
    // 地面(土 + 小石)
    px.r(0, vh * 0.46, vw, vh * 0.54, const Color(0xFFC9AE7E));
    px.noise(0, vh * 0.46, vw, vh * 0.54,
        [const Color(0xFFBBA073), const Color(0xFFD8C08A), const Color(0xFFB0976B)],
        700, rng);
    for (var i = 0; i < 20; i++) {
      px.oval(rng.nextDouble() * vw, vh * (0.5 + rng.nextDouble() * 0.48), 2, 1,
          const Color(0xFFA89066));
    }

    // 店舗
    final sx = -6.0, sy = vh * 0.14, sw = vw * 0.72, sh = vh * 0.36;
    // 壁(細かいレンガ)
    px.r(sx, sy, sw, sh, const Color(0xFFEADFC2));
    final brickH = sh / 12;
    for (var r0 = 0; r0 < 12; r0++) {
      final by = sy + r0 * brickH;
      px.r(sx, by + brickH - 1, sw, 1, const Color(0xFFD9C9A2));
      final off = r0.isEven ? 0.0 : brickH * 1.4;
      for (var bxx = sx + off; bxx < sx + sw; bxx += brickH * 2.8) {
        px.r(bxx, by, 1, brickH, const Color(0xFFD9C9A2));
      }
      // 色ムラのレンガ
      px.r(sx + ((r0 * 31) % (sw - 8)), by + 1, brickH * 2, brickH - 2,
          r0 % 3 == 0 ? const Color(0xFFF2E8CE) : const Color(0xFFE0D2A8));
    }
    // 屋根(赤瓦スカラップ)
    for (var r0 = 0; r0 < 3; r0++) {
      final ry = sy - 16 + r0 * 5.4;
      px.r(sx - 5, ry, sw + 10, 5.4,
          r0.isEven ? const Color(0xFFC85C4E) : const Color(0xFFB84C40));
      for (var sxx = sx - 5 + (r0.isEven ? 0.0 : 6.0); sxx < sx + sw + 5; sxx += 12) {
        px.oval(sxx + 3, ry + 5, 3, 1.6, const Color(0xFF9C3E34));
      }
    }
    px.r(sx - 5, sy - 16, sw + 10, 1.4, const Color(0xFF8A3229));
    // 看板(木板 + 縁)
    px.r(sx + sw * 0.18, sy - 9, sw * 0.5, 15, const Color(0xFF6E4A22));
    px.r(sx + sw * 0.2, sy - 7, sw * 0.46, 11, const Color(0xFFEDD9A5));
    px.noise(sx + sw * 0.2, sy - 7, sw * 0.46, 11,
        [const Color(0xFFE2CB92), const Color(0xFFF5E4B8)], 30, rng);
    // ひさし(赤白 + スカラップ裾 + 影)
    final ay = sy + sh * 0.28;
    for (var i = 0; i < 12; i++) {
      px.r(sx + i * sw / 12, ay, sw / 12, vh * 0.045,
          i.isEven ? const Color(0xFFC85C4E) : Colors.white);
      px.oval(sx + i * sw / 12 + sw / 24, ay + vh * 0.045, sw / 24, 1.6,
          i.isEven ? const Color(0xFFC85C4E) : Colors.white);
    }
    px.r(sx, ay + vh * 0.05, sw, 2, const Color(0x30000000));
    // ショーウィンドウ(棚2段 + パン)
    final wx = sx + sw * 0.08, wy = sy + sh * 0.44, ww = sw * 0.48, wh = sh * 0.42;
    px.r(wx - 2, wy - 2, ww + 4, wh + 4, const Color(0xFF54371A));
    px.r(wx, wy, ww, wh, const Color(0xFF7C5B36));
    for (var row = 0; row < 2; row++) {
      px.r(wx, wy + (row + 1) * wh / 2 - 2, ww, 2, const Color(0xFF54371A));
      for (var i = 0; i < 4; i++) {
        final bx2 = wx + 2 + i * ww / 4;
        final by2 = wy + 2 + row * wh / 2;
        px.oval(bx2 + ww / 10, by2 + wh / 8, ww / 10, wh / 9,
            const Color(0xFFD8A055));
        px.oval(bx2 + ww / 10 - 1, by2 + wh / 8 - 1, ww / 22, wh / 20,
            const Color(0xFFF2CB8E));
        px.dot(bx2 + ww / 10 + 2, by2 + wh / 8 + 1, const Color(0xFFB0763C));
      }
    }
    // ドア(緑・板目・アーチ)
    final dx = sx + sw * 0.66, dy = sy + sh * 0.4, dw = sw * 0.16, dh = sh * 0.6;
    px.oval(dx + dw / 2, dy + 2, dw / 2 + 1, 4, const Color(0xFF2E5234));
    px.r(dx - 1, dy + 2, dw + 2, dh - 2, const Color(0xFF2E5234));
    px.oval(dx + dw / 2, dy + 2, dw / 2, 3, const Color(0xFF3E6B44));
    px.r(dx, dy + 3, dw, dh - 3, const Color(0xFF3E6B44));
    for (var i = 1; i < 3; i++) {
      px.r(dx + i * dw / 3, dy + 4, 1, dh - 4, const Color(0xFF2E5234));
    }
    px.dot(dx + dw * 0.78, dy + dh * 0.5, const Color(0xFFE8C46B));
    // 黒板
    px.r(sx + 8, sy + sh + 4, vw * 0.14, vh * 0.13, const Color(0xFF6E4A22));
    px.r(sx + 10, sy + sh + 6, vw * 0.14 - 4, vh * 0.13 - 4,
        const Color(0xFF2E3230));
    px.r(sx + 12, sy + sh + 9, vw * 0.09, 1, Colors.white70);
    px.r(sx + 12, sy + sh + 13, vw * 0.07, 1, Colors.white54);
    px.oval(sx + 16, sy + sh + 19, 5, 2.6, const Color(0xFFD8A055));
    // ランプ
    px.r(sx + sw * 0.06, sy + 2, 1.6, 8, const Color(0xFF3A3A3A));
    px.r(sx + sw * 0.06 - 2, sy + 9, 5.6, 6, const Color(0xFF3A3A3A));
    px.r(sx + sw * 0.06 - 1, sy + 10, 3.6, 4, const Color(0xFFF2D96B));

    if (dim) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0x66101C3A));
    }
  }

  @override
  bool shouldRepaint(covariant _BakeryPainter old) => old.dim != dim;
}

// ─────────────────────────────────────────────────────────────
// キャラクター付きシーン(島の全景 + スプライト大)。
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
            // みぽりん(pose 0/1)は下部の会話ウィンドウに顔が隠れないよう
            // 腰から上が見える高さに置く
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

// ─────────────────────────────────────────────────────────────
// スマホ画面(招待状)。机の木目もドットで。
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
    final u = size.width / 160;
    final px = Px(canvas, u, snap: 0.625);
    final rng = math.Random(31);
    final vw = 160.0, vh = size.height / u;

    // 木目の机(板 + 節 + むら)
    for (var i = 0; i < 16; i++) {
      final y = i * vh / 16;
      px.r(0, y, vw, vh / 16,
          i.isEven ? const Color(0xFF9C7040) : const Color(0xFF8F6438));
      px.r(0, y, vw, 1, const Color(0xFF7A5530));
      for (var j = 0; j < 4; j++) {
        px.r(rng.nextDouble() * vw, y + 2 + rng.nextInt(3), 5, 1,
            const Color(0xFF7A5530));
      }
      if (i % 4 == 2) {
        px.oval(((i * 47) % 150).toDouble(), y + vh / 32, 2.4, 1.4,
            const Color(0xFF6E4A26));
      }
    }
    px.noise(0, 0, vw, vh,
        [const Color(0xFF8A5F33), const Color(0xFFA9793F)], 300, rng);
    // コーヒー(湯気つき)
    px.oval(vw * 0.09, vh * 0.1, 8, 6, const Color(0xFFE8E4DC));
    px.oval(vw * 0.09, vh * 0.1, 6, 4.4, const Color(0xFF5A3A1E));
    px.oval(vw * 0.09, vh * 0.095, 5, 3.4, const Color(0xFF7A5530));
    px.r(vw * 0.145, vh * 0.09, 3, 1.4, const Color(0xFFE8E4DC));
    for (var i = 0; i < 3; i++) {
      px.dot(vw * 0.07 + i * 2, vh * 0.04 - i % 2, Colors.white54);
    }
    // 観葉植物
    px.r(vw * 0.86, vh * 0.05, 12, 8, const Color(0xFFB56A4A));
    px.r(vw * 0.86, vh * 0.05, 12, 1.4, const Color(0xFF9A5539));
    for (var i = 0; i < 6; i++) {
      px.oval(vw * 0.86 + i * 2.4, vh * 0.03 - (i % 2) * 2, 3.4, 2,
          i.isEven ? const Color(0xFF3B9A31) : const Color(0xFF2E8226));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// きせかえ(主人公の服の配色バリエーション)。
// (名前, トップス, リボン, スカート) — AAP-64の色を使用。
// ─────────────────────────────────────────────────────────────
const kOutfits = <(String, Color, Color, Color)>[
  ('しろ', Colors.white, Color(0xFFE86A73), Color(0xFFB4202A)),
  ('さくら', Color(0xFFF5A097), Color(0xFFE86A73), Color(0xFFBC4A9B)),
  ('そら', Color(0xFFDAE0EA), Color(0xFF849BE4), Color(0xFF588DBE)),
  ('わかば', Color(0xFFCDF7E2), Color(0xFF5DAF8D), Color(0xFF328464)),
  ('ひまわり', Color(0xFFFEF3C0), Color(0xFFDF3E23), Color(0xFFF9A31B)),
];

/// きせかえを反映した主人公パレット。
Map<String, Color> heroinePaletteFor(int outfit) {
  final o = kOutfits[outfit.clamp(0, kOutfits.length - 1)];
  return {...heroinePalette, 'w': o.$2, 'r': o.$3, 'R': o.$4};
}
