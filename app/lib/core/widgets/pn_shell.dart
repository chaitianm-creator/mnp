import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// PRO NAVI ワイヤーフレーム共通シェル。
/// PC: 左サイドバー(ロゴ/Zoom/学習タイマー/ナビ/ログアウト) + メイン +
///     右レール(主人公ステータス/冒険の記録) + フッター
/// SP: ハンバーガー+MIPORINヘッダー + 縦積み
///     (メイン → 主人公 → 記録 → タイマー → Zoom → フッター)
/// ホーム・冒険マップなどのページがメイン部分だけを差し込んで使う。

// ── 配色(淡いベージュ+パステル) ──
const pnBg = Color(0xFFF7F5EF);
const pnCard = Colors.white;
const pnLine = Color(0xFFE6E0D2);
const pnInk = Color(0xFF4A443A);
const pnSub = Color(0xFF938A78);
const pnGreen = Color(0xFFA8D18F);
const pnGreenInk = Color(0xFF3E5C33);
const pnYellow = Color(0xFFF2DFA7);
const pnPurple = Color(0xFFDCD3F2);
const pnBlue = Color(0xFFCFE3F2);
const pnPink = Color(0xFFF9E9EE);

/// 白カード(汎用)。
class PnPanel extends StatelessWidget {
  const PnPanel(
      {super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: pnCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pnLine),
        ),
        padding: padding,
        child: child,
      );
}

/// 斜めストライプのヒーロー背景。
class PnStripePainter extends CustomPainter {
  const PnStripePainter();

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
  bool shouldRepaint(PnStripePainter old) => false;
}

class PnShell extends ConsumerStatefulWidget {
  const PnShell({
    super.key,
    required this.current, // サイドメニューのハイライト('ホーム'/'冒険マップ' 等)
    required this.mainBuilder, // メインカラムの中身(wide: PC3カラムかどうか)
    this.spTitle = 'MIPORIN', // SPヘッダーのタイトル
  });

  final String current;
  final List<Widget> Function(BuildContext context, bool wide) mainBuilder;
  final String spTitle;

  @override
  ConsumerState<PnShell> createState() => _PnShellState();
}

class _PnShellState extends ConsumerState<PnShell> {
  Timer? _timer;
  int _seconds = 0;
  bool _running = false;

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

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final nickname = ref.watch(accountProvider)?.nickname;

    return Scaffold(
      backgroundColor: pnBg,
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: pnBg,
              foregroundColor: pnInk,
              elevation: 0,
              title: Text(widget.spTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
              actions: [
                if (nickname != null)
                  Center(
                    child: Text(nickname,
                        style: const TextStyle(
                            color: pnSub,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: CircleAvatar(
                      radius: 15,
                      backgroundColor: pnPink,
                      child: const Text('🙂', style: TextStyle(fontSize: 14))),
                ),
              ],
            ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _sideMenu())),
      body: wide ? _buildWide() : _buildNarrow(),
    );
  }

