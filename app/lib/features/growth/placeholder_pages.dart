import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-40 スキル = RPGステータス画面。
/// 6系統のスキルバー(HP/MPバー様式) + そうびアイテム(アイテムカード素材様式)。
/// ツリーUI・分岐選択は Phase 9 後半の次マイルストーンで実装。
class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  // 6系統(Phase 8 §1.2)。バーの色はエリア地形の語彙と揃える。
  static const _categories = [
    ('制作技術', Icons.brush, KdColors.pink500),
    ('ヒアリング', Icons.hearing, KdColors.ocean500),
    ('提案力', Icons.lightbulb, KdColors.gold500),
    ('改善力', Icons.refresh, KdColors.lava500),
    ('自己管理', Icons.schedule, KdColors.grass500),
    ('コミュニティ', Icons.group, KdColors.pink700),
  ];

  // そうびアイテム(みぽりん王国 素材パックのアイテムカード)。
  // DEMO: 納品数に応じて1つずつ解放される。
  static const _items = [
    ('デザインペン', '伝説の武器', Icons.edit, '制作力 +9', 'アイデアを形にする魔法のペン。'),
    ('共感のリボン', 'そうび', Icons.loyalty, '伝える力 +8', '相手の気持ちに寄り添う魔法のリボン。'),
    ('自信のティアラ', 'そうび', Icons.workspace_premium, '自己肯定感 +10',
        '自分の魅力に気づける魔法のティアラ。'),
    ('実践のローブ', 'そうび', Icons.checkroom, '行動力 +10', '学びを成果につなげる魔法のローブ。'),
    ('信頼のリング', 'そうび', Icons.donut_large, '選ばれる力 +10', '人とのご縁を育てる魔法のリング。'),
    ('未来のコンパス', 'どうぐ', Icons.explore, '判断力 +8', '進むべき方向を示してくれるコンパス。'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProgressProvider);
    final delivered = p.deliveredQuestIds.length;
    // DEMO: 納品でバーが伸びる(本番は deliverQuest の skillPoints 反映)
    double skillValue(int i) => switch (i) {
          0 => (0.20 + delivered * 0.22).clamp(0.0, 0.95),
          1 => (0.15 + delivered * 0.18).clamp(0.0, 0.95),
          _ => 0.10 + delivered * 0.03,
        };

    return Scaffold(
      appBar: AppBar(title: const Text('スキル')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const KdBandMessage('敵はいない。敵は、昨日の自分。'),
          const SizedBox(height: 16),
          // ── ステータス(レベル枠 + EXPバー) ──
          KdParchmentCard(
            child: Row(children: [
              // レベル枠(素材パックの木製プレート様式)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: KdColors.wood900,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.gold500, width: 2),
                ),
                child: Text('Lv.${p.level}',
                    style: KdTheme.dot(size: 18, color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('EXP',
                        style: KdTheme.dot(size: 12, color: KdColors.ink900)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${p.xp} / 100',
                        style: KdTheme.dot(size: 12, color: KdColors.ink900)),
                  ]),
                  const SizedBox(height: 4),
                  _SkillBar(
                      value: (p.xp % 100) / 100, color: KdColors.grass500),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          // ── そだてるスキル(6系統のステータスバー) ──
          Center(child: KdRibbonBanner('そだてるスキル', fontSize: 14)),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Column(children: [
              for (final (i, c) in _categories.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.$3,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KdColors.wood900, width: 2),
                    ),
                    child: Icon(c.$2, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(c.$1,
                                style: KdTheme.dot(
                                        size: 13, color: KdColors.ink900)
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text('Lv.1',
                                style: KdTheme.dot(
                                    size: 12, color: KdColors.heading)),
                          ]),
                          const SizedBox(height: 4),
                          _SkillBar(value: skillValue(i), color: c.$3),
                        ]),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          // ── そうびアイテム(アイテムカード素材様式) ──
          Center(child: KdRibbonBanner('そうび・どうぐ', fontSize: 14)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 168,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final item = _items[i];
              final owned = i < delivered; // 納品1件ごとに1つ解放(DEMO)
              return _ItemCard(
                name: item.$1,
                kind: item.$2,
                icon: item.$3,
                effect: item.$4,
                flavor: item.$5,
                owned: owned,
              );
            },
          ),
          const SizedBox(height: 6),
          Text('お仕事を納品すると、そうびが1つずつ手に入るよ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          const KdBandMessage('コツコツ育てたスキルが、あなたの冒険を支えてくれるよ！'),
        ]),
      ),
    );
  }
}

/// スキルバー: HP/MPバー様式(木枠レール + 2トーン充填)。色はスキルごと。
class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.value, required this.color});
  final double value; // 0.0-1.0
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: KdColors.parchmentLight,
        border: Border.all(color: KdColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Column(children: [
            Expanded(
                child: Container(color: Color.lerp(color, Colors.white, 0.45))),
            Expanded(flex: 2, child: Container(color: color)),
          ]),
        ),
      ),
    );
  }
}

/// アイテムカード(そうび・どうぐ): 素材パックのカード様式。未入手はシルエット。
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.name,
    required this.kind,
    required this.icon,
    required this.effect,
    required this.flavor,
    required this.owned,
  });
  final String name;
  final String kind;
  final IconData icon;
  final String effect;
  final String flavor;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    return KdParchmentCard(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(kind,
            style: KdTheme.dot(
                size: 10,
                color: owned ? KdColors.heading : KdColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: owned ? KdColors.pink100 : KdColors.border.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: owned ? KdColors.pink500 : KdColors.border, width: 2),
          ),
          child: Icon(owned ? icon : Icons.lock,
              size: 24,
              color: owned ? KdColors.pink700 : KdColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(owned ? name : '？？？',
            style: KdTheme.dot(size: 12, color: KdColors.ink900)
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(owned ? effect : '- - -',
            style: KdTheme.dot(size: 11, color: KdColors.heading)),
        const SizedBox(height: 4),
        Expanded(
          child: Text(owned ? flavor : 'お仕事を納品すると手に入るよ',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11, height: 1.4)),
        ),
      ]),
    );
  }
}

