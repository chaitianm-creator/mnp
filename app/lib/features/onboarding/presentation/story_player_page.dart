import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/features/onboarding/data/story_repository.dart';
import 'package:design_kingdom/features/onboarding/presentation/pixel_ui.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// オンボーディング/ストーリー再生(/story/:ep)。
/// 各ページは「コード描画シーン + 16bit風ピクセルUI(pixel_ui.dart)」。
/// 文言・構成は story.json でデータ管理 — 第2話以降も追加できる。
class StoryPlayerPage extends ConsumerStatefulWidget {
  const StoryPlayerPage({super.key, required this.episodeId});
  final String episodeId;

  @override
  ConsumerState<StoryPlayerPage> createState() => _StoryPlayerPageState();
}

class _StoryPlayerPageState extends ConsumerState<StoryPlayerPage> {
  int _index = 0;
  String? _choiceFeedback; // 選択肢で不正解を選んだときのひとこと

  Future<void> _finish(StoryEpisode ep) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
    if (!mounted) return;
    context.go(ep.finishRoute);
  }

  @override
  Widget build(BuildContext context) {
    final episodes = ref.watch(storyEpisodesProvider);

    return Scaffold(
      backgroundColor: PixelTheme.navyEdge,
      body: episodes.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => const Center(
            child: Text('ストーリーを読み込めなかったよ',
                style: TextStyle(color: Colors.white))),
        data: (list) {
          final ep = list.where((e) => e.id == widget.episodeId).firstOrNull;
          if (ep == null || ep.pages.isEmpty) {
            return const Center(
                child: Text('このお話は準備中だよ',
                    style: TextStyle(color: Colors.white)));
          }
          final page = ep.pages[_index.clamp(0, ep.pages.length - 1)];
          final isLast = _index >= ep.pages.length - 1;

          void advance() {
            if (isLast) {
              _finish(ep);
            } else {
              setState(() {
                _index++;
                _choiceFeedback = null;
              });
            }
          }

          // PCでは中央寄せ・最大幅(比率維持)。ページ切替は250msフェード。
          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: PixelTheme.maxContentWidth),
              child: LayoutBuilder(builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                return AnimatedSwitcher(
                  duration: PixelTheme.pageFade,
                  child: KeyedSubtree(
                    key: ValueKey('${ep.id}-$_index'),
                    child: _buildPage(ep, page, size, isLast, advance),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPage(StoryEpisode ep, StoryPage page, Size size, bool isLast,
      VoidCallback advance) {
    // 第1話1ページ目は完成済みの専用レイアウト
    if (ep.id == 'ep1' && page.no == 1) {
      return PixelStoryPageOne(
        pageNo: page.no,
        totalPages: ep.pages.length,
        headerBadge: page.headerBadge,
        headerTitle: page.headerTitle,
        bubble: page.bubble,
        onNext: advance,
      );
    }

    final hasChoices = page.choices.isNotEmpty;
    final landscape = size.width > size.height;

    return Stack(children: [
      // ── シーン(コード描画 / 旧: 画像) ──
      if (page.scene == 'phone')
        const Positioned.fill(
            child: PixelRoomBackground(mode: RoomMode.phone))
      else if (page.scene == 'bedroom_awake')
        const Positioned.fill(
            child: PixelRoomBackground(mode: RoomMode.awake))
      else if (page.scene != null)
        buildStoryScene(page.scene!)
      else if (page.image != null)
        Positioned.fill(
          child: Image.asset(
            page.imageFor(landscape: landscape)!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
      // ── 全画面タップで前進(選択肢ページ以外) ──
      if (!hasChoices)
        Positioned.fill(
          child: Semantics(
            button: true,
            label: isLast ? ep.finishLabel : '次へ',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: advance,
            ),
          ),
        ),
      // ── 看板の文字(コード描画なので変更が容易) ──
      if (page.boardTitle != null)
        Positioned(
          left: size.width * 0.17,
          right: size.width * 0.17,
          top: size.height * 0.27,
          height: size.height * 0.3,
          child: IgnorePointer(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _outlinedText(page.boardTitle!, 26,
                      const Color(0xFFF2E2B8), const Color(0xFF4E351B)),
                  if (page.boardText != null) ...[
                    const SizedBox(height: 8),
                    Text(page.boardText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFF2E2B8),
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w800)),
                  ],
                ]),
          ),
        ),
      // ── 島マップの場所ラベル ──
      if (page.mapLabels) ..._mapLabels(size),
      // ── パン屋の看板文字 ──
      if (page.scene == 'bakery' || page.scene == 'mission')
        Positioned(
          left: size.width * 0.12,
          top: size.height * 0.155,
          width: size.width * 0.32,
          child: const IgnorePointer(
            child: Text('パン屋',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF5A3A1E),
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      // ── パン屋・主人公のスプライト(会話シーン) ──
      if (page.scene == 'bakery') ...[
        Positioned(
          left: size.width * 0.1,
          bottom: size.height * 0.24,
          child: IgnorePointer(
            child: PixelSprite(
                rows: bakerRows,
                palette: bakerPalette,
                width: size.width * 0.3),
          ),
        ),
        Positioned(
          right: size.width * 0.06,
          bottom: size.height * 0.24,
          child: IgnorePointer(
            child: PixelSprite(
                rows: heroineFrontRows,
                palette: heroinePalette,
                width: size.width * 0.26),
          ),
        ),
      ],
      SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: PixelTheme.padPage),
          child: Column(children: [
            const SizedBox(height: 10),
            // ── ページ番号 + ヘッダー ──
            Row(children: [
              PixelPageIndicator(page: page.no, total: ep.pages.length),
              const Spacer(),
            ]),
            const SizedBox(height: 10),
            if (page.headerBadge != null || page.headerTitle != null)
              PixelStoryHeader(
                  badge: page.headerBadge, title: page.headerTitle),
            if (page.bubble != null) ...[
              const SizedBox(height: 16),
              PixelSpeechBubble(text: page.bubble!),
            ],
            const Spacer(),
            // ── 会話ウィンドウ ──
            if (page.text != null)
              PixelMessageWindow(speaker: page.speaker, text: page.text!),
            if (page.subText != null) ...[
              const SizedBox(height: 8),
              PixelMessageWindow(
                  speaker: page.subSpeaker, text: page.subText!),
            ],
            // ── 選択肢(どう答える？) ──
            if (hasChoices) ...[
              const SizedBox(height: 8),
              PixelChoicePanel(
                prompt: page.choicePrompt ?? 'どう答える？',
                choices: page.choices,
                feedback: _choiceFeedback,
                onSelect: (c) {
                  if (c.correct) {
                    advance();
                  } else {
                    setState(() => _choiceFeedback =
                        c.feedback ?? 'もういちど こたえよう。');
                  }
                },
              ),
            ],
            // ── ミッションカード ──
            if (page.mission != null) ...[
              const SizedBox(height: 8),
              PixelMissionCard(mission: page.mission!),
            ],
            // ── 可視ボタン ──
            if ((isLast || page.buttonLabel != null) && !hasChoices)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: 232,
                  child: PixelButton(
                    label: isLast ? ep.finishLabel : page.buttonLabel!,
                    onTap: advance,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ]);
  }

  List<Widget> _mapLabels(Size size) {
    const labels = [
      ('パン屋さん 🍞', 0.16, 0.30),
      ('八百屋さん 🥬', 0.14, 0.50),
      ('デザイン工房 ✏️', 0.60, 0.22),
      ('カフェ ☕', 0.66, 0.36),
      ('資料館 📖', 0.64, 0.52),
      ('港 ⚓', 0.30, 0.66),
      ('広場 🚩', 0.58, 0.64),
    ];
    return [
      for (final (text, fx, fy) in labels)
        Positioned(
          left: size.width * fx,
          top: size.height * fy,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PixelTheme.cream,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: PixelTheme.brown, width: 2),
              ),
              child: Text(text,
                  style: const TextStyle(
                      color: PixelTheme.brown,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
    ];
  }

  Widget _outlinedText(String text, double size, Color fill, Color outline) {
    final base = TextStyle(
        fontSize: size, fontWeight: FontWeight.w900, height: 1.25);
    return Stack(children: [
      Text(text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.18
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          )),
      Text(text,
          textAlign: TextAlign.center, style: base.copyWith(color: fill)),
    ]);
  }
}
