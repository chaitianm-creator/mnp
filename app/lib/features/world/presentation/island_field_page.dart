import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 実践デザイナー島の村フィールド試作(/island)。
/// 参考: RPGツクール系の見下ろし型タイルマップ。
/// すべてコード描画(CustomPainter) — タイル定義は _rows の文字列を
/// 書き換えるだけでマップを編集できる。
///  G:草 P:石畳 W:川 B:橋 F:噴水 T:木 H:家(パン屋) D:パン屋の入口
///  S:砂地 K:看板
/// タップした場所へBFS経路探索で歩き、入口や看板に着くと会話が出る。
class IslandFieldPage extends StatefulWidget {
  const IslandFieldPage({super.key});

  @override
  State<IslandFieldPage> createState() => _IslandFieldPageState();
}

enum _Dialog { none, bakery, sign }

class _IslandFieldPageState extends State<IslandFieldPage> {
  static const _rows = [
    'WWTTGGPGGHHHH', // 0
    'WWTTGGPGGHHHH', // 1
    'WWTTGGPGGHDHH', // 2
    'WWGGGGPGGGPGG', // 3
    'WWGGGGPGGGPGG', // 4
    'WWGGPPPPPPPGG', // 5
    'WWGGPPPPPPGGG', // 6
    'WWGGPFFFPPGGG', // 7
    'BBPPPFFFPPPPP', // 8
    'WWGGPFFFPPGGG', // 9
    'WWGKPPPPPPGGG', // 10
    'WWGGGGPGGSSSG', // 11
    'WWGGGGPGGSSSG', // 12
    'WWTGGGPGGSSSG', // 13
    'WWTGGGPGGGGTG', // 14
    'WWGGGGPGGGGTG', // 15
    'WWWWWWbWWWWWW', // 16
    'WWWWWWbWWWWWW', // 17
  ];

  static int get cols => _rows[0].length;
  static int get rowCount => _rows.length;

  static String tileAt(int x, int y) =>
      (x < 0 || y < 0 || x >= cols || y >= rowCount) ? 'W' : _rows[y][x];

  static bool walkable(int x, int y) =>
      const {'G', 'P', 'B', 'b', 'S', 'D', 'K'}.contains(tileAt(x, y));

  // プレイヤー位置(タイル座標)
  int _px = 6, _py = 12;
  Timer? _walker;
  _Dialog _dialog = _Dialog.none;

  @override
  void dispose() {
    _walker?.cancel();
    super.dispose();
  }

