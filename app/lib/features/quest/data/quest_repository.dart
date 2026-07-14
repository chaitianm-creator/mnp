import 'dart:math';

import 'package:design_kingdom/features/quest/domain/entities/quest.dart';

/// リポジトリ抽象(domain層)。Phase 10 で Firestore/Functions 実装に差し替える。
/// 契約は Phase 6 の Callable と 1:1 (acceptQuest / submitForReview / deliverQuest)。
abstract interface class QuestRepository {
  Future<List<Quest>> fetchTodayOffers();
  Future<List<Quest>> fetchPracticeQuests();
  Future<Quest> fetchQuest(String questId);
  Future<void> acceptQuest(String questId);
  Future<ReviewResult> submitForReview(String questId, StepAnswer submission);
  Future<DeliveryOutcome> deliverQuest(String questId);
}

/// ── DEMO モード実装 ─────────────────────────────────────────
/// Firebase なしで全画面フローを動かすための Fake。
/// コンテンツは content/quests/area_01/q_marco_01.yaml と同一(マルコ第1話)。
class FakeQuestRepository implements QuestRepository {
  final _rng = Random();

  static const _marco01 = Quest(
    questId: 'q_marco_01',
    areaId: 'area_01_hajimari',
    residentId: 'res_marco',
    residentName: 'パン屋のマルコ',
    type: QuestType.villager,
    sizeMinutes: 7,
    title: '新商品『もちもち王国パン』のPOP',
    brief: '来週発売の新商品。店頭で目を引くPOPがほしいんだ。',
    reward: QuestReward(xp: 50, coins: 10, skillPoints: {'craft': 2, 'hearing': 1}),
    nextTeaser: '行列ができたよ！実は次の相談が…',
    steps: [
      HearingStep(
        stepId: 's1',
        dialogue: [
          DialogueLine(speaker: 'マルコ', text: '来てくれたんだね！実は相談があって…'),
          DialogueLine(
              speaker: 'マルコ',
              text: '来週「もちもち王国パン」っていう新商品を出すんだ。店頭に置くPOPを作ってほしくて。'),
        ],
        question: 'まずマルコさんに何を聞く？',
        choices: [
          HearingChoice(
              id: 'a',
              text: '誰に買ってほしいパンですか？',
              score: 2,
              feedback: 'いいね！ターゲットの確認は最初の一歩だよ'),
          HearingChoice(
              id: 'b',
              text: '何色のPOPにしますか？',
              score: 0,
              feedback: '色はまだ早いかも。まず目的から聞いてみよ？'),
          HearingChoice(
              id: 'c',
              text: 'いつまでに必要ですか？',
              score: 1,
              feedback: '納期の確認も大事！目的とセットで聞けたら完璧'),
        ],
      ),
      ChoiceStep(
        stepId: 's2',
        question: '「もちもち感」が一番伝わるキャッチコピーはどれ？',
        options: [
          ChoiceOption(
              id: 'a',
              text: '新発売！王国パン 300G',
              correct: false,
              feedback: '情報は正しいけど、もちもち感が伝わらないかも'),
          ChoiceOption(
              id: 'b',
              text: 'のび〜る幸せ、もっちもち。',
              correct: true,
              feedback: '食感が目に浮かぶね！擬音は強い味方だよ'),
          ChoiceOption(
              id: 'c',
              text: '当店自慢の新商品です',
              correct: false,
              feedback: '「自慢」はお店側の言葉。お客さんの気持ちで書いてみよ？'),
        ],
      ),
      ReorderStep(
        stepId: 's3',
        question: 'POPの情報を「目立たせたい順」に並べてみよう',
        items: ['価格', 'キャッチコピー', '発売日', '商品名'],
        answerOrder: ['キャッチコピー', '商品名', '価格', '発売日'],
      ),
      SubmitStep(
        stepId: 's4',
        brief: 'ヒアリング内容をもとにPOPを作って提出しよう（Canvaなどの外部ツールでOK！）',
      ),
    ],
  );

