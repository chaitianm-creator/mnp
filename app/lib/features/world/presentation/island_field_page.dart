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

/// タイルマップ描画(固定シード・ちらつきなし)。
class _FieldMapPainter extends CustomPainter {
  const _FieldMapPainter({required this.rows, required this.tile});
  final List<String> rows;
  final double tile;

  static const _grass = Color(0xFF7EC850);
  static const _grassDark = Color(0xFF6FB945);
  static const _stone = Color(0xFFB9BCB4);
  static const _stoneDark = Color(0xFFA3A69E);
  static const _stoneLine = Color(0xFF8E9189);
  static const _water = Color(0xFF3C7EA8);
  static const _waterDark = Color(0xFF356F95);
  static const _sand = Color(0xFFE7D9A8);
  static const _wood = Color(0xFF9C6B35);
  static const _woodDark = Color(0xFF6E4A22);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(5);
    final p = Paint();
    final cols = rows[0].length;

    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < cols; x++) {
        final r = Rect.fromLTWH(x * tile, y * tile, tile + 0.5, tile + 0.5);
        final t = rows[y][x];
        switch (t) {
          case 'G':
          case 'T':
          case 'K':
            p.color = (x + y).isEven ? _grass : _grassDark;
            canvas.drawRect(r, p);
          case 'P':
          case 'F':
          case 'D':
          case 'H':
            p.color = (x + y).isEven ? _stone : _stoneDark;
            canvas.drawRect(r, p);
            // 石畳の丸石
            p.color = _stoneLine;
            for (var i = 0; i < 3; i++) {
              canvas.drawCircle(
                  Offset(r.left + (0.2 + 0.3 * i) * tile,
                      r.top + (0.25 + 0.25 * i) * tile),
                  tile * 0.06,
                  p);
            }
          case 'W':
            p.color = (x + y).isEven ? _water : _waterDark;
            canvas.drawRect(r, p);
          case 'B':
          case 'b':
            p.color = _wood;
            canvas.drawRect(r, p);
            p.color = _woodDark;
            if (t == 'B') {
              for (var i = 1; i < 4; i++) {
                canvas.drawRect(
                    Rect.fromLTWH(r.left + i * tile / 4, r.top, tile * 0.06,
                        tile),
                    p);
              }
            } else {
              for (var i = 1; i < 4; i++) {
                canvas.drawRect(
                    Rect.fromLTWH(r.left, r.top + i * tile / 4, tile,
                        tile * 0.06),
                    p);
              }
            }
          case 'S':
            p.color = _sand;
            canvas.drawRect(r, p);
        }
        // 草むらの点々
        if (t == 'G' && rng.nextDouble() < 0.3) {
          p.color = rng.nextBool()
              ? const Color(0xFFF2A5C0)
              : const Color(0xFF5DA53A);
          canvas.drawCircle(
              Offset(r.left + rng.nextDouble() * tile,
                  r.top + rng.nextDouble() * tile),
              tile * 0.07,
              p);
        }
        // 川面のきらめき
        if (t == 'W' && rng.nextDouble() < 0.18) {
          p.color = const Color(0xFF7FB9E0);
          canvas.drawRect(
              Rect.fromLTWH(r.left + rng.nextDouble() * tile * 0.6,
                  r.top + rng.nextDouble() * tile * 0.8, tile * 0.32,
                  tile * 0.08),
              p);
        }
      }
    }

    // ── 大きな構造物 ──
    _drawFountain(canvas);
    _drawBakery(canvas);
    _drawSign(canvas, 3, 10);
    // 木
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < cols; x++) {
        if (rows[y][x] == 'T') _drawTree(canvas, x, y);
      }
    }
    // 砂地の切り株
    _drawStump(canvas, 10, 12);
  }

  Rect _tileRect(num x, num y, [num w = 1, num h = 1]) =>
      Rect.fromLTWH(x * tile, y * tile, w * tile, h * tile);

  void _drawFountain(Canvas canvas) {
    final p = Paint();
    final pool = _tileRect(5, 7, 3, 3);
    // 縁石
    p.color = const Color(0xFF8E9189);
    canvas.drawRect(pool.inflate(tile * 0.08), p);
    // 水
    p.color = const Color(0xFF57A8D8);
    canvas.drawRect(pool.deflate(tile * 0.12), p);
    p.color = const Color(0xFF8FD0F0);
    canvas.drawRect(
        Rect.fromCenter(
            center: pool.center.translate(-tile * 0.5, tile * 0.5),
            width: tile * 0.5,
            height: tile * 0.12),
        p);
    // 噴水柱と水しぶき
    p.color = Colors.white;
    canvas.drawRect(
        Rect.fromCenter(
            center: pool.center, width: tile * 0.28, height: tile * 0.9),
        p);
    p.color = const Color(0xFFCFEBFA);
    canvas.drawCircle(pool.center.translate(0, -tile * 0.5), tile * 0.3, p);
  }

  void _drawBakery(Canvas canvas) {
    final p = Paint();
    // 壁(9..12 x 0..2)
    final wall = _tileRect(9, 0.4, 4, 2.6);
    p.color = const Color(0xFFB5652F);
    canvas.drawRect(wall, p);
    // レンガ目地
    p.color = const Color(0xFF8E4C20);
    for (var i = 1; i < 5; i++) {
      canvas.drawRect(
          Rect.fromLTWH(wall.left, wall.top + i * wall.height / 5,
              wall.width, tile * 0.05),
          p);
    }
    // 屋根
    p.color = const Color(0xFF4A5A78);
    canvas.drawRect(_tileRect(8.8, 0, 4.4, 0.7), p);
    p.color = const Color(0xFF394760);
    canvas.drawRect(_tileRect(8.8, 0, 4.4, 0.22), p);
    // 窓
    p.color = const Color(0xFFF6E6B0);
    canvas.drawRect(_tileRect(11.2, 1.1, 0.6, 0.6), p);
    canvas.drawRect(_tileRect(12.1, 1.1, 0.6, 0.6), p);
    // 入口ドア(x10, y2)
    p.color = const Color(0xFF6E4A22);
    final door = _tileRect(10.1, 1.9, 0.8, 1.1);
    canvas.drawRRect(
        RRect.fromRectAndCorners(door,
            topLeft: Radius.circular(tile * 0.4),
            topRight: Radius.circular(tile * 0.4)),
        p);
    // 看板(パンの絵)
    p.color = const Color(0xFFF2D8A0);
    canvas.drawRect(_tileRect(9.15, 0.75, 0.7, 0.5), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawOval(_tileRect(9.3, 0.87, 0.4, 0.26), p);
  }

  void _drawSign(Canvas canvas, int x, int y) {
    final p = Paint();
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(_tileRect(x + 0.42, y + 0.4, 0.16, 0.55), p);
    p.color = const Color(0xFF9C6B35);
    canvas.drawRect(_tileRect(x + 0.1, y + 0.05, 0.8, 0.45), p);
    p.color = const Color(0xFFE8D5A8);
    canvas.drawRect(_tileRect(x + 0.18, y + 0.14, 0.64, 0.08), p);
    canvas.drawRect(_tileRect(x + 0.18, y + 0.28, 0.64, 0.08), p);
  }

  void _drawTree(Canvas canvas, int x, int y) {
    final p = Paint();
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(_tileRect(x + 0.4, y + 0.6, 0.2, 0.35), p);
    p.color = const Color(0xFF2E7D32);
    canvas.drawOval(_tileRect(x + 0.05, y + 0.05, 0.9, 0.7), p);
    p.color = const Color(0xFF43A047);
    canvas.drawOval(_tileRect(x + 0.15, y + 0.1, 0.4, 0.28), p);
  }

  void _drawStump(Canvas canvas, int x, int y) {
    final p = Paint();
    p.color = const Color(0xFF9C6B35);
    canvas.drawOval(_tileRect(x + 0.2, y + 0.25, 0.6, 0.5), p);
    p.color = const Color(0xFFD9B37C);
    canvas.drawOval(_tileRect(x + 0.3, y + 0.33, 0.4, 0.34), p);
  }

  @override
  bool shouldRepaint(covariant _FieldMapPainter old) =>
      old.tile != tile || old.rows != rows;
}

