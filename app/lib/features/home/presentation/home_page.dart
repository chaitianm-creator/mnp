import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/state/account.dart';
import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';

/// SC-10 ホームメニュー(ゲーム様式)。
/// 上: ステータスバー(アバター/ニックネーム/Lv/XP/コイン/連続/通知/設定)
/// 中: みぽりん先生(大きく) + 状況別の吹き出し
/// 下: メニューボタン(練習クエスト/今日の依頼/工房/成長記録/お知らせ/プロフィール)
/// ※参考画像はレイアウトの考え方のみ。配色・キャラ・フォントは王国の様式を維持。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  bool _unlockCelebrated = true; // prefs 読込前は演出を出さない

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.of(context).disableAnimations) _bob.repeat();
    });
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() =>
          _unlockCelebrated = prefs.getBool('daily_unlock_celebrated') ?? false);
      _maybeCelebrateUnlock();
    });
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
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
    final account = ref.watch(accountProvider);
    final progress = ref.watch(userProgressProvider);

    // 進捗が更新されたら解放演出のチャンスを見にいく
    ref.listen(userProgressProvider, (_, __) => _maybeCelebrateUnlock());

    final unlocked = progress.dailyRequestUnlocked;

    return Scaffold(
      body: Stack(children: [
        // 背景: 王国の空と草原(メニューの後ろでキャラが立つ舞台)
        const Positioned.fill(child: CustomPaint(painter: _HomeFieldPainter())),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              // ── ステータスバー ──
              _StatusBar(account: account, progress: progress),
              const SizedBox(height: 18),
              // ── みぽりん先生 + 吹き出し ──
              _SpeechBubble(text: _teacherLine(progress, unlocked)),
              const SizedBox(height: 6),
              Center(
                child: AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Transform.translate(
                    offset:
                        Offset(0, math.sin(_bob.value * 2 * math.pi) * 4),
                    child: child,
                  ),
                  child: const _TeacherStanding(),
                ),
              ),
              const SizedBox(height: 16),
              // ── メニュー ──
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
                children: [
                  _MenuButton(
                    icon: Icons.school,
                    color: KdColors.pink500,
                    label: '練習クエスト',
                    caption: 'きほんのレッスン',
                    onTap: () => context.push('/quests'),
                  ),
                  _MenuButton(
                    icon: unlocked ? Icons.mail : Icons.lock,
                    color: unlocked ? KdColors.gold500 : const Color(0xFFB3A68E),
                    label: '今日の依頼',
                    caption: unlocked ? 'お客様からのおしごと' : '練習3つで解放',
                    locked: !unlocked,
                    onTap: () {
                      if (unlocked) {
                        context.push('/daily-request');
                      } else {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(const SnackBar(
                            content:
                                Text('練習クエストを3つクリアすると解放されるよ♪'),
                          ));
                      }
                    },
                  ),
                  _MenuButton(
                    icon: Icons.handyman,
                    color: KdColors.ocean500,
                    label: '工房',
                    caption: 'つくったもの',
                    onTap: () => context.push('/workshop'),
                  ),
                  _MenuButton(
                    icon: Icons.park,
                    color: KdColors.grass500,
                    label: '成長記録',
                    caption: 'スキルとレベル',
                    onTap: () => context.go('/skills'),
                  ),
                  _MenuButton(
                    icon: Icons.notifications,
                    color: KdColors.lava500,
                    label: 'お知らせ',
                    caption: '王国からの手紙',
                    onTap: () => context.push('/notices'),
                  ),
                  _MenuButton(
                    icon: Icons.person,
                    color: KdColors.pink700,
                    label: 'プロフィール',
                    caption: 'ぼうけんの記録',
                    onTap: () => context.go('/profile'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // エリアへの入り口(村ビュー/ワールドマップは下タブからも行ける)
              GestureDetector(
                onTap: () => context.push('/village'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: KdColors.pink500,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KdColors.pink700, width: 2),
                    boxShadow: const [
                      BoxShadow(color: KdColors.pink700, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.castle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('エリア①',
                                style:
                                    KdTheme.dot(size: 10, color: Colors.white)),
                            Text('はじまりの街（みぽりん村）',
                                style:
                                    KdTheme.dot(size: 15, color: Colors.white)
                                        .copyWith(
                                            fontWeight: FontWeight.w700)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.white, size: 22),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// 状況にあわせた先生のひとこと。
  String _teacherLine(UserProgress progress, bool unlocked) {
    final practice = progress.practiceClearedCount;
    final hasRealDelivery =
        progress.deliveredQuestIds.any((id) => !id.startsWith('q_practice'));
    if (!unlocked) {
      return switch (practice) {
        0 => 'まずは、どこへ行ってみる？\nおすすめは『練習クエスト』だよ♪',
        1 => 'いいスタート！\n練習クエスト、あと2つで依頼が解放だよ',
        _ => 'もうすこし！あと1つクリアで\nはじめての依頼が届くよ♪',
      };
    }
    if (!hasRealDelivery) {
      return 'もちもち王国のパン屋さんが待ってるよ！\n『今日の依頼』を見てみて♪';
    }
    return 'きょうも いっしょに がんばろう♪\nまずは、どこへ行ってみる？';
  }
}

/// ── ステータスバー(羊皮紙パネル) ─────────────────────────
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.account, required this.progress});
  final UserAccount? account;
  final UserProgress progress;

  @override
  Widget build(BuildContext context) {
    // レベル内XP(DEMO: 1レベル=100XP)
    final xpInLevel = progress.xp % 100;
    return KdParchmentCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KdColors.pink100,
              shape: BoxShape.circle,
              border: Border.all(color: KdColors.wood900, width: 2.5),
            ),
            child: const Icon(Icons.person, size: 24, color: KdColors.pink700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(account?.nickname ?? 'デザイン見習いさん',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KdTheme.dot(size: 14, color: KdColors.heading)
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(children: [
                // Lv プレート(スキル画面と同じ様式)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: KdColors.wood900,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: KdColors.gold500, width: 1.5),
                  ),
                  child: Text('Lv.${progress.level}',
                      style: KdTheme.dot(size: 10, color: KdColors.gold500)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.monetization_on,
                    size: 15, color: KdColors.gold500),
                const SizedBox(width: 2),
                Text('${progress.coins}',
                    style: KdTheme.dot(size: 12, color: KdColors.ink900)),
                const SizedBox(width: 8),
                const Icon(Icons.favorite, size: 14, color: KdColors.pink500),
                const SizedBox(width: 2),
                Text('${progress.streak}日',
                    style: KdTheme.dot(size: 12, color: KdColors.ink900)),
              ]),
            ]),
          ),
          // 通知・設定
          _RoundIconButton(
            icon: Icons.notifications,
            onTap: () => context.push('/notices'),
          ),
          const SizedBox(width: 6),
          _RoundIconButton(
            icon: Icons.settings,
            onTap: () => context.push('/settings'),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('EXP', style: KdTheme.dot(size: 10, color: KdColors.pink700)),
          const SizedBox(width: 6),
          Expanded(child: KdProgressBar(value: xpInLevel / 100)),
          const SizedBox(width: 6),
          Text('$xpInLevel/100',
              style: KdTheme.dot(size: 10, color: KdColors.ink900)),
        ]),
      ]),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.wood900, width: 2),
          boxShadow: const [
            BoxShadow(color: KdColors.wood900, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 17, color: KdColors.wood700),
      ),
    );
  }
}

