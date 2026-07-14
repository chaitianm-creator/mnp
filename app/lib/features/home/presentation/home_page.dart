import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// SC-10 ホーム。
/// 「わかりやすさ」優先の情報設計:
///  ① あいさつヘッダー(だれの画面か) → ② エリアバンド(いまどこか)
///  → ③ きょうのサマリー(大きな数字) → ④ きょうの依頼(チェックリスト)
///  → ⑤ ぼうけんマップ(ゲームフィールド)。
/// 設計目標: 起動 → クエスト開始まで 2 タップは維持(依頼リスト即タップ)。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(todayOffersProvider);
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: offers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              const Center(child: Text('あれれ、王国とつながらないみたい')),
          data: (quests) {
            final delivered = progress.deliveredQuestIds;
            final doneCount =
                quests.where((q) => delivered.contains(q.questId)).length;
            final activeIndex =
                quests.indexWhere((q) => !delivered.contains(q.questId));

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Header(streak: progress.streak, keys: progress.keys),
                const SizedBox(height: 8),
                // タップでエリア紹介(SC-31)へ
                GestureDetector(
                  onTap: () => context.push('/area/area_01_hajimari'),
                  child: const _AreaBand(
                    areaLabel: 'エリア①',
                    title: 'はじまりの街（みぽりん村）',
                  ),
                ),
                if (progress.reservedQuestId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      const Icon(Icons.mail, color: KdColors.pink500, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            '予約したお仕事「${progress.reservedTeaser}」はあした届くよ！',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
                // ── きょうのサマリー(大きな数字で今日の状態がひと目でわかる) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: KdParchmentCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KdSectionHeader('きょうのサマリー'),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: _SummaryTile(
                                icon: Icons.check_circle,
                                label: 'できた依頼',
                                value: '$doneCount',
                                unit: '件',
                                color: const Color(0xFFF7E3A8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryTile(
                                icon: Icons.favorite,
                                label: 'れんぞく',
                                value: '${progress.streak}',
                                unit: '日',
                                color: KdColors.pink100,
                              ),
                            ),
                          ]),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                // ── きょうの依頼(チェックリスト: どれをやればいいか迷わない) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: KdParchmentCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KdSectionHeader('きょうの依頼'),
                          const SizedBox(height: 4),
                          for (final (i, q) in quests.indexed)
                            _QuestRow(
                              quest: q,
                              index: i,
                              done: delivered.contains(q.questId),
                              active: i == activeIndex,
                            ),
                        ]),
                  ),
                ),
                const SizedBox(height: 16),
                // ── ぼうけんマップ(進み具合を風景で楽しむ) ──
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: KdSectionHeader('ぼうけんマップ'),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: KdColors.wood900, width: 2.5),
                    ),
                    child: _StageField(
                      quests: quests,
                      deliveredIds: delivered,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// あいさつヘッダー: アバター + 呼びかけ + 連続日数ハート/カギ。
class _Header extends StatelessWidget {
  const _Header({required this.streak, required this.keys});
  final int streak;
  final int keys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: KdColors.pink100,
            shape: BoxShape.circle,
            border: Border.all(color: KdColors.wood900, width: 2.5),
          ),
          child: const Icon(Icons.person, size: 26, color: KdColors.pink700),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('おかえりなさい！',
              style: KdTheme.dot(size: 11, color: KdColors.ink900)),
          Text('デザイン見習いさん',
              style: KdTheme.dot(size: 15, color: KdColors.heading)
                  .copyWith(fontWeight: FontWeight.w700)),
        ]),
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

/// サマリータイル: 大きな数字でひと目で状態がわかる(参考UIのサマリー様式)。
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KdColors.wood900, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: KdColors.ink900),
          const SizedBox(width: 4),
          Text(label, style: KdTheme.dot(size: 11, color: KdColors.ink900)),
        ]),
        const SizedBox(height: 6),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.ideographic,
            children: [
              Text(value,
                  style: KdTheme.dot(size: 30, color: KdColors.ink900)
                      .copyWith(fontWeight: FontWeight.w700, height: 1.0)),
              const SizedBox(width: 3),
              Text(unit, style: KdTheme.dot(size: 12, color: KdColors.ink900)),
            ]),
      ]),
    );
  }
}

/// きょうの依頼の1行(チェックリスト様式)。
class _QuestRow extends ConsumerWidget {
  const _QuestRow({
    required this.quest,
    required this.index,
    required this.done,
    required this.active,
  });
  final Quest quest;
  final int index;
  final bool done;
  final bool active;

