import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/outfit.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes_clean.dart';

/// SC-31 街マップ(ワイヤーフレーム22準拠)。
/// どうぶつの森風の街マップに7スポットを配置し、タップで選択すると
/// 右(PCサイド)/下(SP)の詳細パネルが切り替わる。ドット絵の主人公が
/// 選んだスポットまで歩き、「このスポットへ行く」で中に入る。
class VillagePage extends ConsumerStatefulWidget {
  const VillagePage({super.key});

  @override
  ConsumerState<VillagePage> createState() => _VillagePageState();
}

/// スポット定義(位置は 0.0-1.0 の正規化座標)。
class _Spot {
  const _Spot(this.id, this.name, this.grid, this.desc, this.pos, this.scene);
  final String id;
  final String name;
  final String grid; // マス目表記(B-2 など)
  final String desc;
  final Offset pos;
  final String scene; // 選択中スポットのイラスト(クリーンシーン名)
  String get status => '未着手';
  int get xp => 50;
}

const _spots = [
  _Spot('bakery', 'パン屋さん', 'B-2',
      'お客さんが入らないと悩んでいる。チラシとメニューを見直したい。',
      Offset(0.24, 0.22), 'bakery_front'),
  _Spot('cafe', 'カフェ', 'B-5', '新メニューのポスターを作りたいんだって。',
      Offset(0.70, 0.22), 'cafe_front'),
  _Spot('studio', 'デザイン会社', 'C-3',
      'デザイン体験として練習制作ができる会社。店先の掲示板には街のお困りごと(ポイント獲得)が貼り出され、たまに実務のプチお手伝い案件も登場！',
      Offset(0.42, 0.50), 'studio_front'),
  _Spot('museum', '図書館', 'C-6', 'デザインの本や資料がそろう学びの場所。',
      Offset(0.80, 0.46), 'museum_front'),
  _Spot('grocery', '八百屋さん', 'E-1', '旬の野菜のPOPを作ってほしいみたい。',
      Offset(0.15, 0.70), 'grocery_front'),
  _Spot('port', 'イベント会場', 'F-6',
      'ワークショップやコンテストが開かれる会場。',
      Offset(0.83, 0.86), 'event_front'),
];

/// 道でつながっているスポットのペア(それ以外の移動はショートカット)。
const _roadPairs = {
  'bakery|studio', 'grocery|studio', 'grocery|port', 'cafe|museum',
  'museum|port', 'museum|studio',
};

bool _isConnected(String a, String b) {
  final key = ([a, b]..sort()).join('|');
  return _roadPairs.contains(key);
}

class _VillagePageState extends ConsumerState<VillagePage> {
  String _selectedId = 'bakery';
  bool _walking = false;
  bool _flying = false; // 道がないところは飛行機で移動
  int _dir = 0; // 歩く向き(0=正面 1=左 2=右 3=うしろ)
  bool _shortcutBubble = false; // 道なき移動(飛行機)のときの「びゅーん♪」
  Timer? _bubbleTimer;