/// ── みぽりん先生(立ち姿・大きく) ────────────────────────
class _TeacherStanding extends StatelessWidget {
  const _TeacherStanding();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          color: KdColors.pink100,
          shape: BoxShape.circle,
          border: Border.all(color: KdColors.wood900, width: 3),
          boxShadow: const [
            BoxShadow(color: KdColors.pink700, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.favorite, size: 60, color: KdColors.pink500),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.pink500, width: 1.5),
        ),
        child: Text('みぽりん先生',
            style: KdTheme.dot(size: 11, color: KdColors.pink700)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// 吹き出し(しっぽ付き・キャラの上に出る)。
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: KdColors.pink500, width: 2),
          boxShadow: const [
            BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
      ),
      // しっぽ(下向き三角)
      CustomPaint(size: const Size(16, 9), painter: _BubbleTailPainter()),
    ]);
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = KdColors.pink500);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ── メニューボタン(ドット絵の作法: 面取り+固いオフセット影) ──
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
    required this.onTap,
    this.locked = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: locked ? '$label（練習クエストを3つクリアすると解放）' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: locked ? const Color(0xFFEFE7D5) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: KdColors.wood900, width: 2.5),
            boxShadow: const [
              BoxShadow(color: KdColors.wood900, offset: Offset(0, 3)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: KdColors.wood900, width: 2),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KdTheme.dot(
                                size: 13,
                                color: locked
                                    ? KdColors.wood700
                                    : KdColors.ink900)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 10)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 解放演出ダイアログ(先生からのメッセージ)。
class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.onGo});
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: KdParchmentCard(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          KdRibbonBanner('依頼が届いたよ！', fontSize: 14),
          const SizedBox(height: 14),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: KdColors.pink100,
              shape: BoxShape.circle,
              border: Border.all(color: KdColors.pink500, width: 2.5),
            ),
            child:
                const Icon(Icons.favorite, size: 36, color: KdColors.pink500),
          ),
          const SizedBox(height: 12),
          Text(
            'すごい！基礎のクエストを3つクリアしたね。\nもちもち王国のパン屋さんから、\nはじめての依頼が届いているよ。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 16),
          KdPrimaryButton(label: '依頼を見に行く', onPressed: onGo),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('あとで'),
          ),
        ]),
      ),
    );
  }
}

/// ホームの背景(空+草原の帯。キャラが立つ舞台)。固定シードでちらつきなし。
class _HomeFieldPainter extends CustomPainter {
  const _HomeFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final p = Paint();

    // 空(上 55%)
    p.color = const Color(0xFFBFE3F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.55), p);
    // 雲(角丸ブロック)
    p.color = Colors.white;
    for (var i = 0; i < 5; i++) {
      final x = rng.nextDouble() * size.width;
      final y = 20 + rng.nextDouble() * size.height * 0.3;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: 64, height: 18),
              const Radius.circular(9)),
          p);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x + 18, y - 10), width: 36, height: 14),
              const Radius.circular(7)),
          p);
    }
    // 地平線のディザ帯
    final horizon = size.height * 0.55;
    p.color = const Color(0xFF9CCB6E);
    for (double x = 0; x < size.width; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x, horizon - 6, 6, 6), p);
    }
    // 草原(下 45%) + むら
    p.color = const Color(0xFF8CC868);
    canvas.drawRect(
        Rect.fromLTWH(0, horizon, size.width, size.height - horizon), p);
    for (var i = 0; i < (size.width * (size.height - horizon)) / 1200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = horizon + rng.nextDouble() * (size.height - horizon);
      p.color = rng.nextBool()
          ? const Color(0xFF7CB151)
          : const Color(0xFF9AD478);
      canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 5, 5), p);
    }
    // 花
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = horizon + rng.nextDouble() * (size.height - horizon);
      p.color = rng.nextBool() ? KdColors.pink100 : Colors.white;
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 3, height: 3), p);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x - 3, y), width: 3, height: 3), p);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x + 3, y), width: 3, height: 3), p);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y - 3), width: 3, height: 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
