import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-03 みぽりん先生との出会い。
/// 初回起動フローの物語パート: キャラクターを大きく見せ、
/// タップ送りのセリフで「入団手続き(登録)」へ自然につなぐ。
/// [replay]=true のときは設定画面からの再生(最後は「もどる」)。
class MeetingPage extends StatefulWidget {
  const MeetingPage({super.key, this.replay = false});
  final bool replay;

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage>
    with SingleTickerProviderStateMixin {
  static const _lines = [
    'はじめまして！\nあなたが、新しく来てくれた見習いさんね♪',
    'わたしは みぽりん先生。\nこの国で、デザインを教えているの。',
    'ここは デザイン王国。\nデザインの力で、みんなを笑顔にする国よ。',
    'あなたも、王国の見習いデザイナーに\nなってくれる？',
  ];

  int _line = 0;
  late final AnimationController _bob;

  bool get _isLast => _line == _lines.length - 1;

  @override
  void initState() {
    super.initState();
    // ふわふわの上下ゆれ(reduce motion 時は停止)
    _bob = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.of(context).disableAnimations) _bob.repeat();
    });
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _advance() {
    if (!_isLast) setState(() => _line++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(children: [
          // 城の前の風景(タイトル画面と同じ世界)
          const Positioned.fill(
            child: CustomPaint(painter: KdSceneryPainter(showCastle: false)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 4),
                Center(child: KdRibbonBanner('みぽりん先生との出会い', fontSize: 14)),
                const Spacer(),
                // ── みぽりん先生(大きく・ふわふわ) ──
                AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                        0, math.sin(_bob.value * 2 * math.pi) * 5),
                    child: child,
                  ),
                  child: const _TeacherFigure(),
                ),
                const SizedBox(height: 20),
                // ── セリフ(タップ送り) ──
                _SpeechWindow(
                  text: _lines[_line],
                  showNextHint: !_isLast,
                ),
                const SizedBox(height: 16),
                if (_isLast)
                  widget.replay
                      ? KdPrimaryButton(
                          label: 'もどる', onPressed: () => context.pop())
                      : KdPrimaryButton(
                          label: '入団手続きへすすむ',
                          onPressed: () => context.go('/student-register'),
                        )
                else
                  Text('タップしてつづける',
                      style: KdTheme.dot(size: 11, color: KdColors.ink900)),
                const Spacer(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// みぽりん先生の立ち姿(大きな円形ポートレート。本番はドット絵に差し替え)。
class _TeacherFigure extends StatelessWidget {
  const _TeacherFigure();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 148,
        height: 148,
        decoration: BoxDecoration(
          color: KdColors.pink100,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.wood900, width: 3),
          boxShadow: const [
            BoxShadow(color: KdColors.pink700, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.favorite, size: 72, color: KdColors.pink500),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.pink500, width: 2),
        ),
        child: Text('みぽりん先生',
            style: KdTheme.dot(size: 13, color: KdColors.pink700)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// セリフウィンドウ(メッセージウィンドウ様式 + ▼送りサイン)。
class _SpeechWindow extends StatelessWidget {
  const _SpeechWindow({required this.text, required this.showNextHint});
  final String text;
  final bool showNextHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KdColors.pink50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: KdColors.pink500, width: 2),
        boxShadow: const [
          BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.7)),
        if (showNextHint)
          Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.arrow_drop_down,
                size: 22, color: KdColors.pink700.withOpacity(0.85)),
          ),
      ]),
    );
  }
}