  static const _mini = Quest(
    questId: 'q_mini_001',
    areaId: 'area_01_hajimari',
    residentId: 'res_rina',
    residentName: '美容室のリナ',
    type: QuestType.villager,
    sizeMinutes: 3,
    title: 'お店の看板、どっちがいい？',
    brief: '2案あるんだけど、どっちがいいか意見がほしいな。',
    reward: QuestReward(xp: 20, coins: 5),
    steps: [
      ChoiceStep(
        stepId: 's1',
        question: '遠くからでも読みやすい看板はどっち？',
        options: [
          ChoiceOption(
              id: 'a',
              text: '細い筆記体・淡いグレー文字',
              correct: false,
              feedback: 'おしゃれだけど、遠くからだと読みにくいかも'),
          ChoiceOption(
              id: 'b',
              text: '太めの丸ゴシック・濃い色文字',
              correct: true,
              feedback: '正解！看板は「3秒で読める」が合言葉だよ'),
        ],
      ),
    ],
  );

  /// 練習クエスト(みぽりん先生の基礎レッスン)。
  /// 3つクリアで「今日の依頼」(お客様からの実依頼)が解放される。
  static const practiceQuests = [
    Quest(
      questId: 'q_practice_01',
      areaId: 'area_01_hajimari',
      residentId: 'res_miporin',
      residentName: 'みぽりん先生',
      type: QuestType.guild,
      sizeMinutes: 3,
      title: 'はじめの一歩　文字を見やすく並べてみよう',
      brief: 'デザインのきほんは「じゅんばん」。お知らせの文字を、読みやすい順に並べてみよう。',
      reward: QuestReward(xp: 15, coins: 3, skillPoints: {'craft': 1}),
      steps: [
        ChoiceStep(
          stepId: 's1',
          question: 'けいじばんのお知らせ、パッと見て伝わるのはどっち？',
          options: [
            ChoiceOption(
                id: 'a',
                text: '全部おなじ大きさの文字',
                correct: false,
                feedback: 'ぜんぶ同じだと、どこが大事かわからないかも'),
            ChoiceOption(
                id: 'b',
                text: 'いちばん大事なことだけ大きい文字',
                correct: true,
                feedback: '正解！「大事なことを大きく」が見やすさの第一歩だよ'),
          ],
        ),
        ReorderStep(
          stepId: 's2',
          question: 'お祭りのお知らせ、目立たせたい順に並べてみよう',
          items: ['日づけ', 'お祭りの名前', '場所', '問い合わせ先'],
          answerOrder: ['お祭りの名前', '日づけ', '場所', '問い合わせ先'],
        ),
      ],
    ),
    Quest(
      questId: 'q_practice_02',
      areaId: 'area_01_hajimari',
      residentId: 'res_miporin',
      residentName: 'みぽりん先生',
      type: QuestType.guild,
      sizeMinutes: 3,
      title: 'いろのちから　目立つ色をえらぼう',
      brief: '色にはそれぞれ役割があるの。「見てほしいところ」に合う色をえらぶ練習だよ。',
      reward: QuestReward(xp: 15, coins: 3, skillPoints: {'craft': 1}),
      steps: [
        ChoiceStep(
          stepId: 's1',
          question: '「セール中！」を一番目立たせたいとき、どの組み合わせ？',
          options: [
            ChoiceOption(
                id: 'a',
                text: 'うすい黄色の紙に 白い文字',
                correct: false,
                feedback: '似た明るさどうしだと、文字が消えちゃうの'),
            ChoiceOption(
                id: 'b',
                text: '赤い紙に 白い文字',
                correct: true,
                feedback: '正解！濃い色×白のコントラストは遠くからでも読めるよ'),
            ChoiceOption(
                id: 'c',
                text: '青い紙に むらさきの文字',
                correct: false,
                feedback: '近い色どうしは、なじみすぎて読みにくいんだ'),
          ],
        ),
        ChoiceStep(
          stepId: 's2',
          question: 'たくさんの色をつかうと、どうなると思う？',
          options: [
            ChoiceOption(
                id: 'a',
                text: 'にぎやかで ぜんぶ目立つ',
                correct: false,
                feedback: 'ぜんぶ目立つ＝どれも目立たない、なんだ。ふしぎだね'),
            ChoiceOption(
                id: 'b',
                text: 'どこを見ればいいか わからなくなる',
                correct: true,
                feedback: '正解！色は「3色まで」がきほん。しぼるほど強くなるよ'),
          ],
        ),
      ],
    ),
    Quest(
      questId: 'q_practice_03',
      areaId: 'area_01_hajimari',
      residentId: 'res_miporin',
      residentName: 'みぽりん先生',
      type: QuestType.guild,
      sizeMinutes: 3,
      title: 'そろえるまほう　まっすぐ整列させよう',
      brief: '「そろえる」だけでデザインは見ちがえるの。整列のまほうを覚えよう。',
      reward: QuestReward(xp: 15, coins: 3, skillPoints: {'craft': 1}),
      steps: [
        ChoiceStep(
          stepId: 's1',
          question: 'メニュー表、きれいに見えるのはどっち？',
          options: [
            ChoiceOption(
                id: 'a',
                text: '文字のはじまりが バラバラ',
                correct: false,
                feedback: 'バラバラだと、目があちこち迷子になっちゃう'),
            ChoiceOption(
                id: 'b',
                text: '文字のはじまりが 左でピシッとそろっている',
                correct: true,
                feedback: '正解！「左ぞろえ」は読みやすさのまほうだよ'),
          ],
        ),
        ReorderStep(
          stepId: 's2',
          question: 'ポスターづくりの手順を、正しい順に並べてみよう',
          items: ['かざりをつける', 'つたえることを決める', 'ならべてそろえる'],
          answerOrder: ['つたえることを決める', 'ならべてそろえる', 'かざりをつける'],
        ),
      ],
    ),
  ];

