import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_celebration.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-07 ギルド入団(オンボーディングの物語パート)。
/// 目標設定 → 【先生との出会い → デザインペン → 練習クエスト → 入団演出】
/// → はじめてのお客様(q_marco_01) という導線で、
/// 実案件の前に「立場・道具・小さな成功体験」を与える。
/// テンポ最優先: 1画面・タップ送り・練習は1問(失敗なし)。
class GuildPage extends ConsumerStatefulWidget {
  const GuildPage({super.key});

  @override
  ConsumerState<GuildPage> createState() => _GuildPageState();
}

enum _Step { meet, pen, practice, celebrate, handoff }

class _GuildPageState extends ConsumerState<GuildPage> {
  _Step _step = _Step.meet;
  String? _hint; // 練習でAを選んだときのやさしいヒント

  void _next() {
    setState(() {
      _step = switch (_step) {
        _Step.meet => _Step.pen,
        _Step.pen => _Step.practice,
        _ => _step,
      };
    });
  }

  void _answer(bool correct) {
    if (correct) {
      // 入団ボーナス(EXP+20)はここで一度だけ付与
      ref.read(userProgressProvider.notifier).grantGuildBonus();
      setState(() => _step = _Step.celebrate);
    } else {
      setState(() =>
          _hint = 'おしい！おしゃれだけど、遠くからだと読みにくいかも。もういちど見てみて♪');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 入団演出(SC-27と同じ祝福オーバーレイを再利用)
    if (_step == _Step.celebrate) {
      return Scaffold(
        body: KdCelebrationOverlay(
          icon: Icons.school,
          title: 'ギルド入団！',
          lines: const [
            'みならいデザイナーに なったよ！',
            'EXP +20',
            '★ デザインペンを 手に入れた！',
          ],
          onDone: () => setState(() => _step = _Step.handoff),
        ),
      );
    }

    return Scaffold(
      body: Stack(children: [
        // 城の前の風景(タイトル画面と同じ世界)
        const Positioned.fill(
          child: CustomPaint(painter: KdSceneryPainter()),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 4),
              Center(child: KdRibbonBanner('デザインギルド', fontSize: 15)),
              const Spacer(),
              ..._buildScene(context),
              const Spacer(),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildScene(BuildContext context) {
    switch (_step) {
      case _Step.meet:
        return [
          const _TeacherWindow(
              text: 'ようこそ、デザインギルドへ！\n'
                  'わたしは みぽりん先生。\n'
                  'あなたと いっしょに歩む先生だよ♪'),
          const SizedBox(height: 20),
          KdPrimaryButton(label: 'よろしくおねがいします！', onPressed: _next),
        ];

      case _Step.pen:
        return [
          const _TeacherWindow(
              text: '入団のしるしに、これをどうぞ。\n'
                  'アイデアをかたちにする、\n見習いのさいしょの道具よ。'),
          const SizedBox(height: 16),
          // アイテムカード(そうび様式)
          KdParchmentCard(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('伝説の武器…になる予定',
                  style: KdTheme.dot(size: 10, color: KdColors.heading)),
              const SizedBox(height: 6),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: KdColors.pink100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.pink500, width: 2),
                ),
                child:
                    const Icon(Icons.edit, size: 28, color: KdColors.pink700),
              ),
              const SizedBox(height: 6),
              Text('デザインペン',
                  style: KdTheme.dot(size: 14, color: KdColors.ink900)
                      .copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 20),
          KdPrimaryButton(label: 'うけとる', onPressed: _next),
        ];

      case _Step.practice:
        return [
          const _TeacherWindow(
              text: 'さっそく練習してみよ♪\n'
                  'お店のポスター、\nどっちが読みやすいと思う？'),
          const SizedBox(height: 16),
          _PracticeCard(
            label: 'ほそい字で ぎっしり',
            icon: Icons.notes,
            onTap: () => _answer(false),
          ),
          const SizedBox(height: 10),
          _PracticeCard(
            label: 'ふとい字で すっきり',
            icon: Icons.format_bold,
            onTap: () => _answer(true),
          ),
          if (_hint != null) ...[
            const SizedBox(height: 14),
            _TeacherWindow(text: _hint!, small: true),
          ],
        ];

      case _Step.handoff:
        return [
          const _TeacherWindow(
              text: 'すごい！もう見習いデザイナーの目だね。\n'
                  '…あのね、パン屋のマルコさんが\n'
                  '「店頭POPをたのみたい」って！\n'
                  'あなたの はじめてのお客様だよ♪'),
          const SizedBox(height: 20),
          KdPrimaryButton(
            label: 'はじめてのお客様に会いに行く',
            onPressed: () => context.go('/quest/q_marco_01'),
          ),
        ];

      case _Step.celebrate:
        return const []; // build() 冒頭で処理済み
    }
  }
}

/// みぽりん先生のメッセージウィンドウ(ハートのアバター付き)。
class _TeacherWindow extends StatelessWidget {
  const _TeacherWindow({required this.text, this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KdColors.pink50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: KdColors.pink500, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: small ? 34 : 48,
          height: small ? 34 : 48,
          decoration: BoxDecoration(
            color: KdColors.pink100,
            shape: BoxShape.circle,
            border: Border.all(color: KdColors.pink500, width: 2),
          ),
          child: Icon(Icons.favorite,
              size: small ? 16 : 24, color: KdColors.pink500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('みぽりん先生',
                style: KdTheme.dot(size: 12, color: KdColors.pink700)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ]),
        ),
      ]),
    );
  }
}

/// 練習の選択カード(目標設定の選択カードと同じ様式)。
class _PracticeCard extends StatelessWidget {
  const _PracticeCard(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KdColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.border, width: 2),
          boxShadow: const [
            BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: KdColors.wood700),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}
