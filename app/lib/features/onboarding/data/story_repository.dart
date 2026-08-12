import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// オンボーディング/ストーリーのデータ管理。
/// 内容は assets/story/story.json に分離してあり、
/// 第2話・第3話は episodes 配列に追記するだけで追加できる。
/// ページは「コード描画シーン(scene)」または「画像(image)」のどちらでも定義可能。
class StoryChoice {
  const StoryChoice({required this.text, required this.correct, this.feedback});
  final String text;
  final bool correct;
  final String? feedback; // 不正解のときに出るひとこと

  static StoryChoice fromJson(Map<String, dynamic> j) => StoryChoice(
        text: j['text'] as String,
        correct: j['correct'] as bool? ?? false,
        feedback: j['feedback'] as String?,
      );
}

class StoryMission {
  const StoryMission(
      {required this.title,
      required this.items,
      required this.xp,
      required this.coins});
  final String title;
  final List<String> items;
  final int xp;
  final int coins;

  static StoryMission fromJson(Map<String, dynamic> j) => StoryMission(
        title: j['title'] as String,
        items: (j['items'] as List? ?? const []).cast<String>(),
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
      );
}

class StoryPage {
  const StoryPage({
    required this.no,
    this.scene,
    this.image,
    this.imageWide,
    this.headerBadge,
    this.headerTitle,
    this.bubble,
    this.speaker,
    this.text,
    this.subSpeaker,
    this.subText,
    this.boardTitle,
    this.boardText,
    this.mapLabels = false,
    this.choicePrompt,
    this.choices = const [],
    this.mission,
    this.buttonLabel,
  });

  final int no;
  final String? scene; // コード描画シーン名(story_scenes.dart)
  final String? image; // 画像ページ(旧方式)の縦アセット
  final String? imageWide;
  final String? headerBadge; // 金縁ヘッダーの上段(第一話 等)
  final String? headerTitle; // 金縁ヘッダーの本文
  final String? bubble; // 主人公の吹き出し
  final String? speaker; // 会話ウィンドウの話者
  final String? text;
  final String? subSpeaker; // 2つ目の会話ウィンドウ
  final String? subText;
  final String? boardTitle; // 看板に描く文字
  final String? boardText;
  final bool mapLabels; // 島マップの場所ラベルを重ねる
  final String? choicePrompt; // 選択肢(どう答える？)
  final List<StoryChoice> choices;
  final StoryMission? mission; // ミッション発生カード
  final String? buttonLabel; // 可視ボタン(島へ行く 等)

  String? imageFor({required bool landscape}) =>
      image == null ? null : (landscape ? (imageWide ?? image) : image);

  static StoryPage fromJson(Map<String, dynamic> j) => StoryPage(
        no: (j['no'] as num).toInt(),
        scene: j['scene'] as String?,
        image: j['image'] as String?,
        imageWide: j['imageWide'] as String?,
        headerBadge: j['headerBadge'] as String?,
        headerTitle: j['headerTitle'] as String?,
        bubble: j['bubble'] as String?,
        speaker: j['speaker'] as String?,
        text: j['text'] as String?,
        subSpeaker: j['subSpeaker'] as String?,
        subText: j['subText'] as String?,
        boardTitle: j['boardTitle'] as String?,
        boardText: j['boardText'] as String?,
        mapLabels: j['mapLabels'] as bool? ?? false,
        choicePrompt: j['choicePrompt'] as String?,
        choices: [
          for (final c in (j['choices'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
            StoryChoice.fromJson(c),
        ],
        mission: j['mission'] == null
            ? null
            : StoryMission.fromJson(
                (j['mission'] as Map).cast<String, dynamic>()),
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
  final String finishLabel; // 最終ページのボタン文言(例: 開始)
  final String finishRoute; // 終了後の遷移先(例: /map)
  final List<StoryPage> pages;

  static StoryEpisode fromJson(Map<String, dynamic> j) => StoryEpisode(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        finishLabel: j['finishLabel'] as String? ?? '開始',
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
