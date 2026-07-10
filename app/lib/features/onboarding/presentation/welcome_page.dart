import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-02 世界観導入。60秒以内・常時スキップ可(US-E1-01)。
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
      context.go('/goal');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/goal'), // 常時スキップ可
              child: const Text('スキップ',
                  style: TextStyle(color: KdColors.ink900)),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              itemBuilder: (context, i) {
                final (icon, title, body) = _slides[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 96, color: KdColors.pink500),
                      const SizedBox(height: 24),
                      Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Text(body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              Container(
                margin: const EdgeInsets.all(4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? KdColors.pink500
                      : KdColors.border.withOpacity(0.3),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: KdPrimaryButton(
                label: _page < _slides.length - 1 ? 'つぎへ' : 'はじめる',
                onPressed: _next,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