  _Spot get _selected => _spots.firstWhere((s) => s.id == _selectedId);

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  void _select(String id) {
    if (_selectedId == id) return;
    final shortcut = !_isConnected(_selectedId, id);
    // 移動方向からスプライトの向きを決める(横移動が大きければ左右)
    final from = _selected.pos;
    final to = _spots.firstWhere((s) => s.id == id).pos;
    final d = to - from;
    final dir = d.dx.abs() >= d.dy.abs() ? (d.dx < 0 ? 1 : 2) : (d.dy < 0 ? 3 : 0);
    setState(() {
      _selectedId = id;
      _walking = true;
      _flying = shortcut;
      _dir = dir;
      _shortcutBubble = shortcut;
    });
    Future<void>.delayed(const Duration(milliseconds: 700)).then((_) {
      if (mounted) {
        setState(() {
          _walking = false;
          _flying = false;
          _dir = 0; // 到着したら正面に戻る
        });
      }
    });
    _bubbleTimer?.cancel();
    if (shortcut) {
      _bubbleTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _shortcutBubble = false);
      });
    }
  }

  void _enter(_Spot s) {
    switch (s.id) {
      case 'bakery':
        context.push('/daily-request');
      case 'port':
        _message('イベントは近日開催！おたのしみに♪');
      case 'studio':
        context.go('/home'); // 練習制作+お困りごとの受付(依頼リスト)へ
      case 'cafe':
        _message('カフェでひとやすみ♪ あったかいココアをどうぞ♡');
      case 'grocery':
        _message('八百屋さんのPOPづくりは、これから登場するよ♪');
      case 'museum':
        _message('図書館は v1.1 でオープンするよ！おたのしみに♪');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pnBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── 左: 見出し + マップ ──
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 10),
                        Expanded(child: _mapCard()),
                      ]),
                ),
                const SizedBox(width: 16),
                // ── 右: おすすめ + 詳細パネル ──
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _questButton('おすすめ：パン屋さん',
                              onTap: () => _select('bakery')),
                          const SizedBox(height: 8),
                          _questButton('パン屋さんの再出発', onTap: () {
                            _select('bakery');
                            _enter(_spots.first);
                          }),
                          const SizedBox(height: 12),
                          _illustrationCard(height: 190),
                          const SizedBox(height: 12),
                          _infoCard(),
                          const SizedBox(height: 12),
                          _hintCard(),
                          const SizedBox(height: 16),
                          _ctaButton(),
                        ]),
                  ),
                ),
              ]),
            );
          }
          // ── SP: 縦積み(WF 22b) ──
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 10),
                  AspectRatio(aspectRatio: 0.98, child: _mapCard()),
                  const SizedBox(height: 12),
                  _questButton('パン屋さんの再出発', onTap: () {
                    _select('bakery');
                    _enter(_spots.first);
                  }),
                  const SizedBox(height: 12),
                  _illustrationCard(height: 170),
                  const SizedBox(height: 12),
                  _infoCard(),
                  const SizedBox(height: 12),
                  _hintCard(),
                  const SizedBox(height: 16),
                  _ctaButton(),
                ]),
          );
        }),
      ),
    );
  }

  // ── 見出し(戻る + 街マップ + スポット数チップ) ──
  Widget _header() => Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.canPop() ? context.pop() : context.go('/map'),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.arrow_back_rounded, size: 22, color: pnInk),
          ),
        ),
        const SizedBox(width: 6),
        const Text('街マップ',
            style: TextStyle(
                color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: pnLine),
          ),
          child: const Text('6スポット',
              style: TextStyle(
                  color: pnSub, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]);

  // ── マップ(どうぶつの森風の街 + スポット + ドット主人公) ──
  Widget _mapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pnLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final sel = _selected;
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _TownPainter())),
          // スポット(タップで選択)
          for (final s in _spots)
            Positioned(
              left: s.pos.dx * w - 34,
              top: s.pos.dy * h - 26,
              child: _SpotMarker(
                  spot: s,
                  selected: s.id == _selectedId,
                  onTap: () => _select(s.id)),
            ),
          // ドット絵の主人公(選んだスポットまで歩く)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOut,
            left: sel.pos.dx * w + 36,
            top: sel.pos.dy * h - 22,
            child: _Avatar(walking: _walking, flying: _flying, dir: _dir),
          ),
          // 道がないところを歩いたときの吹き出し
          AnimatedPositioned(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOut,
            left: sel.pos.dx * w + 18,
            top: sel.pos.dy * h - 54,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _shortcutBubble ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pnLine),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x1A4A443A),
                          blurRadius: 5,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Text('びゅーん♪',
                      style: TextStyle(
                          color: Color(0xFFD16E8E),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _questButton(String label, {required VoidCallback onTap}) => Material(
        color: const Color(0xFFFBF4E2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEBD9AE)),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF8A744A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );

  Widget _illustrationCard({required double height}) => Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pnLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          buildCleanScene(_selected.scene),
        ]),
      );

  Widget _infoCard() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pnLine),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('スポット情報',
              style: TextStyle(color: pnSub, fontSize: 11.5)),
          const SizedBox(height: 4),
          Text('${_selected.name}（${_selected.grid}）',
              style: const TextStyle(
                  color: pnInk, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(_selected.desc,
              style: const TextStyle(
                  color: pnInk,
                  fontSize: 13.5,
                  height: 1.6,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: pnLine),
              ),
              child: Text(_selected.status,
                  style: const TextStyle(
                      color: pnInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF4E2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEBD9AE)),
              ),
              child: Text('経験値 +${_selected.xp}',
                  style: const TextStyle(
                      color: Color(0xFF8A744A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      );

  Widget _hintCard() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pnLine),
        ),
        child: Row(children: [
          PixelSprite(
              rows: miporinRows(0), palette: miporinPalette, width: 34),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('気になるマスをタップして、村人の困りごとを見てみよう！',
                style: TextStyle(
                    color: pnInk,
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _ctaButton() => SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: () => _enter(_selected),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF2AFC1),
            foregroundColor: const Color(0xFF8E4A62),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.play_arrow_rounded, size: 20),
            const SizedBox(width: 4),
            Text('このスポットへ行く'),
          ]),
        ),
      );
}

