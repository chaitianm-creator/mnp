import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// エリア定義(Phase 8 §1.2 の確定マッピング)。
/// 本番は areas コレクション(Phase 5 §2.1)から取得 — DEMO は静的定義。
class AreaDef {
  const AreaDef({
    required this.id,
    required this.order,
    required this.name,
    required this.mindTheme,
    required this.skillLabel,
    required this.icon,
    required this.color,
  });
  final String id;
  final int order;
  final String name;
  final String mindTheme;
  final String skillLabel;
  final IconData icon;
  final Color color;
}

const kAreas = [
  AreaDef(
      id: 'area_01_hajimari',
      order: 1,
      name: 'はじまりの街（ミポリン村）',
      mindTheme: '冒険のスタート',
      skillLabel: '仕事の型',
      icon: Icons.home_work,
      color: KdColors.pink500),
  AreaDef(
      id: 'area_02_migaki',
      order: 2,
      name: 'みがき上げの森',
      mindTheme: '自分磨き・習慣化',
      skillLabel: '自己管理',
      icon: Icons.forest,
      color: KdColors.forest700),
  AreaDef(
      id: 'area_03_commu',
      order: 3,
      name: 'コミュ力の湖',
      mindTheme: '対話力・伝え方',
      skillLabel: 'ヒアリング',
      icon: Icons.water,
      color: KdColors.ocean500),
  AreaDef(
      id: 'area_04_jishin',
      order: 4,
      name: '自信の塔',
      mindTheme: '自己肯定感',
      skillLabel: '提案力',
      icon: Icons.castle,
      color: KdColors.gold500),
  AreaDef(
      id: 'area_05_yaruki',
      order: 5,
      name: 'やる気の火山',
      mindTheme: '行動力・継続力',
      skillLabel: '継続',
      icon: Icons.local_fire_department,
      color: KdColors.lava500),
  AreaDef(
      id: 'area_06_nakama',
      order: 6,
      name: '仲間の大草原',
      mindTheme: '仲間・チームワーク',
      skillLabel: 'コミュニティ',
      icon: Icons.grass,
      color: KdColors.grass500),
  AreaDef(
      id: 'area_07_shiren',
      order: 7,
      name: '試練の洞窟',
      mindTheme: '壁を乗り越える',
      skillLabel: '改善力',
      icon: Icons.landscape,
      color: KdColors.wood700),
  AreaDef(
      id: 'area_08_miporin',
      order: 8,
      name: 'みぽりん城',
      mindTheme: '理想の未来・ゴール',
      skillLabel: '王国認定',
      icon: Icons.favorite,
      color: KdColors.pink700),
];

/// SC-30 世界マップ。解放状態と発展度を一覧(未解放=セピア+雲)。
class WorldMapPage extends ConsumerWidget {
  const WorldMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ワールドマップ')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('王国中の困りごとを、デザインで解決しよう',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final area in kAreas) ...[
            _AreaNode(
              area: area,
              // DEMO: エリア①のみ解放。②以降は①クリア(12件)で解放(Phase 5 §2.1)
              unlocked: area.order == 1 ||
                  (progress.areaDelivered['area_01_hajimari'] ?? 0) >= 12,
              stage: progress.stageOf(area.id),
              delivered: progress.areaDelivered[area.id] ?? 0,
            ),
            const SizedBox(height: 12),
          ],
        ]),
      ),
    );
  }
}

class _AreaNode extends StatelessWidget {
  const _AreaNode(
      {required this.area,
      required this.unlocked,
      required this.stage,
      required this.delivered});
  final AreaDef area;
  final bool unlocked;
  final int stage;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    final child = KdParchmentCard(
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: unlocked ? area.color : KdColors.border.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: KdColors.wood900, width: 2),
          ),
          child: Icon(unlocked ? area.icon : Icons.cloud,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${area.order}. ${area.name}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: unlocked
                        ? KdColors.ink900
                        : KdColors.ink900.withOpacity(0.4))),
            const SizedBox(height: 2),
            Text(unlocked ? area.mindTheme : '？？？',
                style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
        if (unlocked)
          Column(children: [
            Text('発展', style: KdTheme.dot(size: 11, color: KdColors.ink900)),
            Row(children: [
              for (var i = 1; i <= 3; i++)
                Icon(Icons.local_florist,
                    size: 16,
                    color: i <= stage
                        ? KdColors.pink500
                        : KdColors.border.withOpacity(0.3)),
            ]),
          ])
        else
          const Icon(Icons.lock, color: KdColors.wood700),
      ]),
    );

    if (!unlocked) return Opacity(opacity: 0.7, child: child);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/area/${area.id}'),
      child: child,
    );
  }
}

