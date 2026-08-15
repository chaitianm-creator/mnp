import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/features/onboarding/data/story_repository.dart';
import 'package:design_kingdom/features/onboarding/presentation/pixel_ui.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes_clean.dart';

/// オンボーディング/ストーリー再生(/story/:ep)。
/// シーン背景・キャラはドット絵のまま、UI部品(ページ番号/見出し/吹き出し/
/// 会話ウィンドウ/選択肢/ミッション/ボタン)はホームと同じクリーンな様式。
/// 文言・構成は story.json でデータ管理 — 第2話以降も追加できる。
class StoryPlayerPage extends ConsumerStatefulWidget {
  const StoryPlayerPage({super.key, required this.episodeId});
  final String episodeId;

  @override
  ConsumerState<StoryPlayerPage> createState() => _StoryPlayerPageState();
}

const _pageFade = Duration(milliseconds: 250);
const _maxContentWidth = 460.0;
const _ink = KdColors.ink900;
const _sub = Color(0xFF938A78);
const _line = KdColors.border;
const _pinkChip = Color(0xFFE98FA9);

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
      backgroundColor: const Color(0xFFEFEBE0),
      body: episodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('ストーリーを読み込めなかったよ')),
        data: (list) {
          final ep = list.where((e) => e.id == widget.episodeId).firstOrNull;
          if (ep == null || ep.pages.isEmpty) {
            return const Center(child: Text('このお話は準備中だよ'));
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

          // シーンは常に全画面。UI列はSP=460px / PC(900px以上)=1080pxに
          // 制約する(ワイヤーフレームのPC/SPレイアウト準拠)。250msフェード。
          return LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return AnimatedSwitcher(
              duration: _pageFade,
              child: KeyedSubtree(
                key: ValueKey('${ep.id}-$_index'),
                child: _buildPage(ep, page, size, isLast, advance),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildPage(StoryEpisode ep, StoryPage page, Size size, bool isLast,
      VoidCallback advance) {
    final hasChoices = page.choices.isNotEmpty;
    final landscape = size.width > size.height;
    final wide = size.width >= 900; // PCワイドレイアウト
    final showButton = (isLast || page.buttonLabel != null) && !hasChoices;

    return Stack(children: [
      // ── シーン(背景はクリーンイラスト、キャラはドット) ──
      if (page.scene == 'phone' || page.scene == 'phone_notify')
        const Positioned.fill(child: CleanDeskScene())
      else if (page.scene == 'bedroom_sleep')
        const Positioned.fill(
            child: CleanRoomBackground(mode: RoomMode.sleep))
      else if (page.scene == 'bedroom_awake')
        const Positioned.fill(
            child: CleanRoomBackground(mode: RoomMode.awake))
      else if (page.scene != null)
        buildCleanScene(page.scene!)
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
      // ── 到着シーン: 吹き出しを主人公(左下)の近くに ──
      if (page.scene == 'island_overview' && page.bubble != null)
        Positioned(
          left: 8,
          bottom: size.height * 0.40,
          child: IgnorePointer(child: _SpeechBubble(text: page.bubble!)),
        ),
      // ── 考えるシーン: 吹き出しを主人公(左下)の真上に ──
      if (page.scene == 'heroine_think' && page.bubble != null)
        Positioned(
          left: 10,
          bottom: (size.width * 0.42).clamp(0.0, 230.0) * 1.25 + 12,
          child: IgnorePointer(child: _SpeechBubble(text: page.bubble!)),
        ),
      // ── 島マップの場所ラベル ──
      if (page.mapLabels) ..._mapLabels(size),
      // ── パン屋の看板文字 ──
      if (page.scene == 'bakery' || page.scene == 'mission')
        Positioned(
          left: size.width * (wide ? 0.045 : 0.12),
          top: size.height * (wide ? 0.12 : 0.155),
          width: size.width * (wide ? 0.2 : 0.32),
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
        // PC(WF17a)では店の右横に2人を並べる。SPは店の前(左右)に立たせる。
        // 足元にはどうぶつの森風のやわらかい落ち影。
        Positioned(
          left: size.width * (wide ? 0.55 : 0.1) +
              (wide ? size.height * 0.026 : size.width * 0.03),
          bottom: size.height * (wide ? 0.30 : 0.24) - 5,
          child: IgnorePointer(
            child: _SpriteShadow(
                width: (wide ? size.height * 0.26 : size.width * 0.3) * 0.8),
          ),
        ),
        Positioned(
          left: size.width * (wide ? 0.55 : 0.1),
          bottom: size.height * (wide ? 0.30 : 0.24),
          child: IgnorePointer(
            child: PixelSprite(
                rows: bakerRows,
                palette: bakerPalette,
                width: wide ? size.height * 0.26 : size.width * 0.3),
          ),
        ),
        Positioned(
          right: size.width * (wide ? 0.14 : 0.06) +
              (wide ? size.height * 0.022 : size.width * 0.026),
          bottom: size.height * (wide ? 0.28 : 0.24) - 5,
          child: IgnorePointer(
            child: _SpriteShadow(
                width: (wide ? size.height * 0.22 : size.width * 0.26) * 0.8),
          ),
        ),
        Positioned(
          right: size.width * (wide ? 0.14 : 0.06),
          bottom: size.height * (wide ? 0.28 : 0.24),
          child: IgnorePointer(
            child: PixelSprite(
                rows: heroineFrontRows,
                palette: heroinePalette,
                width: wide ? size.height * 0.22 : size.width * 0.26),
          ),
        ),
      ],
      SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: size.width.clamp(0.0, wide ? 1080.0 : _maxContentWidth),
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
            const SizedBox(height: 10),
            // ── ページ番号 ──
            Row(children: [
              _counterChip('${page.no} / ${ep.pages.length}'),
              const Spacer(),
            ]),
            const SizedBox(height: 10),
            if (page.headerBadge != null || page.headerTitle != null)
              _HeaderCard(badge: page.headerBadge, title: page.headerTitle),
            if (page.bubble != null &&
                page.scene != 'island_overview' &&
                page.scene != 'heroine_think') ...[
              const SizedBox(height: 14),
              _SpeechBubble(text: page.bubble!),
            ],
            if (page.scene == 'phone') ...[
              const Spacer(),
              Flexible(
                flex: 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _InvitePhoneCard(onDetail: advance),
                ),
              ),
            ],
            if (page.scene == 'phone_notify') ...[
              const Spacer(),
              Flexible(
                flex: 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _NotifyPhoneCard(onTap: advance),
                ),
              ),
            ],
            const Spacer(),
            // ── 会話ウィンドウ ──
            if (page.text != null)
              _MessageCard(speaker: page.speaker, text: page.text!),
            if (page.subText != null) ...[
              const SizedBox(height: 8),
              _MessageCard(speaker: page.subSpeaker, text: page.subText!),
            ],
            // ── 選択肢(どう答える？) ──
            if (hasChoices) ...[
              const SizedBox(height: 8),
              _ChoiceCard(
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
            // 画面下に固定表示するボタンのぶんの余白
            SizedBox(height: hasChoices ? 12 : 90),
          ]),
            ),
          ),
        ),
      ),
      // ── 進行ボタン(全ページ同じ位置・画面下中央に固定) ──
      if (!hasChoices)
        Positioned(
          left: 0,
          right: 0,
          bottom: 22,
          child: Center(
            child: SizedBox(
              width: showButton ? 300 : 220,
              height: showButton ? 56 : 50,
              child: _NextButton(
                label: isLast ? ep.finishLabel : (page.buttonLabel ?? '次へ'),
                onTap: advance,
              ),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _line),
              ),
              child: Text(text,
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
    ];
  }

  Widget _counterChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _line),
        ),
        child: Text(label,
            style: const TextStyle(
                color: _ink, fontSize: 12.5, fontWeight: FontWeight.w800)),
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

