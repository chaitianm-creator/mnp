import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// お困りの村人「パン屋さん」ヒアリング(練習クエストの導入)。
/// インタビュー記事風の吹き出し会話が1つずつ進む。
class HearingPage extends ConsumerStatefulWidget {
  const HearingPage({super.key});

  @override
  ConsumerState<HearingPage> createState() => _HearingPageState();
}

/// (話者: baker=パン屋さん(左) / me=わたし(右), 本文)
const _messages = <(String, String)>[
  ('me', 'こんにちは、パン屋さん！\n今日はお話を聞かせてください。どんなことにお困りですか？'),
  ('baker', 'よく来てくれたね。実はお店の前はたくさん人が通るのに、なかなか入ってきてもらえないんだ…。'),
  ('me', 'なるほど…。お店を知ってもらうきっかけが必要そうですね。チラシを作りたいとのことですが、いちばん伝えたいことは何ですか？'),
  ('baker', 'うちの自慢は毎朝焼きたての「もちもち王国パン」！まずはこれを知ってもらいたいなあ。'),
  ('me', 'いいですね！そのチラシは、どんな人に届けたいですか？'),
  ('baker', 'ご近所に住んでいる家族連れのお客さまに来てほしいな。子どもにも喜んでもらえるパンなんだよ。'),
  ('me', 'ありがとうございます！「焼きたてのもちもち王国パン」を「ご近所の家族連れ」に伝えるチラシですね。さっそく練習ワークで作ってみます！'),
];

class _HearingPageState extends ConsumerState<HearingPage> {
  int _shown = 1; // 表示済みの吹き出し数
  final _scroll = ScrollController();

  bool get _done => _shown >= _messages.length;

  void _advance() {
    if (!_done) {
      setState(() => _shown++);
      // 追加された吹き出しが見えるよう下までスクロール
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
    } else {
      context.push('/quests');
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outfit = ref.watch(outfitProvider);

    return Scaffold(
      backgroundColor: pnBg,
      appBar: AppBar(
        backgroundColor: pnBg,
        foregroundColor: pnInk,
        elevation: 0,
        title: const Text('お困りの村人「パン屋さん」',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              // ── 導入 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: PnPanel(
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: pnYellow, shape: BoxShape.circle),
                      child: PixelSprite(
                          rows: bakerRows, palette: bakerPalette, width: 40),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                          'お困りの村人パン屋さんが、チラシを制作したいみたい。\nヒアリングをしてみよう！',
                          style: TextStyle(
                              color: pnInk,
                              fontSize: 13.5,
                              height: 1.6,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
              // ── 会話 ──
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  itemCount: _shown,
                  itemBuilder: (context, i) {
                    final (who, text) = _messages[i];
                    final isMe = who == 'me';
                    final avatar = Column(mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: isMe ? pnPink : pnYellow,
                                shape: BoxShape.circle),
                            child: PixelSprite(
                                rows: isMe ? heroineFrontRows : bakerRows,
                                palette: isMe
                                    ? heroinePaletteFor(outfit)
                                    : bakerPalette,
                                width: 34),
                          ),
                          const SizedBox(height: 3),
                          Text(isMe ? 'わたし' : 'パン屋さん',
                              style: const TextStyle(
                                  color: pnSub,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700)),
                        ]);
                    final bubble = Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFF9E9EE) : pnCard,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isMe ? 14 : 4),
                            topRight: Radius.circular(isMe ? 4 : 14),
                            bottomLeft: const Radius.circular(14),
                            bottomRight: const Radius.circular(14),
                          ),
                          border: Border.all(color: pnLine),
                        ),
                        child: Text(text,
                            style: const TextStyle(
                                color: pnInk, fontSize: 13, height: 1.65)),
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children:
                            isMe ? [bubble, avatar] : [avatar, bubble],
                      ),
                    );
                  },
                ),
              ),
              // ── 進行ボタン ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: 300,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _advance,
                    style: FilledButton.styleFrom(
                        backgroundColor: _done
                            ? const Color(0xFFA8D18F)
                            : const Color(0xFFF2AFC1),
                        foregroundColor: _done
                            ? pnGreenInk
                            : const Color(0xFF8E4A62)),
                    icon: Icon(
                        _done
                            ? Icons.check_rounded
                            : Icons.play_arrow_rounded,
                        size: 18),
                    label: Text(
                        _done ? 'ヒアリング完了！練習ワークへ' : '次へ',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