  /// BFSで最短経路を求めてタップ先まで歩く
  void _walkTo(int tx, int ty) {
    if (!walkable(tx, ty)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('そこには行けないよ')));
      return;
    }
    // BFS
    final prev = <int, int>{};
    final start = _py * cols + _px, goal = ty * cols + tx;
    final q = Queue<int>()..add(start);
    final seen = {start};
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      if (cur == goal) break;
      final cx = cur % cols, cy = cur ~/ cols;
      for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
        final nx = cx + dx, ny = cy + dy;
        final n = ny * cols + nx;
        if (walkable(nx, ny) && seen.add(n)) {
          prev[n] = cur;
          q.add(n);
        }
      }
    }
    if (!seen.contains(goal)) return; // 到達不能
    // 経路復元
    final path = <int>[];
    for (int? cur = goal; cur != null && cur != start; cur = prev[cur]) {
      path.add(cur);
    }
    final steps = path.reversed.toList();

    _walker?.cancel();
    setState(() => _dialog = _Dialog.none);
    var i = 0;
    _walker = Timer.periodic(const Duration(milliseconds: 170), (t) {
      if (i >= steps.length) {
        t.cancel();
        _onArrive();
        return;
      }
      final s = steps[i++];
      setState(() {
        _px = s % cols;
        _py = s ~/ cols;
      });
    });
  }

  void _onArrive() {
    final tile = tileAt(_px, _py);
    if (tile == 'D') {
      setState(() => _dialog = _Dialog.bakery);
    } else if (tile == 'K') {
      setState(() => _dialog = _Dialog.sign);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10305E),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          // マップ全体が入るタイルサイズ(正方形)を計算
          final tile = math.min(c.maxWidth / cols, c.maxHeight / rowCount);
          final mapW = tile * cols, mapH = tile * rowCount;
          final ox = (c.maxWidth - mapW) / 2, oy = (c.maxHeight - mapH) / 2;

          return Stack(children: [
            // ── タイルマップ ──
            Positioned(
              left: ox,
              top: oy,
              width: mapW,
              height: mapH,
              child: GestureDetector(
                onTapDown: (d) {
                  final tx = (d.localPosition.dx / tile).floor();
                  final ty = (d.localPosition.dy / tile).floor();
                  _walkTo(tx, ty);
                },
                child: CustomPaint(
                  size: Size(mapW, mapH),
                  painter: _FieldMapPainter(rows: _rows, tile: tile),
                ),
              ),
            ),
            // ── プレイヤー ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              left: ox + _px * tile + tile * 0.1,
              top: oy + _py * tile - tile * 0.25,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(tile * 0.8, tile * 1.05),
                  painter: _PlayerPainter(),
                ),
              ),
            ),
            // ── パン屋の「!」マーカー ──
            Positioned(
              left: ox + 10 * tile + tile * 0.28,
              top: oy + 2 * tile - tile * 0.9,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: tile * 0.14, vertical: tile * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFB93B55), width: 2),
                  ),
                  child: Text('!',
                      style: TextStyle(
                          color: const Color(0xFFB93B55),
                          fontWeight: FontWeight.w900,
                          fontSize: tile * 0.5)),
                ),
              ),
            ),
            // ── 上部バー ──
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(children: [
                _chip('実践デザイナー島（試作）'),
                const SizedBox(width: 8),
                _chip('タップで移動'),
                const Spacer(),
                InkWell(
                  onTap: () => context.go('/map'),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10305E), width: 2),
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF10305E)),
                  ),
                ),
              ]),
            ),
            // ── 会話ウィンドウ(RPG様式) ──
            if (_dialog != _Dialog.none)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _DialogWindow(
                  speaker: _dialog == _Dialog.bakery ? 'パン屋さん' : 'かんばん',
                  text: _dialog == _Dialog.bakery
                      ? 'いらっしゃい〜 いらっしゃい〜…はぁ。\n実は毎日お店の前は人が通るのに、誰も入ってきてくれないんだ…。'
                      : '「実践デザイナー島」\nここでは、実践を通して一流のデザイナーを目指します。',
                  actions: _dialog == _Dialog.bakery
                      ? [
                          ('悩みを聞く（クエストへ）',
                              () => context.push('/daily-request')),
                          ('また今度', () => setState(() => _dialog = _Dialog.none)),
                        ]
                      : [
                          ('とじる', () => setState(() => _dialog = _Dialog.none)),
                        ],
                ),
              ),
          ]);
        }),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xE6101C3A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFC9A24B), width: 1.5),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// RPG様式の会話ウィンドウ(ストーリーページの金縁ヘッダーと同系の意匠)。
class _DialogWindow extends StatelessWidget {
  const _DialogWindow(
      {required this.speaker, required this.text, required this.actions});
  final String speaker;
  final String text;
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xF2101C3A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC9A24B), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE85C86),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(speaker,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.6)),
        const SizedBox(height: 10),
        Row(children: [
          for (final (label, onTap) in actions) ...[
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5AC8),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFF0D2F73), width: 2),
                  ),
                  child: Center(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
            if ((label, onTap) != actions.last) const SizedBox(width: 8),
          ],
        ]),
      ]),
    );
  }
}


/// タイルマップ描画(高解像度ドット: 1タイル=16x16サブピクセル・固定シード)。
class _FieldMapPainter extends CustomPainter {
  const _FieldMapPainter({required this.rows, required this.tile});
  final List<String> rows;
  final double tile;

