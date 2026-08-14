import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// SC-02 タイトル/オープニング(PRO NAVI ワイヤーフレーム5a/5b準拠)。
/// 全画面イラスト(島・お店・キャラクター=コード描画のドット絵)の上に、
/// ようこそチップ+ロゴカード+コピー+スタート+スタッフ導線を重ねる。
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final spriteW = (size.width * 0.20).clamp(64.0, 110.0);

    return Scaffold(
      backgroundColor: pnBg,
      body: Stack(children: [
        // ── 背景(なめらかなクリーンイラスト。キャラのみドットのまま) ──
        const Positioned.fill(
          child: CustomPaint(painter: _WelcomeBackdropPainter()),
        ),
        // ── キャラクター(みぽりん先生 & 主人公) ──
        Positioned(
          left: size.width * 0.07,
          bottom: size.height * 0.20,
          child: IgnorePointer(
            child: PixelSprite(
                rows: miporinRows(0),
                palette: miporinPalette,
                width: spriteW),
          ),
        ),
        Positioned(
          right: size.width * 0.07,
          bottom: size.height * 0.19,
          child: IgnorePointer(
            child: PixelSprite(
                rows: heroineFrontRows,
                palette: heroinePalette,
                width: spriteW * 0.92),
          ),
        ),
        // ── オーバーレイUI ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(children: [
              // スキップ(右上)
              Row(children: [
                const Spacer(),
                Material(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => context.go('/student-register'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pnLine),
                      ),
                      child: const Text('スキップ',
                          style: TextStyle(
                              color: pnSub,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
              const Spacer(flex: 2),
              // 中央: ようこそチップ + ロゴカード + コピー
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCFE3F2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFAFCBE4)),
                      ),
                      child: const Text('👑 ようこそ 👑',
                          style: TextStyle(
                              color: Color(0xFF44607A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 14),
                    // ロゴカード(ロゴ画像が用意できたら差し替え)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: pnLine),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x1A4A443A),
                              blurRadius: 14,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Text('実践デザイナー物語',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: pnInk,
                              fontSize: 30,
                              height: 1.4,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4C6D2).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                          'ここは、デザインの力で\nみんなの困りごとを解決する島。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF8E4A62),
                              fontSize: 14,
                              height: 1.7,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
              const Spacer(flex: 3),
              // スタート → オンボーディング(第1話)へ
              SizedBox(
                width: 300,
                height: 58,
                child: FilledButton(
                  onPressed: () => context.go('/story/ep1'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF2AFC1),
                    foregroundColor: const Color(0xFF8E4A62),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    textStyle: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  child: const Text('スタート ▶'),
                ),
              ),
              const SizedBox(height: 8),
              // 先生・スタッフ用の控えめな導線
              TextButton(
                onPressed: () => context.go('/teacher-login'),
                child: const Text('先生・スタッフの方はこちら',
                    style: TextStyle(
                        color: pnSub,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// タイトル画面のクリーン背景。ドットのグリッドを使わず、
/// なめらかなグラデーションと丸いシルエットで島の風景を描く。
class _WelcomeBackdropPainter extends CustomPainter {
  const _WelcomeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 空(上から下へやわらかいグラデーション)
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFAECBEB), Color(0xFFD7E7F5), Color(0xFFF3F0E4)],
        stops: [0.0, 0.55, 0.78],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // 太陽(淡い光の輪つき)
    final sunC = Offset(w * 0.82, h * 0.13);
    canvas.drawCircle(
        sunC, w * 0.13, Paint()..color = const Color(0x33FBE8A6));
    canvas.drawCircle(
        sunC, w * 0.075, Paint()..color = const Color(0x66FBE8A6));
    canvas.drawCircle(sunC, w * 0.045, Paint()..color = const Color(0xFFFCE9A8));

    // 雲(ふんわり白)
    void cloud(double cx, double cy, double s, double opacity) {
      final p = Paint()..color = Colors.white.withOpacity(opacity);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy), width: 120 * s, height: 34 * s),
          p);
      canvas.drawCircle(Offset(cx - 28 * s, cy - 2 * s), 20 * s, p);
      canvas.drawCircle(Offset(cx + 6 * s, cy - 12 * s), 24 * s, p);
      canvas.drawCircle(Offset(cx + 34 * s, cy - 3 * s), 17 * s, p);
    }

    cloud(w * 0.2, h * 0.1, w / 430 * 0.9, 0.95);
    cloud(w * 0.62, h * 0.2, w / 430 * 0.6, 0.8);
    cloud(w * 0.1, h * 0.28, w / 430 * 0.5, 0.65);

    // 奥の丘(街の背景にうっすら)
    final groundY = h * 0.72;
    final hillBack = Path()
      ..moveTo(0, groundY)
      ..quadraticBezierTo(w * 0.25, groundY - h * 0.10, w * 0.5, groundY)
      ..quadraticBezierTo(w * 0.75, groundY - h * 0.09, w, groundY - h * 0.02)
      ..lineTo(w, groundY + 4)
      ..lineTo(0, groundY + 4)
      ..close();
    canvas.drawPath(hillBack, Paint()..color = const Color(0xFFDFEBD2));

    // ── 街並み ──
    final bw = (w * 0.24).clamp(96.0, 200.0); // 建物の基準幅

    void windowBox(double cx, double cy, double s) {
      final r = Rect.fromCenter(
          center: Offset(cx, cy), width: 15 * s, height: 15 * s);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.inflate(2 * s), Radius.circular(4 * s)),
          Paint()..color = Colors.white);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(3 * s)),
          Paint()..color = const Color(0xFFBDDCF2));
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: 1.6 * s, height: 15 * s),
          Paint()..color = Colors.white);
    }

    void shop({
      required double cx,
      required double scale,
      required Color wall,
      required Color roof,
      List<Color>? awning,
      String? sign,
    }) {
      final bwx = bw * scale, bh = bwx * 0.78;
      final left = cx - bwx / 2, top = groundY - bh;
      // 壁
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(left, top, bwx, bh), const Radius.circular(8)),
          Paint()..color = wall);
      // 屋根(台形)
      final roofPath = Path()
        ..moveTo(left - bwx * 0.08, top + 2)
        ..lineTo(left + bwx * 0.18, top - bh * 0.34)
        ..lineTo(left + bwx * 0.82, top - bh * 0.34)
        ..lineTo(left + bwx * 1.08, top + 2)
        ..close();
      canvas.drawPath(roofPath, Paint()..color = roof);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(left - bwx * 0.1, top - 2, bwx * 1.2, 6),
              const Radius.circular(3)),
          Paint()..color = Color.lerp(roof, Colors.black, 0.18)!);
      // ひさし(スカラップ)
      if (awning != null) {
        final ay = top + bh * 0.30;
        const n = 6;
        for (var i = 0; i < n; i++) {
          final sx = left + bwx * 0.06 + i * (bwx * 0.88) / n;
          final sw = (bwx * 0.88) / n;
          final c = awning[i % awning.length];
          canvas.drawRect(
              Rect.fromLTWH(sx, ay, sw, bh * 0.12), Paint()..color = c);
          canvas.drawArc(Rect.fromLTWH(sx, ay + bh * 0.12 - sw * 0.3, sw, sw * 0.6),
              0, 3.1416, true, Paint()..color = c);
        }
      }
      // 窓と扉
      windowBox(left + bwx * 0.26, top + bh * 0.62, bwx / 100);
      windowBox(left + bwx * 0.74, top + bh * 0.62, bwx / 100);
      final doorW = bwx * 0.2, doorH = bh * 0.34;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - doorW / 2, groundY - doorH, doorW, doorH),
              Radius.circular(doorW * 0.4)),
          Paint()..color = const Color(0xFF9A6B45));
      // 看板
      if (sign != null) {
        final tp = TextPainter(
          text: TextSpan(
              text: sign,
              style: TextStyle(
                  color: const Color(0xFF6E4A22),
                  fontSize: bwx * 0.13,
                  fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        final signW = tp.width + bwx * 0.14, signH = tp.height + 6;
        final signRect = Rect.fromCenter(
            center: Offset(cx, top + bh * 0.15), width: signW, height: signH);
        canvas.drawRRect(
            RRect.fromRectAndRadius(signRect, const Radius.circular(6)),
            Paint()..color = const Color(0xFFFBF4E2));
        canvas.drawRRect(
            RRect.fromRectAndRadius(signRect, const Radius.circular(6)),
            Paint()
              ..color = const Color(0xFFD9C48F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4);
        tp.paint(canvas,
            signRect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    void tree(double cx, double s) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 3 * s, groundY - 22 * s, 6 * s, 22 * s),
              Radius.circular(3 * s)),
          Paint()..color = const Color(0xFF9A6B45));
      final leaf = Paint()..color = const Color(0xFFA8D18F);
      canvas.drawCircle(Offset(cx, groundY - 30 * s), 14 * s, leaf);
      canvas.drawCircle(Offset(cx - 10 * s, groundY - 24 * s), 10 * s, leaf);
      canvas.drawCircle(Offset(cx + 10 * s, groundY - 24 * s), 10 * s, leaf);
      canvas.drawCircle(Offset(cx - 3 * s, groundY - 34 * s), 8 * s,
          Paint()..color = const Color(0xFFBCDCA4));
    }

    // 建物の配置(SPは3軒、PCは5軒 + 木)
    final wideTown = w >= 900;
    if (wideTown) {
      shop(
          cx: w * 0.09,
          scale: 0.9,
          wall: const Color(0xFFDCE9F4),
          roof: const Color(0xFF9DBBD4));
      tree(w * 0.21, w / 1280 * 1.6);
      shop(
          cx: w * 0.32,
          scale: 1.1,
          wall: const Color(0xFFF6EBD3),
          roof: const Color(0xFFC98A6B),
          awning: const [Color(0xFFE8A0A8), Colors.white],
          sign: 'パン屋');
      shop(
          cx: w * 0.68,
          scale: 1.05,
          wall: const Color(0xFFF4D9DE),
          roof: const Color(0xFFE8A0A8),
          awning: const [Color(0xFFA8D18F), Colors.white],
          sign: 'カフェ');
      tree(w * 0.82, w / 1280 * 1.8);
      shop(
          cx: w * 0.93,
          scale: 0.9,
          wall: const Color(0xFFF3E6C4),
          roof: const Color(0xFFA8D18F));
    } else {
      shop(
          cx: w * 0.14,
          scale: 0.82,
          wall: const Color(0xFFF4D9DE),
          roof: const Color(0xFFE8A0A8));
      shop(
          cx: w * 0.5,
          scale: 1.0,
          wall: const Color(0xFFF6EBD3),
          roof: const Color(0xFFC98A6B),
          awning: const [Color(0xFFE8A0A8), Colors.white],
          sign: 'パン屋');
      shop(
          cx: w * 0.86,
          scale: 0.82,
          wall: const Color(0xFFDCE9F4),
          roof: const Color(0xFF9DBBD4));
      tree(w * 0.985, w / 430 * 0.9);
    }

    // 通り(石畳風の地面)
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h - groundY),
        Paint()..color = const Color(0xFFEDE2C4));
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, 5),
        Paint()..color = const Color(0xFFDCCFA9));
    final stone = Paint()..color = const Color(0x33A08662);
    for (final (fx, fy, s) in [
      (0.08, 0.80, 1.0), (0.2, 0.9, 1.3), (0.34, 0.83, 0.9),
      (0.46, 0.94, 1.2), (0.6, 0.8, 1.0), (0.7, 0.9, 1.4),
      (0.84, 0.84, 0.9), (0.94, 0.95, 1.1), (0.12, 0.97, 1.2),
      (0.55, 0.88, 0.8), (0.9, 0.78, 0.8), (0.3, 0.96, 1.0),
    ]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * fx, h * fy),
              width: 26 * s,
              height: 10 * s),
          stone);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
