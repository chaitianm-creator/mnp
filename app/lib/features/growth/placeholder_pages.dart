import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-40 スキルツリー(骨格)。6系統の獲得ポイントのみ表示。
/// ツリーUI・分岐選択は Phase 9 後半の次マイルストーンで実装。
class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  static const _categories = {
    'craft': ('制作技術', Icons.brush),
    'hearing': ('ヒアリング', Icons.hearing),
    'proposal': ('提案力', Icons.lightbulb),
    'revision': ('改善力', Icons.refresh),
    'selfmgmt': ('自己管理', Icons.schedule),
    'community': ('コミュニティ', Icons.group),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('スキル')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('敵はいない。敵は、昨日の自分。',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final e in _categories.entries) ...[
            KdParchmentCard(
              child: Row(children: [
                Icon(e.value.$2, color: KdColors.pink500),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(e.value.$1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16))),
                // DEMO: スキルポイントの実配分は deliverQuest 反映後に接続
                Text('Lv 1', style: KdTheme.dot(size: 14, color: KdColors.ink900)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
    );
  }
}

/// SC-50 プロフィール(骨格)。レベル・XP・コイン・ストリーク・鍵。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProgressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('わたし'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'), // SC-53
        ),
      ]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          KdParchmentCard(
            child: Column(children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: KdColors.pink100,
                child: Icon(Icons.person, size: 40, color: KdColors.pink700),
              ),
              const SizedBox(height: 8),
              Text('デザイン見習い',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('レベル ${p.level}',
                  style: KdTheme.dot(size: 16, color: KdColors.ink900)),
            ]),
          ),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Column(children: [
              _statRow(context, Icons.star, 'XP', '${p.xp}'),
              _statRow(context, Icons.monetization_on, 'コイン', '${p.coins}'),
              _statRow(context, Icons.favorite, 'ストリーク', '${p.streak}日'),
              _statRow(context, Icons.vpn_key, '宝箱の鍵', '${p.keys}'),
              _statRow(context, Icons.inventory, '納品数',
                  '${p.deliveredQuestIds.length}件'),
            ]),
          ),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Text(
              '納品ポートフォリオ・称号・設定は次のマイルストーンで実装予定だよ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: KdColors.gold500),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        Text(value, style: KdTheme.dot(size: 15, color: KdColors.ink900)),
      ]),
    );
  }
}
