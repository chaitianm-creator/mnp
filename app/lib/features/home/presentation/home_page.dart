import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// SC-10 ホーム。設計目標: 起動 → クエスト開始まで 2 タップ。
/// 最上部は常に「今日の依頼」カード(US-E2-01)。予約依頼は最上部固定(Phase 4 §4)。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(todayOffersProvider);
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('デザイン王国'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              const Icon(Icons.favorite, color: KdColors.pink500, size: 20),
              const SizedBox(width: 4),
              Text('${progress.streak}',
                  style: KdTheme.dot(size: 16, color: KdColors.ink900)),
              const SizedBox(width: 12),
              const Icon(Icons.vpn_key, color: KdColors.gold500, size: 18),
              const SizedBox(width: 2),
              Text('${progress.keys}',
                  style: KdTheme.dot(size: 14, color: KdColors.ink900)),
            ]),
          ),
        ],
      ),
      body: SafeArea(
        child: offers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              const Center(child: Text('あれれ、王国とつながらないみたい')),
          data: (quests) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 予約した依頼(US-E9-05: 本番は手紙+push経由で到着)
              if (progress.reservedQuestId != null) ...[
                KdParchmentCard(
                  child: Row(children: [
                    const Icon(Icons.mail, color: KdColors.pink500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          '予約したお仕事: 「${progress.reservedTeaser}」\n（あした届くよ！お楽しみに）',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              const KdSectionHeader('きょうの依頼'),
              const SizedBox(height: 4),
              Text('王国のみんなが、あなたを待ってるよ',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final q in quests) ...[
                _OfferCard(
                  q: q,
                  delivered: progress.deliveredQuestIds.contains(q.questId),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.q, required this.delivered});
  final Quest q;
  final bool delivered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = KdParchmentCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KdChip('${q.sizeMinutes}分', icon: Icons.schedule),
          const Spacer(),
          delivered
              ? const Icon(Icons.check_circle, color: KdColors.grass500)
              : Text('XP ${q.reward.xp}',
                  style: KdTheme.dot(size: 13, color: KdColors.reward)),
        ]),
        const SizedBox(height: 8),
        Text(q.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 4),
        Text('${q.residentName}「${q.brief}」',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium),
        if (delivered) ...[
          const SizedBox(height: 4),
          Text('納品ずみ！おつかれさま',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: KdColors.grass500)),
        ],
      ]),
    );

    if (delivered) return Opacity(opacity: 0.75, child: card);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/quest/${q.questId}'),
      child: card,
    );
  }
}