/// スポットマーカー(ミニ建物 + 名前プレート)。
class _SpotMarker extends StatelessWidget {
  const _SpotMarker(
      {required this.spot, required this.selected, required this.onTap});
  final _Spot spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(
            size: const Size(68, 44),
            painter: _MiniSpotPainter(id: spot.id, selected: selected)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDD7E9B) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? const Color(0xFFC96687) : pnLine,
                width: selected ? 1.6 : 1),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1A4A443A), blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          child: Text(spot.name,
              style: TextStyle(
                  color: selected ? Colors.white : pnInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// プレイヤーのアバター(ドット絵の主人公。きせかえの服も反映)。
/// 歩行中は参考スプライトシートのように向き(前・横・後ろ)と
/// 足踏み3コマのアニメーションで表示する。
/// flying=true のときは小さな飛行機に乗って移動する。
class _Avatar extends ConsumerStatefulWidget {
  const _Avatar({required this.walking, this.flying = false, this.dir = 0});
  final bool walking;
  final bool flying;
  final int dir; // 0=正面 1=左 2=右 3=うしろ

  @override
  ConsumerState<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends ConsumerState<_Avatar> {
  Timer? _stepTimer;
  int _tick = 0;
  // 歩行サイクル: 大また→そろえ→小また→そろえ
  static const _cycle = [1, 0, 2, 0];

  @override
  void didUpdateWidget(covariant _Avatar old) {
    super.didUpdateWidget(old);
    if (widget.walking && !old.walking) {
      _tick = 0;
      _stepTimer?.cancel();
      _stepTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (mounted) setState(() => _tick++);
      });
    } else if (!widget.walking && old.walking) {
      _stepTimer?.cancel();
      _stepTimer = null;
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walking = widget.walking;
    final flying = widget.flying;
    final outfit = ref.watch(outfitProvider);
    final frame = walking ? _cycle[_tick % _cycle.length] : 0;
    final sprite = PixelSprite(
      rows: heroineWalkRows(walking ? widget.dir : 0, frame),
      palette: heroinePaletteFor(outfit),
      width: 32,
    );
    if (flying) {
      return IgnorePointer(
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(alignment: Alignment.topCenter, children: [
            Positioned(
              top: 26,
              child: CustomPaint(
                  size: const Size(84, 52), painter: _PlanePainter()),
            ),
            Positioned(top: 0, child: sprite),
            Positioned(
              bottom: 0,
              child: Container(
                width: 46,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0x26304018),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ]),
        ),
      );
    }
    return IgnorePointer(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedRotation(
          turns: walking ? 0.012 : 0,
          duration: const Duration(milliseconds: 250),
          child: sprite,
        ),
        const SizedBox(height: 1),
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0x26304018),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ]),
    );
  }
}