  static const _chipColors = [
    KdColors.ocean500,
    KdColors.pink500,
    KdColors.grass500,
    KdColors.gold500,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (done || active) {
          context.push('/quest/${quest.questId}');
        } else {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(
              content: Text('まずは上の依頼をクリアしよう！一歩ずつでいいの♡'),
            ));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _chipColors[index % _chipColors.length],
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: KdColors.wood900, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(quest.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          if (done)
            const Icon(Icons.check_circle, size: 20, color: KdColors.grass500)
          else if (active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KdColors.pink500,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KdColors.pink700, width: 1.5),
              ),
              child: Text('いまここ',
                  style: KdTheme.dot(size: 10, color: Colors.white)
                      .copyWith(fontWeight: FontWeight.w700)),
            )
          else
            Icon(Icons.lock, size: 18, color: KdColors.border.withOpacity(0.6)),
        ]),
      ),
    );
  }
}

/// エリアバンド(桜ピンクの帯)。
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

/// ゲームフィールド本体: 芝生 + タイルの道 + 木々 + 川の上にノードを配置。
class _StageField extends StatelessWidget {
  const _StageField({required this.quests, required this.deliveredIds});
  final List<Quest> quests;
  final Set<String> deliveredIds;

  // 蛇行(左右への振れ幅の並び)
  static const _sway = [0.0, 0.45, 0.7, 0.45, 0.0, -0.45, -0.7, -0.45];
  static const _rowH = 118.0;
  static const _topPad = 40.0;
  static const _bottomPad = 48.0;

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
    final activeIndex = nodes.indexWhere((n) =>
        n.kind == _NodeKind.quest &&
        !deliveredIds.contains(n.quest!.questId));

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final totalH = _topPad + nodes.length * _rowH + _bottomPad;
      // 各ノードの中心座標(タイルの道もこの座標を通る)
      final centers = <Offset>[
        for (var i = 0; i < nodes.length; i++)
          Offset(
            w / 2 + _sway[i % _sway.length] * (w * 0.28),
            _topPad + i * _rowH + _rowH / 2,
          ),
      ];

