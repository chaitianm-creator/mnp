import 'package:flutter/material.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';

/// Phase 8 §6 コアコンポーネント(みぽりん王国 素材パック準拠)。
/// 影は使わず「下辺2pxの濃色段差」で立体感を出す(ドット絵の作法)。

/// 羊皮紙カード: 全カードの基底。木枠2px + 下辺段差。
class KdParchmentCard extends StatelessWidget {
  const KdParchmentCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KdColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KdColors.border, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.wood900, offset: Offset(0, 2), blurRadius: 0),
        ],
      ),
      child: child,
    );
  }
}

/// ❀ セクション見出し: 桜マーク + ローズピンクの太字(素材パックの見出し様式)。
class KdSectionHeader extends StatelessWidget {
  const KdSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.local_florist, size: 18, color: KdColors.pink500),
      const SizedBox(width: 6),
      Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: KdColors.heading)),
    ]);
  }
}

/// リボンバナー: タイトル・見出しバナー(「みぽりん王国」プレート様式)。
/// 両端にリボンの折り返しを持つピンクのプレート + 白抜き太字。
class KdRibbonBanner extends StatelessWidget {
  const KdRibbonBanner(this.label, {super.key, this.fontSize = 18});
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RibbonPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2,
            )),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tail = Paint()..color = KdColors.pink700;
    final plate = Paint()..color = KdColors.pink500;
    final borderPaint = Paint()
      ..color = KdColors.pink700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 左右のリボン折り返し(端にV字の切り込み)
    final leftTail = Path()
      ..moveTo(0, 8)
      ..lineTo(18, 8)
      ..lineTo(18, size.height)
      ..lineTo(0, size.height)
      ..lineTo(7, (size.height + 8) / 2)
      ..close();
    final rightTail = Path()
      ..moveTo(size.width, 8)
      ..lineTo(size.width - 18, 8)
      ..lineTo(size.width - 18, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - 7, (size.height + 8) / 2)
      ..close();
    canvas.drawPath(leftTail, tail);
    canvas.drawPath(rightTail, tail);

    // 中央プレート
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(12, 0, size.width - 12, size.height - 6),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, plate);
    canvas.drawRRect(rect, borderPaint);

    // 上辺のハイライト(ドット絵のベベル)
    final highlight = Paint()..color = Colors.white.withOpacity(0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(18, 3, size.width - 18, 6),
        const Radius.circular(2),
      ),
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 黒ラベルチップ: 地名 / サイズ(3・7・15分) / 納期などの「情報」。
class KdChip extends StatelessWidget {
  const KdChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: KdColors.chipBlack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(label, style: KdTheme.dot(size: 13)),
      ]),
    );
  }
}

/// プライマリボタン: RPGプレート様式(焦げ茶の輪郭 + 上辺ハイライト + 押下1段沈み)。
/// アクセシビリティ: 白文字はBold限定(Phase 8 §10)。最小48dp。
class KdPrimaryButton extends StatefulWidget {
  const KdPrimaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  State<KdPrimaryButton> createState() => _KdPrimaryButtonState();
}

class _KdPrimaryButtonState extends State<KdPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        constraints: const BoxConstraints(minHeight: 48),
        transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? (_down ? KdColors.primaryActionPressed : KdColors.primaryAction)
              : KdColors.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: enabled ? KdColors.wood900 : KdColors.border, width: 2),
          boxShadow: _down
              ? null
              : const [BoxShadow(color: KdColors.wood900, offset: Offset(0, 3))],
        ),
        child: Stack(alignment: Alignment.center, children: [
          // 上辺ハイライト(ドット絵のベベル)
          if (enabled)
            Positioned(
              top: 4,
              left: 10,
              right: 10,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
          ),
        ]),
      ),
    );
  }
}

/// 進捗バー: HPバー様式(木枠レール + 桜ピンク充填 + 先端に桜の花)。
class KdProgressBar extends StatelessWidget {
  const KdProgressBar({super.key, required this.value});
  final double value; // 0.0-1.0

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 18,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            top: 3,
            bottom: 3,
            child: Container(
              decoration: BoxDecoration(
                color: KdColors.parchmentLight,
                border: Border.all(color: KdColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [KdColors.pink100, KdColors.pink500],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 充填の先端に桜の花(進みが見えるご褒美)
          if (v > 0.02)
            Positioned(
              left: (w * v - 9).clamp(0.0, w - 18),
              top: 0,
              child: const Icon(Icons.local_florist,
                  size: 18, color: KdColors.pink700),
            ),
        ]),
      );
    });
  }
}

/// 住民会話の吹き出し(SC-20/21)。話者名 + 羊皮紙吹き出し。
class KdDialogueBubble extends StatelessWidget {
  const KdDialogueBubble({super.key, required this.speaker, required this.text});
  final String speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(speaker,
          style: const TextStyle(
              color: KdColors.pink700, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 4),
      KdParchmentCard(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: KdColors.textPrimary)),
      ),
    ]);
  }
}
