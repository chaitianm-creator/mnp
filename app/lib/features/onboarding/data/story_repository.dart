import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// オンボーディング/ストーリーのデータ管理。
/// 内容は assets/story/story.json に分離してあり、
/// 第2話・第3話は episodes 配列に追記するだけで追加できる。
class StoryPage {
  const StoryPage({
    required this.no,
    required this.image,
    this.imageWide,
    this.buttonLabel,
  });
  final int no;
  final String image; // 縦画面用(スマホ)のアセットパス
  final String? imageWide; // 横画面用(PC/タブレット)。無ければ縦画像を使う
  final String? buttonLabel; // 画像にボタンが無いページに重ねるボタンの文言

  /// 画面の縦横に応じた画像を返す
  String imageFor({required bool landscape}) =>
      landscape ? (imageWide ?? image) : image;

  static StoryPage fromJson(Map<String, dynamic> j) => StoryPage(
        no: (j['no'] as num).toInt(),
        image: j['image'] as String,
        imageWide: j['imageWide'] as String?,
        buttonLabel: j['buttonLabel'] as String?,
      );
}

class StoryEpisode {
  const StoryEpisode({
    required this.id,
    required this.title,
    required this.finishLabel,
    required this.finishRoute,
    required this.pages,
  });

  final String id;
  final String title;
  final String finishLabel; // 最終ページのボタン文言(例: 島へ行く)
  final String finishRoute; // 終了後の遷移先(例: /map)
  final List<StoryPage> pages;

  static StoryEpisode fromJson(Map<String, dynamic> j) => StoryEpisode(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        finishLabel: j['finishLabel'] as String? ?? 'ゲーム開始',
        finishRoute: j['finishRoute'] as String? ?? '/map',
        pages: [
          for (final p in (j['pages'] as List).cast<Map<String, dynamic>>())
            StoryPage.fromJson(p),
        ],
      );
}

Future<List<StoryEpisode>> loadStoryEpisodes() async {
  final raw = await rootBundle.loadString('assets/story/story.json');
  final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
  return [
    for (final e in (j['episodes'] as List).cast<Map<String, dynamic>>())
      StoryEpisode.fromJson(e),
  ];
}

final storyEpisodesProvider =
    FutureProvider<List<StoryEpisode>>((_) => loadStoryEpisodes());