  // ── パレット(参考画像の実測系) ──
  static const _grassA = Color(0xFF83C95A);
  static const _grassB = Color(0xFF77BE4E);
  static const _grassDark = Color(0xFF63A93F);
  static const _grassLight = Color(0xFF97D46C);
  static const _dirt = Color(0xFF8F9086);
  static const _stone1 = Color(0xFFC4C7BE);
  static const _stone2 = Color(0xFFB2B5AB);
  static const _stone3 = Color(0xFFA5A89E);
  static const _stoneHi = Color(0xFFD9DCD2);
  static const _water1 = Color(0xFF3E7FAA);
  static const _water2 = Color(0xFF37749C);
  static const _waterHi = Color(0xFF6FB1D8);
  static const _waterLo = Color(0xFF2C6086);
  static const _sand1 = Color(0xFFE9DCAB);
  static const _sand2 = Color(0xFFDECD93);
  static const _wood1 = Color(0xFFA9743C);
  static const _wood2 = Color(0xFF8E5E2E);
  static const _wood3 = Color(0xFF6E4A22);

  String _tileAt(int x, int y) {
    if (x < 0 || y < 0 || x >= rows[0].length || y >= rows.length) return 'W';
    return rows[y][x];
  }

  bool _isWater(String t) => t == 'W';
  bool _isLand(String t) => !_isWater(t);

