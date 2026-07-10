import 'package:flutter/material.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';

/// Phase 8 §6 コアコンポーネント。
/// 影は使わず「下辺2pxの濃色段差」で立体感を出す(ドット絵の作法)。

/// 羊皮紙カード: 全カードの基底。木枠1.5px + 下辺段差。
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KdColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(color: KdColors.wood700, offset: Offset(0, 2), blurRadius: 0),
        ],
      ),
      child: child,
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

/// プライマリボタン: pink500 / 押下でドット的1段沈み込み。
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: _down
              ? null
              : const [BoxShadow(color: KdColors.pink700, offset: Offset(0, 2))],
        ),
        child: Text(widget.label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
    );
  }
}

/// 進捗バー: 木枠レール + gold充填(ステップ/エリア進捗共用)。
class KdProgressBar extends StatelessWidget {
  const KdProgressBar({super.key, required this.value});
  final double value; // 0.0-1.0

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: KdColors.parchment,
          border: Border.all(color: KdColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: KdColors.reward),
        ),
      ),
    );
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
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ]);
  }
}
