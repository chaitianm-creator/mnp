import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/widgets/pn_shell.dart';

/// ショッピングセンター(モールの店先が並ぶページ)。
/// 服屋さん・本屋さん・雑貨屋さん・チケット屋さんの4店舗。
class ShoppingCenterPage extends StatelessWidget {
  const ShoppingCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    const shops = [
      (
        '服屋さん',
        'きせかえアイテムを購入できるよ！',
        Color(0xFF8E4A62),
        Color(0xFFF9E3EA),
        'clothes',
        '/clothes-shop',
      ),
      (
        '本屋さん',
        'デザインの本がずらり',
        Color(0xFF3E6B8E),
        Color(0xFFDDEBF6),
        'books',
        null,
      ),
      (
        '雑貨屋さん',
        'たのしい雑貨がいっぱい',
        Color(0xFF4A7A4E),
        Color(0xFFE2F0DB),
        'goods',
        null,
      ),
      (
        'チケット屋さん',
        'イベントのチケットはこちら',
        Color(0xFFB84C40),
        Color(0xFFF9E9D2),
        'tickets',
        null,
      ),
    ];

    return PnShell(
      current: 'ショッピングセンター',
      spTitle: 'ショッピングセンター',
      showRail: false,
      mainBuilder: (context, wide) => [
        Row(children: const [
          Text('ショッピングセンター',
              style: TextStyle(
                  color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 4),
        const Text('気になるお店をのぞいてみよう！',
            style: TextStyle(color: pnSub, fontSize: 12.5)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 2 : 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: wide ? 1.9 : 1.7,
          ),
          itemCount: shops.length,
          itemBuilder: (context, i) {
            final (name, desc, band, wall, kind, route) = shops[i];
            return Material(
              color: pnCard,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: route != null
                    ? () => context.push(route)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('$nameは近日オープン！おたのしみに(DEMO)'),
                              duration: const Duration(seconds: 2)),
                        ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pnLine),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CustomPaint(
                            painter: _ShopFrontPainter(
                                name: name,
                                band: band,
                                wall: wall,
                                kind: kind),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Row(children: [
                            Expanded(
                              child: Text(desc,
                                  style: const TextStyle(
                                      color: pnSub,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: route != null ? pnPink : pnBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: pnLine),
                              ),
                              child: Text(route != null ? 'お店に入る' : '近日公開',
                                  style: const TextStyle(
                                      color: pnInk,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ]),
                        ),
                      ]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 店先(看板 + 店内)のイラスト
// ─────────────────────────────────────────────────────────────
class _ShopFrontPainter extends CustomPainter {
  const _ShopFrontPainter(
      {required this.name,
      required this.band,
      required this.wall,
      required this.kind});
  final String name;
  final Color band;
  final Color wall;
  final String kind;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 店内(壁)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = wall);
    // 床
    canvas.drawRect(Rect.fromLTWH(0, h * 0.82, w, h * 0.18),
        Paint()..color = const Color(0xFFE9E2D2));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.82, w, 2),
        Paint()..color = const Color(0x33474038));

    // 看板
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.24), Paint()..color = band);
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: TextStyle(
              color: Colors.white,
              fontSize: (h * 0.115).clamp(12.0, 18.0),
              fontWeight: FontWeight.w900,
              letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.12 - tp.height / 2));

    final dark = Paint()..color = const Color(0x33474038);
    switch (kind) {
      case 'clothes':
        // ハンガーラック
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.14, h * 0.36, w * 0.5, 4),
                const Radius.circular(2)),
            Paint()..color = const Color(0xFF9A6B45));
        const cols = [
          Color(0xFFF5A097),
          Color(0xFF849BE4),
          Color(0xFF5DAF8D),
          Color(0xFFF9A31B),
        ];
        for (var i = 0; i < 4; i++) {
          final cx = w * (0.2 + i * 0.13);
          canvas.drawLine(
              Offset(cx, h * 0.37),
              Offset(cx, h * 0.42),
              Paint()
                ..color = const Color(0xFF6E4A22)
                ..strokeWidth = 2);
          final shirt = Path()
            ..moveTo(cx - w * 0.045, h * 0.42)
            ..lineTo(cx + w * 0.045, h * 0.42)
            ..lineTo(cx + w * 0.06, h * 0.48)
            ..lineTo(cx + w * 0.04, h * 0.52)
            ..lineTo(cx + w * 0.035, h * 0.49)
            ..lineTo(cx + w * 0.035, h * 0.62)
            ..lineTo(cx - w * 0.035, h * 0.62)
            ..lineTo(cx - w * 0.035, h * 0.49)
            ..lineTo(cx - w * 0.04, h * 0.52)
            ..lineTo(cx - w * 0.06, h * 0.48)
            ..close();
          canvas.drawPath(shirt, Paint()..color = cols[i]);
        }
        // マネキン
        canvas.drawCircle(Offset(w * 0.82, h * 0.42), h * 0.05,
            Paint()..color = const Color(0xFFEFE3C4));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.775, h * 0.48, w * 0.09, h * 0.26),
                const Radius.circular(8)),
            Paint()..color = const Color(0xFFE98FA9));
        canvas.drawRect(
            Rect.fromLTWH(w * 0.81, h * 0.74, w * 0.02, h * 0.08), dark);
      case 'books':
        // 本棚2段
        for (final sy in [0.34, 0.56]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(w * 0.12, h * (sy + 0.155), w * 0.76, 5),
                  const Radius.circular(2)),
              Paint()..color = const Color(0xFF9A6B45));
          const cols = [
            Color(0xFFD97A6A),
            Color(0xFF7FA3CB),
            Color(0xFF8CC178),
            Color(0xFFE0B268),
            Color(0xFFA98BC6),
            Color(0xFFE8A0A8),
            Color(0xFF5DAF8D),
            Color(0xFFF5A097),
          ];
          for (var i = 0; i < 8; i++) {
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromLTWH(w * (0.15 + i * 0.09), h * sy, w * 0.055,
                        h * 0.15),
                    const Radius.circular(2)),
                Paint()..color = cols[i]);
          }
        }
      case 'goods':
        // 棚 + 雑貨(マグ・植木・箱・時計)
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.12, h * 0.52, w * 0.76, 5),
                const Radius.circular(2)),
            Paint()..color = const Color(0xFF9A6B45));
        // マグカップ
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.17, h * 0.4, w * 0.08, h * 0.12),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFFE8A0A8));
        canvas.drawArc(
            Rect.fromLTWH(w * 0.245, h * 0.42, w * 0.035, h * 0.07),
            -1.57, 3.1416, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFE8A0A8));
        // 植木
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.4, h * 0.44, w * 0.09, h * 0.08),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFFB56A4A));
        canvas.drawCircle(Offset(w * 0.445, h * 0.38), h * 0.07,
            Paint()..color = const Color(0xFF8CC178));
        // 箱
        canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.4, w * 0.12, h * 0.12),
            Paint()..color = const Color(0xFFE0B268));
        canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.44, w * 0.12, h * 0.02),
            dark);
        // 下段: 時計とキャンドル
        canvas.drawCircle(Offset(w * 0.3, h * 0.68), h * 0.09,
            Paint()..color = Colors.white);
        canvas.drawCircle(
            Offset(w * 0.3, h * 0.68),
            h * 0.09,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFF4A7A4E));
        canvas.drawLine(
            Offset(w * 0.3, h * 0.68),
            Offset(w * 0.3, h * 0.62),
            Paint()
              ..strokeWidth = 2
              ..color = pnInk);
        canvas.drawLine(
            Offset(w * 0.3, h * 0.68),
            Offset(w * 0.33, h * 0.68),
            Paint()
              ..strokeWidth = 2
              ..color = pnInk);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.55, h * 0.62, w * 0.07, h * 0.14),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFFF2DFA7));
        canvas.drawOval(
            Rect.fromLTWH(w * 0.578, h * 0.585, w * 0.014, h * 0.035),
            Paint()..color = const Color(0xFFF9A31B));
      case 'tickets':
        // カウンター + 窓口
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.55, h * 0.34, w * 0.32, h * 0.42),
                const Radius.circular(8)),
            Paint()..color = Colors.white);
        canvas.drawArc(
            Rect.fromLTWH(w * 0.61, h * 0.4, w * 0.2, h * 0.28),
            3.1416, 3.1416, true,
            Paint()..color = const Color(0xFFBDDCF2));
        canvas.drawRect(Rect.fromLTWH(w * 0.55, h * 0.66, w * 0.32, h * 0.1),
            Paint()..color = const Color(0xFFE9E2D2));
        // 大きなチケット
        canvas.save();
        canvas.translate(w * 0.28, h * 0.55);
        canvas.rotate(-0.12);
        final ticket = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: w * 0.34, height: h * 0.2),
            const Radius.circular(8));
        canvas.drawRRect(ticket, Paint()..color = const Color(0xFFF6D96B));
        final perf = Paint()
          ..color = Colors.white
          ..strokeWidth = 2;
        for (var i = -3; i <= 3; i++) {
          canvas.drawLine(Offset(w * 0.06, i * h * 0.026),
              Offset(w * 0.06, i * h * 0.026 + h * 0.012), perf);
        }
        // 星
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final r = i.isEven ? h * 0.055 : h * 0.024;
          final x = -w * 0.05 + math.cos(a) * r;
          final y = math.sin(a) * r;
          i == 0 ? star.moveTo(x, y) : star.lineTo(x, y);
        }
        canvas.drawPath(star..close(),
            Paint()..color = const Color(0xFFB84C40));
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShopFrontPainter old) =>
      old.name != name || old.kind != kind;
}