  List<Quest> get _all => [...practiceQuests, _marco01, _mini];

  @override
  Future<List<Quest>> fetchTodayOffers() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [_marco01, _mini];
  }

  @override
  Future<List<Quest>> fetchPracticeQuests() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return practiceQuests;
  }

  @override
  Future<Quest> fetchQuest(String questId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _all.firstWhere((q) => q.questId == questId);
  }

  @override
  Future<void> acceptQuest(String questId) async {}

  @override
  Future<ReviewResult> submitForReview(String questId, StepAnswer submission) async {
    // 本番は Phase 6 §4 パイプライン(Claude API)。DEMO は添削待ち演出のため 2 秒待つ。
    await Future<void>.delayed(const Duration(seconds: 2));
    if (questId.startsWith('q_practice')) {
      // 練習クエストは先生の基礎レッスン向けコメント
      return const ReviewResult(
        goodPoints: [
          '「大事なことから」の順番で考えられているね！',
          '迷わず選べたのがすばらしい。目がもう育ってきているよ',
        ],
        improvements: [
          'つぎは「なぜそれが見やすいのか」を一言で言えるようになろう',
        ],
        nextAdvice: 'この調子！基礎のクエストを3つクリアすると、お客様からの依頼に挑戦できるよ♪',
        scores: {
          'satisfaction': 4, 'quality': 4, 'proposal': 3,
          'deadline': 5, 'hearing': 3, 'revision': 3,
        },
      );
    }
    return const ReviewResult(
      goodPoints: [
        'キャッチコピーを一番大きく置けているね！情報の優先順位がバッチリ',
        'ターゲットを最初に確認できたのが仕事として素晴らしい',
      ],
      improvements: [
        '価格の文字をもう一回り大きくすると、遠くからでも読めるよ',
      ],
      nextAdvice: '次は「お客さんが3秒で内容をつかめるか」を意識してみよ？あなたなら ぜったいできるよ！',
      scores: {
        'satisfaction': 4, 'quality': 3, 'proposal': 4,
        'deadline': 5, 'hearing': 4, 'revision': 3,
      },
    );
  }

  @override
  Future<DeliveryOutcome> deliverQuest(String questId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final quest = await fetchQuest(questId);
    return DeliveryOutcome(
      reward: quest.reward,
      levelUpTo: questId == 'q_marco_01' ? 2 : null,
      droppedKey: _rng.nextDouble() < 0.3, // Remote Config: drop_key_chance
      streak: 1,
      nextTeaser: quest.nextTeaser,
    );
  }
}