  @override
  void paint(Canvas canvas, Size size) {
    final cols = rows[0].length;
    final u = tile / 16; // サブピクセル
    final p = Paint();

    Rect g(int x, int y, num gx, num gy, [num gw = 1, num gh = 1]) => Rect.fromLTWH(
        x * tile + gx * u, y * tile + gy * u, gw * u + 0.3, gh * u + 0.3);

    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < cols; x++) {
        final t = rows[y][x];
        final rng = math.Random(x * 131 + y * 977);
        switch (t) {
          case 'G':
          case 'T':
          case 'K':
            _grassTile(canvas, p, g, x, y, rng, decorate: t == 'G');
          case 'P':
          case 'D':
          case 'H':
            _cobbleTile(canvas, p, g, x, y, rng);
          case 'W':
            _waterTile(canvas, p, g, x, y, rng);
          case 'B':
            _bridgeTile(canvas, p, g, x, y, horizontal: true);
          case 'b':
            _bridgeTile(canvas, p, g, x, y, horizontal: false);
          case 'S':
            _sandTile(canvas, p, g, x, y, rng);
          case 'F':
            _cobbleTile(canvas, p, g, x, y, rng);
        }
      }
    }

    // ── 大きな構造物(タイルの上に重ねる) ──
    _drawFountain(canvas, p, u);
    _drawBakery(canvas, p, u);
    _drawSign(canvas, p, u, 3, 10);
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < cols; x++) {
        if (rows[y][x] == 'T') _drawTree(canvas, p, u, x, y);
      }
    }
    _drawStump(canvas, p, u, 10, 12);
  }

  // ── 草: 2色の下地 + むらノイズ + 草の房 + 花 ──
  void _grassTile(Canvas canvas, Paint p, Rect Function(int, int, num, num, [num, num]) g,
      int x, int y, math.Random rng, {required bool decorate}) {
    p.color = (x + y).isEven ? _grassA : _grassB;
    canvas.drawRect(g(x, y, 0, 0, 16, 16), p);
    for (var i = 0; i < 26; i++) {
      final gx = rng.nextInt(16), gy = rng.nextInt(16);
      p.color = rng.nextBool() ? _grassDark : _grassLight;
      canvas.drawRect(g(x, y, gx, gy, 1, 1), p);
    }
    // 草の房(3本の縦ピクセル)
    for (var i = 0; i < 2; i++) {
      if (rng.nextDouble() < 0.7) {
        final gx = 2 + rng.nextInt(11), gy = 3 + rng.nextInt(10);
        p.color = _grassDark;
        canvas.drawRect(g(x, y, gx, gy, 1, 3), p);
        canvas.drawRect(g(x, y, gx + 2, gy + 1, 1, 2), p);
        p.color = _grassLight;
        canvas.drawRect(g(x, y, gx + 1, gy - 1, 1, 3), p);
      }
    }
    // 花(十字5ピクセル + 中心)
    if (decorate && rng.nextDouble() < 0.30) {
      final gx = 3 + rng.nextInt(9), gy = 3 + rng.nextInt(9);
      final petal = [
        const Color(0xFFF2A5C0),
        Colors.white,
        const Color(0xFFF6D96B)
      ][rng.nextInt(3)];
      p.color = petal;
      canvas.drawRect(g(x, y, gx - 1, gy, 1, 1), p);
      canvas.drawRect(g(x, y, gx + 1, gy, 1, 1), p);
      canvas.drawRect(g(x, y, gx, gy - 1, 1, 1), p);
      canvas.drawRect(g(x, y, gx, gy + 1, 1, 1), p);
      p.color = const Color(0xFFF6D96B);
      canvas.drawRect(g(x, y, gx, gy, 1, 1), p);
    }
  }

  // ── 石畳: 目地 + 丸石(明暗3色) + ハイライト ──
  void _cobbleTile(Canvas canvas, Paint p, Rect Function(int, int, num, num, [num, num]) g,
      int x, int y, math.Random rng) {
    p.color = _dirt;
    canvas.drawRect(g(x, y, 0, 0, 16, 16), p);
    // 2x2の丸石(位置を半タイルずらして自然に)
    final stones = [
      (0.5, 0.5, 7.0, 6.5),
      (8.5, 1.0, 7.0, 6.0),
      (1.0, 8.5, 6.5, 6.5),
      (8.0, 8.0, 7.5, 7.0),
    ];
    for (final (sx, sy, sw, sh) in stones) {
      final shade = [_stone1, _stone2, _stone3][rng.nextInt(3)];
      p.color = shade;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              g(x, y, sx, sy, sw, sh), Radius.circular(tile * 0.14)),
          p);
      // 左上ハイライト
      p.color = _stoneHi;
      canvas.drawRect(g(x, y, sx + 1, sy + 1, sw - 3, 1), p);
      // 小石
      if (rng.nextDouble() < 0.4) {
        p.color = _stone3;
        canvas.drawRect(
            g(x, y, sx + 1 + rng.nextInt(3), sy + sh - 2, 2, 1), p);
      }
    }
  }

  // ── 水: 市松の下地 + 波ピクセル + 岸の際 ──
  void _waterTile(Canvas canvas, Paint p, Rect Function(int, int, num, num, [num, num]) g,
      int x, int y, math.Random rng) {
    p.color = (x + y).isEven ? _water1 : _water2;
    canvas.drawRect(g(x, y, 0, 0, 16, 16), p);
    for (var i = 0; i < 3; i++) {
      if (rng.nextDouble() < 0.8) {
        final gx = rng.nextInt(11), gy = 2 + rng.nextInt(12);
        p.color = _waterHi;
        canvas.drawRect(g(x, y, gx, gy, 4, 1), p);
        p.color = _waterLo;
        canvas.drawRect(g(x, y, gx + 1, gy + 1, 3, 1), p);
      }
    }
    // 岸の際: 隣が陸なら濃い縁と白い泡
    void shore(num gx, num gy, num gw, num gh, num fx, num fy, num fw, num fh) {
      p.color = _waterLo;
      canvas.drawRect(g(x, y, gx, gy, gw, gh), p);
      p.color = const Color(0xFFA8D8EE);
      canvas.drawRect(g(x, y, fx, fy, fw, fh), p);
    }

    if (_isLand(_tileAt(x, y - 1))) shore(0, 0, 16, 2, 2, 1, 3, 1);
    if (_isLand(_tileAt(x, y + 1))) shore(0, 14, 16, 2, 10, 15, 3, 1);
    if (_isLand(_tileAt(x - 1, y))) shore(0, 0, 2, 16, 1, 5, 1, 3);
    if (_isLand(_tileAt(x + 1, y))) shore(14, 0, 2, 16, 15, 9, 1, 3);
    // すいれん(まれに)
    if (rng.nextDouble() < 0.10 && !_isLand(_tileAt(x, y - 1))) {
      p.color = const Color(0xFF4F9E44);
      canvas.drawOval(g(x, y, 4, 6, 7, 5), p);
      p.color = _water2;
      canvas.drawRect(g(x, y, 7, 6, 2, 3), p); // 切れ込み
      if (rng.nextBool()) {
        p.color = const Color(0xFFF2A5C0);
        canvas.drawRect(g(x, y, 9, 5, 3, 2), p);
        p.color = Colors.white;
        canvas.drawRect(g(x, y, 10, 5, 1, 1), p);
      }
    }
  }

  // ── 橋: 板目 + 釘 + 両側の手すり ──
  void _bridgeTile(Canvas canvas, Paint p, Rect Function(int, int, num, num, [num, num]) g,
      int x, int y, {required bool horizontal}) {
    p.color = _wood1;
    canvas.drawRect(g(x, y, 0, 0, 16, 16), p);
    p.color = _wood2;
    if (horizontal) {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(g(x, y, i * 4 + 3, 0, 1, 16), p);
      }
      p.color = _wood3;
      canvas.drawRect(g(x, y, 0, 0, 16, 2), p);
      canvas.drawRect(g(x, y, 0, 14, 16, 2), p);
      p.color = const Color(0xFFC79059);
      canvas.drawRect(g(x, y, 1, 4, 2, 1), p);
      canvas.drawRect(g(x, y, 9, 10, 2, 1), p);
    } else {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(g(x, y, 0, i * 4 + 3, 16, 1), p);
      }
      p.color = _wood3;
      canvas.drawRect(g(x, y, 0, 0, 2, 16), p);
      canvas.drawRect(g(x, y, 14, 0, 2, 16), p);
      p.color = const Color(0xFFC79059);
      canvas.drawRect(g(x, y, 4, 2, 1, 2), p);
      canvas.drawRect(g(x, y, 10, 9, 1, 2), p);
    }
  }

  // ── 砂地: ノイズ + 縁 ──
  void _sandTile(Canvas canvas, Paint p, Rect Function(int, int, num, num, [num, num]) g,
      int x, int y, math.Random rng) {
    p.color = _sand1;
    canvas.drawRect(g(x, y, 0, 0, 16, 16), p);
    for (var i = 0; i < 14; i++) {
      p.color = rng.nextBool() ? _sand2 : const Color(0xFFF3E9C2);
      canvas.drawRect(g(x, y, rng.nextInt(16), rng.nextInt(16), 1, 1), p);
    }
    p.color = const Color(0xFFC9B678);
    if (_tileAt(x, y - 1) != 'S') canvas.drawRect(g(x, y, 0, 0, 16, 1), p);
    if (_tileAt(x, y + 1) != 'S') canvas.drawRect(g(x, y, 0, 15, 16, 1), p);
    if (_tileAt(x - 1, y) != 'S') canvas.drawRect(g(x, y, 0, 0, 1, 16), p);
    if (_tileAt(x + 1, y) != 'S') canvas.drawRect(g(x, y, 15, 0, 1, 16), p);
  }

  Rect _t(double u, num x, num y, num w, num h) =>
      Rect.fromLTWH(x * tile, y * tile, w * tile, h * tile);

  // ── 噴水(3x3): 石の縁 + 水面 + 中央の水柱としぶき ──
  void _drawFountain(Canvas canvas, Paint p, double u) {
    final rim = _t(u, 5, 7, 3, 3);
    p.color = _stone3;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rim, Radius.circular(u * 3)), p);
    p.color = _stone1;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rim.deflate(u * 1.2), Radius.circular(u * 2.5)),
        p);
    p.color = _stoneHi;
    canvas.drawRect(Rect.fromLTWH(rim.left + u * 2, rim.top + u * 1.4,
        rim.width - u * 10, u * 1.1), p);
    // 水面
    p.color = const Color(0xFF57A8D8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rim.deflate(u * 4), Radius.circular(u * 2)), p);
    p.color = const Color(0xFF8FD0F0);
    canvas.drawRect(Rect.fromLTWH(rim.left + u * 6, rim.top + u * 9, u * 6, u * 1.2), p);
    canvas.drawRect(Rect.fromLTWH(rim.left + u * 28, rim.top + u * 34, u * 8, u * 1.2), p);
    // 台座と水柱
    final c = rim.center;
    p.color = _stone2;
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, u * 6), width: u * 14, height: u * 6), p);
    p.color = Colors.white;
    canvas.drawRect(Rect.fromCenter(center: c, width: u * 4, height: u * 16), p);
    p.color = const Color(0xFFCFEBFA);
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, -u * 9), width: u * 11, height: u * 7), p);
    // しぶき
    p.color = Colors.white;
    for (final (dx, dy) in const [(-8, -4), (8, -5), (-6, 3), (7, 4), (0, -13)]) {
      canvas.drawRect(
          Rect.fromCenter(center: c.translate(u * dx, u * dy), width: u * 1.4, height: u * 1.4),
          p);
    }
  }

  // ── パン屋: 瓦屋根 + レンガ壁 + アーチ扉 + 窓と花箱 + 看板 ──
  void _drawBakery(Canvas canvas, Paint p, double u) {
    // 壁
    final wall = _t(u, 9.0, 0.7, 4.0, 2.4);
    p.color = const Color(0xFFC17037);
    canvas.drawRect(wall, p);
    // レンガ(互い違い)
    final brickH = u * 4.0;
    for (var r = 0; r < 10; r++) {
      final by = wall.top + r * brickH;
      if (by > wall.bottom - brickH * 0.5) break;
      p.color = const Color(0xFF9A521F);
      canvas.drawRect(Rect.fromLTWH(wall.left, by + brickH - u, wall.width, u * 0.8), p);
      final off = r.isEven ? 0.0 : brickH;
      for (var bx = wall.left + off; bx < wall.right; bx += brickH * 2) {
        canvas.drawRect(Rect.fromLTWH(bx, by, u * 0.8, brickH), p);
      }
      // 明るいレンガを散らす
      p.color = const Color(0xFFD08148);
      canvas.drawRect(Rect.fromLTWH(
          wall.left + ((r * 37) % 48) * u, by + u, u * 3, brickH - u * 2), p);
    }
    // 屋根(瓦: 2色の段々 + 棟)
    final roof = _t(u, 8.7, -0.1, 4.6, 1.0);
    for (var r = 0; r < 4; r++) {
      p.color = r.isEven ? const Color(0xFF51648C) : const Color(0xFF46577D);
      canvas.drawRect(Rect.fromLTWH(roof.left, roof.top + r * roof.height / 4,
          roof.width, roof.height / 4 + 0.5), p);
      p.color = const Color(0xFF3B4A6B);
      for (var sx = roof.left + (r.isEven ? 0 : u * 2); sx < roof.right; sx += u * 4) {
        canvas.drawRect(Rect.fromLTWH(sx, roof.top + r * roof.height / 4, u * 0.7,
            roof.height / 4), p);
      }
    }
    p.color = const Color(0xFF2F3C57);
    canvas.drawRect(Rect.fromLTWH(roof.left, roof.top, roof.width, u * 1.2), p);
    // 軒の影
    p.color = const Color(0x40202020);
    canvas.drawRect(Rect.fromLTWH(wall.left, wall.top, wall.width, u * 1.5), p);
    // 窓(枠 + 十字桟 + 花箱)
    for (final wx in [11.3, 12.2]) {
      final win = _t(u, wx, 1.15, 0.62, 0.62);
      p.color = const Color(0xFFEADFC2);
      canvas.drawRect(win.inflate(u * 0.9), p);
      p.color = const Color(0xFFF9E9A8);
      canvas.drawRect(win, p);
      p.color = const Color(0xFFB8A26B);
      canvas.drawRect(Rect.fromLTWH(win.left, win.center.dy - u * 0.35, win.width, u * 0.7), p);
      canvas.drawRect(Rect.fromLTWH(win.center.dx - u * 0.35, win.top, u * 0.7, win.height), p);
      // 花箱
      p.color = _wood2;
      canvas.drawRect(Rect.fromLTWH(win.left - u, win.bottom + u * 0.6, win.width + u * 2, u * 2), p);
      p.color = const Color(0xFFF2A5C0);
      canvas.drawRect(Rect.fromLTWH(win.left, win.bottom + u * 0.2, u * 1.4, u * 1.2), p);
      p.color = const Color(0xFFF6D96B);
      canvas.drawRect(Rect.fromLTWH(win.left + u * 3, win.bottom + u * 0.2, u * 1.4, u * 1.2), p);
    }
    // アーチ扉(x10,y2 のタイルへ)
    final door = _t(u, 10.12, 1.8, 0.76, 1.2);
    p.color = const Color(0xFF4E351B);
    canvas.drawRRect(
        RRect.fromRectAndCorners(door.inflate(u * 0.8),
            topLeft: Radius.circular(u * 7), topRight: Radius.circular(u * 7)),
        p);
    p.color = _wood2;
    canvas.drawRRect(
        RRect.fromRectAndCorners(door,
            topLeft: Radius.circular(u * 6), topRight: Radius.circular(u * 6)),
        p);
    p.color = _wood3;
    for (var i = 1; i < 4; i++) {
      canvas.drawRect(Rect.fromLTWH(door.left + i * door.width / 4, door.top + u * 2,
          u * 0.6, door.height - u * 2), p);
    }
    // 丸窓とノブ
    p.color = const Color(0xFFF9E9A8);
    canvas.drawCircle(Offset(door.center.dx, door.top + u * 4), u * 1.6, p);
    p.color = const Color(0xFFE8C46B);
    canvas.drawCircle(Offset(door.right - u * 1.6, door.center.dy + u * 2), u * 0.8, p);
    // 吊り看板(パン)
    final sign = _t(u, 9.15, 0.75, 0.75, 0.55);
    p.color = _wood3;
    canvas.drawRect(Rect.fromLTWH(sign.center.dx - u * 0.4, sign.top - u * 2, u * 0.8, u * 2), p);
    p.color = const Color(0xFFEDD9A5);
    canvas.drawRRect(RRect.fromRectAndRadius(sign, Radius.circular(u * 1.2)), p);
    p.color = _wood3;
    canvas.drawRRect(
        RRect.fromRectAndRadius(sign, Radius.circular(u * 1.2)),
        Paint()
          ..color = _wood3
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.7);
    p.color = const Color(0xFFB07B3E);
    canvas.drawOval(Rect.fromCenter(center: sign.center, width: sign.width * 0.62, height: sign.height * 0.5), p);
    p.color = const Color(0xFFE5B877);
    canvas.drawRect(Rect.fromCenter(center: sign.center.translate(0, -u * 0.3), width: sign.width * 0.4, height: u * 0.6), p);
  }

  // ── 看板 ──
  void _drawSign(Canvas canvas, Paint p, double u, int x, int y) {
    p.color = _wood3;
    canvas.drawRect(_t(u, x + 0.42, y + 0.35, 0.16, 0.6), p);
    final board = _t(u, x + 0.06, y + 0.02, 0.88, 0.5);
    p.color = _wood1;
    canvas.drawRRect(RRect.fromRectAndRadius(board, Radius.circular(u * 1.2)), p);
    p.color = _wood3;
    canvas.drawRRect(
        RRect.fromRectAndRadius(board, Radius.circular(u * 1.2)),
        Paint()
          ..color = _wood3
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.7);
    p.color = const Color(0xFFEDD9A5);
    canvas.drawRect(Rect.fromLTWH(board.left + u * 1.6, board.top + u * 1.8, board.width - u * 3.2, u * 1.1), p);
    canvas.drawRect(Rect.fromLTWH(board.left + u * 1.6, board.top + u * 4.2, board.width - u * 3.2, u * 1.1), p);
  }

  // ── 木: 3層の茂み + 明るい房 + 幹 ──
  void _drawTree(Canvas canvas, Paint p, double u, int x, int y) {
    // 幹
    p.color = _wood3;
    canvas.drawRect(_t(u, x + 0.42, y + 0.58, 0.16, 0.36), p);
    p.color = _wood2;
    canvas.drawRect(_t(u, x + 0.42, y + 0.58, 0.07, 0.36), p);
    // 茂み(下層ほど濃い)
    p.color = const Color(0xFF25691F);
    canvas.drawOval(_t(u, x + 0.04, y + 0.26, 0.92, 0.5), p);
    p.color = const Color(0xFF2E8226);
    canvas.drawOval(_t(u, x + 0.08, y + 0.1, 0.84, 0.5), p);
    p.color = const Color(0xFF3B9A31);
    canvas.drawOval(_t(u, x + 0.18, y + 0.02, 0.64, 0.42), p);
    // 明るい房(ドットのクラスタ)
    p.color = const Color(0xFF5FBE4C);
    final rng = math.Random(x * 7 + y * 13);
    for (var i = 0; i < 6; i++) {
      final gx = 3 + rng.nextInt(10), gy = 1 + rng.nextInt(8);
      canvas.drawRect(Rect.fromLTWH(x * tile + gx * u, y * tile + gy * u, u * 2, u * 1.4), p);
    }
    // 実(まれに)
    if (rng.nextBool()) {
      p.color = const Color(0xFFE8556A);
      canvas.drawRect(Rect.fromLTWH(x * tile + u * 5, y * tile + u * 6, u * 1.4, u * 1.4), p);
      canvas.drawRect(Rect.fromLTWH(x * tile + u * 10, y * tile + u * 3, u * 1.4, u * 1.4), p);
    }
  }

  // ── 切り株(年輪つき) ──
  void _drawStump(Canvas canvas, Paint p, double u, int x, int y) {
    p.color = const Color(0xFF7C5326);
    canvas.drawOval(_t(u, x + 0.16, y + 0.22, 0.68, 0.56), p);
    p.color = const Color(0xFFDDB77E);
    canvas.drawOval(_t(u, x + 0.24, y + 0.28, 0.52, 0.42), p);
    p.color = const Color(0xFFB88F53);
    canvas.drawOval(
        _t(u, x + 0.33, y + 0.35, 0.34, 0.27),
        Paint()
          ..color = const Color(0xFFB88F53)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.7);
    canvas.drawOval(
        _t(u, x + 0.42, y + 0.42, 0.16, 0.13),
        Paint()
          ..color = const Color(0xFFB88F53)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.7);
  }

  @override
  bool shouldRepaint(covariant _FieldMapPainter old) =>
      old.tile != tile || old.rows != rows;
}

