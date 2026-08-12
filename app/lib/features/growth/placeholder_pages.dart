import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';

/// SC-40 スキル = 画面いっぱいの全幅レイアウト(ワイヤーフレーム準拠)。
/// 上部バー(スキル+Lv+アバター) + EXPと6スキルの一枚カード +
/// そうび・どうぐ(中央チップ見出し+グリッド)。
class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  // 6系統(Phase 8 §1.2)。淡いパステルで色分け。
  static const _categories = [
    ('制作技術', Icons.brush_rounded, Color(0xFFF4B8C8)),
    ('ヒアリング', Icons.hearing_rounded, Color(0xFFB8D4EE)),
    ('提案力', Icons.lightbulb_rounded, Color(0xFFF2DFA7)),
    ('改善力', Icons.refresh_rounded, Color(0xFFF4CBA8)),
    ('自己管理', Icons.schedule_rounded, Color(0xFFC4E0B2)),
    ('コミュニティ', Icons.group_rounded, Color(0xFFDCD3F2)),
  ];

  // そうびアイテム。DEMO: 納品数に応じて1つずつ解放される。
  static const _items = [
    ('デザインペン', '伝説の武器', Icons.edit_rounded, '制作力 +9',
        'アイデアを形にする魔法のペン。'),
    ('共感のリボン', 'そうび', Icons.loyalty_rounded, '伝える力 +8',
        '相手の気持ちに寄り添う魔法のリボン。'),
    ('自信のティアラ', 'そうび', Icons.workspace_premium_rounded,
        '自己肯定感 +10', '自分の魅力に気づける魔法のティアラ。'),
    ('実践のローブ', 'そうび', Icons.checkroom_rounded, '行動力 +10',
        '学びを成果につなげる魔法のローブ。'),
    ('信頼のリング', 'そうび', Icons.donut_large_rounded, '選ばれる力 +10',
        '人とのご縁を育てる魔法のリング。'),
    ('未来のコンパス', 'どうぐ', Icons.explore_rounded, '判断力 +8',
        '進むべき方向を示してくれるコンパス。'),
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
      backgroundColor: pnBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 760 ? 3 : 2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              // ── 上部バー(タイトル + Lv + アバター) ──
              Row(children: [
                const Text('スキル',
                    style: TextStyle(
                        color: pnInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pnYellow.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Lv.${p.level}',
                      style: const TextStyle(
                          color: pnInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                    radius: 15,
                    backgroundColor: pnPink,
                    child: Text('🙂', style: TextStyle(fontSize: 14))),
              ]),
              const SizedBox(height: 12),
              // ── EXP + 6スキル(一枚カード) ──
              PnPanel(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: pnBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pnLine),
                      ),
                      child: Text('Lv.${p.level}',
                          style: const TextStyle(
                              color: pnInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('EXP',
                                  style: TextStyle(
                                      color: pnSub,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text('${p.xp} / 100',
                                  style: const TextStyle(
                                      color: pnInk,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ]),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                  value: (p.xp % 100) / 100,
                                  minHeight: 7,
                                  backgroundColor: pnBg,
                                  color: const Color(0xFFE98FA9)),
                            ),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  for (final (i, cat) in _categories.indexed) ...[
                    if (i > 0) const SizedBox(height: 14),
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cat.$3,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat.$2, color: pnInk, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(cat.$1,
                                    style: const TextStyle(
                                        color: pnInk,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: pnBg,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: const Text('Lv.1',
                                      style: TextStyle(
                                          color: pnSub,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                    value: skillValue(i),
                                    minHeight: 7,
                                    backgroundColor: pnBg,
                                    color: cat.$3),
                              ),
                            ]),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
              // ── そうび・どうぐ(中央チップ見出し) ──
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0C9D6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('そうび・どうぐ',
                      style: TextStyle(
                          color: Color(0xFF9E5570),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 172,
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
              const SizedBox(height: 8),
              const Center(
                child: Text('お仕事を納品すると、そうびが1つずつ手に入るよ',
                    style: TextStyle(color: pnSub, fontSize: 12)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// スキルバー(プロフィールで使用): 角丸2トーンの進捗バー。
class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.value, required this.color});
  final double value; // 0.0-1.0
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: const Color(0xFFF7F5EF),
          color: color),
    );
  }
}

/// アイテムカード(そうび・どうぐ)。未入手はシルエット。
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
    return PnPanel(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(kind,
            style: TextStyle(
                color: owned ? const Color(0xFFD16E8E) : pnSub,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: owned ? pnPink : pnBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(owned ? icon : Icons.lock_rounded,
              size: 22,
              color: owned ? const Color(0xFFD16E8E) : pnSub),
        ),
        const SizedBox(height: 7),
        Text(owned ? name : '？？？',
            style: TextStyle(
                color: owned ? pnInk : pnSub,
                fontSize: 12.5,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(owned ? effect : '- - -',
            style: TextStyle(
                color: owned ? const Color(0xFFD16E8E) : pnSub,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Expanded(
          child: Text(owned ? flavor : 'お仕事を納品すると手に入るよ',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                  color: pnSub, fontSize: 10.5, height: 1.45)),
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
