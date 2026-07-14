import 'package:flutter/material.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// お知らせ(/notices)。王国からの手紙のメタファー。
/// DEMO: 固定のお知らせ。本番は letters コレクション購読に差し替え。
class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  static const _notices = [
    (
      Icons.celebration,
      'デザイン王国へようこそ！',
      'ギルドの一員になってくれてありがとう。まずは練習クエストで、デザインのきほんを身につけよう♪',
      'きょう',
    ),
    (
      Icons.mail,
      '「今日の依頼」について',
      '練習クエストを3つクリアすると、お客様からの本物の依頼が届くようになるよ。',
      'きょう',
    ),
    (
      Icons.construction,
      '工房がオープンしたよ',
      'これまでに納品した作品は「工房」でいつでも見返せるよ。',
      'きょう',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お知らせ')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final (icon, title, body, date) in _notices) ...[
            KdParchmentCard(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KdColors.pink100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: KdColors.pink500, width: 2),
                      ),
                      child:
                          Icon(icon, size: 20, color: KdColors.pink700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(title,
                                    style: KdTheme.dot(
                                            size: 13, color: KdColors.heading)
                                        .copyWith(
                                            fontWeight: FontWeight.w700)),
                              ),
                              Text(date,
                                  style: KdTheme.dot(
                                      size: 10, color: KdColors.wood700)),
                            ]),
                            const SizedBox(height: 4),
                            Text(body,
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ]),
                    ),
                  ]),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          const KdBandMessage('あたらしいお知らせが届いたら、ここでお知らせするね♪'),
        ]),
      ),
    );
  }
}
