import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// SC-10 ホーム = ステージパス。
/// Duolingo様式の縦パス: 上からステージノードが蛇行し、
/// 「いま挑戦できる1個」だけが桜ピンクで光る(迷わせない)。
/// 設計目標: 起動 → クエスト開始まで 2 タップは維持(スタートノード即タップ)。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(todayOffersProvider);
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _StatsBar(streak: progress.streak, keys: progress.keys),
          const SizedBox(height: 8),
          const _AreaBand(
            areaLabel: 'エリア①',
            title: 'はじまりの街（ミポリン村）',
          ),
          if (progress.reservedQuestId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                const Icon(Icons.mail, color: KdColors.pink500, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('予約したお仕事「${progress.reservedTeaser}」はあした届くよ！',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ]),
            ),
          Expanded(
            child: offers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('あれれ、王国とつながらないみたい')),
              data: (quests) => _StagePath(
                quests: quests,
                deliveredIds: progress.deliveredQuestIds,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 上部ステータス(Duolingo様式のトップバー): 連続日数ハート + カギ。
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.streak, required this.keys});
  final int streak;
  final int keys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(children: [
        const Icon(Icons.local_florist, color: KdColors.pink500, size: 22),
        const SizedBox(width: 4),
        Text('デザイン王国',
            style: KdTheme.dot(size: 15, color: KdColors.heading)
                .copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        const Icon(Icons.favorite, color: KdColors.pink500, size: 20),
        const SizedBox(width: 4),
        Text('$streak', style: KdTheme.dot(size: 16, color: KdColors.ink900)),
        const SizedBox(width: 14),
        const Icon(Icons.vpn_key, color: KdColors.gold500, size: 18),
        const SizedBox(width: 3),
        Text('$keys', style: KdTheme.dot(size: 15, color: KdColors.ink900)),
      ]),
    );
  }
}

