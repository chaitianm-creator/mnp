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

/// SC-31 エリア詳細(町ビュー)。授かり効果の中心画面。
/// DEMO は骨格のみ — 本番はドット絵の町全景(発展3段階の差分レイヤー)。
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

    return Scaffold(
      appBar: AppBar(title: Text(area.name)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          // 町の全景プレースホルダ(発展stageで色が濃くなる)
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: area.color.withOpacity(0.2 + stage * 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KdColors.border, width: 1.5),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ]),
      ),
    );
  }
}