/// エリアガイドの静的コンテンツ(仲間の大草原様式のエリア紹介)。
/// 本番は areas コレクションから取得 — DEMO はエリア①のみ定義。
class _Spot {
  const _Spot(this.icon, this.color, this.name, this.desc);
  final IconData icon;
  final Color color;
  final String name;
  final String desc;
}

class _RecQuest {
  const _RecQuest(this.title, this.exp, {this.questId});
  final String title;
  final String exp;
  final String? questId;
}

class _Reward {
  const _Reward(this.icon, this.color, this.label, this.value);
  final IconData icon;
  final Color color;
  final String label;
  final String value;
}

class _AreaGuide {
  const _AreaGuide({
    required this.subtitle,
    required this.concept,
    required this.spots,
    required this.quests,
    required this.rewards,
    required this.teacherMessage,
    required this.footer,
  });
  final String subtitle;
  final String concept;
  final List<_Spot> spots;
  final List<_RecQuest> quests;
  final List<_Reward> rewards;
  final String teacherMessage;
  final String footer;
}

const _guides = <String, _AreaGuide>{
  'area_01_hajimari': _AreaGuide(
    subtitle: '〜はじめての仕事と出会う、冒険のスタート地点〜',
    concept: 'はじめてでも、だいじょうぶ。この街の住民はみんな、'
        'デザイン見習いのあなたを待っています。'
        '小さな依頼をひとつずつクリアして、「仕事の型」を身につけよう！',
    spots: [
      _Spot(Icons.storefront, KdColors.pink500, 'パン屋のマルコ',
          '・はじめての依頼主。「聞く→つくる→届ける」を体験しよう'),
      _Spot(Icons.content_cut, KdColors.ocean500, '美容室のリナ',
          '・3分のミニ依頼。「選ばれるデザイン」の感覚をつかもう'),
      _Spot(Icons.assignment, KdColors.wood700, '依頼掲示板',
          '・きょうの依頼はここでチェック。あなたを待ってる人がいるよ'),
      _Spot(Icons.favorite, KdColors.pink700, 'みぽりん先生の家',
          '・納品前の添削タイム。よかったところから教えてくれるよ'),
      _Spot(Icons.water_drop, KdColors.ocean500, '噴水広場',
          '・連続日数のハートが育つ、みんなの憩いの場'),
      _Spot(Icons.flag, KdColors.gold500, '王国の門',
          '・12件納品でボス戦が解放！次のエリアへの入り口'),
    ],
    quests: [
      _RecQuest('新商品『もちもち王国パン』のPOP', 'EXP+50', questId: 'q_marco_01'),
      _RecQuest('お店の看板、どっちがいい？', 'EXP+20', questId: 'q_mini_001'),
      _RecQuest('目標を決めて冒険をはじめよう', 'EXP+10'),
      _RecQuest('みぽりん先生にあいさつしよう', 'EXP+10'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+50'),
      _Reward(Icons.monetization_on, KdColors.gold500, 'コイン', '+10'),
      _Reward(Icons.vpn_key, KdColors.gold500, 'カギ（たまにドロップ）', '+1'),
      _Reward(Icons.local_florist, KdColors.pink500, '町の発展レベル', 'UP'),
      _Reward(Icons.redeem, KdColors.pink700, 'ボス戦解放', '12件納品'),
    ],
    teacherMessage: '一人で頑張ることも大切だけど、\n'
        'はじめの一歩がいちばん勇気がいるの。\n'
        'あなたなら ぜったいできるよ！\n'
        '一歩ずつでいいの。いっしょに\n'
        '理想の未来へ進んでいこうね♡',
    footer: 'はじめての納品が、冒険の第一歩だよ！',
  ),
};

/// SC-31 エリア詳細(町ビュー)。授かり効果の中心画面。
/// エリアガイドがあるエリアは「仲間の大草原」様式の紹介ページを表示。
class AreaDetailPage extends ConsumerWidget {
  const AreaDetailPage({super.key, required this.areaId});
  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = kAreas.firstWhere((a) => a.id == areaId,
        orElse: () => kAreas.first);
    final progress = ref.watch(userProgressProvider);
    final delivered = progress.areaDelivered[areaId] ?? 0;
    final stage = progress.stageOf(areaId);
    final guide = _guides[areaId];

    return Scaffold(
      appBar: AppBar(title: Text(area.name)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (guide != null) ...[
            // ── リボンタイトル + サブタイトル ──
            Center(child: KdRibbonBanner(area.name, fontSize: 17)),
            const SizedBox(height: 6),
            Center(
              child: Text(guide.subtitle,
                  style: KdTheme.dot(size: 12, color: KdColors.pink700)),
            ),
            const SizedBox(height: 16),
            // ── コンセプト ──
            const KdSectionHeader('コンセプト'),
            const SizedBox(height: 8),
            KdParchmentCard(
              child: Text(guide.concept,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 20),
            // ── この街でできること(スポット一覧) ──
            Center(child: KdRibbonBanner('この街でできること', fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Column(children: [
                for (final (i, spot) in guide.spots.indexed) ...[
                  if (i > 0) const Divider(height: 16),
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: spot.color,
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: KdColors.wood900, width: 2),
                      ),
                      child:
                          Icon(spot.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(spot.name,
                                style: KdTheme.dot(
                                        size: 14, color: KdColors.heading)
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(spot.desc,
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ]),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // ── おすすめクエスト ──
            Center(child: KdRibbonBanner('おすすめクエスト', fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Column(children: [
                for (final (i, q) in guide.quests.indexed) ...[
                  if (i > 0) const Divider(height: 14),
                  InkWell(
                    onTap: q.questId == null
                        ? null
                        : () => context.push('/quest/${q.questId}'),
                    child: Row(children: [
                      const Icon(Icons.star,
                          size: 18, color: KdColors.gold500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(q.title,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: KdColors.pink100,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: KdColors.pink500, width: 1.5),
                        ),
                        child: Text(q.exp,
                            style: KdTheme.dot(
                                size: 12, color: KdColors.pink700)),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // ── クリア報酬(例) ──
            Center(child: KdRibbonBanner('クリア報酬（例）', fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Column(children: [
                for (final (i, r) in guide.rewards.indexed) ...[
                  if (i > 0) const Divider(height: 14),
                  Row(children: [
                    Icon(r.icon, size: 20, color: r.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.label,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text(r.value,
                        style: KdTheme.dot(size: 15, color: KdColors.heading)
                            .copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // ── みぽりん先生からのメッセージ ──
            Center(
                child: KdRibbonBanner('みぽりん先生からのメッセージ', fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KdColors.pink100,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: KdColors.pink500, width: 2),
                      ),
                      child: const Icon(Icons.favorite,
                          color: KdColors.pink500, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(guide.teacherMessage,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ]),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // ガイド未定義エリアの骨格(発展stageで色が濃くなる)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: area.color.withOpacity(0.2 + stage * 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: KdColors.border, width: 2),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(area.icon, size: 64, color: area.color),
                  Text('発展レベル $stage / 3',
                      style: KdTheme.dot(size: 14, color: KdColors.ink900)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            KdParchmentCard(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('このエリアで育つもの',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('マインド: ${area.mindTheme}',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('スキル: ${area.skillLabel}',
                    style: Theme.of(context).textTheme.bodyLarge),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          // ── エリアクリアまで(共通) ──
          KdParchmentCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('エリアクリアまで',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                Text('$delivered / 12',
                    style: KdTheme.dot(size: 15, color: KdColors.ink900)),
              ]),
              const SizedBox(height: 8),
              KdProgressBar(value: delivered / 12),
              const SizedBox(height: 8),
              Text('12件納品でボス戦（大型案件）が解放されるよ',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          if (guide != null) ...[
            const SizedBox(height: 20),
            Center(child: KdRibbonBanner(guide.footer, fontSize: 13)),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}