/// 話タイトル(白カード + ピンクのバッジチップ)。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.badge, this.title});
  final String? badge;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x1A4A443A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null)
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: _pinkChip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900)),
          ),
        if (title != null)
          Text(title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// 主人公の吹き出し(白カード + しっぽ)。
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(color: Color(0x144A443A), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _ink,
                fontSize: 19,
                height: 1.5,
                fontWeight: FontWeight.w800)),
      ),
      CustomPaint(size: const Size(18, 9), painter: _TailPainter()),
    ]);
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}

/// 会話ウィンドウ(白カード + 話者チップ)。
class _MessageCard extends StatelessWidget {
  const _MessageCard({this.speaker, required this.text});
  final String? speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x144A443A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (speaker != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
            decoration: BoxDecoration(
              color: _pinkChip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(speaker!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
        ],
        Text(text,
            style: const TextStyle(
                color: _ink,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 選択肢パネル(どう答える？)。
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCFE3F2), // WF19: どう答える？は水色チップ
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFAFCBE4)),
            ),
            child: Text(prompt,
                style: const TextStyle(
                    color: Color(0xFF44607A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 10),
        for (final c in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEED4DC), width: 1.4),
                  ),
                  child: Row(children: [
                    Text(c.correct ? '💗' : '💬',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.text,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        if (feedback != null)
          Text(feedback!,
              style: const TextStyle(
                  color: Color(0xFFD16E8E),
                  fontSize: 13,
                  height: 1.5,
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
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x1A4A443A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Transform.translate(
          offset: const Offset(0, -13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: BoxDecoration(
              color: _pinkChip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('ミッション発生！',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        Text(mission.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _ink,
                fontSize: 19,
                height: 1.35,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final (i, item) in mission.items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Icon(
                  i == 0
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: i == 0 ? KdColors.grass500 : _sub),
              const SizedBox(width: 7),
              Expanded(
                child: Text(item,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        // WF21: 報酬は「獲得ポイント」チップ1つに集約
        _reward('⭐ 獲得ポイント', '+${mission.xp}'),
      ]),
    );
  }

  Widget _reward(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF4E2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFEBD9AE)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8A744A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: _ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900)),
        ]),
      );
}

/// キャラの足元のやわらかい落ち影(どうぶつの森風)。
class _SpriteShadow extends StatelessWidget {
  const _SpriteShadow({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: (width * 0.16).clamp(8.0, 16.0),
        decoration: BoxDecoration(
          color: const Color(0x26304018),
          borderRadius: BorderRadius.circular(999),
        ),
      );
}

/// 進行ボタン(次へ/島へ行く/開始)。
class _NextButton extends StatelessWidget {
  const _NextButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF2AFC1),
        foregroundColor: const Color(0xFF8E4A62),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.play_arrow_rounded, size: 20),
        const SizedBox(width: 4),
        Text(label),
      ]),
    );
  }
}

