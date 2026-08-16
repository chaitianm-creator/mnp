import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// お困りの村人「パン屋さん」チラシ制作ヒアリング。
/// 吹き出し会話 + 選択肢(GOOD/BAD判定つき) + ヒアリングPOINT。
/// 最後はヒアリング内容を整理するテキスト入力フォーム。
class HearingPage extends ConsumerStatefulWidget {
  const HearingPage({super.key});

  @override
  ConsumerState<HearingPage> createState() => _HearingPageState();
}

// ── シナリオのデータ型 ──
sealed class _Step {
  const _Step();
}

class _Msg extends _Step {
  const _Msg(this.who, this.text); // who: 'baker' | 'me'
  final String who;
  final String text;
}

class _Point extends _Step {
  const _Point(this.text);
  final String text;
}

class _Opt {
  const _Opt(this.label, this.grade, this.feedback); // grade: good/bad/worst
  final String label;
  final String grade;
  final String feedback;
}

class _Choice extends _Step {
  const _Choice(this.prompt, this.opts);
  final String prompt;
  final List<_Opt> opts;
}

class _End extends _Step {
  const _End();
}

// ── シナリオ本体 ──
const _steps = <_Step>[
  _Msg('baker', '実は今までチラシを作ったことがなくて……。\nお店のチラシを作ってみたいと思っているんです。'),
  _Choice('あなたなら、最初になんて聞く？', [
    _Opt('「チラシを作ろうと思ったきっかけから、お聞きしてもいいですか？」', 'good',
        '目的や困りごとを知る質問。\n「チラシを作ること」自体を目的にせず、まず背景を探れる！'),
    _Opt('「どんなデザインのチラシにしたいですか？」', 'bad',
        'まだ目的やターゲットが分からない段階でデザインを決めるのは早い。\n誰に何を伝えるかによって、デザインも変わる！'),
    _Opt('「A4サイズで両面にしますか？」', 'bad',
        'サイズや仕様も必要だけど、今聞くことではない。\nまずは「なぜチラシを作りたいのか？」を知ろう。'),
  ]),
  _Msg('baker', '最近、新しいお客さんがなかなか増えなくて……。\n近所でも、うちのお店を知らない方が結構いるみたいなんです。'),
  _Msg('me', 'なるほど。今一番のお悩みは、売上そのものというより\n“近くに住んでいる方に、まだお店を知ってもらえていないこと”でしょうか？'),
  _Msg('baker', 'そうですね！\n常連さんは来てくださるんですが、新しいお客さんをもっと増やしたいです。'),
  _Point('「チラシを作りたい」をそのまま目的にせず、\nなぜ作りたいのか？どんなことに困っているのか？を確認しよう。'),
  _Msg('me', '今は、どんなお客様がよく来られますか？'),
  _Msg('baker', '近所の方が多いですね。\n特に40〜60代くらいの方や、昔から来てくださっている方が多いです。'),
  _Choice('あなたなら、次にどう返す？', [
    _Opt('「では、40〜60代の方向けのチラシにしましょう！」', 'bad',
        '今のお客様だけを見てターゲットを決めるのは早い！\nこれから増やしたいお客様は別にいるかもしれない。'),
    _Opt('「では、これから増えたら嬉しいお客様はいますか？」', 'good',
        '「今来ている人」と「これから来てほしい人」は違うかもしれない。\nお店側がどんなお客様を増やしたいのか確認しよう！'),
    _Opt('「パン屋さんなら、子育て中の女性をターゲットにするのが良さそうですね！」', 'worst',
        '「パン屋＝子育て女性」と、こちらで決めつけてしまっている。\nまずはお店がどんな方に来てほしいと思っているのかを聞いてみよう。'),
  ]),
  _Msg('baker', 'できれば、小さいお子さんがいるご家族にももっと来てもらいたいですね。\n近くに住宅も増えているので。'),
  _Point('現在のお客様と、これから来てほしいお客様は同じとは限らない。\n「現在」と「理想」の両方を聞いてみよう。'),
  _Msg('me', 'お客様からよく褒められるパンや、お店の特徴はありますか？'),
  _Msg('baker', '一番人気はクリームパンですね。\n自家製のカスタードを使っていて、毎朝お店で作っています。'),
  _Choice('あなたなら、次にどう返す？', [
    _Opt('「では、クリームパンを一番大きく載せましょう！」', 'bad',
        '人気商品だからといって、すぐにメインに決めるのはまだ早い。\nなぜ人気なのか・誰に喜ばれているのかをもう少し掘り下げよう。'),
    _Opt('「自家製カスタードなら、『こだわりの高級クリームパン』として打ち出しましょう！」', 'worst',
        'お店から聞いていないイメージを勝手に付け加えてしまっている。\n作り手のこだわりと、お客様が感じている魅力が同じとは限らない！'),
    _Opt('「お客様からもクリームパンについて何か言われますか？」', 'good',
        'お店側の「こだわり」だけでなく、お客様がどこに魅力を感じているのかを聞くことで、チラシで訴求できる強みが見つかる！'),
  ]),
  _Msg('baker', '『子どもがここのクリームパンだけはよく食べる』って言ってくださる方もいます。'),
  _Msg('me', 'それは今回来てほしい“子育て世代”とも相性が良さそうですね。'),
  _Point('「お店の強みは何ですか？」だけでは答えにくいことも。\n人気商品・お客様から言われること・こだわりから強みを見つけよう。'),
  _Msg('me', '今回チラシを見た方には、最終的にどうしてもらえたら一番嬉しいですか？'),
  _Msg('baker', 'まずは一度、お店に来てもらいたいです！'),
  _Choice('あなたなら、次にどう返す？', [
    _Opt('「では、今回は実際にお店へ来てもらうことを一番の目的にしましょう」', 'good',
        'チラシを見た人に最終的にどう行動してほしいのかを整理できている！\n目的を絞ることで、チラシに載せる情報や見せ方も決めやすくなる。'),
    _Opt('「InstagramのQRコードも大きく載せて、フォロワーも増やしましょう！」', 'bad',
        'あれもこれも目的にすると、結局何をしてほしいチラシなのか分かりにくくなる。まずは一番重要な行動を決めよう。'),
    _Opt('「では、とにかく目立つチラシにして、たくさんの人に見てもらいましょう！」', 'worst',
        '「見てもらうこと」がゴールになってしまっている。\nチラシは目立たせることが目的ではなく、その先の「来店」につなげることが大切。'),
  ]),
  _Msg('baker', 'はい、それがいいです！'),
  _Point('「認知」「SNS」「来店」「購入」など、目的を増やしすぎない。\nチラシを見た後にしてほしい行動を1つ決めよう。'),
  _Choice('あなたなら、どう提案する？', [
    _Opt('「特典がないと来てもらえないと思うので、何か付けた方がいいですね！」', 'worst',
        '「特典がないと来ない」と決めつけるのはNG。\n商品の魅力やお店のこだわり自体が来店理由になることも。特典はあくまで選択肢のひとつとして提案しよう。'),
    _Opt('「ちなみに、初めての方が「行ってみよう」と思えるような特典を付けることはできますか？」', 'good',
        '「行ってみよう」と思えるきっかけが作れないか確認！\nただお店を紹介するだけでなく、来店を後押しする方法を考えよう。'),
    _Opt('「では、初回来店の方は10％OFFにしましょう！」', 'bad',
        '特典を付けるとしても、内容をデザイナー側で勝手に決めるのはNG。\n値引きできるのか、どんな特典なら無理なく提供できるのかをお店に確認しよう。'),
  ]),
  _Msg('baker', 'チラシを持ってきてくれた方に、何かプレゼントするのはできそうです。\n例えば、○円以上購入でミニパンプレゼントなどもできそうですね。'),
  _Msg('me', 'とても素敵ですね！'),
  _Point('チラシを見てもらうだけではなく、\n“今行ってみよう”と思える理由を作れないか確認しよう。'),
  _Msg('me', 'チラシはどのあたりに配ろうと考えていますか？'),
  _Msg('baker', 'お店の近くの住宅にポスティングしたいです。\n特に新しくできた住宅街にも配りたいですね。'),
  _Choice('あなたなら、次にどう返す？', [
    _Opt('「では、“近所に住んでいるけれど、まだこのパン屋さんを知らない子育て世代”を中心に考えて制作しますね。」', 'good',
        'これまでのヒアリング内容と配布エリアをもとに、「誰に届けるチラシなのか」を具体的に整理できている！'),
    _Opt('「では、できるだけ広い地域にたくさん配りましょう！」', 'bad',
        '配る範囲を広げれば良いとは限らない。\n今回来てほしい人に合わせて、届ける地域を絞ることも大切！'),
    _Opt('「新しい住宅街なら、若い人向けのチラシにしましょう！」', 'worst',
        '「新しい住宅街＝若い人」と決めつけるのはNG。\nこれまでのヒアリングで分かった「子育て世代に来てほしい」という希望まで踏まえて、ターゲットを整理しよう。'),
  ]),
  _Msg('baker', 'ありがとう、よろしくお願いします！'),
  _End(),
];

