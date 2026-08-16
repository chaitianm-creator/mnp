import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// お困りの村人「パン屋さん」チラシ制作ヒアリング(①お困りごと/②デザインの方向性)。
/// 吹き出し会話 + 選択肢(GOOD/BAD判定) + 参考チラシ選び + ヒアリングPOINT。
/// 最後はヒアリング内容を整理するテキスト入力フォーム。
class HearingPage extends ConsumerStatefulWidget {
  const HearingPage({super.key, this.part = 1});
  final int part; // 1 = お困りごとヒアリング / 2 = デザインの方向性

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

/// 参考チラシ(A〜E)から選ぶステップ。A・Dのみ選べば正解。
class _ImgChoice extends _Step {
  const _ImgChoice();
}

class _End extends _Step {
  const _End();
}

class _Scenario {
  const _Scenario({
    required this.introTitle,
    required this.introSub,
    required this.steps,
    required this.fields,
    required this.endSub,
    required this.clearTitle,
    required this.clearBody,
    required this.nextLabel,
    required this.nextRoute,
  });
  final String introTitle;
  final String? introSub;
  final List<_Step> steps;
  final List<String> fields;
  final String endSub;
  final String clearTitle;
  final String clearBody;
  final String nextLabel;
  final String nextRoute;
}

// ── ① お困りごとヒアリング ──
const _part1 = _Scenario(
  introTitle: 'チラシ制作のヒアリングをしてみよう！',
  introSub: null,
  fields: [
    'パン屋のお困りごとは？',
    '原因の仮説',
    'チラシの目的',
    'ターゲット',
    '伝える強み',
    'してほしい行動',
    '配布場所',
    '来店のきっかけ',
  ],
  endSub: '今回のヒアリングから分かったことを整理してみよう！',
  clearTitle: '次のクエスト',
  clearBody:
      '「誰に・何を・何のために伝えるか」が決まりました。\n\n次回は──\nどんなチラシなら、このお店の魅力が伝わる？\n\n写真・色・雰囲気・レイアウトなど、\nデザインの方向性をパン屋さんと一緒に決めてみよう！',
  nextLabel: '次に進む',
  nextRoute: '/hearing2',
  steps: [
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
  ],
);

// ── ② デザインの方向性ヒアリング ──
const _part2 = _Scenario(
  introTitle: 'チラシ制作のヒアリングをしてみよう！②',
  introSub:
      '前回のヒアリングで、パン屋さんのお困りごとが見えてきた！\n今回は、実際にどんなチラシにするのか パン屋さんと一緒に決めてみよう！\nまずは前回のヒアリング内容を確認！',
  fields: [
    'デザインの目的',
    'メイン商品',
    'サブ商品',
    'デザインの印象',
    '色の方向性',
    '写真',
    '店舗情報',
    'SNS',
    '来店特典',
  ],
  endSub: '今回決まったことを整理してみよう！',
  clearTitle: 'QUEST CLEAR！🎉',
  clearBody:
      '「誰に・何を伝えるか」から、\n「どう見せれば伝わるか」まで決まりました！\n\nさあ、ヒアリングした内容をもとに\nパン屋さんのチラシをワイヤー制作してみよう！',
  nextLabel: 'ワイヤー制作へすすむ',
  nextRoute: '/quests',
  steps: [
    _Msg('me', '前回のお話から、今回は“近所の子育て世代にお店を知ってもらい、初めて来店してもらうチラシ”にしたいと思っています。こちらの方向性で合っていますか？'),
    _Msg('baker', 'はい！お願いします！'),
    _Point('いきなりデザインの話を始めず、目的・ターゲットの認識が合っているか確認しよう！'),
    _Msg('me', '今回、初めてお店を知る方に一番見てもらいたいものは何ですか？'),
    _Msg('baker', 'やっぱり一番人気のクリームパンですね！'),
    _Msg('me', 'クリームパンをメインに見せながら、お店のことを知ってもらえる構成を考えてみますね。'),
    _Point('全部を目立たせようとすると、何を伝えたいのか分からなくなる。\n“一番見せたいもの”を決めよう！'),
    _Msg('me', 'クリームパン以外にも、チラシに載せたい商品はありますか？'),
    _Msg('baker', '食パンとメロンパンも人気なので載せたいです。あと、新商品のクロワッサンも……。'),
    _Msg('me', 'ありがとうございます。メインはクリームパンにして、その他の商品はおすすめとして見せるのが良さそうですね。'),
    _Point('載せたい商品を全部同じ大きさで見せる必要はない。\n情報に優先順位をつけることもデザインの仕事！'),
    _Msg('me', 'チラシを見た方に、お店についてどんな印象を持ってもらいたいですか？'),
    _Msg('baker', '入りやすくて、家族で気軽に行けそうなパン屋さんと思ってほしいです。'),
    _Choice('あなたなら、次にどう返す？', [
      _Opt('「では、“家族で気軽に入りやすい”と感じてもらえる、親しみやすい雰囲気が良さそうですね。」', 'good',
          'お客様の言葉から方向性を整理できている！\n「どんな印象を与えたいか」を整理してから、デザインを考えよう。'),
      _Opt('「では、かわいいデザインにしましょう！」', 'worst',
          '「家族で入りやすい＝かわいい」とは限らない。\n自分の解釈だけでデザインの方向性を決めないようにしよう！'),
      _Opt('「子育て世代向けなら、ピンクやパステルカラーが良さそうですね！」', 'worst',
          '「子育て世代＝この色」と決めつけるのはNG！\nターゲットの属性だけでなく、お店が与えたい印象や既存の雰囲気も踏まえて考えよう。'),
    ]),
    _Msg('baker', 'そうですね、そう言いたかった！ぜひお願いします。'),
    _Point('「かわいい？おしゃれ？」だけでなく、\nターゲットにどんな印象を持ってほしいかからデザインを考えよう！'),
    _Msg('me', 'イメージが近そうな参考チラシを用意してみました。'),
    _ImgChoice(),
    _Msg('baker', 'このデザインが好きです！'),
    _Msg('me', 'どのあたりが好きですか？色・写真の見せ方・文字・雰囲気など、近いものはありますか？'),
    _Msg('baker', '写真が大きくて、美味しそうに見えるところが好きです。あと、あたたかい感じもいいですね。'),
    _Point('「これが好き！」だけではなく、“どこが好きなのか”まで聞こう。'),
    _Msg('me', 'お店で普段使っている色や、ロゴ・看板などで大切にしている色はありますか？'),
    _Msg('baker', 'お店ではベージュと茶色をよく使っています。'),
    _Msg('me', 'では、お店の雰囲気も残しながら、パンがおいしそうに見える色合いで考えてみますね。'),
    _Point('単純に「好きな色」を聞くのではなく、\n店舗・ロゴなど既存のブランドとの統一感も確認しよう！'),
    _Msg('me', 'パンの写真はお持ちですか？'),
    _Msg('baker', 'スマホで撮った写真ならあります！'),
    _Choice('あなたなら、次にどう返す？', [
      _Opt('「写真があるなら、それを使って制作を進めますね！」', 'bad',
          '写真の状態を確認せずに決めるのはNG。\n暗い・画質が低い・メイン写真として使いにくい可能性もある！'),
      _Opt('「スマホの写真だと画質が悪いので、新しく撮影しましょう！」', 'worst',
          '「スマホ写真＝使えない」と決めつけるのもNG！\n十分きれいな場合もあるので、まず実際の写真を確認してから判断しよう。'),
      _Opt('「メインでクリームパンは大きく使うので、一度確認させていただけますか？必要であれば改めて撮影することも検討しましょう」', 'good',
          '写真があるからといって、必ず使えるとは限らない！\n使用するサイズや画質、チラシの目的に合っているかを確認して判断しよう。'),
    ]),
    _Msg('baker', 'iPhone5なので画質は多分良くないですね…！！ありがとうございます！'),
    _Point('写真がある＝そのまま使える、とは限らない！\nどのくらいの大きさで使うのかも考えて素材を確認しよう。'),
    _Msg('me', '初めて来る方が迷わないように、住所・営業時間・定休日・駐車場・地図も掲載しておきたいと思います。他に載せたい情報はありますか？'),
    _Msg('baker', 'InstagramのQRコードも載せたいです！'),
    _Choice('あなたなら、次にどう返す？', [
      _Opt('「わかりました！Instagramも大事なので、QRコードを大きく目立たせましょう！」', 'bad',
          'Instagramを目立たせすぎると、「来店してもらう」という一番の目的が弱くなる可能性がある。何を一番見せるべきか考えよう！'),
      _Opt('「今回は“来店”が一番の目的なので、地図や店舗情報をしっかり見せて、Instagramは補足として掲載しましょう。」', 'good',
          '掲載したい情報を尊重しながら、チラシの目的に合わせて情報の優先順位を整理できている！'),
      _Opt('「今回は来店が目的なので、Instagramは載せなくていいと思います！」', 'worst',
          '目的と違うからといって、必要な情報を削るのもNG！\nInstagramはお店の雰囲気や商品をもっと知ってもらう補足情報として活用できる。'),
    ]),
    _Msg('baker', 'そうですね！ありがとうございます！'),
    _Point('お客様が「載せたい」と言った情報を全部目立たせるのではなく、\n目的に合わせて情報の優先順位を考えよう！'),
    _Msg('me', '前回お話しした、初回来店のきっかけになる特典はどうしましょう？'),
    _Msg('baker', 'チラシを持ってきて、1,000円以上購入してくださった方にミニパンをプレゼントしたいです！'),
    _Msg('me', 'いいですね！では、来店の後押しになるようにチラシ内でも分かりやすく見せますね！'),
    _End(),
  ],
);

const _refLetters = ['A', 'B', 'C', 'D', 'E'];
const _goodRefs = {0, 3}; // A・Dが正解

class _HearingPageState extends ConsumerState<HearingPage> {
  late final _Scenario _sc = widget.part == 2 ? _part2 : _part1;