/// 通知シーン(p2): ロック画面に「ピコン♪」の通知だけが届いたスマホ。
class _NotifyPhoneCard extends StatelessWidget {
  const _NotifyPhoneCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 290,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF9A938A), width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x334A443A), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // スピーカー
          Container(
            width: 54,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD8D2C6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          // ロック画面(やわらかいグラデーション + 時計 + 通知)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 330,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFBFD9F0), Color(0xFFE8D9EE)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
              child: Column(children: [
                const Text('7:00',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(color: Color(0x33445566), blurRadius: 6),
                        ])),
                const Text('4月1日(月)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Color(0x33445566), blurRadius: 6),
                        ])),
                const SizedBox(height: 18),
                // ピコン♪ の通知バナー
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22445566),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF4E2),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFEBD9AE)),
                      ),
                      child: const Center(
                          child: Text('✉️', style: TextStyle(fontSize: 16))),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('通知：ピコン♪',
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900)),
                            SizedBox(height: 2),
                            Text('新着メッセージが届いたよ',
                                style: TextStyle(
                                    color: _sub,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // ホームバー
          Container(
            width: 84,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD8D2C6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 招待状シーン(p2): クリーンなスマホUIカード(ワイヤーフレーム7準拠)。
class _InvitePhoneCard extends StatelessWidget {
  const _InvitePhoneCard({required this.onDetail});
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDetail, // カードのどこを押しても次へ(全画面タップと同じ)
      child: Container(
      width: 290,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF9A938A), width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x2E4A443A), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // スピーカー
        Container(
          width: 56,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFC9C2B6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 16),
        const Text('実践デザイナー島\n招待状',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _ink,
                fontSize: 17,
                height: 1.45,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        // 島のイラスト(ドット絵)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
              width: double.infinity,
              height: 110,
              child: PixelIslandThumb()),
        ),
        const SizedBox(height: 12),
        const Text('あなたを、\n実践デザイナー島へ\nご招待します。',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ink, fontSize: 13, height: 1.65)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: onDetail,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBBD8EE),
              foregroundColor: const Color(0xFF44607A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
            child: const Text('くわしく見る'),
          ),
        ),
        const SizedBox(height: 12),
        // ホームバー
        Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFC9C2B6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ]),
      ),
    );
  }
}