/// 主人公が乗る飛行機(横向きのジャンボ機・参考イラスト準拠)。
class _PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outline = Paint()
      ..color = const Color(0xFF3A3532)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final white = Paint()..color = Colors.white;
    final lightBlue = Paint()..color = const Color(0xFFC9EFFB);

    // 尾翼(右うしろに大きく)
    final fin = Path()
      ..moveTo(w * 0.74, h * 0.44)
      ..quadraticBezierTo(w * 0.78, h * 0.10, w * 0.87, h * 0.04)
      ..quadraticBezierTo(w * 0.95, h * 0.00, w * 0.94, h * 0.16)
      ..lineTo(w * 0.90, h * 0.52)
      ..close();
    canvas.drawPath(fin, white);
    canvas.drawPath(fin, outline);
    // 水平尾翼
    final tailWing = Path()
      ..moveTo(w * 0.80, h * 0.52)
      ..quadraticBezierTo(w * 0.99, h * 0.56, w * 0.99, h * 0.66)
      ..lineTo(w * 0.82, h * 0.64)
      ..close();
    canvas.drawPath(tailWing, white);
    canvas.drawPath(tailWing, outline);

    // 胴体(左が機首の白いカプセル)
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.01, h * 0.32, w * 0.92, h * 0.4),
        Radius.circular(h * 0.2));
    canvas.drawRRect(body, white);
    // 青いおなか
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.57, w, h * 0.16),
        Paint()..color = const Color(0xFF2AA5CE));
    canvas.restore();
    canvas.drawRRect(body, outline);

    // コックピットの窓(機首の上・水色の帯)
    final cockpit = Path()
      ..moveTo(w * 0.045, h * 0.40)
      ..quadraticBezierTo(w * 0.10, h * 0.345, w * 0.185, h * 0.35)
      ..lineTo(w * 0.175, h * 0.46)
      ..quadraticBezierTo(w * 0.10, h * 0.46, w * 0.055, h * 0.49)
      ..close();
    canvas.drawPath(cockpit, lightBlue);
    canvas.drawPath(
        cockpit,
        Paint()
          ..color = const Color(0xFF3A3532)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);
    // 客席の窓(小さな水色の四角)
    final winStroke = Paint()
      ..color = const Color(0xFF3A3532)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var i = 0; i < 5; i++) {
      final wr = RRect.fromRectAndRadius(
          Rect.fromLTWH(
              w * (0.25 + i * 0.105), h * 0.42, w * 0.062, h * 0.115),
          const Radius.circular(2.5));
      canvas.drawRRect(wr, lightBlue);
      canvas.drawRRect(wr, winStroke);
    }

    // 主翼(手前へ下りる白い翼)
    final wing = Path()
      ..moveTo(w * 0.40, h * 0.55)
      ..lineTo(w * 0.62, h * 0.62)
      ..quadraticBezierTo(w * 0.60, h * 0.80, w * 0.50, h * 0.96)
      ..quadraticBezierTo(w * 0.44, h * 1.02, w * 0.40, h * 0.94)
      ..close();
    canvas.drawPath(wing, white);
    canvas.drawPath(wing, outline);
    // エンジン(翼の下の黒い楕円)
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.335, h * 0.80),
            width: w * 0.10,
            height: h * 0.16),
        white);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.335, h * 0.80),
            width: w * 0.10,
            height: h * 0.16),
        outline);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.325, h * 0.80),
            width: w * 0.05,
            height: h * 0.10),
        Paint()..color = const Color(0xFF3A3532));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 街の背景(どうぶつの森風: 芝生 + 紙吹雪 + 木 + 港の入り江)。