/// まとめフォームの項目。
const _summaryFields = [
  'パン屋のお困りごとは？',
  '原因の仮説',
  'チラシの目的',
  'ターゲット',
  '伝える強み',
  'してほしい行動',
  '配布場所',
  '来店のきっかけ',
];

class _HearingPageState extends ConsumerState<HearingPage> {
  // ログに積まれた表示済みステップ(_Msg / _Point)。
  final List<_Step> _log = [_steps.first];
  int _index = 1; // いま対話中のステップ
  int? _selected; // 選択肢: 選択中のインデックス
  final _scroll = ScrollController();

  _Step get _current =>
      _steps[_index.clamp(0, _steps.length - 1)];

  bool get _isEnd => _current is _End;

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _advance() {
    final cur = _current;
    setState(() {
      if (cur is _Choice) {
        // GOODを選んだ状態からの前進: 選んだセリフをログに追加
        _log.add(_Msg('me', cur.opts[_selected!].label));
        _selected = null;
        _index++;
      } else if (cur is! _End) {
        _log.add(cur);
        _index++;
      }
    });
    _toBottom();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    final choice = cur is _Choice ? cur : null;
    final goodPicked = choice != null &&
        _selected != null &&
        choice.opts[_selected!].grade == 'good';
    // 進行ボタンを出すのは「会話 or GOOD選択後」のみ
    final showNext = cur is _Msg || cur is _Point || goodPicked;

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
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  children: [
                    // ── 導入 ──
                    PnPanel(
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: pnYellow, shape: BoxShape.circle),
                          child: PixelSprite(
                              rows: bakerRows,
                              palette: bakerPalette,
                              width: 40),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('チラシ制作のヒアリングをしてみよう！',
                              style: TextStyle(
                                  color: pnInk,
                                  fontSize: 14,
                                  height: 1.6,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // ── 会話ログ ──
                    for (final step in _log)
                      if (step is _Msg)
                        _bubble(step)
                      else if (step is _Point)
                        _pointCard(step.text),
                    // ── 選択肢 ──
                    if (choice != null) _choiceCard(choice),
                    // ── まとめフォーム ──
                    if (_isEnd) ..._endSection(context),
                  ],
                ),
              ),
              if (showNext && !_isEnd)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: 300,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _advance,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF2AFC1),
                          foregroundColor: const Color(0xFF8E4A62)),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('次へ',
                          style: TextStyle(
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

  // ── 吹き出し ──
  Widget _bubble(_Msg m) {
    final isMe = m.who == 'me';
    final outfit = ref.watch(outfitProvider);
    final avatar = Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: isMe ? pnPink : pnYellow, shape: BoxShape.circle),
        child: PixelSprite(
            rows: isMe ? heroineFrontRows : bakerRows,
            palette: isMe ? heroinePaletteFor(outfit) : bakerPalette,
            width: 34),
      ),
      const SizedBox(height: 3),
      Text(isMe ? 'デザイナー' : 'パン屋さん',
          style: const TextStyle(
              color: pnSub, fontSize: 9.5, fontWeight: FontWeight.w700)),
    ]);
    final bubble = Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
        child: Text(m.text,
            style:
                const TextStyle(color: pnInk, fontSize: 13, height: 1.65)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: isMe ? [bubble, avatar] : [avatar, bubble],
      ),
    );
  }

  // ── ヒアリングPOINT ──
  Widget _pointCard(String text) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF3D8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8D48A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡 ヒアリングPOINT',
              style: TextStyle(
                  color: Color(0xFF8A6D1F),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF6B5A28), fontSize: 12.5, height: 1.7)),
        ]),
      );

  // ── 選択肢カード ──
  Widget _choiceCard(_Choice c) {
    const letters = ['A', 'B', 'C', 'D'];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pnCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFAFCBE4), width: 1.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFCFE3F2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('デザイナーのあなたなら？　${c.prompt}',
              style: const TextStyle(
                  color: Color(0xFF44607A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        for (final (i, opt) in c.opts.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          Material(
            color: _selected == i ? const Color(0xFFEFF5FA) : pnBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() => _selected = i);
                _toBottom();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _selected == i
                          ? const Color(0xFF6E93C0)
                          : pnLine,
                      width: _selected == i ? 1.8 : 1),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFCFE3F2),
                        child: Text(letters[i],
                            style: const TextStyle(
                                color: Color(0xFF44607A),
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(opt.label,
                            style: const TextStyle(
                                color: pnInk,
                                fontSize: 12.5,
                                height: 1.55,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
              ),
            ),
          ),
        ],
        if (_selected != null) ...[
          const SizedBox(height: 10),
          _feedbackCard(c.opts[_selected!]),
        ],
      ]),
    );
  }

  Widget _feedbackCard(_Opt opt) {
    final (label, bg, border, ink) = switch (opt.grade) {
      'good' => (
          'GOOD！◎',
          const Color(0xFFE9F3DF),
          const Color(0xFFA8D18F),
          pnGreenInk
        ),
      'bad' => (
          'BAD △',
          const Color(0xFFF9EEDB),
          const Color(0xFFE0BE7A),
          const Color(0xFF8A6D1F)
        ),
      _ => (
          'BAD ×',
          const Color(0xFFF9E3DE),
          const Color(0xFFDFA091),
          const Color(0xFFA14A38)
        ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: ink, fontSize: 13.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(opt.feedback,
            style: TextStyle(color: ink, fontSize: 12.5, height: 1.65)),
        if (opt.grade != 'good') ...[
          const SizedBox(height: 5),
          const Text('もう一度、ほかの聞き方を選んでみよう！',
              style: TextStyle(
                  color: pnSub, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // ── 完了(まとめフォーム + 次のクエスト) ──
  List<Widget> _endSection(BuildContext context) => [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0C9D6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(children: [
            Text('🎉 ヒアリング完了！',
                style: TextStyle(
                    color: Color(0xFF9E5570),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text('今回のヒアリングから分かったことを整理してみよう！',
                style: TextStyle(
                    color: Color(0xFF9E5570),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        PnPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, label) in _summaryFields.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Text(label,
                      style: const TextStyle(
                          color: pnInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  TextField(
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 13, color: pnInk),
                    decoration: InputDecoration(
                      hintText: 'テキスト入力',
                      hintStyle:
                          const TextStyle(color: pnSub, fontSize: 12.5),
                      filled: true,
                      fillColor: pnBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: pnLine),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: pnLine),
                      ),
                    ),
                  ),
                ],
              ]),
        ),
        const SizedBox(height: 16),
        PnPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('次のクエスト',
                    style: TextStyle(
                        color: pnInk,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('「誰に・何を・何のために伝えるか」が決まりました。',
                    style: TextStyle(
                        color: pnInk, fontSize: 12.5, height: 1.7)),
                SizedBox(height: 6),
                Text('次回は──\nどんなチラシなら、このお店の魅力が伝わる？',
                    style: TextStyle(
                        color: pnInk,
                        fontSize: 13.5,
                        height: 1.7,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('写真・色・雰囲気・レイアウトなど、\nデザインの方向性をパン屋さんと一緒に決めてみよう！',
                    style: TextStyle(
                        color: pnSub, fontSize: 12.5, height: 1.7)),
              ]),
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 300,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.push('/quests'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA8D18F),
                  foregroundColor: pnGreenInk),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('次に進む',
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ];
}
