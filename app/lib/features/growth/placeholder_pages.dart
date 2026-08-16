import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

// 6系統のスキル(Phase 8 §1.2)。淡いパステルで色分け。
const _skillCategories = [
  ('制作技術', Icons.brush_rounded, Color(0xFFF4B8C8)),
  ('ヒアリング', Icons.hearing_rounded, Color(0xFFB8D4EE)),
  ('提案力', Icons.lightbulb_rounded, Color(0xFFF2DFA7)),
  ('改善力', Icons.refresh_rounded, Color(0xFFF4CBA8)),
  ('自己管理', Icons.schedule_rounded, Color(0xFFC4E0B2)),
  ('コミュニティ', Icons.group_rounded, Color(0xFFDCD3F2)),
];

// そうびアイテム。DEMO: 納品数に応じて1つずつ解放される。
const _equipItems = [
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

/// 中央のピンクチップ見出し(わたし/アイテム共通)。
Widget _chipHeader(String label) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0C9D6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF9E5570),
                fontSize: 13,
                fontWeight: FontWeight.w900)),
      ),
    );

/// アイテム(下部タブ)。そうび・どうぐの一覧。納品で1つずつ解放。
class ItemsPage extends ConsumerWidget {
  const ItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProgressProvider);
    final delivered = p.deliveredQuestIds.length;

    return PnShell(
      current: 'アイテム',
      spTitle: 'アイテム',
      showRail: false,
      mainBuilder: (context, wide) => [
        Row(children: [
          const Text('アイテム',
              style: TextStyle(
                  color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        ]),
        const SizedBox(height: 4),
        const Text('お仕事を納品すると、そうび・どうぐが1つずつ手に入るよ！',
            style: TextStyle(color: pnSub, fontSize: 12.5)),
        const SizedBox(height: 14),
        _chipHeader('そうび・どうぐ'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 3 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 172,
          ),
          itemCount: _equipItems.length,
          itemBuilder: (context, i) {
            final item = _equipItems[i];
            return _ItemCard(
              name: item.$1,
              kind: item.$2,
              icon: item.$3,
              effect: item.$4,
              flavor: item.$5,
              owned: i < delivered, // 納品1件ごとに1つ解放(DEMO)
            );
          },
        ),
      ],
    );
  }
}

