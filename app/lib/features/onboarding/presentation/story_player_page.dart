import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/features/onboarding/data/story_repository.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// オンボーディング/ストーリー再生(/story/:ep)。
/// 各ページは「コード描画シーン + コード描画のUI(ヘッダー/吹き出し/会話/選択肢)」。
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
      backgroundColor: const Color(0xFF1B2440),
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
          final hasChoices = page.choices.isNotEmpty;

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

          final size = MediaQuery.sizeOf(context);
          final landscape = size.width > size.height;

          return Stack(children: [
            // ── シーン(コード描画 / 旧: 画像) ──
            if (page.scene != null)
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
              child: Column(children: [
                const SizedBox(height: 8),
                // ── ページ番号 + ヘッダー ──
                Row(children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _counterChip('${page.no} / ${ep.pages.length}'),
                  ),
                  const Spacer(),
                ]),
                if (page.headerBadge != null || page.headerTitle != null)
                  _HeaderPlaque(
                      badge: page.headerBadge, title: page.headerTitle),
                if (page.bubble != null) ...[
                  const SizedBox(height: 14),
                  _SpeechBubble(text: page.bubble!),
                ],
                const Spacer(),
                // ── 会話ウィンドウ ──
                if (page.text != null)
                  _MessageWindow(speaker: page.speaker, text: page.text!),
                if (page.subText != null) ...[
                  const SizedBox(height: 8),
                  _MessageWindow(
                      speaker: page.subSpeaker, text: page.subText!),
                ],
                // ── 選択肢(どう答える？) ──
                if (hasChoices) ...[
                  const SizedBox(height: 8),
                  _ChoicePanel(
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
                  _MissionCard(mission: page.mission!),
                ],
                // ── 可視ボタン ──
                if ((isLast || page.buttonLabel != null) && !hasChoices)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: 220,
                      height: 52,
                      child: _PixelButton(
                        label: isLast ? ep.finishLabel : page.buttonLabel!,
                        onTap: advance,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ]),
            ),
          ]);
        },
      ),
    );
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
                color: const Color(0xFFFDF6E5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF3A2C1A), width: 2),
              ),
              child: Text(text,
                  style: const TextStyle(
                      color: Color(0xFF3A2C1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
    ];
  }

  Widget _counterChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF3A2C1A), width: 1.5),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF3A2C1A),
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      );

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

/// 金縁ヘッダー(話数バッジ + タイトル)。
class _HeaderPlaque extends StatelessWidget {
  const _HeaderPlaque({this.badge, this.title});
  final String? badge;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF15254D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFC9A24B), width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black45, offset: Offset(0, 3)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null)
          Text(badge!,
              style: const TextStyle(
                  color: Color(0xFFF2D96B),
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
        if (title != null)
          Text(title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// 主人公の吹き出し(白いピクセル風)。
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 36),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E5),
        border: Border.all(color: const Color(0xFF3A2C1A), width: 2.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF3A2C1A),
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w800)),
    );
  }
}

/// RPG会話ウィンドウ(話者チップ + 本文)。
class _MessageWindow extends StatelessWidget {
  const _MessageWindow({this.speaker, required this.text});
  final String? speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xF2FDF6E5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A2C1A), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (speaker != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE85C86),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(speaker!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        if (speaker != null) const SizedBox(height: 5),
        Text(text,
            style: const TextStyle(
                color: Color(0xFF3A2C1A),
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 選択肢パネル(どう答える？)。
class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.prompt,
    required this.choices,
    required this.onSelect,
    this.feedback,
  });
  final String prompt;
  final List<StoryChoice> choices;
  final ValueChanged<StoryChoice> onSelect;
  final String? feedback;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xF2FDF6E5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A2C1A), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE85C86),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(prompt,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        for (final c in choices) ...[
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: const Color(0xFFB93B55), width: 2),
              ),
              child: Row(children: [
                Text(c.correct ? '💗' : '💬',
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.text,
                      style: const TextStyle(
                          color: Color(0xFF3A2C1A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ],
        if (feedback != null)
          Text(feedback!,
              style: const TextStyle(
                  color: Color(0xFFB93B55),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// ミッション発生カード。
class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});
  final StoryMission mission;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8A6A3F), width: 3),
      ),
      child: Column(children: [
        Transform.translate(
          offset: const Offset(0, -14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE85C86),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFB93B55), width: 2),
            ),
            child: const Text('ミッション発生！',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        Text(mission.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF3A2C1A),
                fontSize: 20,
                height: 1.35,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final (i, item) in mission.items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(
                  i == 0
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: const Color(0xFFB93B55)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item,
                    style: const TextStyle(
                        color: Color(0xFF3A2C1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _reward('⭐ 経験値', '+${mission.xp}'),
          const SizedBox(width: 10),
          _reward('🪙 コイン', '+${mission.coins}'),
        ]),
      ]),
    );
  }

  Widget _reward(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3A2C1A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF8A6A3F), width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFF2D96B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
        ]),
      );
}

/// 青のピクセルボタン(次へ/島へ行く/ゲーム開始)。
class _PixelButton extends StatelessWidget {
  const _PixelButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E5AC8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0D2F73), width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0xFF0D2F73), offset: Offset(0, 3)),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border:
                Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}