  // ログに積まれた表示済みステップ(_Msg / _Point)。
  late final List<_Step> _log = [_sc.steps.first];
  int _index = 1; // いま対話中のステップ
  int? _selected; // 選択肢: 選択中のインデックス
  final Set<int> _refSelected = {}; // 参考チラシの複数選択
  bool _refConfirmed = false; // 提案済みか
  final _scroll = ScrollController();
  final _endKey = GlobalKey(); // 「🎉 ヒアリング完了！」の位置

  String get _prefsKey => 'hearing_progress_${widget.part}';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// 途中まで進めた記録を復元する(戻っても会話を見返せる)。
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || !mounted) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final saved = <_Step>[
        for (final e in (j['log'] as List).cast<Map<String, dynamic>>())
          if (e['t'] == 'p')
            _Point(e['x'] as String)
          else
            _Msg(e['w'] as String, e['x'] as String),
      ];
      if (saved.isEmpty) return;
      setState(() {
        _log
          ..clear()
          ..addAll(saved);
        _index =
            (j['index'] as num).toInt().clamp(1, _sc.steps.length - 1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_isEnd ? 0 : _scroll.position.maxScrollExtent);
        if (_isEnd) {
          // 完了済みは「🎉 ヒアリング完了！」付近から
          _scroll.jumpTo((_scroll.position.maxScrollExtent - 600)
              .clamp(0.0, _scroll.position.maxScrollExtent));
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey,
          jsonEncode({
            'index': _index,
            'log': [
              for (final st in _log)
                if (st is _Msg)
                  {'t': 'm', 'w': st.who, 'x': st.text}
                else if (st is _Point)
                  {'t': 'p', 'x': st.text},
            ],
          }));
      if (_isEnd) await prefs.setBool('hearing_done_${widget.part}', true);
    } catch (_) {}
  }

