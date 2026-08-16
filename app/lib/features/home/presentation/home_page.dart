import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// SC-10 ホーム = エリア詳細「はじまりの街」(PRO NAVI ワイヤーフレーム準拠)。
/// 共通シェル(PnShell)にメインカラムを差し込む。キャラはドット絵のまま。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _unlockCelebrated = true; // prefs 読込前は演出を出さない

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() =>
          _unlockCelebrated = prefs.getBool('daily_unlock_celebrated') ?? false);
      _maybeCelebrateUnlock();
    });
  }

  /// 練習3つクリアの瞬間の解放演出(一度だけ)。
  Future<void> _maybeCelebrateUnlock() async {
    final progress = ref.read(userProgressProvider);
    if (_unlockCelebrated ||
        progress.practiceClearedCount < 3 ||
        progress.deliveredQuestIds.any((id) => !id.startsWith('q_practice'))) {
      return;
    }
    setState(() => _unlockCelebrated = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_unlock_celebrated', true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _UnlockDialog(onGo: () {
        Navigator.of(ctx).pop();
        context.push('/daily-request');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProgressProvider, (_, __) => _maybeCelebrateUnlock());
    return PnShell(
      current: 'ホーム',
      mainBuilder: (context, wide) => wide
          ? [
              Align(alignment: Alignment.centerLeft, child: _backToMap()),
              const SizedBox(height: 10),
              _heroCard(withSpeech: true),
              const SizedBox(height: 18),
              _questHeader(),
              const SizedBox(height: 10),
              ..._questCards(),
              const SizedBox(height: 10),
              _nextAreaCard(),
            ]
          : [
              _backToMap(),
              const SizedBox(height: 10),
              _heroCard(),
              const SizedBox(height: 10),
              PnPanel(
                child: const Text(
                  '今は「はじまりの街」にいるよ！ここから、あなただけの新しい物語をはじめよう！',
                  style: TextStyle(color: pnInk, fontSize: 13, height: 1.7),
                ),
              ),
              const SizedBox(height: 10),
              PnPanel(
                child: const Text(
                  'ようこそ、デザイナー冒険者さん！ここはすべての旅が始まる地。まずはこの世界の歩き方を知って、最初の一歩を踏み出そう。',
                  style: TextStyle(color: pnInk, fontSize: 13.5, height: 1.7),
                ),
              ),
              const SizedBox(height: 10),
              _progressCard(),
              const SizedBox(height: 18),
              _questHeader(),
              const SizedBox(height: 10),
              ..._questCards(),
              const SizedBox(height: 10),
              _nextAreaCard(),
            ],
    );
  }

  Widget _backToMap() => TextButton.icon(
        onPressed: () => context.go('/map'),
        icon: const Icon(Icons.arrow_back_rounded, size: 16, color: pnSub),
        label: const Text('冒険マップに戻る',
            style: TextStyle(color: pnSub, fontSize: 13)),
      );

  /// ヒーロー: 斜めストライプの帯 + エリア名 + みぽりん先生(仮キャラ)。
  Widget _heroCard({bool withSpeech = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pnLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const PnStripePainter(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: pnCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pnLine),
                      ),
                      child: const Text('冒険のはじまり',
                          style: TextStyle(
                              color: pnSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    const Text('🏠 はじまりの街',
                        style: TextStyle(
                            color: pnInk,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    if (withSpeech) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'ようこそ、デザイナー冒険者さん！ここはすべての旅が始まる地。\nまずはこの世界の歩き方を知って、最初の一歩を踏み出そう。',
                        style: TextStyle(
                            color: pnInk, fontSize: 13.5, height: 1.7),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(width: 340, child: _progressCard()),
                    ],
                  ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              if (withSpeech)
                Container(
                  width: 190,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pnCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pnLine),
                  ),
                  child: const Text(
                    '今は「はじまりの街」にいるよ！ここから、あなただけの新しい物語をはじめよう！',
                    style:
                        TextStyle(color: pnInk, fontSize: 12, height: 1.6),
                  ),
                ),
              PixelSprite(
                  rows: miporinRows(0),
                  palette: miporinPalette,
                  width: withSpeech ? 92 : 76),
              const SizedBox(height: 4),
              const Text('みぽりん先生',
                  style: TextStyle(
                      color: pnSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }

  int _clearedCount() {
    final p = ref.watch(userProgressProvider);
    var n = 1; // QUEST 01(ようこそ動画)はオンボーディング済みで完了扱い
    if (p.practiceClearedCount >= 3) n++;
    if (p.deliveredQuestIds.any((id) => !id.startsWith('q_practice'))) n++;
    return n;
  }

  Widget _progressCard() {
    final n = _clearedCount();
    final pct = (n / 3 * 100).round();
    return PnPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('エリア進捗率',
              style: TextStyle(
                  color: pnSub, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$pct%',
              style: const TextStyle(
                  color: pnInk, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: n / 3,
              minHeight: 8,
              backgroundColor: pnBg,
              color: pnGreen),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.check_rounded, size: 14, color: pnGreenInk),
          const SizedBox(width: 4),
          Text('$n/3 クエスト完了',
              style: const TextStyle(color: pnSub, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _questHeader() => const Row(children: [
        Text('🍃', style: TextStyle(fontSize: 16)),
        SizedBox(width: 6),
        Text('はじまりの村のクエスト一覧',
            style: TextStyle(
                color: pnInk, fontSize: 16, fontWeight: FontWeight.w900)),
      ]);

  List<Widget> _questCards() {
    final p = ref.watch(userProgressProvider);
    final practiceDone = p.practiceClearedCount >= 3;
    final dailyUnlocked = p.dailyRequestUnlocked;
    return [
      _QuestCard(
        no: '01',
        color: pnBlue,
        title: 'ようこそ',
        badges: [
          const ('動画視聴', pnBlue),
          if (p.welcomeVideoWatched) const ('視聴済み', pnGreen),
        ],
        desc: '実践デザイナー冒険へようこそ。これから始まる冒険の全体像を見てみよう。',
        meta: '所要時間 5分　・　獲得ポイント +50ポイント',
        buttonLabel: p.welcomeVideoWatched ? '✓ 視聴済み' : '▶ 動画を見る',
        // TODO(動画): ここに動画プレイヤーを埋め込む。それまでは遷移しない
        onTap: () {
          if (p.welcomeVideoWatched) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('この動画はもう視聴済みだよ！'),
                duration: Duration(seconds: 2)));
          } else {
            ref.read(userProgressProvider.notifier).watchWelcomeVideo();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('視聴完了！ +50ポイント ゲット！(動画は準備中・DEMO)'),
                duration: Duration(seconds: 2)));
          }
        },
      ),
      const SizedBox(height: 10),
      _QuestCard(
        no: '02',
        color: pnYellow,
        title: '練習クエスト',
        badges: [
          ('ワーク', pnYellow),
          if (practiceDone) ('完了', pnGreen),
        ],
        desc: 'はじめの一歩。3つの練習ワークでデザインの基礎体力をつけよう。',
        meta: '所要時間 20分　・　進捗 ${p.practiceClearedCount}/3',
        progress: p.practiceClearedCount / 3,
        buttonLabel: 'ワークを始める',
        onTap: () => context.push('/quests'),
      ),
      const SizedBox(height: 10),
      _QuestCard(
        no: '03',
        color: dailyUnlocked ? pnGreen : pnBg,
        title: '今日の依頼',
        badges: [
          if (dailyUnlocked)
            ('解放中！', pnGreen)
          else
            ('練習3つで解放', pnLine),
        ],
        locked: !dailyUnlocked,
        desc: '村の人たちからのほんものの依頼。ヒアリングから納品まで挑戦しよう。',
        meta: '所要時間 15分　・　獲得EXP +50 EXP',
        buttonLabel: dailyUnlocked ? '依頼を見る' : 'QUEST 02 をクリアで開放',
        onTap: () => context.push('/daily-request'),
      ),
    ];
  }

  Widget _nextAreaCard() => PnPanel(
        child: Row(children: [
          Container(
            width: 64,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pnBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pnLine),
            ),
            child: const Text('次エリア',
                style: TextStyle(fontSize: 10, color: pnSub)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('次のエリア', style: TextStyle(color: pnSub, fontSize: 11)),
                  Text('はじまりの森',
                      style: TextStyle(
                          color: pnInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pnBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: pnLine),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 12, color: pnSub),
              SizedBox(width: 4),
              Text('ロック', style: TextStyle(fontSize: 11, color: pnSub)),
            ]),
          ),
        ]),
      );
}