  Widget _buildNarrow() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        ...widget.mainBuilder(context, false),
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
                      children: widget.mainBuilder(context, true)),
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

  // ── サイドメニュー(SP: ドロワー / PC: 左サイドバー) ──
  Widget _sideMenu({bool embedded = false}) {
    final items = [
      ('ホーム', Icons.home_rounded, '/home'),
      ('冒険日誌', Icons.menu_book_rounded, '/skills'),
      ('冒険マップ', Icons.map_rounded, '/map'),
      ('もくもく学習室', Icons.edit_note_rounded, '/workshop'),
      ('お役立ちショップ', Icons.storefront_rounded, null),
      ('ギルドカード', Icons.badge_rounded, null),
    ];
    final menu = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text('MIPORIN',
                style: TextStyle(
                    color: pnInk,
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
          for (final (label, icon, route) in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: label == widget.current ? pnPink : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: label == widget.current
                      ? null
                      : route == null
                          ? () => _comingSoon(label)
                          : () => context.go(route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Icon(icon,
                          size: 18,
                          color: label == widget.current ? pnInk : pnSub),
                      const SizedBox(width: 8),
                      Text(label,
                          style: TextStyle(
                              color:
                                  label == widget.current ? pnInk : pnSub,
                              fontSize: 13.5,
                              fontWeight: label == widget.current
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      const Spacer(),
                      if (route == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: pnBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: pnLine)),
                          child: const Text('近日公開',
                              style:
                                  TextStyle(fontSize: 9.5, color: pnSub)),
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
              icon: const Icon(Icons.logout_rounded, size: 16, color: pnSub),
              label: const Text('ログアウト',
                  style: TextStyle(color: pnSub, fontSize: 13)),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            ),
          ),
        ]);
    if (!embedded) return menu;
    return Container(
      decoration: BoxDecoration(
        color: pnCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pnLine),
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

  // ── 右レール/SP下部の共通カード ──
  Widget _heroineCard() {
    final account = ref.watch(accountProvider);
    final p = ref.watch(userProgressProvider);
    return PnPanel(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pnBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: PixelSprite(
              rows: heroineFrontRows,
              palette: heroinePaletteFor(ref.watch(outfitProvider)),
              width: 96),
        ),
        const SizedBox(height: 10),
        Text(account?.nickname ?? 'デザイナー冒険者',
            style: const TextStyle(
                color: pnInk, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        const Text('勇者のステータス',
            style: TextStyle(color: pnSub, fontSize: 11)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Lv.${p.level}',
              style: const TextStyle(
                  color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          const Text('見習い冒険者',
              style: TextStyle(color: pnSub, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: (p.xp % 100) / 100,
              minHeight: 8,
              backgroundColor: pnBg,
              color: pnPurple),
        ),
        const SizedBox(height: 8),
        Text('獲得ポイント　${p.xp} ポイント',
            style: const TextStyle(color: pnSub, fontSize: 12)),
      ]),
    );
  }

  Widget _recordCard() {
    final p = ref.watch(userProgressProvider);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(label, style: const TextStyle(color: pnSub, fontSize: 12.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: pnInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
          ]),
        );
    return PnPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('冒険の記録',
            style: TextStyle(
                color: pnInk, fontSize: 13, fontWeight: FontWeight.w900)),
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
    return PnPanel(
      child: Column(children: [
        const Text('学習タイマー',
            style: TextStyle(color: pnSub, fontSize: 11.5)),
        const SizedBox(height: 4),
        Text('$mm:$ss',
            style: const TextStyle(
                color: pnInk,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            onPressed: _toggleTimer,
            style: FilledButton.styleFrom(
                backgroundColor: pnGreen,
                foregroundColor: pnGreenInk,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            icon: Icon(
                _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 16),
            label: Text(_running ? '一時停止' : '開始',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _recordTimer,
            style: OutlinedButton.styleFrom(
                foregroundColor: pnSub,
                side: const BorderSide(color: pnLine),
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
          color: pnPurple.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBBFE8)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('次回のZoom',
              style: TextStyle(color: pnSub, fontSize: 11)),
          const SizedBox(height: 2),
          const Text('5/24(金) 12:00〜13:00',
              style: TextStyle(
                  color: pnInk, fontSize: 15, fontWeight: FontWeight.w900)),
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
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: pnLine)),
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
                    case 'ホーム':
                      context.go('/home');
                    case '冒険日誌':
                      context.push('/skills');
                    case '冒険マップ':
                      context.go('/map');
                    case 'もくもく学習室':
                      context.push('/workshop');
                    default:
                      _comingSoon(l);
                  }
                },
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero),
                child: Text(l,
                    style: const TextStyle(color: pnSub, fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('© 2026 PRO NAVI',
            style: TextStyle(color: pnSub, fontSize: 11)),
      ]),
    );
  }
}