  Future<void> _resetProgress() async {
    setState(() {
      _log
        ..clear()
        ..add(_sc.steps.first);
      _index = 1;
      _selected = null;
      _refSelected.clear();
      _refConfirmed = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      await prefs.remove('hearing_done_${widget.part}');
    } catch (_) {}
  }

  _Step get _current => _sc.steps[_index.clamp(0, _sc.steps.length - 1)];

  bool get _isEnd => _current is _End;

  bool get _refGood =>
      _refSelected.isNotEmpty && _refSelected.every(_goodRefs.contains);

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
    // 完了画面に入るときのスクロール目安(いまの最下部 + 追加される吹き出しぶん)
    final endEstimate = _scroll.hasClients
        ? _scroll.position.maxScrollExtent + 90
        : 0.0;
    setState(() {
      if (cur is _Choice) {
        // GOODを選んだ状態からの前進: 選んだセリフをログに追加
        _log.add(_Msg('me', cur.opts[_selected!].label));
        _selected = null;
        _index++;
      } else if (cur is _ImgChoice) {
        final picked =
            (_refSelected.toList()..sort()).map((i) => _refLetters[i]).join('・');
        _log.add(_Msg('me', '(参考チラシ $picked を見せてみた)'));
        _refSelected.clear();
        _refConfirmed = false;
        _index++;
      } else if (cur is! _End) {
        _log.add(cur);
        _index++;
      }
    });
    if (_isEnd) {
      // 最下部まで飛ばず、「🎉 ヒアリング完了！」の見出しから見せる
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(
            endEstimate.clamp(0.0, _scroll.position.maxScrollExtent));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _endKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                alignment: 0.02,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        });
      });
    } else {
      _toBottom();
    }
    _save();
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
    final refGoodPicked = cur is _ImgChoice && _refConfirmed && _refGood;
    // 進行ボタンを出すのは「会話 or GOOD選択後」のみ
    final showNext =
        cur is _Msg || cur is _Point || goodPicked || refGoodPicked;

    return Scaffold(
      backgroundColor: pnBg,
      appBar: AppBar(
        backgroundColor: pnBg,
        foregroundColor: pnInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'ワーク一覧へ',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/works'),
        ),
        title: const Text('お困りの村人「パン屋さん」',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        actions: [
          if (_index > 1)
            TextButton(
              onPressed: _resetProgress,
              child: const Text('さいしょから',
                  style: TextStyle(
                      color: pnSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          TextButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/works'),
            child: const Text('ワーク一覧',
                style: TextStyle(
                    color: pnSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
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
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_sc.introTitle,
                                    style: const TextStyle(
                                        color: pnInk,
                                        fontSize: 14,
                                        height: 1.5,
                                        fontWeight: FontWeight.w900)),
                                if (_sc.introSub != null) ...[
                                  const SizedBox(height: 4),
                                  Text(_sc.introSub!,
                                      style: const TextStyle(
                                          color: pnSub,
                                          fontSize: 11.5,
                                          height: 1.6)),
                                ],
                              ]),
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
                    if (cur is _ImgChoice) _refCard(),
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

  // ── 参考チラシ選び(複数選択) ──
  Widget _refCard() {
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
          child: const Text('あなたなら、どれを参考として提案する？(複数選択できるよ)',
              style: TextStyle(
                  color: Color(0xFF44607A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _refConfirmed = false;
                    _refSelected.contains(i)
                        ? _refSelected.remove(i)
                        : _refSelected.add(i);
                  });
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(children: [
                    Container(
                      width: 104,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _refSelected.contains(i)
                                ? const Color(0xFF6E93C0)
                                : pnLine,
                            width: _refSelected.contains(i) ? 2.5 : 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CustomPaint(
                            painter: _RefThumbPainter(kind: i),
                            size: const Size(104, 140)),
                      ),
                    ),
                    if (_refSelected.contains(i))
                      const Positioned(
                        right: 4,
                        top: 4,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Color(0xFF49B675),
                          child: Icon(Icons.check,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text('${_refLetters[i]}案',
                      style: const TextStyle(
                          color: pnInk,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(
            onPressed: _refSelected.isEmpty
                ? null
                : () {
                    setState(() => _refConfirmed = true);
                    _toBottom();
                  },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCFE3F2),
                foregroundColor: const Color(0xFF44607A)),
            child: const Text('この参考で提案する',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ),
        if (_refConfirmed) ...[
          const SizedBox(height: 10),
          if (_refGood)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F3DF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA8D18F)),
              ),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GOOD！◎',
                        style: TextStyle(
                            color: pnGreenInk,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('“親しみやすくて、あたたかい”というお店の希望に合った参考を選べた！',
                        style: TextStyle(
                            color: pnGreenInk,
                            fontSize: 12.5,
                            height: 1.65)),
                  ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9EEDB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0BE7A)),
              ),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('パン屋さん「なんだかイメージと違うような…」',
                        style: TextStyle(
                            color: Color(0xFF8A6D1F),
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('“親しみやすくて、あたたかい雰囲気”に合う参考はどれだろう？\n選び直してみよう！',
                        style: TextStyle(
                            color: Color(0xFF8A6D1F),
                            fontSize: 12.5,
                            height: 1.65)),
                  ]),
            ),
        ],
      ]),
    );
  }

  // ── 完了(まとめフォーム + クリア案内) ──
  List<Widget> _endSection(BuildContext context) => [
        Container(
          key: _endKey,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0C9D6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            const Text('🎉 ヒアリング完了！',
                style: TextStyle(
                    color: Color(0xFF9E5570),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_sc.endSub,
                style: const TextStyle(
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
                for (final (i, label) in _sc.fields.indexed) ...[
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
              children: [
                Text(_sc.clearTitle,
                    style: const TextStyle(
                        color: pnInk,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(_sc.clearBody,
                    style: const TextStyle(
                        color: pnInk, fontSize: 13, height: 1.7)),
              ]),
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 300,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.push(_sc.nextRoute),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA8D18F),
                  foregroundColor: pnGreenInk),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(_sc.nextLabel,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ];
}

// ─────────────────────────────────────────────────────────────
// 参考チラシのサムネイル(A〜E)。実物の参考画像の雰囲気を模したミニ版。
// A: あたたかい家族向け / B: 白ミニマル高級 / C: 黒クール
// D: ナチュラル(緑) / E: ピンクの派手グラム
// ─────────────────────────────────────────────────────────────
class _RefThumbPainter extends CustomPainter {
  const _RefThumbPainter({required this.kind});
  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void bread(double cx, double cy, double r, [Color? crust, Color? crumb]) {
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()..color = crust ?? const Color(0xFFE0A45E));
      canvas.drawCircle(Offset(cx, cy - r * 0.15), r * 0.62,
          Paint()..color = crumb ?? const Color(0xFFF2CB8E));
    }

    switch (kind) {
      case 0: // A: クリーム地 + ガーランド + パン大きめ + 商品3つ
        canvas.drawRect(Offset.zero & size,
            Paint()..color = const Color(0xFFFBF0DC));
        for (var i = 0; i < 5; i++) {
          final flag = Path()
            ..moveTo(w * (0.06 + i * 0.2), h * 0.02)
            ..lineTo(w * (0.16 + i * 0.2), h * 0.02)
            ..lineTo(w * (0.11 + i * 0.2), h * 0.1)
            ..close();
          canvas.drawPath(
              flag,
              Paint()
                ..color = i.isEven
                    ? const Color(0xFFE8A46B)
                    : const Color(0xFFD9C48A));
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.12, h * 0.15, w * 0.62, h * 0.09),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFF6E4A22));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.68, h * 0.28, w * 0.26, h * 0.2),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFFF4E1BE));
        bread(w * 0.42, h * 0.46, w * 0.24);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                      w * (0.08 + i * 0.3), h * 0.72, w * 0.24, h * 0.2),
                  const Radius.circular(3)),
              Paint()..color = const Color(0xFFEFD9B4));
        }
      case 1: // B: 白ミニマル(余白多め + 細い文字 + パン右上)
        canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
        final thin = Paint()..color = const Color(0xFF6B655C);
        canvas.drawRect(
            Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.36, h * 0.035), thin);
        canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.18, w * 0.28, h * 0.02),
            Paint()..color = const Color(0xFFB0AAA0));
        bread(w * 0.68, h * 0.28, w * 0.2);
        canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.36, w * 0.24, h * 0.018),
            Paint()..color = const Color(0xFFB0AAA0));
        canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.41, w * 0.2, h * 0.018),
            Paint()..color = const Color(0xFFB0AAA0));
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
              Rect.fromLTWH(w * (0.1 + i * 0.28), h * 0.56, w * 0.22,
                  h * 0.16),
              Paint()..color = const Color(0xFFEFECE6));
        }
        canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.82, w * 0.8, h * 0.008),
            Paint()..color = const Color(0xFFD8D3CB));
        canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.87, w * 0.5, h * 0.015),
            Paint()..color = const Color(0xFFB0AAA0));
      case 2: // C: 黒クール(白抜きの太文字 + 黄アクセント)
        canvas.drawRect(Offset.zero & size,
            Paint()..color = const Color(0xFF17140F));
        canvas.drawRect(
            Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.55, h * 0.06),
            Paint()..color = Colors.white);
        canvas.drawRect(
            Rect.fromLTWH(w * 0.08, h * 0.17, w * 0.45, h * 0.06),
            Paint()..color = Colors.white);
        canvas.drawRect(
            Rect.fromLTWH(w * 0.08, h * 0.27, w * 0.34, h * 0.04),
            Paint()..color = const Color(0xFFC0392B));
        bread(w * 0.6, h * 0.44, w * 0.24);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.62, h * 0.06, w * 0.3, h * 0.2),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFF2A2620));
        canvas.drawRect(
            Rect.fromLTWH(w * 0.66, h * 0.12, w * 0.22, h * 0.03),
            Paint()..color = const Color(0xFFF2C94C));
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
              Rect.fromLTWH(
                  w * (0.08 + i * 0.3), h * 0.74, w * 0.24, h * 0.18),
              Paint()..color = const Color(0xFF3A342C));
        }
      case 3: // D: ナチュラル緑(葉っぱ + チェック柄フッター)
        canvas.drawRect(Offset.zero & size,
            Paint()..color = const Color(0xFFF4F1E2));
        for (var i = 0; i < 4; i++) {
          final flag = Path()
            ..moveTo(w * (0.05 + i * 0.14), h * 0.02)
            ..lineTo(w * (0.14 + i * 0.14), h * 0.02)
            ..lineTo(w * (0.095 + i * 0.14), h * 0.09)
            ..close();
          canvas.drawPath(flag,
              Paint()..color = const Color(0xFFBFD48A));
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.1, h * 0.13, w * 0.55, h * 0.05),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFF6B7A3A));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.1, h * 0.21, w * 0.4, h * 0.04),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFF8CA86E));
        // 葉っぱ
        for (final (lx, ly) in [(0.85, 0.08), (0.78, 0.16), (0.9, 0.2)]) {
          canvas.drawOval(
              Rect.fromLTWH(w * lx, h * ly, w * 0.1, h * 0.035),
              Paint()..color = const Color(0xFFA9C77E));
        }
        canvas.drawOval(
            Rect.fromLTWH(w * 0.2, h * 0.5, w * 0.6, h * 0.1),
            Paint()..color = const Color(0xFFE3DECB));
        bread(w * 0.5, h * 0.44, w * 0.22);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                      w * (0.08 + i * 0.3), h * 0.66, w * 0.24, h * 0.18),
                  const Radius.circular(3)),
              Paint()..color = const Color(0xFFEDE7CF));
        }
        // 緑のチェック柄フッター
        for (var i = 0; i < 8; i++) {
          canvas.drawRect(
              Rect.fromLTWH(i * w / 8, h * 0.9, w / 16, h * 0.1),
              Paint()..color = const Color(0xFFB9CD8C));
        }
        canvas.drawRect(Rect.fromLTWH(0, h * 0.9, w, h * 0.02),
            Paint()..color = const Color(0xFF8CA86E));
      default: // E: ピンク派手(黒リボン + ハート + キラキラ)
        canvas.drawRect(Offset.zero & size,
            Paint()..color = const Color(0xFFE8388A));
        canvas.drawRect(
            Rect.fromLTWH(0, 0, w, h * 0.12),
            Paint()..color = const Color(0xFFB8145E));
        canvas.drawRect(
            Rect.fromLTWH(w * 0.06, h * 0.16, w * 0.7, h * 0.07),
            Paint()..color = const Color(0xFF1A1512));
        canvas.drawRect(
            Rect.fromLTWH(w * 0.06, h * 0.27, w * 0.5, h * 0.045),
            Paint()..color = const Color(0xFF1A1512));
        bread(w * 0.52, h * 0.48, w * 0.22);
        // ハート
        void heart(double cx, double cy, double s, Color c) {
          final p = Paint()..color = c;
          canvas.drawCircle(Offset(cx - s * 0.5, cy - s * 0.3), s * 0.55, p);
          canvas.drawCircle(Offset(cx + s * 0.5, cy - s * 0.3), s * 0.55, p);
          final tri = Path()
            ..moveTo(cx - s * 1.02, cy - s * 0.1)
            ..lineTo(cx + s * 1.02, cy - s * 0.1)
            ..lineTo(cx, cy + s * 1.1)
            ..close();
          canvas.drawPath(tri, p);
        }

        heart(w * 0.12, h * 0.44, w * 0.05, const Color(0xFFFF8FC0));
        heart(w * 0.88, h * 0.36, w * 0.04, const Color(0xFFFF8FC0));
        heart(w * 0.84, h * 0.62, w * 0.05, const Color(0xFFB8145E));
        // キラキラ
        final rng = math.Random(5);
        final spark = Paint()..color = Colors.white;
        for (var i = 0; i < 14; i++) {
          canvas.drawCircle(
              Offset(rng.nextDouble() * w, rng.nextDouble() * h),
              0.8 + rng.nextDouble() * 1.4,
              spark);
        }
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                      w * (0.08 + i * 0.3), h * 0.74, w * 0.24, h * 0.18),
                  const Radius.circular(3)),
              Paint()..color = const Color(0xFF1A1512));
        }
    }
  }

  @override
  bool shouldRepaint(covariant _RefThumbPainter old) => old.kind != kind;
}