class _TownPainter extends CustomPainter {
  const _TownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rng = math.Random(9);
    // 芝生
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF7EC55E));
    acGrassSpeckle(canvas, Offset.zero & size, math.Random(75),
        step: (w / 16).clamp(26.0, 56.0), color: const Color(0x141E5216));
    // 小道(スポットをゆるくつなぐ)
    final road = Paint()
      ..color = const Color(0x66EDE2C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(w * 0.24, h * 0.26);
    for (final (fx, fy) in [
      (0.42, 0.54), (0.15, 0.74), (0.5, 0.86), (0.83, 0.90),
    ]) {
      path.lineTo(w * fx, h * fy);
    }
    final path2 = Path()
      ..moveTo(w * 0.70, h * 0.26)
      ..lineTo(w * 0.80, h * 0.50)
      ..lineTo(w * 0.83, h * 0.90);
    // デザイン会社 → 図書館の道
    final path3 = Path()
      ..moveTo(w * 0.42, h * 0.54)
      ..lineTo(w * 0.80, h * 0.50);
    canvas.drawPath(path, road);
    canvas.drawPath(path2, road);
    canvas.drawPath(path3, road);
    // 港の入り江(右下)
    final sea = Path()
      ..moveTo(w, h * 0.82)
      ..quadraticBezierTo(w * 0.86, h * 0.88, w * 0.88, h)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(sea, Paint()..color = const Color(0xFFA9D7EC));
    final wave = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.93 - 5, h * 0.92 + 3.5)
          ..lineTo(w * 0.93, h * 0.92)
          ..lineTo(w * 0.93 + 5, h * 0.92 + 3.5),
        wave);
    // 木・花・草の房
    for (final (fx, fy, conifer) in [
      (0.08, 0.14, false), (0.52, 0.12, true), (0.92, 0.32, false),
      (0.06, 0.46, true), (0.55, 0.60, false), (0.30, 0.88, true),
      (0.55, 0.93, false),
    ]) {
      if (conifer) {
        acConifer(canvas, w * fx, h * fy, 0.75);
      } else {
        acTree(canvas, w * fx, h * fy, 0.7);
      }
    }
    for (var i = 0; i < 10; i++) {
      acFlower(canvas, rng.nextDouble() * w, rng.nextDouble() * h,
          [Colors.white, const Color(0xFFF2A5C0), const Color(0xFFF6D96B)][i % 3]);
    }
    for (var i = 0; i < 14; i++) {
      acTuft(canvas, rng.nextDouble() * w, rng.nextDouble() * h, 1.1,
          const Color(0x40295C1E));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// スポットのミニ建物(どうぶつの森風の丸いシルエット)。
class _MiniSpotPainter extends CustomPainter {
  const _MiniSpotPainter({required this.id, required this.selected});
  final String id;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height - 6);
    // 落ち影
    canvas.drawOval(Rect.fromCenter(center: c, width: 52, height: 9),
        Paint()..color = const Color(0x22304018));
    // 選択中はやわらかい光の輪
    if (selected) {
      canvas.drawOval(
          Rect.fromCenter(center: c.translate(0, -14), width: 72, height: 48),
          Paint()..color = const Color(0x2EFFFFFF));
    }
    switch (id) {
      case 'port':
        _tent(canvas, c);
      default:
        _house(canvas, c, _roofOf(id), awning: id == 'bakery');
    }
  }

  Color _roofOf(String id) => switch (id) {
        'bakery' => const Color(0xFFC98A6B),
        'cafe' => const Color(0xFFE8A0A8),
        'studio' => const Color(0xFFA98BC6),
        'museum' => const Color(0xFF7FA3CB),
        'grocery' => const Color(0xFF8CC178),
        _ => const Color(0xFFC98A6B),
      };

  void _house(Canvas canvas, Offset base, Color roof, {bool awning = false}) {
    final wall =
        Rect.fromCenter(center: base.translate(0, -12), width: 40, height: 24);
    canvas.drawRRect(
        RRect.fromRectAndRadius(wall, const Radius.circular(5)),
        Paint()..color = const Color(0xFFF6EBD3));
    final roofPath = Path()
      ..moveTo(wall.left - 6, wall.top + 2)
      ..lineTo(wall.left + 10, wall.top - 13)
      ..lineTo(wall.right - 10, wall.top - 13)
      ..lineTo(wall.right + 6, wall.top + 2)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roof);
    if (awning) {
      for (var i = 0; i < 4; i++) {
        final p = Paint()
          ..color = i.isEven ? Colors.white : const Color(0xFFE8A0A8);
        final sx = wall.left + 3 + i * 8.6;
        canvas.drawRect(Rect.fromLTWH(sx, wall.top + 1, 8.6, 4), p);
        canvas.drawArc(
            Rect.fromLTWH(sx, wall.top + 3, 8.6, 5), 0, 3.1416, true, p);
      }
    }
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromCenter(
                center: base.translate(0, -7), width: 9, height: 12),
            topLeft: const Radius.circular(4.5),
            topRight: const Radius.circular(4.5)),
        Paint()..color = const Color(0xFF9A6B45));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base.translate(-12, -13), width: 8, height: 7),
            const Radius.circular(2.5)),
        Paint()..color = const Color(0xFFBDDCF2));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base.translate(12, -13), width: 8, height: 7),
            const Radius.circular(2.5)),
        Paint()..color = const Color(0xFFBDDCF2));
  }

  void _tent(Canvas canvas, Offset base) {
    // ストライプのテント(イベント会場)
    final wall = Rect.fromCenter(
        center: base.translate(0, -9), width: 34, height: 14);
    canvas.drawRRect(
        RRect.fromRectAndRadius(wall, const Radius.circular(4)),
        Paint()..color = const Color(0xFFF6EBD3));
    final roof = Path()
      ..moveTo(base.dx - 20, base.dy - 15)
      ..quadraticBezierTo(base.dx, base.dy - 34, base.dx + 20, base.dy - 15)
      ..close();
    canvas.save();
    canvas.clipPath(roof);
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
          Rect.fromLTWH(base.dx - 20 + i * 8, base.dy - 34, 8, 20),
          Paint()
            ..color = i.isEven ? const Color(0xFFDF6A5E) : Colors.white);
    }
    canvas.restore();
    // 入口と旗
    canvas.drawPath(
        Path()
          ..moveTo(base.dx - 5, base.dy - 2)
          ..lineTo(base.dx, base.dy - 12)
          ..lineTo(base.dx + 5, base.dy - 2)
          ..close(),
        Paint()..color = const Color(0xFF8E5B52));
    canvas.drawLine(
        Offset(base.dx, base.dy - 27),
        Offset(base.dx, base.dy - 33),
        Paint()
          ..color = const Color(0xFF9A6B45)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy - 33)
          ..lineTo(base.dx + 7, base.dy - 30.5)
          ..lineTo(base.dx, base.dy - 28)
          ..close(),
        Paint()..color = const Color(0xFFF6D96B));
  }

  @override
  bool shouldRepaint(covariant _MiniSpotPainter old) =>
      old.selected != selected || old.id != id;
}