/// SC-50 わたし(ギルドカード) = PRO NAVI ワイヤーフレーム4a/4b準拠。
/// 共通シェル(右レールなし)にプロフィール/ぼうけんの記録/じっせきバッジ/
/// みぽりん先生からのメッセージを差し込む。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProgressProvider);
    final account = ref.watch(accountProvider);
    final outfit = ref.watch(outfitProvider);
    final delivered = p.deliveredQuestIds.length;

    // 実績バッジ(DEMO: 進捗から判定。本番は achievements コレクション)
    final badges = [
      ('はじめての納品', Icons.emoji_events_rounded, const Color(0xFFF2DFA7),
          delivered >= 1),
      ('おかわり達人', Icons.replay_rounded, const Color(0xFFF4B8C8),
          delivered >= 2),
      ('よやく上手', Icons.mail_rounded, const Color(0xFFB8D4EE),
          p.reservedQuestId != null),
      ('3日れんぞく', Icons.favorite_rounded, const Color(0xFFF0C9D6),
          p.streak >= 3),
      ('エリア①クリア', Icons.flag_rounded, const Color(0xFFC4E0B2),
          (p.areaDelivered['area_01_hajimari'] ?? 0) >= 12),
      ('王国認定', Icons.workspace_premium_rounded,
          const Color(0xFFE3C57C), false), // v1.1
    ];

    return PnShell(
      current: 'わたし',
      spTitle: 'わたし',
      showRail: false,
      mainBuilder: (context, wide) => [
        // ── 上部バー(タイトル + Lv + 設定) ──
        Row(children: [
          const Text('わたし',
              style: TextStyle(
                  color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 20, color: pnSub),
            onPressed: () => context.push('/settings'),
          ),
        ]),
        const SizedBox(height: 8),
        // ── プロフィールカード ──
        PnPanel(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pnPink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: PixelSprite(
                  rows: heroineFrontRows,
                  palette: heroinePaletteFor(outfit),
                  width: 96),
            ),
            const SizedBox(height: 10),
            Text(account?.nickname ?? 'デザイン見習い',
                style: const TextStyle(
                    color: pnInk, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            const Text('〜 王国認定デザイナーを目指して 〜',
                style: TextStyle(color: pnSub, fontSize: 11.5)),
            const SizedBox(height: 14),
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
          ]),
        ),
        const SizedBox(height: 20),
        // ── スキル(6系統。旧スキルページから集約) ──
        _chipHeader('スキル'),
        const SizedBox(height: 12),
        PnPanel(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final (i, cat) in _skillCategories.indexed) ...[
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
                              borderRadius: BorderRadius.circular(999),
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
                              value: switch (i) {
                                0 => (0.20 + delivered * 0.22)
                                    .clamp(0.0, 0.95),
                                1 => (0.15 + delivered * 0.18)
                                    .clamp(0.0, 0.95),
                                _ => 0.10 + delivered * 0.03,
                              },
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
        _chipHeader('ぼうけんの記録'),
        const SizedBox(height: 12),
        PnPanel(
          child: Column(children: [
            _statRow(const Color(0xFFF2DFA7), Icons.auto_awesome_rounded,
                'けいけんち', '${p.xp}'),
            _divider(),
            _statRow(const Color(0xFFF4CBA8),
                Icons.monetization_on_rounded, 'コイン', '${p.coins}'),
            _divider(),
            _statRow(const Color(0xFFF4B8C8), Icons.favorite_rounded,
                'れんぞく日数', '${p.streak}日'),
            _divider(),
            _statRow(const Color(0xFFB8D4EE), Icons.vpn_key_rounded,
                '宝箱のカギ', '${p.keys}'),
            _divider(),
            _statRow(const Color(0xFFC4E0B2), Icons.inventory_2_rounded,
                '納品したお仕事', '$delivered件'),
          ]),
        ),
        const SizedBox(height: 20),
        _chipHeader('じっせきバッジ'),
        const SizedBox(height: 12),
        PnPanel(
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
                        color: earned ? color : pnBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: earned
                                ? Color.lerp(color, pnInk, 0.25)!
                                : pnLine,
                            width: 1.5),
                      ),
                      child: Icon(earned ? icon : Icons.lock_rounded,
                          size: 24, color: earned ? pnInk : pnSub),
                    ),
                    const SizedBox(height: 6),
                    Text(earned ? name : '？？？',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: earned ? pnInk : pnSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _chipHeader('みぽりん先生からのメッセージ'),
        const SizedBox(height: 12),
        PnPanel(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: pnPink, shape: BoxShape.circle),
              child: PixelSprite(
                  rows: miporinRows(0),
                  palette: miporinPalette,
                  width: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  delivered == 0
                      ? 'ようこそ、実践デザイナー島へ！\nさいしょの一歩を、いっしょに踏み出そうね♪'
                      : 'ここまで $delivered件も納品できたね！\nあなたの努力は、ちゃんと未来につながっているよ♡',
                  style: const TextStyle(
                      color: pnInk, fontSize: 13.5, height: 1.7)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── ピンクの帯 ──
        Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0C9D6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('✦ きょうのがんばりも、ちゃんと未来につながってるよ♪ ✦',
                style: TextStyle(
                    color: Color(0xFF9E5570),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(height: 1, color: pnLine),
      );

  Widget _statRow(Color color, IconData icon, String label, String value) {
    return Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: pnInk),
      ),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: pnInk, fontSize: 13.5)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              color: Color(0xFFD16E8E),
              fontSize: 14,
              fontWeight: FontWeight.w900)),
    ]);
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
              size: 22, color: owned ? const Color(0xFFD16E8E) : pnSub),
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
