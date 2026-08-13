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

    // 海(遠景の帯) + 島影
    final seaTop = h * 0.62;
    canvas.drawRect(Rect.fromLTWH(0, seaTop, w, h * 0.1),
        Paint()..color = const Color(0xFFBBD8EE));
    canvas.drawRect(Rect.fromLTWH(0, seaTop, w, h * 0.012),
        Paint()..color = const Color(0xFFD8E9F6));
    // 島影(中央奥に山のある島)
    final island = Path()
      ..moveTo(w * 0.30, seaTop + h * 0.02)
      ..quadraticBezierTo(
          w * 0.42, seaTop - h * 0.075, w * 0.52, seaTop + h * 0.005)
      ..quadraticBezierTo(
          w * 0.62, seaTop - h * 0.035, w * 0.72, seaTop + h * 0.02)
      ..lineTo(w * 0.72, seaTop + h * 0.03)
      ..lineTo(w * 0.30, seaTop + h * 0.03)
      ..close();
    canvas.drawPath(island, Paint()..color = const Color(0xFF9DBBD4));

    // 手前の丘(2枚重ねのやわらかい緑)
    final hillBack = Path()
      ..moveTo(0, h * 0.76)
      ..quadraticBezierTo(w * 0.28, h * 0.665, w * 0.58, h * 0.735)
      ..quadraticBezierTo(w * 0.82, h * 0.79, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillBack, Paint()..color = const Color(0xFFCFE6BA));
    final hillFront = Path()
      ..moveTo(0, h * 0.85)
      ..quadraticBezierTo(w * 0.32, h * 0.775, w * 0.62, h * 0.845)
      ..quadraticBezierTo(w * 0.85, h * 0.895, w, h * 0.83)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillFront, Paint()..color = const Color(0xFFA8D18F));

    // 丘の上の小さな草(丸ドット風のアクセント・なめらか描画)
    final grass = Paint()..color = const Color(0x593E5C33);
    for (final (fx, fy) in [
      (0.12, 0.9), (0.24, 0.87), (0.4, 0.885), (0.58, 0.9),
      (0.72, 0.915), (0.86, 0.885), (0.94, 0.93), (0.06, 0.95),
    ]) {
      canvas.drawCircle(Offset(w * fx, h * fy), 3.2, grass);
      canvas.drawCircle(Offset(w * fx + 7, h * fy + 3), 2.2, grass);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