/// SC-50 プロフィール = 冒険者カード。
/// キャラクターカード + ステータス + 実績バッジ + みぽりん先生からのメッセージ。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProgressProvider);
    final delivered = p.deliveredQuestIds.length;

    // 実績バッジ(DEMO: 進捗から判定。本番は achievements コレクション)
    final badges = [
      ('はじめての納品', Icons.emoji_events, KdColors.gold500, delivered >= 1),
      ('おかわり達人', Icons.replay, KdColors.pink500, delivered >= 2),
      ('よやく上手', Icons.mail, KdColors.ocean500, p.reservedQuestId != null),
      ('3日れんぞく', Icons.favorite, KdColors.pink700, p.streak >= 3),
      ('エリア①クリア', Icons.flag, KdColors.grass500,
          (p.areaDelivered['area_01_hajimari'] ?? 0) >= 12),
      ('王国認定', Icons.workspace_premium, KdColors.gold500, false), // v1.1
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('わたし'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'), // SC-53
        ),
      ]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          // ── 冒険者カード ──
          KdParchmentCard(
            child: Column(children: [
              // アバター(額入り)
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: KdColors.pink100,
                  shape: BoxShape.circle,
                  border: Border.all(color: KdColors.pink500, width: 3),
                  boxShadow: const [
                    BoxShadow(color: KdColors.pink700, offset: Offset(0, 3)),
                  ],
                ),
                child:
                    const Icon(Icons.person, size: 48, color: KdColors.pink700),
              ),
              const SizedBox(height: 10),
              Text('デザイン見習い',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text('〜 王国認定デザイナーを目指して 〜',
                  style: KdTheme.dot(size: 11, color: KdColors.ink900)),
              const SizedBox(height: 12),
              Row(children: [
                // レベル枠(木製プレート様式)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KdColors.wood900,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KdColors.gold500, width: 2),
                  ),
                  child: Text('Lv.${p.level}',
                      style: KdTheme.dot(size: 18, color: Colors.white)
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('EXP',
                              style: KdTheme.dot(
                                      size: 12, color: KdColors.ink900)
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text('${p.xp} / 100',
                              style: KdTheme.dot(
                                  size: 12, color: KdColors.ink900)),
                        ]),
                        const SizedBox(height: 4),
                        _SkillBar(
                            value: (p.xp % 100) / 100,
                            color: KdColors.grass500),
                      ]),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          // ── ぼうけんの記録(ステータス) ──
          Center(child: KdRibbonBanner('ぼうけんの記録', fontSize: 14)),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Column(children: [
              _statRow(context, Icons.auto_awesome, KdColors.gold500,
                  'けいけんち', '${p.xp}'),
              const Divider(height: 14),
              _statRow(context, Icons.monetization_on, KdColors.gold500,
                  'コイン', '${p.coins}'),
              const Divider(height: 14),
              _statRow(context, Icons.favorite, KdColors.pink500,
                  'れんぞく日数', '${p.streak}日'),
              const Divider(height: 14),
              _statRow(context, Icons.vpn_key, KdColors.gold500,
                  '宝箱のカギ', '${p.keys}'),
              const Divider(height: 14),
              _statRow(context, Icons.inventory, KdColors.wood700,
                  '納品したお仕事', '$delivered件'),
            ]),
          ),
          const SizedBox(height: 20),
          // ── じっせきバッジ ──
          Center(child: KdRibbonBanner('じっせきバッジ', fontSize: 14)),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final (name, icon, color, earned) in badges)
                  SizedBox(
                    width: 92,
                    child: Column(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: earned
                              ? color
                              : KdColors.border.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: earned
                                  ? KdColors.wood900
                                  : KdColors.border,
                              width: 2),
                          boxShadow: earned
                              ? [
                                  BoxShadow(
                                      color: Color.lerp(
                                          color, KdColors.wood900, 0.35)!,
                                      offset: const Offset(0, 3)),
                                ]
                              : null,
                        ),
                        child: Icon(earned ? icon : Icons.lock,
                            size: 26,
                            color: earned
                                ? Colors.white
                                : KdColors.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      Text(earned ? name : '？？？',
                          textAlign: TextAlign.center,
                          style: KdTheme.dot(
                              size: 11,
                              color: earned
                                  ? KdColors.ink900
                                  : KdColors.textSecondary)),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── みぽりん先生からのメッセージ ──
          Center(child: KdRibbonBanner('みぽりん先生からのメッセージ', fontSize: 14)),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KdColors.pink100,
                  shape: BoxShape.circle,
                  border: Border.all(color: KdColors.pink500, width: 2),
                ),
                child: const Icon(Icons.favorite,
                    color: KdColors.pink500, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    delivered == 0
                        ? 'ようこそ、デザイン王国へ！\nさいしょの一歩を、いっしょに\n踏み出そうね♪'
                        : 'ここまで $delivered件も納品できたね！\nあなたの努力は、ちゃんと\n未来につながっているよ♡',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const KdBandMessage('きょうのがんばりも、ちゃんと未来につながってるよ♪'),
        ]),
      ),
    );
  }

  Widget _statRow(BuildContext context, IconData icon, Color color,
      String label, String value) {
    return Row(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Text(label, style: Theme.of(context).textTheme.bodyLarge),
      const Spacer(),
      Text(value,
          style: KdTheme.dot(size: 15, color: KdColors.heading)
              .copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}