/// クエストカード(番号バブル + バッジ + 本文 + ボタン)。
class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.no,
    required this.color,
    required this.title,
    required this.badges,
    required this.desc,
    required this.meta,
    required this.buttonLabel,
    required this.onTap,
    this.progress,
    this.locked = false,
  });

  final String no;
  final Color color;
  final String title;
  final List<(String, Color)> badges;
  final String desc;
  final String meta;
  final String buttonLabel;
  final VoidCallback onTap;
  final double? progress;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pnCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: locked ? pnLine : color, width: locked ? 1 : 1.6),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: locked ? pnBg : color.withOpacity(0.5),
                  shape: BoxShape.circle),
              child: Text(no,
                  style: TextStyle(
                      color: locked ? pnSub : pnInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(title,
                            style: TextStyle(
                                color: locked ? pnSub : pnInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      for (final (label, badgeColor) in badges)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (label.contains('解放') && locked)
                              const Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(Icons.lock_rounded,
                                    size: 10, color: pnSub),
                              ),
                            Text(label,
                                style: const TextStyle(
                                    color: pnInk,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 5),
                    Text(desc,
                        style: const TextStyle(
                            color: pnSub, fontSize: 12.5, height: 1.55)),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: pnBg,
                            color: pnGreen),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Text(meta,
                            style:
                                const TextStyle(color: pnSub, fontSize: 11)),
                      ),
                      locked
                          ? OutlinedButton(
                              onPressed: onTap,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: pnSub,
                                  side: const BorderSide(color: pnLine),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6)),
                              child: Text(buttonLabel,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700)),
                            )
                          : FilledButton(
                              onPressed: onTap,
                              style: FilledButton.styleFrom(
                                  backgroundColor: pnGreen,
                                  foregroundColor: pnGreenInk,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 6)),
                              child: Text(buttonLabel,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 「今日の依頼」解放のお祝いダイアログ。
class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.onGo});
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          const Text('すごい！基礎のクエストを3つクリアしたね',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: pnInk, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('「今日の依頼」が解放されたよ。村の人たちの依頼に挑戦しよう！',
              textAlign: TextAlign.center,
              style: TextStyle(color: pnSub, fontSize: 13, height: 1.6)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onGo,
              style: FilledButton.styleFrom(
                  backgroundColor: pnGreen, foregroundColor: pnGreenInk),
              child: const Text('依頼を見に行く',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
