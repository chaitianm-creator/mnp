import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-05 入団完了。祝福 → 「冒険へ行く」でホームメニューへ。
class EnrollmentCompletePage extends ConsumerWidget {
  const EnrollmentCompletePage({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    await ref.read(accountProvider.notifier).completeOnboarding();
    // 旧フラグ互換(既存コードの onboarding_done 参照を壊さない)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!context.mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(
          child: CustomPaint(painter: KdSceneryPainter()),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Spacer(),
              Center(child: KdRibbonBanner('入団完了！', fontSize: 16)),
              const SizedBox(height: 18),
              // 入団証(アイテムカード様式)
              KdParchmentCard(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: KdColors.pink100,
                      shape: BoxShape.circle,
                      border: Border.all(color: KdColors.pink500, width: 2.5),
                    ),
                    child: const Icon(Icons.person,
                        size: 44, color: KdColors.pink700),
                  ),
                  const SizedBox(height: 10),
                  Text(account?.nickname ?? 'みならいさん',
                      style: KdTheme.dot(size: 18, color: KdColors.ink900)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('デザイン王国 みならいデザイナー',
                      style: KdTheme.dot(size: 11, color: KdColors.pink700)),
                  const SizedBox(height: 12),
                  Text(
                    'デザイン王国への入団が完了しました！\nみぽりん先生と一緒に、\n最初の一歩を踏み出しましょう。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              const KdBandMessage('★ みぽりん先生が 王国で待っているよ ★'),
              const SizedBox(height: 18),
              KdPrimaryButton(
                label: '冒険へ行く',
                onPressed: () => _start(context, ref),
              ),
              const Spacer(),
            ]),
          ),
        ),
      ]),
    );
  }
}
