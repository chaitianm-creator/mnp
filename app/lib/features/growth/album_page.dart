import 'package:flutter/material.dart';

import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// お客さまアルバム。
/// 島の村人を助けたり仲良くなると写真が追加されていく。
/// パン屋さんのお願いごとを聞いたらクリア → 写真追加(現状は仮で掲載)。
class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PnShell(
      current: 'お客さまアルバム',
      spTitle: 'お客さまアルバム',
      showRail: false,
      mainBuilder: (context, wide) => [
        const Text('お客さまアルバム',
            style: TextStyle(
                color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('島の村人を助けたり仲良くなると、写真がふえていくよ！',
            style: TextStyle(color: pnSub, fontSize: 12.5)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: wide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
          children: [
            _photoCard(
              context,
              name: 'パン屋さん',
              memo: 'お店の集客のお悩みを相談中。\nお願いごとを聞いたらクリア！',
              badge: 'おねがい進行中',
            ),
            for (final hint in ['カフェ', '八百屋さん', '図書館', 'イベント会場', '？？？'])
              _lockedCard(hint),
          ],
        ),
      ],
    );
  }

  // ── 村人の写真(ポラロイド風) ──
  Widget _photoCard(BuildContext context,
      {required String name, required String memo, String? badge}) {
    return Container(
      decoration: BoxDecoration(
        color: pnCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pnLine),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              const CustomPaint(painter: _BakeryPhotoPainter()),
              Align(
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(builder: (context, c) {
                  final w = (c.maxWidth * 0.44).clamp(60.0, 110.0);
                  return Padding(
                    padding: EdgeInsets.only(bottom: c.maxHeight * 0.06),
                    child: PixelSprite(
                        rows: bakerRows, palette: bakerPalette, width: w),
                  );
                }),
              ),
              if (badge != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pnLine),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            color: pnSub,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: const TextStyle(
                color: pnInk, fontSize: 13.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(memo,
            style: const TextStyle(color: pnSub, fontSize: 10.5, height: 1.35)),
      ]),
    );
  }

  // ── まだ出会っていない村人(？のプレースホルダー) ──
  Widget _lockedCard(String hint) {
    return Container(
      decoration: BoxDecoration(
        color: pnBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pnLine),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8DC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('？',
                  style: TextStyle(
                      color: pnSub,
                      fontSize: 34,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint == '？？？' ? '？？？' : '$hintの村人',
            style: const TextStyle(
                color: pnSub, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        const Text('助けたり仲良くなると\n写真が追加されるよ',
            style: TextStyle(color: pnSub, fontSize: 10.5, height: 1.35)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// パン屋さんの写真背景(店先のミニイラスト)
// ─────────────────────────────────────────────────────────────
class _BakeryPhotoPainter extends CustomPainter {
  const _BakeryPhotoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 空
    final sky = Rect.fromLTWH(0, 0, w, h * 0.5);
    canvas.drawRect(
        sky,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFAECBEB), Color(0xFFD7E7F5)],
          ).createShader(sky));
    // 奥の緑と地面
    canvas.drawRect(Rect.fromLTWH(0, h * 0.42, w, h * 0.16),
        Paint()..color = const Color(0xFF7EC55E));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.58, w, h * 0.42),
        Paint()..color = const Color(0xFFD0B584));
    // 店(かんたんな正面)
    final sx = w * 0.2, sy = h * 0.2, sw = w * 0.6, sh = h * 0.42;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx, sy, sw, sh), const Radius.circular(5)),
        Paint()..color = const Color(0xFFEFE3C4));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx - 5, sy - h * 0.045, sw + 10, h * 0.05),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFFB84C40));
    // ひさし
    final n = 6;
    for (var i = 0; i < n; i++) {
      final c = i.isEven ? const Color(0xFFC85C4E) : Colors.white;
      canvas.drawRect(
          Rect.fromLTWH(sx + i * sw / n, sy + sh * 0.28, sw / n, h * 0.035),
          Paint()..color = c);
    }
    // 窓とドア
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sx + sw * 0.1, sy + sh * 0.48, sw * 0.4, sh * 0.36),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF7C5B36));
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTWH(sx + sw * 0.62, sy + sh * 0.44, sw * 0.2, sh * 0.56),
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8)),
        Paint()..color = const Color(0xFF3E6B44));
    // 太陽
    canvas.drawCircle(Offset(w * 0.86, h * 0.1), w * 0.06,
        Paint()..color = const Color(0xFFF6D96B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
