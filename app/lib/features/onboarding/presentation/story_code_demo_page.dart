import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ストーリー第1話ページ1(寝室)を「コード描画」で再現した試作(/story-demo)。
/// 背景はCustomPainter(仮想96x168ピクセルのドット絵)、
/// ヘッダー・吹き出し・ボタンはウィジェットで描画 — 文言はコード側で自由に変更できる。
class StoryCodeDemoPage extends StatelessWidget {
  const StoryCodeDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2440),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/story/ep1'),
        child: Stack(children: [
          // ── 寝室のドット絵(コード描画) ──
          const Positioned.fill(
            child: CustomPaint(painter: _BedroomPainter()),
          ),
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 10),
              // ── 話数ヘッダー(金縁の板) ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF15254D),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFFC9A24B), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(children: [
                  const Text('第一話',
                      style: TextStyle(
                          color: Color(0xFFF2D96B),
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  const Text('実践デザイナー島へようこそ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 18),
              // ── 吹き出し(コード描画なので文言変更が即反映) ──
              Align(
                alignment: const Alignment(0.35, 0),
                child: CustomPaint(
                  painter: _BubbleTail(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF6E5),
                      border: Border.all(
                          color: const Color(0xFF3A2C1A), width: 2.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('ぐーすぴー…',
                        style: TextStyle(
                            color: Color(0xFF3A2C1A),
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const Spacer(),
              // ── 次へ(青ピクセルボタン) ──
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => context.go('/story/ep1'),
                  child: Container(
                    width: 230,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E5AC8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF0D2F73), width: 3),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFF0D2F73), offset: Offset(0, 3)),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 1.5),
                      ),
                      child: const Center(
                        child: Text('次へ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BubbleTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height - 1)
      ..lineTo(size.width * 0.2 - 14, size.height + 16)
      ..lineTo(size.width * 0.2 + 18, size.height - 1)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF3A2C1A));
    final inner = Path()
      ..moveTo(size.width * 0.2 + 3, size.height - 2)
      ..lineTo(size.width * 0.2 - 8, size.height + 11)
      ..lineTo(size.width * 0.2 + 13, size.height - 2)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFDF6E5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 夜の寝室(仮想96x168ピクセル)。BoxFit.cover相当で画面に合わせる。
class _BedroomPainter extends CustomPainter {
  const _BedroomPainter();

  static const _wall = Color(0xFF8F7A57);
  static const _wallDark = Color(0xFF7C6949);
  static const _floor1 = Color(0xFF8A5F33);
  static const _floor2 = Color(0xFF7C5329);
  static const _floorLine = Color(0xFF64431F);
  static const _wood = Color(0xFF9C6B35);
  static const _woodDark = Color(0xFF6E4A22);
  static const _night = Color(0xFF16244E);
  static const _pink1 = Color(0xFFF2B7C6);
  static const _pink2 = Color(0xFFE898AF);

  @override
  void paint(Canvas canvas, Size size) {
    // 仮想ピクセル: 96x168 を画面内に収める(contain)
    final u = math.min(size.width / 96, size.height / 168);
    final ox = (size.width - 96 * u) / 2;
    final oy = (size.height - 168 * u) / 2;
    final p = Paint();
    final rng = math.Random(9);

    Rect r(num x, num y, num w, num h) =>
        Rect.fromLTWH(ox + x * u, oy + y * u, w * u + 0.4, h * u + 0.4);

    // ── 壁と床 ──
    p.color = _wall;
    canvas.drawRect(r(-8, -20, 112, 84), p);
    for (var i = 0; i < 120; i++) {
      p.color = rng.nextBool() ? _wallDark : const Color(0xFF9A8562);
      canvas.drawRect(r(-8 + rng.nextInt(112), -20 + rng.nextInt(84), 1, 1), p);
    }
    // 床(横板)
    for (var i = 0; i < 14; i++) {
      p.color = i.isEven ? _floor1 : _floor2;
      canvas.drawRect(r(-8, 64 + i * 8, 112, 8), p);
      p.color = _floorLine;
      canvas.drawRect(r(-8, 64 + i * 8, 112, 0.8), p);
      // 板の継ぎ目
      for (var j = 0; j < 3; j++) {
        canvas.drawRect(r(-8 + ((i * 37 + j * 41) % 110), 64 + i * 8 + 2, 0.8, 4), p);
      }
    }
    // 幅木
    p.color = _woodDark;
    canvas.drawRect(r(-8, 62, 112, 2.4), p);

    // ── 窓(夜空・月・カーテン) ──
    p.color = _woodDark;
    canvas.drawRect(r(14, 2, 34, 30), p);
    p.color = _night;
    canvas.drawRect(r(16, 4, 30, 26), p);
    // 星
    p.color = Colors.white;
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(r(17 + rng.nextInt(27), 5 + rng.nextInt(12), 1, 1), p);
    }
    // 月(三日月)
    p.color = const Color(0xFFF2D96B);
    canvas.drawCircle(Offset(ox + 27 * u, oy + 11 * u), 4.2 * u, p);
    p.color = _night;
    canvas.drawCircle(Offset(ox + 29 * u, oy + 9.6 * u), 3.6 * u, p);
    // 木のシルエット
    p.color = const Color(0xFF1E4A32);
    canvas.drawOval(r(16, 22, 12, 9), p);
    canvas.drawOval(r(30, 24, 16, 8), p);
    // 桟
    p.color = _wood;
    canvas.drawRect(r(30.4, 4, 1.4, 26), p);
    canvas.drawRect(r(16, 16, 30, 1.4), p);
    // カーテン(ひだ + 房かけ)
    for (final cx in [10.0, 46.0]) {
      p.color = _pink1;
      canvas.drawRect(r(cx, 1, 6, 34), p);
      p.color = _pink2;
      canvas.drawRect(r(cx + 1.6, 1, 1.4, 34), p);
      canvas.drawRect(r(cx + 4.2, 1, 1.2, 34), p);
      p.color = _pink2;
      canvas.drawRect(r(cx - 0.6, 20, 7.2, 3), p); // タッセル
    }
    p.color = _woodDark;
    canvas.drawRect(r(8, 0, 46, 1.6), p); // カーテンレール

    // ── 壁の額(島の絵と花の絵) ──
    _frame(canvas, p, r, 1, 8, 9, 8, const Color(0xFF3E7FAA), flower: false);
    _frame(canvas, p, r, 1, 22, 9, 8, const Color(0xFFDCE9D5), flower: true);

    // ── 本棚(右) ──
    p.color = _woodDark;
    canvas.drawRect(r(66, -2, 28, 74), p);
    p.color = _wood;
    canvas.drawRect(r(67.4, -0.5, 25.2, 71), p);
    for (var shelf = 0; shelf < 3; shelf++) {
      final sy = 6 + shelf * 22;
      p.color = const Color(0xFF54371A);
      canvas.drawRect(r(68, sy, 24, 16), p); // 棚内の陰
      p.color = _woodDark;
      canvas.drawRect(r(67.4, sy + 16, 25.2, 2.4), p); // 棚板
      // 本(色とりどりの背表紙) / 一部は小物
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
          // 植木鉢や小箱
          p.color = const Color(0xFF4C7AB8);
          canvas.drawRect(r(bx, sy + 10, 5, 6), p);
          p.color = const Color(0xFF54A05A);
          canvas.drawRect(r(bx + 1, sy + 5, 3, 5), p);
          canvas.drawRect(r(bx - 0.6, sy + 7, 2.4, 2.4), p);
          canvas.drawRect(r(bx + 3.2, sy + 7, 2.4, 2.4), p);
          bx += 7;
        }
        k++;
      }
    }

    // ── ベッド ──
    // ヘッドボード
    p.color = _woodDark;
    canvas.drawRect(r(18, 40, 40, 20), p);
    p.color = _wood;
    canvas.drawRect(r(19.4, 41.4, 37.2, 17), p);
    p.color = const Color(0xFFB07B3E);
    canvas.drawRect(r(19.4, 41.4, 37.2, 3), p);
    // 支柱(玉飾り)
    for (final px in [17.0, 56.5]) {
      p.color = _woodDark;
      canvas.drawRect(r(px, 38, 2.6, 24), p);
      canvas.drawCircle(Offset(ox + (px + 1.3) * u, oy + 37.5 * u), 2.2 * u, p);
      p.color = _wood;
      canvas.drawCircle(Offset(ox + (px + 0.9) * u, oy + 37.1 * u), 1.0 * u, p);
    }
    // マットレスと枕
    p.color = const Color(0xFFE9E4EF);
    canvas.drawRect(r(18, 58, 40, 26), p);
    p.color = Colors.white;
    canvas.drawRRect(
        RRect.fromRectAndRadius(r(21, 55, 20, 10), Radius.circular(3 * u)), p);
    p.color = const Color(0xFFD5CEDF);
    canvas.drawRect(r(21, 62, 20, 2), p);
    // 掛け布団(ギンガムチェック)
    for (var cy = 0; cy < 7; cy++) {
      for (var cx = 0; cx < 10; cx++) {
        p.color = ((cx + cy) % 2 == 0)
            ? const Color(0xFFF0A8BC)
            : const Color(0xFFF7CBD6);
        canvas.drawRect(r(18 + cx * 4, 84 + cy * 4, 4, 4), p);
      }
    }
    // チェックの重なり色
    p.color = const Color(0x33FFFFFF);
    for (var cx = 0; cx < 5; cx++) {
      canvas.drawRect(r(18 + cx * 8 + 2, 84, 1.2, 28), p);
    }
    // 布団の縁と足元ボード
    p.color = const Color(0xFFE898AF);
    canvas.drawRect(r(18, 84, 40, 2), p);
    p.color = _woodDark;
    canvas.drawRect(r(17, 112, 42, 4), p);
    p.color = _wood;
    canvas.drawRect(r(17.8, 112.8, 40.4, 2.4), p);

    // ── 眠る女の子 ──
    // 髪(枕の上に広がる)
    p.color = const Color(0xFF6E4423);
    canvas.drawOval(r(24, 52, 16, 12), p);
    canvas.drawOval(r(22, 57, 8, 8), p);
    canvas.drawOval(r(35, 57, 7, 8), p);
    // 顔
    p.color = const Color(0xFFF6D7B8);
    canvas.drawOval(r(27, 55.5, 10, 8.5), p);
    // 前髪
    p.color = const Color(0xFF7A4A22);
    canvas.drawOval(r(26.4, 53.4, 11, 4.6), p);
    // 閉じた目(下向きカーブ) + ほお
    p.color = const Color(0xFF3E2410);
    canvas.drawRect(r(29, 60, 2.2, 0.9), p);
    canvas.drawRect(r(33, 60, 2.2, 0.9), p);
    p.color = const Color(0xFFF0A8A0);
    canvas.drawRect(r(28, 61.4, 1.8, 1.2), p);
    canvas.drawRect(r(34.2, 61.4, 1.8, 1.2), p);
    // 口(ほほえみ)
    p.color = const Color(0xFFB3583F);
    canvas.drawRect(r(31.4, 62.4, 1.4, 0.8), p);
    // パジャマの腕(布団から)
    p.color = const Color(0xFF6FB3E8);
    canvas.drawRect(r(40, 80, 7, 4), p);
    p.color = const Color(0xFFF6D7B8);
    canvas.drawRect(r(46, 80.6, 3, 2.8), p);

    // ── ナイトスタンド + ランプ ──
    p.color = _woodDark;
    canvas.drawRect(r(60, 66, 13, 18), p);
    p.color = _wood;
    canvas.drawRect(r(60.8, 66.8, 11.4, 16.4), p);
    p.color = _woodDark;
    canvas.drawRect(r(62, 72, 9, 1.2), p); // 引き出し線
    canvas.drawCircle(Offset(ox + 66.5 * u, oy + 76 * u), 0.9 * u, p);
    // ランプ(グロー → 台 → シェード)
    p.color = const Color(0x33FFD98A);
    canvas.drawCircle(Offset(ox + 66.5 * u, oy + 58 * u), 12 * u, p);
    p.color = const Color(0xFFB07B3E);
    canvas.drawRect(r(65.6, 60, 1.8, 6), p);
    p.color = _pink2;
    final shade = Path()
      ..moveTo(ox + 61.5 * u, oy + 60 * u)
      ..lineTo(ox + 71.5 * u, oy + 60 * u)
      ..lineTo(ox + 69.5 * u, oy + 53 * u)
      ..lineTo(ox + 63.5 * u, oy + 53 * u)
      ..close();
    canvas.drawPath(shade, p);
    p.color = _pink1;
    canvas.drawRect(r(63.5, 54, 2, 6), p);

    // ── ラグと鉢植え ──
    p.color = const Color(0xFFD87A8C);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r(4, 128, 26, 14), Radius.circular(2 * u)), p);
    p.color = const Color(0xFFC2687A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r(6.4, 130.4, 21.2, 9.2), Radius.circular(1.6 * u)),
        Paint()
          ..color = const Color(0xFFC2687A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * u);
    // 鉢植え(右下)
    p.color = const Color(0xFFE8E4DC);
    canvas.drawRect(r(74, 128, 9, 8), p);
    p.color = const Color(0xFFCFC9BE);
    canvas.drawRect(r(74, 134.4, 9, 1.6), p);
    p.color = const Color(0xFF3B9A31);
    canvas.drawRect(r(77.6, 121, 2, 7), p);
    for (final (dx, dy) in const [(-3.2, -1.0), (2.6, -1.4), (-1.4, -4.0), (1.2, -4.2), (0.0, 1.0)]) {
      canvas.drawOval(r(77.6 + dx, 122 + dy, 3.4, 2.2), p);
    }

    // ── 夜のトーン(全体をわずかに青く) ──
    p.color = const Color(0x1A16244E);
    canvas.drawRect(Offset.zero & size, p);
  }

  void _frame(Canvas canvas, Paint p, Rect Function(num, num, num, num) r,
      num x, num y, num w, num h, Color inner, {required bool flower}) {
    p.color = _woodDark;
    canvas.drawRect(r(x, y, w, h), p);
    p.color = inner;
    canvas.drawRect(r(x + 1, y + 1, w - 2, h - 2), p);
    if (flower) {
      p.color = const Color(0xFFE86E9A);
      canvas.drawRect(r(x + w / 2 - 1, y + h / 2 - 1.6, 2, 2), p);
      p.color = const Color(0xFF54A05A);
      canvas.drawRect(r(x + w / 2 - 0.4, y + h / 2 + 0.6, 0.8, 2), p);
    } else {
      p.color = const Color(0xFF54A05A);
      canvas.drawOval(r(x + 2, y + h / 2 - 1, w - 4, 2.4), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