      return SizedBox(
          width: w,
          height: totalH,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(painter: _FieldPainter(centers: centers)),
            ),
            // みぽりん先生の応援スポット(フィールドの飾り)
            Positioned(
              left: 14,
              top: centers[2].dy - 56,
              child: const _MiporinSpot(),
            ),
            for (var i = 0; i < nodes.length; i++)
              _positionedNode(context, nodes[i], centers[i],
                  active: i == activeIndex,
                  delivered: nodes[i].kind == _NodeKind.quest &&
                      deliveredIds.contains(nodes[i].quest!.questId),
                  chestOpen:
                      nodes[i].kind == _NodeKind.chest && allQuestsDone),
          ]),
      );
    });
  }

  Widget _positionedNode(
      BuildContext context, _PathNode node, Offset center,
      {required bool active,
      required bool delivered,
      required bool chestOpen}) {
    // 円の中心が center に来るように配置(スタート吹き出しの分は上に伸ばす)
    const boxW = 120.0;
    final circleH = active ? 84.0 : 73.0;
    final balloonH = active ? 52.0 : 0.0;
    return Positioned(
      left: center.dx - boxW / 2,
      top: center.dy - circleH / 2 - balloonH,
      child: SizedBox(
        width: boxW,
        child: _StageNode(
          node: node,
          delivered: delivered,
          active: active,
          chestOpen: chestOpen,
          onTap: () => _onNodeTap(context, node,
              delivered: delivered, active: active, chestOpen: chestOpen),
        ),
      ),
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

/// ゲームフィールドの背景画: 芝生・タイルの道・木々・川・花(ドット絵の作法)。
/// 乱数は固定シード = 毎フレーム同じ絵(ちらつき防止)。
class _FieldPainter extends CustomPainter {
  const _FieldPainter({required this.centers});
  final List<Offset> centers;

  // フィールドパレット(参考ゲーム画面の実測系)
  static const _grass = Color(0xFF77B94C);
  static const _grassDark = Color(0xFF69AC41);
  static const _grassLight = Color(0xFF85C55C);
  static const _leaf = Color(0xFF2E7D32);
  static const _leafLight = Color(0xFF43A047);
  static const _trunk = Color(0xFF6D4C2F);
  static const _tile = Color(0xFFE3C27E);
  static const _tileEdge = Color(0xFFB98F4E);
  static const _tileLight = Color(0xFFF2DCA9);
  static const _water = Color(0xFF3D8FE0);
  static const _waterLight = Color(0xFF7FB9F0);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paintFill = Paint();

    // ── 芝生の下地 + ピクセル調のむら ──
    paintFill.color = _grass;
    canvas.drawRect(Offset.zero & size, paintFill);
    for (var i = 0; i < (size.width * size.height) / 900; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      paintFill.color = rng.nextBool() ? _grassDark : _grassLight;
      canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 6, 6), paintFill);
    }

    // ── 川(右端を蛇行する帯) ──
    final river = Path()..moveTo(size.width, 0);
    for (double y = 0; y <= size.height; y += 24) {
      final wobble = math.sin(y / 90) * 14;
      river.lineTo(size.width - 34 + wobble, y);
    }
    river
      ..lineTo(size.width, size.height)
      ..close();
    paintFill.color = _water;
    canvas.drawPath(river, paintFill);
    // 川面のハイライト(短い横線)
    paintFill.color = _waterLight;
    for (double y = 12; y < size.height; y += 42) {
      final wobble = math.sin(y / 90) * 14;
      canvas.drawRect(
          Rect.fromLTWH(size.width - 24 + wobble, y, 10, 3), paintFill);
    }

    // ── タイルの道(ノード間をジグザグにつなぐひし形タイル) ──
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      const steps = 3;
      for (var s = 1; s <= steps; s++) {
        final t = s / (steps + 1);
        final p = Offset.lerp(a, b, t)!;
        _diamond(canvas, p, 22, 14);
      }
    }
    // ノードの足元は大きめのタイル
    for (final c in centers) {
      _diamond(canvas, c.translate(0, 18), 40, 24);
    }

    // ── 木々(左右の縁) + 花 ──
    for (double y = 30; y < size.height - 20; y += 96) {
      final jitter = rng.nextDouble() * 20 - 10;
      _tree(canvas, Offset(24 + jitter, y));
      _tree(canvas, Offset(size.width - 64 + jitter * 0.5, y + 48));
    }
    for (var i = 0; i < size.height / 26; i++) {
      final x = 46 + rng.nextDouble() * (size.width - 130);
      final y = rng.nextDouble() * size.height;
      _flower(canvas, Offset(x, y),
          rng.nextBool() ? KdColors.pink100 : Colors.white);
    }
  }

  void _diamond(Canvas canvas, Offset c, double w, double h) {
    final path = Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx, c.dy + h)
      ..lineTo(c.dx - w, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _tile);
    canvas.drawPath(
      path,
      Paint()
        ..color = _tileEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.miter,
    );
    // 上辺のハイライト
    canvas.drawLine(Offset(c.dx - w * 0.5, c.dy - h * 0.5),
        Offset(c.dx, c.dy - h * 0.92), Paint()
          ..color = _tileLight
          ..strokeWidth = 2);
  }

  void _tree(Canvas canvas, Offset base) {
    // 幹
    canvas.drawRect(Rect.fromCenter(
        center: base.translate(0, 22), width: 8, height: 12),
        Paint()..color = _trunk);
    // 葉(2段の角丸ブロック)
    final leaf = Paint()..color = _leaf;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base.translate(0, 8), width: 34, height: 18),
            const Radius.circular(5)),
        leaf);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base.translate(0, -6), width: 26, height: 18),
            const Radius.circular(5)),
        leaf);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base.translate(-4, -8), width: 10, height: 6),
            const Radius.circular(2)),
        Paint()..color = _leafLight);
  }

  void _flower(Canvas canvas, Offset c, Color color) {
    final p = Paint()..color = color;
    canvas.drawRect(Rect.fromCenter(center: c, width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(-3, 0), width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(3, 0), width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, -3), width: 3, height: 3), p);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, 3), width: 3, height: 3), p);
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) =>
      old.centers != centers;
}

/// ステージノード(円形3Dボタン)。
///  - 挑戦可能: 桜ピンク + 「スタート」吹き出し + 白ハロー
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
        ]),
      ),
    );
  }
}

/// 「スタート」吹き出し。
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

/// みぽりん先生の応援スポット(フィールドの飾り。本番はドット絵に差し替え)。
class _MiporinSpot extends StatelessWidget {
  const _MiporinSpot();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // 応援の吹き出し
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.pink500, width: 1.5),
        ),
        child: Text('ファイト♪',
            style: KdTheme.dot(size: 11, color: KdColors.pink700)),
      ),
      const SizedBox(height: 4),
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: KdColors.pink100,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.wood900, width: 2.5),
        ),
        child: const Icon(Icons.favorite, color: KdColors.pink500, size: 28),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: KdColors.border, width: 1.5),
        ),
        child: Text('みぽりん先生',
            style: KdTheme.dot(size: 10, color: KdColors.ink900)),
      ),
    ]);
  }
}