/// エリアバンド(「ユニット64」の緑バンドに相当する桜ピンクの帯)。
class _AreaBand extends StatelessWidget {
  const _AreaBand({required this.areaLabel, required this.title});
  final String areaLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: KdColors.pink500,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: KdColors.pink700, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.pink700, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(areaLabel,
            style: KdTheme.dot(size: 12, color: Colors.white)),
        const SizedBox(height: 2),
        Text(title,
            style: KdTheme.dot(size: 18, color: Colors.white)
                .copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// パス上のノード種別。
enum _NodeKind { quest, chest, locked }

class _PathNode {
  const _PathNode(this.kind, {this.quest, this.icon});
  final _NodeKind kind;
  final Quest? quest;
  final IconData? icon;
}

/// 縦に蛇行するステージパス本体。
class _StagePath extends StatelessWidget {
  const _StagePath({required this.quests, required this.deliveredIds});
  final List<Quest> quests;
  final Set<String> deliveredIds;

  // Duolingo様式の蛇行(左右への振れ幅の並び)
  static const _sway = [0.0, 0.45, 0.7, 0.45, 0.0, -0.45, -0.7, -0.45];

  @override
  Widget build(BuildContext context) {
    final nodes = <_PathNode>[
      for (final q in quests) _PathNode(_NodeKind.quest, quest: q),
      const _PathNode(_NodeKind.chest),
      const _PathNode(_NodeKind.locked, icon: Icons.fitness_center),
      const _PathNode(_NodeKind.locked, icon: Icons.lock),
      const _PathNode(_NodeKind.locked, icon: Icons.menu_book),
    ];

    final allQuestsDone =
        quests.every((q) => deliveredIds.contains(q.questId));
    // 「いま挑戦できる1個」= 最初の未納品クエスト
    final activeIndex =
        nodes.indexWhere((n) => n.kind == _NodeKind.quest && !deliveredIds.contains(n.quest!.questId));

    return ListView.builder(
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      itemCount: nodes.length,
      itemBuilder: (context, i) {
        final node = nodes[i];
        final sway = _sway[i % _sway.length];
        final delivered = node.kind == _NodeKind.quest &&
            deliveredIds.contains(node.quest!.questId);
        final active = i == activeIndex;
        final chestOpen = node.kind == _NodeKind.chest && allQuestsDone;

        return SizedBox(
          height: active ? 156 : 104,
          child: Stack(children: [
            // みぽりん先生の応援スポット(パス脇の飾り)
            if (i == 2)
              Align(
                alignment: const Alignment(-0.8, 0),
                child: _MiporinSpot(),
              ),
            Align(
              alignment: Alignment(sway, 1),
              child: _StageNode(
                node: node,
                delivered: delivered,
                active: active,
                chestOpen: chestOpen,
                onTap: () => _onNodeTap(context, node,
                    delivered: delivered, active: active, chestOpen: chestOpen),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _onNodeTap(BuildContext context, _PathNode node,
      {required bool delivered,
      required bool active,
      required bool chestOpen}) {
    switch (node.kind) {
      case _NodeKind.quest:
        if (active || delivered) {
          context.push('/quest/${node.quest!.questId}');
        } else {
          _lockedMessage(context);
        }
      case _NodeKind.chest:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(chestOpen
                ? 'ごほうびボックス！つづきのお仕事は v1.1 で届くよ♡'
                : 'ステージをクリアするとごほうびがもらえるよ'),
          ));
      case _NodeKind.locked:
        _lockedMessage(context);
    }
  }

  void _lockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('まずは上のステージをクリアしよう！一歩ずつでいいの♡'),
      ));
  }
}

/// ステージノード(円形3Dボタン)。
///  - 挑戦可能: 桜ピンク + 「スタート」吹き出し + 白リング
///  - クリア済み: ゴールド + 花
///  - 未解放: ベージュグレー + 鍵など
class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.node,
    required this.delivered,
    required this.active,
    required this.chestOpen,
    required this.onTap,
  });
  final _PathNode node;
  final bool delivered;
  final bool active;
  final bool chestOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color edge;
    final IconData icon;
    if (node.kind == _NodeKind.chest) {
      fill = chestOpen ? KdColors.gold500 : const Color(0xFFD8CBB4);
      edge = chestOpen ? const Color(0xFFB88A18) : const Color(0xFFB3A68E);
      icon = Icons.redeem;
    } else if (delivered) {
      fill = KdColors.gold500;
      edge = const Color(0xFFB88A18);
      icon = Icons.local_florist;
    } else if (active) {
      fill = KdColors.pink500;
      edge = KdColors.pink700;
      icon = Icons.star;
    } else {
      fill = const Color(0xFFD8CBB4); // 未解放のベージュグレー
      edge = const Color(0xFFB3A68E);
      icon = node.icon ?? Icons.lock;
    }

    // ドット絵の作法: 全ノードに焦げ茶の輪郭。挑戦可能ノードは白いハローで囲む。
    Widget circle = Container(
      width: active ? 76 : 68,
      height: active ? 76 : 68,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: KdColors.wood900, width: 2.5),
        boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 5))],
      ),
      child: Icon(icon, color: Colors.white, size: active ? 38 : 30),
    );
    if (active) {
      circle = Container(
        padding: const EdgeInsets.all(4),
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: circle,
      );
    }

    return Semantics(
      button: true,
      label: node.kind == _NodeKind.quest
          ? node.quest!.title
          : (node.kind == _NodeKind.chest ? 'ごほうびボックス' : '未解放ステージ'),
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (active) ...[
            const _StartBalloon(),
            const SizedBox(height: 6),
          ],
          circle,
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}

/// 「スタート」吹き出し(Duolingoのスタートバルーン様式)。
class _StartBalloon extends StatelessWidget {
  const _StartBalloon();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.pink500, width: 2),
        ),
        child: Text('スタート',
            style: KdTheme.dot(size: 14, color: KdColors.pink700)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
      // 吹き出しの三角
      CustomPaint(
        size: const Size(14, 7),
        painter: _TrianglePainter(),
      ),
    ]);
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = KdColors.pink500);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// みぽりん先生の応援スポット(パス脇の飾り。本番はドット絵に差し替え)。
class _MiporinSpot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: KdColors.pink100,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.pink500, width: 2),
        ),
        child: const Icon(Icons.favorite, color: KdColors.pink500, size: 32),
      ),
      const SizedBox(height: 4),
      Text('みぽりん先生',
          style: KdTheme.dot(size: 11, color: KdColors.ink900)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Icon(Icons.star,
              size: 14, color: KdColors.border.withOpacity(0.35)),
      ]),
    ]);
  }
}
