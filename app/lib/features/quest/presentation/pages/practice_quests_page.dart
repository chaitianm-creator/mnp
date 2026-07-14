import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// 練習クエスト一覧(/quests)。
/// みぽりん先生の基礎レッスン。自分で選んで挑戦する(自律性)。
/// 3つクリアで「今日の依頼」(お客様からの実依頼)が解放される。
class PracticeQuestsPage extends ConsumerWidget {
  const PracticeQuestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(practiceQuestsProvider);
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('練習クエスト')),
      body: SafeArea(
        child: quests.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              const Center(child: Text('あれれ、王国とつながらないみたい')),
          data: (list) {
            final cleared = progress.practiceClearedCount;
            return ListView(padding: const EdgeInsets.all(16), children: [
              // 先生のごあんない
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KdColors.pink50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.pink500, width: 2),
                  boxShadow: const [
                    BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: KdColors.pink100,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: KdColors.pink500, width: 2),
                        ),
                        child: const Icon(Icons.favorite,
                            size: 22, color: KdColors.pink500),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('みぽりん先生',
                                  style: KdTheme.dot(
                                          size: 11, color: KdColors.pink700)
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                cleared >= 3
                                    ? '基礎はばっちり！いつでも復習にきてね♪'
                                    : '好きなクエストから始めてOK！\n3つクリアすると、お客様からの依頼に挑戦できるよ。',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ]),
                      ),
                    ]),
              ),
              const SizedBox(height: 12),
              // 解放までの進み具合
              KdParchmentCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.mail,
                            size: 16, color: KdColors.pink700),
                        const SizedBox(width: 6),
                        Text('「今日の依頼」解放まで',
                            style: KdTheme.dot(
                                size: 12, color: KdColors.heading)),
                        const Spacer(),
                        Text('$cleared / 3',
                            style: KdTheme.dot(
                                    size: 14, color: KdColors.ink900)
                                .copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      KdProgressBar(value: cleared / 3),
                    ]),
              ),
              const SizedBox(height: 14),
              const KdSectionHeader('きほんのレッスン'),
              const SizedBox(height: 8),
              for (final (i, q) in list.indexed) ...[
                _PracticeQuestCard(
                  quest: q,
                  number: i + 1,
                  done: progress.deliveredQuestIds.contains(q.questId),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              const KdBandMessage('じぶんのペースで だいじょうぶ♪'),
            ]);
          },
        ),
      ),
    );
  }
}

class _PracticeQuestCard extends StatelessWidget {
  const _PracticeQuestCard({
    required this.quest,
    required this.number,
    required this.done,
  });
  final Quest quest;
  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/quest/${quest.questId}'),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFF3EAD2) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: done ? KdColors.gold500 : KdColors.border, width: 2),
          boxShadow: [
            BoxShadow(
                color: done ? const Color(0xFFB88A18) : KdColors.wood900,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: done ? KdColors.gold500 : KdColors.pink500,
              shape: BoxShape.circle,
              border: Border.all(color: KdColors.wood900, width: 2),
            ),
            child: done
                ? const Icon(Icons.local_florist,
                    color: Colors.white, size: 24)
                : Center(
                    child: Text('$number',
                        style: KdTheme.dot(size: 18, color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(quest.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.timer, size: 13, color: KdColors.wood700),
                const SizedBox(width: 3),
                Text('${quest.sizeMinutes}分',
                    style: KdTheme.dot(size: 11, color: KdColors.wood700)),
                const SizedBox(width: 10),
                const Icon(Icons.auto_awesome,
                    size: 13, color: KdColors.gold500),
                const SizedBox(width: 3),
                Text('EXP +${quest.reward.xp}',
                    style: KdTheme.dot(size: 11, color: KdColors.wood700)),
              ]),
            ]),
          ),
          Icon(done ? Icons.check_circle : Icons.play_circle_fill,
              size: 26, color: done ? KdColors.grass500 : KdColors.pink500),
        ]),
      ),
    );
  }
}
