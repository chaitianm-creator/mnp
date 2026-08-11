import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// SC-10 ホーム = エリア詳細「はじまりの街」(PRO NAVI ワイヤーフレーム準拠)。
/// PC: 左サイドバー + メイン + 右レール + フッター
/// SP: ハンバーガー + 縦積み(ヒーロー→進捗→クエスト一覧→ステータス→記録→タイマー→Zoom→フッター)
/// キャラクター画像はドット絵スプライトを仮アセットとして使用。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

// ── ワイヤーフレームの配色(淡いベージュ+パステル) ──
const _bg = Color(0xFFF7F5EF);
const _card = Colors.white;
const _line = Color(0xFFE6E0D2);
const _ink = Color(0xFF4A443A);
const _sub = Color(0xFF938A78);
const _green = Color(0xFFA8D18F);
const _greenInk = Color(0xFF3E5C33);
const _yellow = Color(0xFFF2DFA7);
const _purple = Color(0xFFDCD3F2);
const _blue = Color(0xFFCFE3F2);
const _pink = Color(0xFFF9E9EE);

class _HomePageState extends ConsumerState<HomePage> {
  bool _unlockCelebrated = true; // prefs 読込前は演出を出さない
  Timer? _timer;
  int _seconds = 0;
  bool _running = false;

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      _running = !_running;
      if (_running) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _recordTimer() {
    _timer?.cancel();
    final min = _seconds ~/ 60;
    setState(() {
      _running = false;
      _seconds = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('学習時間 $min分 を記録したよ！(DEMO)'),
        duration: const Duration(seconds: 2)));
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
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final nickname = ref.watch(accountProvider)?.nickname;

    return Scaffold(
      backgroundColor: _bg,
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: _bg,
              foregroundColor: _ink,
              elevation: 0,
              title: const Text('MIPORIN',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
              actions: [
                if (nickname != null)
                  Center(
                    child: Text(nickname,
                        style: const TextStyle(
                            color: _sub,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: CircleAvatar(
                      radius: 15,
                      backgroundColor: _pink,
                      child: const Text('🙂', style: TextStyle(fontSize: 14))),
                ),
              ],
            ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _sideMenu())),
      body: wide ? _buildWide() : _buildNarrow(),
    );
  }

  // ─────────────────────────── SP(縦積み) ───────────────────────────
  Widget _buildNarrow() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        _backToMap(),
        const SizedBox(height: 10),
        _heroCard(),
        const SizedBox(height: 10),
        _miporinSpeech(),
        const SizedBox(height: 10),
        _welcomeCard(),
        const SizedBox(height: 10),
        _progressCard(),
        const SizedBox(height: 10),
        _statCard(_yellow, '獲得できるポイント', '+100 ポイント'),
        const SizedBox(height: 8),
        _statCard(_purple, 'クエスト数', '${_clearedCount()}/3 完了'),
        const SizedBox(height: 8),
        _statCard(_blue, 'クリア報酬', 'はじまりの森 解放！'),
        const SizedBox(height: 18),
        _questHeader(),
        const SizedBox(height: 10),
        ..._questCards(),
        const SizedBox(height: 10),
        _nextAreaCard(),
        const SizedBox(height: 18),
        _heroineCard(),
        const SizedBox(height: 10),
        _recordCard(),
        const SizedBox(height: 10),
        _timerCard(),
        const SizedBox(height: 10),
        _zoomCard(),
        const SizedBox(height: 20),
        _footer(),
      ],
    );
  }

  // ─────────────────────────── PC(3カラム) ───────────────────────────
  Widget _buildWide() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 250, child: _sideMenu(embedded: true)),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: _backToMap()),
                        const SizedBox(height: 10),
                        _heroCard(withSpeech: true),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _statCard(
                                  _yellow, '獲得できるポイント', '+100 ポイント')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statCard(_purple, 'クエスト数',
                                  '${_clearedCount()}/3 完了')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statCard(
                                  _blue, 'クリア報酬', 'はじまりの森 解放！')),
                        ]),
                        const SizedBox(height: 18),
                        _questHeader(),
                        const SizedBox(height: 10),
                        ..._questCards(),
                        const SizedBox(height: 10),
                        _nextAreaCard(),
                      ]),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 300,
                  child: Column(children: [
                    _heroineCard(),
                    const SizedBox(height: 12),
                    _recordCard(),
                  ]),
                ),
              ]),
              const SizedBox(height: 26),
              _footer(),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── サイドメニュー ───────────────────────────
  Widget _sideMenu({bool embedded = false}) {
    final items = [
      ('ホーム', Icons.home_rounded, null, true),
      ('冒険日誌', Icons.menu_book_rounded, '/skills', false),
      ('冒険マップ', Icons.map_rounded, '/map', false),
      ('もくもく学習室', Icons.edit_note_rounded, '/workshop', false),
      ('お役立ちショップ', Icons.storefront_rounded, null, false),
      ('ギルドカード', Icons.badge_rounded, null, false),
    ];
    final menu = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Text('MIPORIN',
            style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2)),
      ),
      if (embedded) ...[
        _zoomCard(),
        const SizedBox(height: 10),
        _timerCard(),
        const SizedBox(height: 14),
      ],
      for (final (label, icon, route, current) in items)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: current ? _pink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: route == null
                  ? (current ? null : () => _comingSoon(label))
                  : () => context.push(route),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(children: [
                  Icon(icon, size: 18, color: current ? _ink : _sub),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          color: current ? _ink : _sub,
                          fontSize: 13.5,
                          fontWeight:
                              current ? FontWeight.w800 : FontWeight.w600)),
                  const Spacer(),
                  if (route == null && !current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _line)),
                      child: const Text('近日公開',
                          style: TextStyle(fontSize: 9.5, color: _sub)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 16, color: _sub),
          label: const Text('ログアウト',
              style: TextStyle(color: _sub, fontSize: 13)),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
        ),
      ),
    ]);
    if (!embedded) return menu;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
      child: menu,
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウトする？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ログアウト')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(accountProvider.notifier).logout();
    if (mounted) context.go('/welcome');
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label は準備中だよ(近日公開)'),
        duration: const Duration(seconds: 2)));
  }

  // ─────────────────────────── 各カード ───────────────────────────
  Widget _backToMap() => TextButton.icon(
        onPressed: () => context.push('/map'),
        icon: const Icon(Icons.arrow_back_rounded, size: 16, color: _sub),
        label: const Text('冒険マップに戻る',
            style: TextStyle(color: _sub, fontSize: 13)),
      );

  /// ヒーロー: 斜めストライプの帯 + エリア名 + みぽりん先生(仮キャラ)。
  Widget _heroCard({bool withSpeech = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _StripePainter(),
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
                        color: _card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _line),
                      ),
                      child: const Text('冒険のはじまり',
                          style: TextStyle(
                              color: _sub,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    const Text('🏠 はじまりの街',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    if (withSpeech) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'ようこそ、デザイナー冒険者さん！ここはすべての旅が始まる地。\nまずはこの世界の歩き方を知って、最初の一歩を踏み出そう。',
                        style: TextStyle(
                            color: _ink, fontSize: 13.5, height: 1.7),
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
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: const Text(
                    '今は「はじまりの街」にいるよ！ここから、あなただけの新しい物語をはじめよう！',
                    style:
                        TextStyle(color: _ink, fontSize: 12, height: 1.6),
                  ),
                ),
              PixelSprite(
                  rows: miporinRows(0),
                  palette: miporinPalette,
                  width: withSpeech ? 92 : 76),
              const SizedBox(height: 4),
              const Text('みぽりん先生',
                  style: TextStyle(
                      color: _sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _miporinSpeech() => _panel(
        child: const Text(
          '今は「はじまりの街」にいるよ！ここから、あなただけの新しい物語をはじめよう！',
          style: TextStyle(color: _ink, fontSize: 13, height: 1.7),
        ),
      );

  Widget _welcomeCard() => _panel(
        child: const Text(
          'ようこそ、デザイナー冒険者さん！ここはすべての旅が始まる地。まずはこの世界の歩き方を知って、最初の一歩を踏み出そう。',
          style: TextStyle(color: _ink, fontSize: 13.5, height: 1.7),
        ),
      );

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
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('エリア進捗率',
              style: TextStyle(
                  color: _sub, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$pct%',
              style: const TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: n / 3,
              minHeight: 8,
              backgroundColor: _bg,
              color: _green),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.check_rounded, size: 14, color: _greenInk),
          const SizedBox(width: 4),
          Text('$n/3 クエスト完了',
              style: const TextStyle(color: _sub, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _statCard(Color dot, String label, String value) => _panel(
        child: Row(children: [
          Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(color: _sub, fontSize: 11)),
                  Text(value,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ]),
          ),
        ]),
      );

  Widget _questHeader() => const Row(children: [
        Text('🍃', style: TextStyle(fontSize: 16)),
        SizedBox(width: 6),
        Text('はじまりの村のクエスト一覧',
            style: TextStyle(
                color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
      ]);

  List<Widget> _questCards() {
    final p = ref.watch(userProgressProvider);
    final practiceDone = p.practiceClearedCount >= 3;
    final dailyUnlocked = p.dailyRequestUnlocked;
    return [
      _QuestCard(
        no: '01',
        color: _blue,
        title: 'ようこそ',
        badges: const [('動画視聴', _blue)],
        desc: '実践デザイナー冒険へようこそ。これから始まる冒険の全体像を見てみよう。',
        meta: '所要時間 5分　・　獲得ポイント +50ポイント',
        buttonLabel: '▶ 動画を見る',
        onTap: () => context.push('/story/ep1'),
      ),
      const SizedBox(height: 10),
      _QuestCard(
        no: '02',
        color: _yellow,
        title: '練習クエスト',
        badges: [
          ('ワーク', _yellow),
          if (practiceDone) ('完了', _green),
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
        color: dailyUnlocked ? _green : _bg,
        title: '今日の依頼',
        badges: [
          if (dailyUnlocked)
            ('解放中！', _green)
          else
            ('練習3つで解放', _line),
        ],
        locked: !dailyUnlocked,
        desc: '村の人たちからのほんものの依頼。ヒアリングから納品まで挑戦しよう。',
        meta: '所要時間 15分　・　獲得EXP +50 EXP',
        buttonLabel: dailyUnlocked ? '依頼を見る' : 'QUEST 02 をクリアで開放',
        onTap: () => context.push('/daily-request'),
      ),
    ];
  }

  Widget _nextAreaCard() => _panel(
        child: Row(children: [
          Container(
            width: 64,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: const Text('次エリア', style: TextStyle(fontSize: 10, color: _sub)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('次のエリア', style: TextStyle(color: _sub, fontSize: 11)),
              Text('はじまりの森',
                  style: TextStyle(
                      color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _line),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 12, color: _sub),
              SizedBox(width: 4),
              Text('ロック', style: TextStyle(fontSize: 11, color: _sub)),
            ]),
          ),
        ]),
      );

  Widget _heroineCard() {
    final account = ref.watch(accountProvider);
    final p = ref.watch(userProgressProvider);
    return _panel(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const PixelSprite(
              rows: heroineFrontRows, palette: heroinePalette, width: 96),
        ),
        const SizedBox(height: 10),
        Text(account?.nickname ?? 'デザイナー冒険者',
            style: const TextStyle(
                color: _ink, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        const Text('勇者のステータス',
            style: TextStyle(color: _sub, fontSize: 11)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Lv.${p.level}',
              style: const TextStyle(
                  color: _ink, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          const Text('見習い冒険者',
              style: TextStyle(color: _sub, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: (p.xp % 100) / 100,
              minHeight: 8,
              backgroundColor: _bg,
              color: _purple),
        ),
        const SizedBox(height: 8),
        Text('獲得ポイント　${p.xp} ポイント',
            style: const TextStyle(color: _sub, fontSize: 12)),
      ]),
    );
  }

  Widget _recordCard() {
    final p = ref.watch(userProgressProvider);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(label, style: const TextStyle(color: _sub, fontSize: 12.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ]),
        );
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('冒険の記録',
            style: TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        row('連続学習', '${p.streak}日'),
        row('総学習時間', '1時間20分'),
        row('クリアエリア', '0 / 6'),
      ]),
    );
  }

  Widget _timerCard() {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return _panel(
      child: Column(children: [
        const Text('学習タイマー',
            style: TextStyle(color: _sub, fontSize: 11.5)),
        const SizedBox(height: 4),
        Text('$mm:$ss',
            style: const TextStyle(
                color: _ink,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            onPressed: _toggleTimer,
            style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: _greenInk,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 16),
            label: Text(_running ? '一時停止' : '開始',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _recordTimer,
            style: OutlinedButton.styleFrom(
                foregroundColor: _sub,
                side: const BorderSide(color: _line),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('記録',
                style:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }

  Widget _zoomCard() => Container(
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBBFE8)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('次回のZoom',
              style: TextStyle(color: _sub, fontSize: 11)),
          const SizedBox(height: 2),
          const Text('5/24(金) 12:00〜13:00',
              style: TextStyle(
                  color: _ink, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Zoomリンクは準備中だよ(DEMO)'),
                      duration: Duration(seconds: 2))),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB7A8E0),
                  foregroundColor: Colors.white),
              child: const Text('Zoomに参加する',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );

  Widget _footer() {
    const links = [
      'ホーム', '冒険日誌', '冒険マップ', 'もくもく学習室',
      'お役立ちショップ', 'ギルドカード', 'よくある質問', 'お問い合わせ',
      '利用規約', 'プライバシーポリシー',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Column(children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            for (final l in links)
              TextButton(
                onPressed: () {
                  switch (l) {
                    case '冒険日誌':
                      context.push('/skills');
                    case '冒険マップ':
                      context.push('/map');
                    case 'もくもく学習室':
                      context.push('/workshop');
                    case 'ホーム':
                      break;
                    default:
                      _comingSoon(l);
                  }
                },
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero),
                child: Text(l,
                    style: const TextStyle(color: _sub, fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('© 2026 PRO NAVI',
            style: TextStyle(color: _sub, fontSize: 11)),
      ]),
    );
  }

  Widget _panel({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        padding: const EdgeInsets.all(14),
        child: child,
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
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: locked ? _line : color, width: locked ? 1 : 1.6),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: locked ? _bg : color.withOpacity(0.5),
                  shape: BoxShape.circle),
              child: Text(no,
                  style: TextStyle(
                      color: locked ? _sub : _ink,
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
                                color: locked ? _sub : _ink,
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
                                    size: 10, color: _sub),
                              ),
                            Text(label,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 5),
                    Text(desc,
                        style: const TextStyle(
                            color: _sub, fontSize: 12.5, height: 1.55)),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: _bg,
                            color: _green),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Text(meta,
                            style: const TextStyle(
                                color: _sub, fontSize: 11)),
                      ),
                      locked
                          ? OutlinedButton(
                              onPressed: onTap,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: _sub,
                                  side: const BorderSide(color: _line),
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
                                  backgroundColor: _green,
                                  foregroundColor: _greenInk,
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

/// ヒーローの斜めストライプ背景。
class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFF0EADC);
    canvas.drawRect(Offset.zero & size, p);
    p.color = const Color(0xFFE9E1CE);
    const gap = 26.0;
    for (var x = -size.height; x < size.width; x += gap) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + 10, 0)
        ..lineTo(x + 10, size.height)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
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
                  color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('「今日の依頼」が解放されたよ。村の人たちの依頼に挑戦しよう！',
              textAlign: TextAlign.center,
              style: TextStyle(color: _sub, fontSize: 13, height: 1.6)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onGo,
              style: FilledButton.styleFrom(
                  backgroundColor: _green, foregroundColor: _greenInk),
              child: const Text('依頼を見に行く',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
