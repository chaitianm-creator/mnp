import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-06 目標設定(US-E1-04): 目的と1日の時間を選ぶ = 自律性の最初の体験。
/// 完了後は登録を挟まず即マルコの体験クエストへ(US-E1-02: 価値が先、登録は後)。
/// タイトル画面(SC-02)と同じ王国の風景の上に、羊皮紙パネルが乗る。
class GoalPage extends ConsumerStatefulWidget {
  const GoalPage({super.key});

  @override
  ConsumerState<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends ConsumerState<GoalPage> {
  String? _goal;
  int? _minutes;

  static const _goals = [
    ('side_job', '副業をはじめたい', Icons.work_outline),
    ('career', 'デザインの仕事に就きたい', Icons.trending_up),
    ('hobby', '趣味として楽しみたい', Icons.palette),
  ];
  static const _minutesOptions = [3, 7, 15];

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goal', _goal!);
    await prefs.setInt('daily_minutes', _minutes!);
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    // 初日の生命線: ギルド入団(練習+成功体験) → はじめてのお客様へ
    context.go('/guild');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // 王国の風景(城なし = 村の草原)
        const Positioned.fill(
          child: CustomPaint(painter: KdSceneryPainter(showCastle: false)),
        ),
        SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Center(child: KdRibbonBanner('あなたのこと、教えて', fontSize: 15)),
            const SizedBox(height: 16),
            KdParchmentCard(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const KdSectionHeader('目標はなに？'),
                const SizedBox(height: 12),
                for (final (id, label, icon) in _goals) ...[
                  _SelectCard(
                    selected: _goal == id,
                    icon: icon,
                    label: label,
                    onTap: () => setState(() => _goal = id),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                const KdSectionHeader('1日どのくらいできそう？'),
                const SizedBox(height: 4),
                Text('あとで変えられるよ。無理しないでいいの。',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(children: [
                  for (final m in _minutesOptions) ...[
                    Expanded(
                      child: _SelectCard(
                        selected: _minutes == m,
                        label: '$m分',
                        onTap: () => setState(() => _minutes = m),
                      ),
                    ),
                    if (m != _minutesOptions.last) const SizedBox(width: 8),
                  ],
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            KdPrimaryButton(
              label: 'みぽりん先生に会いに行く',
              onPressed: (_goal != null && _minutes != null) ? _start : null,
            ),
            const SizedBox(height: 12),
            // みぽりん先生のひとこと
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.pink500, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.favorite,
                      size: 14, color: KdColors.pink500),
                  const SizedBox(width: 6),
                  Text('どれを選んでも、だいじょうぶ♪',
                      style: KdTheme.dot(size: 12, color: KdColors.pink700)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard(
      {required this.selected,
      required this.label,
      required this.onTap,
      this.icon});
  final bool selected;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? KdColors.pink100 : KdColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? KdColors.pink500 : KdColors.border,
            width: selected ? 2.5 : 2,
          ),
          boxShadow: [
            BoxShadow(
                color: selected ? KdColors.pink700 : KdColors.wood900,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, color: selected ? KdColors.pink700 : KdColors.wood700),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              )),
        ]),
      ),
    );
  }
}
