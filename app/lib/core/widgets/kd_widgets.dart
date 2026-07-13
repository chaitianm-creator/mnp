import 'package:flutter/material.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';

/// Phase 8 §6 コアコンポーネント(みぽりん王国 素材パック準拠・ドット絵の作法)。
///  - 角丸は使わず「角を1段欠いた八角形(チャンファー)」= ピクセルの段付き角
///  - 影はぼかさず「下辺の濃色1段ずれ」
///  - 見出し・ボタン・バナーは DotGothic16

/// 段付き角(チャンファー)のパスを作る共通関数。
Path kdPixelPath(Size size, {double cut = 6, double inset = 0}) {
  final w = size.width;
  final h = size.height;
  final i = inset;
  return Path()
    ..moveTo(i + cut, i)
    ..lineTo(w - i - cut, i)
    ..lineTo(w - i, i + cut)
    ..lineTo(w - i, h - i - cut)
    ..lineTo(w - i - cut, h - i)
    ..lineTo(i + cut, h - i)
    ..lineTo(i, h - i - cut)
    ..lineTo(i, i + cut)
    ..close();
}

class _PixelPanelPainter extends CustomPainter {
  const _PixelPanelPainter({
    required this.fill,
    required this.borderColor,
    this.shadowColor,
  });
  final Color fill;
  final Color borderColor;
  final Color? shadowColor;
  static const borderWidth = 3.0;
  static const cut = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 下辺の濃色1段ずれ(ドット絵の影)
    if (shadowColor != null) {
      final shadowPath = kdPixelPath(
          Size(size.width, size.height - 3), cut: cut)
        ..fillType = PathFillType.nonZero;
      canvas.save();
      canvas.translate(0, 3);
      canvas.drawPath(shadowPath, Paint()..color = shadowColor!);
      canvas.restore();
    }
    final body = kdPixelPath(Size(size.width, size.height - 3), cut: cut);
    canvas.drawPath(body, Paint()..color = fill);
    canvas.drawPath(
      body,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelPanelPainter old) =>
      old.fill != fill || old.borderColor != borderColor;
}

/// 羊皮紙カード: 全カードの基底。RPGウィンドウ(段付き角 + 木枠 + 下辺段差)。
class KdParchmentCard extends StatelessWidget {
  const KdParchmentCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PixelPanelPainter(
        fill: KdColors.surface,
        borderColor: KdColors.border,
        shadowColor: KdColors.wood900,
      ),
      child: Padding(
        padding: (padding ?? const EdgeInsets.all(16))
            .add(const EdgeInsets.only(bottom: 3)),
        child: child,
      ),
    );
  }
}

/// ❀ セクション見出し: 桜マーク + ローズピンクのドット文字(素材パックの見出し様式)。
class KdSectionHeader extends StatelessWidget {
  const KdSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.local_florist, size: 18, color: KdColors.pink500),
      const SizedBox(width: 6),
      Text(title,
          style: KdTheme.dot(size: 17, color: KdColors.heading)
              .copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

/// リボンバナー: タイトル・見出しバナー(「みぽりん王国」プレート様式)。
/// 両端にリボンの折り返しを持つピンクのプレート + 白抜きドット文字。
class KdRibbonBanner extends StatelessWidget {
  const KdRibbonBanner(this.label, {super.key, this.fontSize = 18});
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RibbonPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 10),
        child: Text(label,
            textAlign: TextAlign.center,
            style: KdTheme.dot(size: fontSize, color: Colors.white)
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 2)),
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
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter;

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

    // 中央プレート(段付き角)
    final plateSize = Size(size.width - 24, size.height - 6);
    canvas.save();
    canvas.translate(12, 0);
    final body = kdPixelPath(plateSize, cut: 5);
    canvas.drawPath(body, plate);
    canvas.drawPath(body, borderPaint);
    // 上辺のハイライト(ドット絵のベベル)
    canvas.drawRect(
      Rect.fromLTRB(8, 3, plateSize.width - 8, 6),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 帯メッセージ: ヘッダー/フッターの合言葉(きらめき付きの桜ピンクの帯)。
class KdBandMessage extends StatelessWidget {
  const KdBandMessage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KdColors.pink500,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: KdColors.pink700, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              textAlign: TextAlign.center,
              style: KdTheme.dot(size: 13, color: Colors.white)
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
      ]),
    );
  }
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
        borderRadius: BorderRadius.circular(3),
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

/// プライマリボタン: RPGプレート様式(段付き角 + 焦げ茶輪郭 + 上辺ハイライト + 押下1段沈み)。
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
        transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
        child: CustomPaint(
          painter: _PixelPanelPainter(
            fill: enabled
                ? (_down ? KdColors.primaryActionPressed : KdColors.primaryAction)
                : KdColors.border.withOpacity(0.4),
            borderColor: enabled ? KdColors.wood900 : KdColors.border,
            shadowColor: _down ? null : KdColors.wood900,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Stack(alignment: Alignment.center, children: [
              // 上辺ハイライト(ドット絵のベベル)
              if (enabled)
                Positioned(
                  top: 5,
                  left: 12,
                  right: 12,
                  child: Container(
                      height: 3, color: Colors.white.withOpacity(0.35)),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(widget.label,
                    style: KdTheme.dot(size: 16, color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
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
                border: Border.all(color: KdColors.border, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Column(children: [
                    // ドット絵の2トーン充填(上が明るい)
                    Expanded(child: Container(color: KdColors.pink100)),
                    Expanded(flex: 2, child: Container(color: KdColors.pink500)),
                  ]),
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
          style: KdTheme.dot(size: 13, color: KdColors.pink700)
              .copyWith(fontWeight: FontWeight.w700)),
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
