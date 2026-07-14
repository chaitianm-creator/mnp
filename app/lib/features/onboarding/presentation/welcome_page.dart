import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_scenery.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-02 世界観導入。60秒以内・常時スキップ可(US-E1-01)。
/// ゲームのタイトル画面様式: 空とピンクの城の王国風景の上に、
/// 羊皮紙パネルのスライドが乗る。
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      Icons.castle,
      'ようこそ、デザイン王国へ',
      'ここは、デザインの力で\nみんなの困りごとを解決する王国。',
    ),
    (
      Icons.favorite,
      'みぽりん先生がいるよ',
      '「あなたなら ぜったいできるよ！\n一歩ずつでいいの。」',
    ),
    (
      Icons.work,
      'あなたはデザイン見習い',
      '住民の仕事をクリアして経験を積み、\n「王国認定デザイナー」を目指そう！',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      // 初回フロー: みぽりん先生との出会い → 入団手続き(登録)
      context.go('/meeting');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // 王国の風景(空・城・草原・タイルの道)
        const Positioned.fill(
          child: CustomPaint(painter: KdSceneryPainter()),
        ),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: GestureDetector(
                  onTap: () => context.go('/meeting'), // 常時スキップ可
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KdColors.border, width: 1.5),
                    ),
                    child: Text('スキップ',
                        style: KdTheme.dot(size: 12, color: KdColors.ink900)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final (icon, title, body) = _slides[i];
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: KdParchmentCard(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // アイテムカード様式の額
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                color: KdColors.pink50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: KdColors.pink500, width: 2.5),
                              ),
                              child: Icon(icon,
                                  size: 60, color: KdColors.pink500),
                            ),
                            const SizedBox(height: 20),
                            KdRibbonBanner(title, fontSize: 15),
                            const SizedBox(height: 16),
                            Text(body,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _slides.length; i++)
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(Icons.local_florist,
                      size: 14,
                      color: i == _page
                          ? KdColors.pink700
                          : Colors.white.withOpacity(0.8)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: SizedBox(
                width: double.infinity,
                child: KdPrimaryButton(
                  label: _page < _slides.length - 1 ? 'つぎへ' : 'はじめる',
                  onPressed: _next,
                ),
              ),
            ),
            // 先生・スタッフ用の入り口(生徒フローの邪魔をしない控えめな導線)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.go('/teacher-login'),
                child: Text('先生・スタッフの方はこちら',
                    style: KdTheme.dot(size: 11, color: KdColors.ink900)
                        .copyWith(decoration: TextDecoration.underline)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
