import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// 工房(/workshop)。納品した作品(クエスト)を見返す場所。
/// DEMO: 納品済みクエストをカードで並べる。本番は deliveries + Storage 画像。
class WorkshopPage extends ConsumerWidget {
  const WorkshopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final offers = ref.watch(todayOffersProvider);
    final practices = ref.watch(practiceQuestsProvider);

    final quests = [
      ...?practices.valueOrNull,
      ...?offers.valueOrNull,
    ];
    final delivered = [
      for (final q in quests)
        if (progress.deliveredQuestIds.contains(q.questId)) q,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('工房')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          KdParchmentCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KdColors.ocean500,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.wood900, width: 2),
                ),
                child:
                    const Icon(Icons.handyman, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('あなたの工房',
                          style: KdTheme.dot(size: 14, color: KdColors.heading)
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('納品した作品がここに並ぶよ。ふりかえりは上達のちかみち♪',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          KdSectionHeader('納品した作品（${delivered.length}件）'),
          const SizedBox(height: 8),
          if (delivered.isEmpty)
            KdParchmentCard(
              child: Column(children: [
                const Icon(Icons.brush, size: 40, color: KdColors.wood700),
                const SizedBox(height: 8),
                Text('まだ作品がないよ',
                    style: KdTheme.dot(size: 13, color: KdColors.ink900)
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('クエストをクリアすると、ここに作品が並ぶよ。',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                KdPrimaryButton(
                  label: '練習クエストへ行く',
                  onPressed: () => context.pushReplacement('/quests'),
                ),
              ]),
            )
          else
            for (final q in delivered) ...[
              InkWell(
                onTap: () => context.push('/quest/${q.questId}'),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KdColors.gold500, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFB88A18), offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KdColors.gold500,
                        shape: BoxShape.circle,
                        border: Border.all(color: KdColors.wood900, width: 2),
                      ),
                      child: const Icon(Icons.local_florist,
                          size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('依頼主: ${q.residentName}',
                                style: KdTheme.dot(
                                    size: 10, color: KdColors.wood700)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: KdColors.wood700),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 4),
          const KdBandMessage('つくった数だけ、うまくなる。それがデザインだよ♪'),
        ]),
      ),
    );
  }
}