/// プレイヤー(主人公: 12x16ドットのスプライト定義)。
///  h:髪 H:髪ハイライト f:肌 e:目 b:ほお w:シャツ r:リボン R:スカート s:くつ
class _PlayerPainter extends CustomPainter {
  static const _sprite = [
    '...hhhhhh...',
    '..hHHHHhhh..',
    '.hhhhhhhhhh.',
    '.hhffffffhh.',
    '.hfeffffefh.',
    '.hffffffffh.',
    '.hfbffffbfh.',
    '..ffffffff..',
    '..wwwwwwww..',
    '.fwwwrrwwwf.',
    '.fwwwwwwwwf.',
    '..RRRRRRRR..',
    '.RRRRRRRRRR.',
    '..ff....ff..',
    '..ff....ff..',
    '..ss....ss..',
  ];

  static const _palette = {
    'h': Color(0xFF7A4A22),
    'H': Color(0xFF9A6534),
    'f': Color(0xFFF6D7B8),
    'e': Color(0xFF3E2410),
    'b': Color(0xFFF0A8A0),
    'w': Colors.white,
    'r': Color(0xFFD9494F),
    'R': Color(0xFFB33A4E),
    's': Color(0xFF5A3A1E),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final uw = size.width / 12, uh = size.height / 16;
    final p = Paint();
    // 影
    p.color = Colors.black26;
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.9, size.width * 0.76,
            size.height * 0.12),
        p);
    for (var y = 0; y < _sprite.length; y++) {
      for (var x = 0; x < 12; x++) {
        final ch = _sprite[y][x];
        final color = _palette[ch];
        if (color == null) continue;
        p.color = color;
        canvas.drawRect(
            Rect.fromLTWH(x * uw, y * uh, uw + 0.3, uh + 0.3), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
