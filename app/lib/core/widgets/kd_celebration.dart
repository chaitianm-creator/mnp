import 'package:flutter/material.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// 演出基底(Phase 8 §8)。
///  - 1.5〜2.5秒 / タップで即スキップ可
///  - OS「視差効果を減らす」時はフェードのみに縮退
///  - 演出中も数値はテキスト併記(読めなくても情報が伝わる)
class KdCelebrationOverlay extends StatefulWidget {
  const KdCelebrationOverlay({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    required this.onDone,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onDone;

  @override
  State<KdCelebrationOverlay> createState() => _KdCelebrationOverlayState();
}

class _KdCelebrationOverlayState extends State<KdCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDone, // タップで即スキップ
      child: ColoredBox(
        color: KdColors.pink50,
        child: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              reduceMotion
                  ? Icon(widget.icon, size: 88, color: KdColors.pink500)
                  : ScaleTransition(
                      scale: curve,
                      child:
                          Icon(widget.icon, size: 88, color: KdColors.pink500),
                    ),
              const SizedBox(height: 16),
              KdRibbonBanner(widget.title, fontSize: 20),
              const SizedBox(height: 12),
              for (final line in widget.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line,
                      textAlign: TextAlign.center,
                      style: KdTheme.dot(size: 16, color: KdColors.ink900)),
                ),
              const SizedBox(height: 24),
              Text('タップしてつづける',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
        ),
      ),
    );
  }
}