/// プレイヤー(主人公: 茶髪・白シャツ・赤スカート)。
class _PlayerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;
    // 影
    p.color = Colors.black26;
    canvas.drawOval(
        Rect.fromLTWH(w * 0.15, h * 0.88, w * 0.7, h * 0.12), p);
    // 足
    p.color = const Color(0xFF6E4A22);
    canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.78, w * 0.16, h * 0.12), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.56, h * 0.78, w * 0.16, h * 0.12), p);
    // スカート
    p.color = const Color(0xFFB33A4E);
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.6, w * 0.6, h * 0.2), p);
    // シャツ
    p.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(w * 0.24, h * 0.42, w * 0.52, h * 0.2), p);
    // 腕
    p.color = const Color(0xFFF6D7B8);
    canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.44, w * 0.12, h * 0.16), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.76, h * 0.44, w * 0.12, h * 0.16), p);
    // 顔
    canvas.drawRect(Rect.fromLTWH(w * 0.26, h * 0.16, w * 0.48, h * 0.28), p);
    // 髪
    p.color = const Color(0xFF7A4A22);
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.06, w * 0.6, h * 0.16), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.14, w * 0.14, h * 0.28), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.68, h * 0.14, w * 0.14, h * 0.28), p);
    // 目
    p.color = const Color(0xFF3E2410);
    canvas.drawRect(Rect.fromLTWH(w * 0.36, h * 0.28, w * 0.07, h * 0.07), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.57, h * 0.28, w * 0.07, h * 0.07), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
