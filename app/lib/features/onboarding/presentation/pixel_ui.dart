import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:design_kingdom/features/onboarding/data/story_repository.dart'
    show StoryChoice, StoryMission;
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart'
    show Px;

// ─────────────────────────────────────────────────────────────
// 16bit風ピクセルUI 共通コンポーネント。
//   PixelTheme / PixelPanel / PixelButton / PixelSpeechBubble /
//   PixelStoryHeader / PixelPageIndicator / PixelRoomBackground
// まずは第1話1ページ目(PixelStoryPageOne)で使用。
// アンチエイリアス・ぼかし・グラデーションは使わず、
// 角/枠/影/ハイライトをすべてドット単位(unit)で描く。
// ─────────────────────────────────────────────────────────────

/// デザイン定数(色・枠・余白・フォント・アニメ時間)。
class PixelTheme {
  PixelTheme._();

  // ── 基本色 ──
  static const navy = Color(0xFF1A2A52);
  static const navyDark = Color(0xFF10193A);
  static const navyEdge = Color(0xFF0B1128);
  static const gold = Color(0xFFC9A24B);
  static const goldLight = Color(0xFFF2D96B);
  static const goldDark = Color(0xFF8A6A3F);
  static const cream = Color(0xFFFDF6E5);
  static const creamShade = Color(0xFFEBDCBC);
  static const brown = Color(0xFF3A2C1A);
  static const brownMid = Color(0xFF6B4A2A);
  static const textYellow = Color(0xFFF6D96B);

  // ── ピンクボタン ──
  static const pink = Color(0xFFF0688C);
  static const pinkLight = Color(0xFFFFA9BE);
  static const pinkDark = Color(0xFFC24463);
  static const pinkDeep = Color(0xFF7E2A40);

  // ── 枠・角・影(すべて unit の倍数で扱う) ──
  static const double unit = 3; // 1ドットの論理px
  static const double cornerStep = unit; // 階段状の角: 2段 × unit
  static const double dropShadow = unit * 2; // 下影の高さ

  // ── 余白 ──
  static const double padPage = 14;
  static const double padPanelH = 18;
  static const double padPanelV = 10;

  // ── フォントサイズ ──
  static const double fontBadge = 16;
  static const double fontTitle = 16;
  static const double fontBubble = 21;
  static const double fontIndicator = 13;
  static const double fontButton = 20;

  // ── アニメーション時間(派手にしない) ──
  static const pageFade = Duration(milliseconds: 250);
  static const bubbleFloat = Duration(milliseconds: 2000);
  static const lampFlicker = Duration(milliseconds: 2600);
  static const buttonSink = Duration(milliseconds: 60);

  // ── レスポンシブ: PCでは中央寄せで最大幅 ──
  static const double maxContentWidth = 460;
}

/// 角が階段状(2段)のピクセル矩形を描く基本形。
void _stepped(Canvas canvas, Paint p, double x, double y, double w, double h,
    double s) {
  canvas.drawRect(Rect.fromLTWH(x + 2 * s, y, w - 4 * s, h), p);
  canvas.drawRect(Rect.fromLTWH(x + s, y + s, w - 2 * s, h - 2 * s), p);
  canvas.drawRect(Rect.fromLTWH(x, y + 2 * s, w, h - 4 * s), p);
}

/// ピクセルパネルの描画(枠1u + 任意の金枠 + ハイライト/内側影 + 下影 + 吹き出しの尻尾)。
class _PixelBoxPainter extends CustomPainter {
  const _PixelBoxPainter({
    required this.fill,
    required this.outline,
    this.highlight,
    this.innerShadow,
    this.dropShadow,
    this.frame,
    this.ornament,
    this.tail = false,
    this.pressed = false,
  });

  final Color fill;
  final Color outline;
  final Color? highlight; // 上/左の明るい縁
  final Color? innerShadow; // 下/右の暗い縁
  final Color? dropShadow; // パネルの下に落ちる影
  final Color? frame; // 外枠の内側に回す金枠
  final Color? ornament; // 四隅の飾り(金鋲)
  final bool tail; // 吹き出しの尻尾
  final bool pressed; // ボタン押下(2px沈む)

  @override
  void paint(Canvas canvas, Size size) {
    const u = PixelTheme.unit;
    final p = Paint();
    final w = size.width;
    final tailH = tail ? u * 5 : 0.0;
    final drop = dropShadow != null ? PixelTheme.dropShadow : 0.0;
    final boxTop = pressed ? drop : 0.0;
    final boxH = size.height - tailH - drop;

    // 下影(押下中は本体が重なって沈んで見える)
    if (dropShadow != null) {
      p.color = dropShadow!;
      _stepped(canvas, p, 0, drop, w, boxH, u);
    }

    // 外枠(濃色アウトライン)
    p.color = outline;
    _stepped(canvas, p, 0, boxTop, w, boxH, u);

    // 金枠(任意)
    var inset = u;
    if (frame != null) {
      p.color = frame!;
      _stepped(canvas, p, u, boxTop + u, w - 2 * u, boxH - 2 * u, u);
      inset = u * 2;
    }

    // 本体
    p.color = fill;
    _stepped(canvas, p, inset, boxTop + inset, w - 2 * inset, boxH - 2 * inset,
        u);

    // 上/左のハイライト(1ドット)
    if (highlight != null) {
      p.color = highlight!;
      canvas.drawRect(
          Rect.fromLTWH(inset + 2 * u, boxTop + inset, w - 2 * inset - 4 * u,
              u),
          p);
      canvas.drawRect(
          Rect.fromLTWH(inset, boxTop + inset + 2 * u, u,
              boxH - 2 * inset - 4 * u),
          p);
    }

    // 下/右の内側影(1ドット)
    if (innerShadow != null) {
      p.color = innerShadow!;
      canvas.drawRect(
          Rect.fromLTWH(inset + 2 * u, boxTop + boxH - inset - u,
              w - 2 * inset - 4 * u, u),
          p);
      canvas.drawRect(
          Rect.fromLTWH(w - inset - u, boxTop + inset + 2 * u, u,
              boxH - 2 * inset - 4 * u),
          p);
    }

    // 四隅の飾り鋲(金) — ヘッダー用
    if (ornament != null) {
      for (final (ox, oy) in [
        (inset + u, boxTop + inset + u),
        (w - inset - 3 * u, boxTop + inset + u),
        (inset + u, boxTop + boxH - inset - 3 * u),
        (w - inset - 3 * u, boxTop + boxH - inset - 3 * u),
      ]) {
        p.color = PixelTheme.goldDark;
        canvas.drawRect(Rect.fromLTWH(ox, oy, 2 * u, 2 * u), p);
        p.color = ornament!;
        canvas.drawRect(Rect.fromLTWH(ox, oy, u, u), p);
      }
    }

    // 吹き出しの尻尾(階段状)
    if (tail) {
      final cx = w / 2;
      final tailTop = boxH - u;
      for (var i = 0; i < 4; i++) {
        p.color = outline;
        final half = (4 - i) * u;
        canvas.drawRect(
            Rect.fromLTWH(cx - half, tailTop + i * u, half * 2, u), p);
      }
      for (var i = 0; i < 3; i++) {
        p.color = fill;
        final half = (3 - i) * u;
        canvas.drawRect(
            Rect.fromLTWH(cx - half, tailTop + i * u, half * 2, u), p);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelBoxPainter old) =>
      old.fill != fill || old.pressed != pressed || old.tail != tail;
}

/// クリーム色のピクセルパネル(汎用)。
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.fill = PixelTheme.cream,
    this.outline = PixelTheme.brown,
    this.highlight = Colors.white,
    this.innerShadow = PixelTheme.creamShade,
    this.dropShadow,
    this.frame,
    this.padding = const EdgeInsets.symmetric(
        horizontal: PixelTheme.padPanelH, vertical: PixelTheme.padPanelV),
  });

  final Widget child;
  final Color fill;
  final Color outline;
  final Color? highlight;
  final Color? innerShadow;
  final Color? dropShadow;
  final EdgeInsets padding;
  final Color? frame;

  @override
  Widget build(BuildContext context) {
    // 下影のぶんだけ本文の下余白を足す(影の上に文字が乗らないように)
    final pad = dropShadow == null
        ? padding
        : padding.copyWith(bottom: padding.bottom + PixelTheme.dropShadow);
    return CustomPaint(
      painter: _PixelBoxPainter(
        fill: fill,
        outline: outline,
        highlight: highlight,
        innerShadow: innerShadow,
        dropShadow: dropShadow,
        frame: frame,
      ),
      child: Padding(padding: pad, child: child),
    );
  }
}

/// 左上のページ番号「1 / 15」。
class PixelPageIndicator extends StatelessWidget {
  const PixelPageIndicator({super.key, required this.page, required this.total});
  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      dropShadow: PixelTheme.navyEdge,
      child: Text('$page / $total',
          style: const TextStyle(
              color: PixelTheme.brown,
              fontSize: PixelTheme.fontIndicator,
              height: 1.1,
              fontWeight: FontWeight.w900)),
    );
  }
}

/// 話タイトル(濃紺 + 金ピクセル枠 + 四隅飾り)。
class PixelStoryHeader extends StatelessWidget {
  const PixelStoryHeader({super.key, this.badge, this.title});
  final String? badge;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PixelBoxPainter(
        fill: PixelTheme.navy,
        outline: PixelTheme.navyEdge,
        frame: PixelTheme.gold,
        highlight: Color(0xFF32447C),
        innerShadow: Color(0xFF121D3E),
        dropShadow: PixelTheme.navyEdge,
        ornament: PixelTheme.goldLight,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 12 + PixelTheme.dropShadow),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (badge != null)
            Text(badge!,
                style: const TextStyle(
                    color: PixelTheme.textYellow,
                    fontSize: PixelTheme.fontBadge,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                          color: PixelTheme.navyEdge, offset: Offset(0, 2)),
                    ])),
          if (badge != null && title != null) const SizedBox(height: 3),
          if (title != null)
            Text(title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: PixelTheme.fontTitle,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                          color: PixelTheme.navyEdge, offset: Offset(0, 2)),
                    ])),
        ]),
      ),
    );
  }
}

/// 吹き出し(クリーム地 + 濃茶の階段枠 + 尻尾)。ゆっくり±2px浮遊する。
class PixelSpeechBubble extends StatefulWidget {
  const PixelSpeechBubble({super.key, required this.text});
  final String text;

  @override
  State<PixelSpeechBubble> createState() => _PixelSpeechBubbleState();
}

class _PixelSpeechBubbleState extends State<PixelSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: PixelTheme.bubbleFloat);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        // ±2px、ドット単位で段階的に動かす(なめらか禁止)
        final wave = math.sin(_float.value * math.pi * 2);
        final dy = (wave * 2).roundToDouble();
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: CustomPaint(
        painter: const _PixelBoxPainter(
          fill: PixelTheme.cream,
          outline: PixelTheme.brown,
          highlight: Colors.white,
          innerShadow: PixelTheme.creamShade,
          tail: true,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 12 + 15),
          child: Text(widget.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: PixelTheme.brown,
                  fontSize: PixelTheme.fontBubble,
                  height: 1.4,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// ピンクのピクセルボタン(押すと2px沈む)。タップ領域は48px以上。
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticsLabel,
    this.showTriangle = true,
  });

  final String label;
  final VoidCallback onTap;
  final String? semanticsLabel;
  final bool showTriangle; // 左の小さな黄色三角

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: CustomPaint(
              painter: _PixelBoxPainter(
                fill: PixelTheme.pink,
                outline: PixelTheme.pinkDeep,
                frame: PixelTheme.gold,
                highlight: PixelTheme.pinkLight,
                innerShadow: PixelTheme.pinkDark,
                dropShadow: PixelTheme.pinkDeep,
                pressed: _pressed,
              ),
              child: AnimatedContainer(
                duration: PixelTheme.buttonSink,
                padding: EdgeInsets.only(
                  top: 10 + (_pressed ? PixelTheme.dropShadow : 0),
                  bottom: 10 +
                      PixelTheme.dropShadow -
                      (_pressed ? PixelTheme.dropShadow : 0),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showTriangle) ...[
                        const CustomPaint(
                            size: Size(11, 14), painter: _TrianglePainter()),
                        const SizedBox(width: 9),
                      ],
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: PixelTheme.fontButton,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                    color: PixelTheme.pinkDeep,
                                    offset: Offset(0, 2)),
                              ])),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 右向きの小さな黄色ピクセル三角(▶)。
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = PixelTheme.goldLight;
    final u = size.height / 7;
    // 列ごとに高さを減らして階段状の三角にする
    for (var col = 0; col < 4; col++) {
      canvas.drawRect(
          Rect.fromLTWH(col * u, col * u, u, size.height - 2 * col * u), p);
    }
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// 寝室の背景(高密度16bitドット絵)。暖色カスタムパレット(量子化なし)。
// ─────────────────────────────────────────────────────────────

/// 寝室の状態(1〜3ページ目で共有)。
enum RoomMode {
  sleep, // p1: すやすや眠っている
  phone, // p2: 部屋が暗くなり、スマホが光る
  awake, // p3: 起き上がってスマホを見ている
}

/// 夜の寝室。ランプがかすかに明滅する。
class PixelRoomBackground extends StatefulWidget {
  const PixelRoomBackground({super.key, this.mode = RoomMode.sleep});
  final RoomMode mode;

  @override
  State<PixelRoomBackground> createState() => _PixelRoomBackgroundState();
}

class _PixelRoomBackgroundState extends State<PixelRoomBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: PixelTheme.lampFlicker);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_flicker.isAnimating) {
      _flicker.repeat();
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _RoomPainter(_flicker, widget.mode), size: Size.infinite);
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.flicker, this.mode) : super(repaint: flicker);
  final Animation<double> flicker;
  final RoomMode mode;

  // ── 部屋のパレット(同系色3〜5段階) ──
  static const wall = Color(0xFFEED9B8);
  static const wallLight = Color(0xFFF7E6C9);
  static const wallShade = Color(0xFFE0C49E);
  static const wallPattern = Color(0xFFE4CBA6);
  static const base1 = Color(0xFFD2A76B);
  static const base2 = Color(0xFFB98A55);
  static const base3 = Color(0xFF8F6538);
  static const floor1 = Color(0xFFD9A76E);
  static const floor2 = Color(0xFFC98F5A);
  static const floor3 = Color(0xFFB07845);
  static const floorSeam = Color(0xFF8A5A30);
  static const wood1 = Color(0xFFD9A76E);
  static const wood2 = Color(0xFFB07845);
  static const wood3 = Color(0xFF8A5A30);
  static const wood4 = Color(0xFF6E4522);
  static const sky1 = Color(0xFF1B2650);
  static const sky2 = Color(0xFF27356B);
  static const sky3 = Color(0xFF33437F);
  static const star = Color(0xFFF6E8A8);
  static const moon1 = Color(0xFFF6E7A0);
  static const moon2 = Color(0xFFE0C670);
  static const curt1 = Color(0xFFFBC2CF);
  static const curt2 = Color(0xFFF2A0B4);
  static const curt3 = Color(0xFFD97A94);
  static const curt4 = Color(0xFFB95672);
  static const quilt1 = Color(0xFFFBD3DC);
  static const quilt2 = Color(0xFFF4A8BC);
  static const quilt3 = Color(0xFFE87F9C);
  static const quilt4 = Color(0xFFCF6E8C);
  static const pillow1 = Color(0xFFFBF2DC);
  static const pillow2 = Color(0xFFEBDCB8);
  static const ink = Color(0xFF3A2C1A);

  @override
  void paint(Canvas canvas, Size size) {
    const vw = 160.0;
    final u = size.width / vw;
    final vh = size.height / u;
    final px = Px(canvas, u, quantize: false);
    final rng = math.Random(7);
    final wallH = vh * 0.58;

    _paintWall(px, rng, vw, wallH);
    _paintWindow(px, rng, vw, wallH);
    _paintBookshelf(px, rng, wallH);
    _paintFloor(px, rng, vw, wallH, vh);
    _paintRug(px, vw, wallH, vh);
    _paintNightstand(px, vw, wallH);
    _paintPlant(px, vw, wallH);
    _paintBed(px, rng, vw, wallH, vh);
    _paintProps(px, wallH, vh);
    if (mode == RoomMode.phone) {
      // 部屋を薄暗くして、スマホの光だけが目立つ
      px.r(0, 0, vw, vh, const Color(0x4A16204A));
      _paintPhone(px, vw, wallH);
    }
  }

  /// 布団の上で光るスマホ(p2)。
  void _paintPhone(Px px, double vw, double wallH) {
    final headTop = wallH - 26;
    final gx = vw / 2 + 17, gy = headTop + 33;
    const glowA = Color(0x2E9FD8FF);
    const glowB = Color(0x1E9FD8FF);
    px.oval(gx + 3, gy + 5, 16, 12, glowB);
    px.oval(gx + 3, gy + 5, 10, 8, glowA);
    // 本体(枠 + 画面)
    px.r(gx - 1, gy - 1, 9, 13, ink);
    px.r(gx, gy, 7, 11, const Color(0xFF2A3350));
    px.r(gx + 1, gy + 1, 5, 8, const Color(0xFFBFE8FF));
    px.r(gx + 1, gy + 1, 5, 2, const Color(0xFFE4F4FF));
    px.r(gx + 2, gy + 4, 3, 1, const Color(0xFF7FB6E0));
    px.r(gx + 2, gy + 6, 3, 1, const Color(0xFF7FB6E0));
    // 光のきらめき
    px.sparkle(gx - 5, gy - 4, 2, const Color(0xFFD9F1FF));
    px.sparkle(gx + 11, gy + 1, 1, const Color(0xFFD9F1FF));
    px.sparkle(gx + 8, gy - 6, 1, const Color(0xFFBFE8FF));
  }

  void _paintWall(Px px, math.Random rng, double vw, double wallH) {
    px.r(0, 0, vw, wallH, wall);
    // 上部はほんの少し暗く(夜の空気感を2段で)
    px.r(0, 0, vw, wallH * 0.16, wallShade);
    px.r(0, wallH * 0.16, vw, wallH * 0.05, wallPattern);
    // 薄いひし形の壁紙模様
    for (var y = 6; y < wallH - 8; y += 13) {
      final off = ((y ~/ 13) % 2) * 7;
      for (var x = 3 + off; x < vw - 2; x += 14) {
        px.dot(x, y, wallPattern);
        px.dot(x - 1, y + 1, wallPattern);
        px.dot(x + 1, y + 1, wallPattern);
        px.dot(x, y + 2, wallPattern);
        px.dot(x, y + 1, wallLight);
      }
    }
    // 壁のむら
    px.noise(0, 0, vw.toInt(), wallH.toInt() - 6, [wallLight, wallShade], 90,
        rng);
    // 幅木(3段)
    px.r(0, wallH - 5, vw, 2, base1);
    px.r(0, wallH - 3, vw, 2, base2);
    px.r(0, wallH - 1, vw, 1, base3);
  }

  void _paintWindow(Px px, math.Random rng, double vw, double wallH) {
    final wx = 52.0, wy = wallH * 0.09;
    final ww = 56.0, wh = wallH * 0.46;
    // 窓枠(外側の濃い縁 → 木枠2段)
    px.r(wx - 5, wy - 5, ww + 10, wh + 10, wood4);
    px.r(wx - 4, wy - 4, ww + 8, wh + 8, wood2);
    px.r(wx - 2, wy - 2, ww + 4, wh + 4, wood3);
    // 夜空(横帯3段)
    px.r(wx, wy, ww, wh, sky1);
    px.r(wx, wy + wh * 0.5, ww, wh * 0.3, sky2);
    px.r(wx, wy + wh * 0.8, ww, wh * 0.2, sky3);
    // 星
    for (var i = 0; i < 22; i++) {
      final sx = wx + 2 + rng.nextInt(ww.toInt() - 4);
      final sy = wy + 2 + rng.nextInt((wh * 0.75).toInt());
      px.dot(sx, sy, i % 3 == 0 ? Colors.white : star);
    }
    px.sparkle(wx + 10, wy + wh * 0.2, 2, star);
    px.sparkle(wx + ww - 12, wy + wh * 0.55, 2, star);
    // 月(欠けと影を2段で)
    final mx = wx + ww - 16, my = wy + wh * 0.24;
    px.oval(mx, my, 7, 7, moon1);
    px.oval(mx - 3, my - 2, 5, 5, moon2);
    px.oval(mx - 4, my - 3, 4, 4, sky1);
    px.dot(mx + 2, my + 3, moon2);
    px.dot(mx + 4, my - 1, moon2);
    // 窓の桟(十字)
    px.r(wx + ww / 2 - 1, wy, 2, wh, wood2);
    px.r(wx, wy + wh / 2 - 1, ww, 2, wood2);
    // 窓の下枠(出っぱり)
    px.r(wx - 7, wy + wh + 5, ww + 14, 3, wood1);
    px.r(wx - 7, wy + wh + 8, ww + 14, 1, wood4);
    // カーテンレール
    px.r(wx - 12, wy - 9, ww + 24, 2, wood3);
    px.dot(wx - 13, wy - 9, wood4);
    px.dot(wx + ww + 12, wy - 9, wood4);
    // カーテン(左右、縦の折りひだを3段で)
    for (final left in [true, false]) {
      final cx = left ? wx - 10 : wx + ww - 4;
      px.r(cx, wy - 7, 14, wh * 0.94, curt2);
      for (var i = 0; i < 3; i++) {
        px.r(cx + 2 + i * 4, wy - 7, 1, wh * 0.94, curt3);
        px.r(cx + 3 + i * 4, wy - 7, 1, wh * 0.94, curt1);
      }
      px.r(cx, wy - 7 + wh * 0.94 - 2, 14, 2, curt4);
      // 裾のスカラップ(波)
      for (var i = 0; i < 3; i++) {
        px.oval(cx + 2 + i * 5, wy - 7 + wh * 0.94, 2.6, 2, curt2);
      }
      // タッセル(結び)
      final ty = wy + wh * 0.52;
      px.r(cx - 1, ty, 16, 3, curt4);
      px.dot(cx + 6, ty + 1, PixelTheme.goldLight);
    }
    // 上飾り(バランス)
    px.r(wx - 12, wy - 7, ww + 24, 4, curt3);
    for (var i = 0; i < 8; i++) {
      px.oval(wx - 9 + i * 10, wy - 3, 4, 2.4, curt3);
      px.oval(wx - 9 + i * 10, wy - 4, 3, 1.6, curt1);
    }
  }

  void _paintBookshelf(Px px, math.Random rng, double wallH) {
    const bx = 5.0, bw = 28.0;
    final bh = wallH * 0.42;
    final by = wallH - bh + 3;
    // 外枠
    px.r(bx - 1, by - 1, bw + 2, bh + 2, wood4);
    px.r(bx, by, bw, bh, wood2);
    px.r(bx + 1, by + 1, bw - 2, 1, wood1);
    // 3段の棚と本
    const spineColors = [
      Color(0xFFD95C5C),
      Color(0xFF5C7ED9),
      Color(0xFF6FAF62),
      Color(0xFFE8C25A),
      Color(0xFF9C6FC7),
      Color(0xFFE08A4E),
    ];
    for (var s = 0; s < 3; s++) {
      final sy = by + 3 + s * ((bh - 6) / 3);
      final sh = (bh - 6) / 3 - 2;
      px.r(bx + 2, sy, bw - 4, sh, wood4); // 棚の奥
      var xx = bx + 3.0;
      var i = 0;
      while (xx < bx + bw - 6) {
        final bwd = 3 + rng.nextInt(2);
        final bht = sh - 1 - rng.nextInt(2);
        final c = spineColors[(s * 3 + i) % spineColors.length];
        px.r(xx, sy + sh - bht, bwd.toDouble(), bht, c);
        px.r(xx, sy + sh - bht, 1, bht, Color.lerp(c, Colors.white, 0.35)!);
        px.dot(xx + 1, sy + sh - bht + 2, Color.lerp(c, ink, 0.4)!);
        xx += bwd + 1;
        i++;
      }
      px.r(bx + 2, sy + sh, bw - 4, 2, wood1); // 棚板
      px.r(bx + 2, sy + sh + 1, bw - 4, 1, wood3);
    }
    // 上に小物(目覚まし時計)
    px.r(bx + 8, by - 7, 8, 6, const Color(0xFFE87F9C));
    px.r(bx + 9, by - 6, 6, 4, pillow1);
    px.dot(bx + 11, by - 5, ink);
    px.dot(bx + 12, by - 4, ink);
    px.dot(bx + 9, by - 8, quilt4);
    px.dot(bx + 14, by - 8, quilt4);
  }

  void _paintFloor(Px px, math.Random rng, double vw, double wallH, double vh) {
    final fh = vh - wallH;
    px.r(0, wallH, vw, fh, floor2);
    // 横板(1枚9ドット) + 木目
    var row = 0;
    for (var y = wallH; y < vh; y += 9, row++) {
      px.r(0, y, vw, 1, floor1); // 板の上端ハイライト
      px.r(0, y + 8, vw, 1, floorSeam); // 板の継ぎ目
      // 縦の継ぎ目(互い違い・控えめに)
      final off = (row % 2) * 32;
      for (var x = 18.0 + off; x < vw; x += 64) {
        px.r(x, y + 1, 1, 7, floor3);
      }
      // 木目の短い線
      for (var i = 0; i < 4; i++) {
        final gx = rng.nextInt(vw.toInt() - 8).toDouble();
        px.r(gx, y + 2 + rng.nextInt(5), 3 + rng.nextInt(4).toDouble(), 1,
            rng.nextBool() ? floor3 : floor1);
      }
      // 節
      if (row % 2 == 1) {
        final kx = 14 + rng.nextInt(vw.toInt() - 28).toDouble();
        px.oval(kx, y + 4, 2, 1.4, floor3);
        px.dot(kx, y + 4, floorSeam);
      }
    }
    // 手前(下端)を1段暗くして奥行き
    px.r(0, vh - 5, vw, 5, floor3);
    px.noise(0, vh - 5, vw.toInt(), 5, [floor2, floorSeam], 40, rng);
  }

  void _paintRug(Px px, double vw, double wallH, double vh) {
    final cy = wallH + (vh - wallH) * 0.62;
    const rx = 52.0;
    final ry = (vh - wallH) * 0.30;
    px.oval(vw / 2, cy, rx, ry, const Color(0xFFE8A88C));
    px.oval(vw / 2, cy, rx - 4, ry - 2.6, const Color(0xFFD98A72));
    px.oval(vw / 2, cy, rx - 9, ry - 5.4, const Color(0xFFE8A88C));
    // ふち飾りのドット
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2;
      px.dot(vw / 2 + math.cos(a) * (rx - 6.5),
          cy + math.sin(a) * (ry - 4), const Color(0xFFFBE0CE));
    }
  }

  void _paintNightstand(Px px, double vw, double wallH) {
    final nx = vw - 34, ny = wallH - 10;
    // 台(3段の陰影 + 引き出し)
    px.r(nx - 1, ny - 1, 24, 21, wood4);
    px.r(nx, ny, 22, 19, wood2);
    px.r(nx, ny, 22, 2, wood1);
    px.r(nx + 2, ny + 5, 18, 8, wood3);
    px.r(nx + 3, ny + 6, 16, 6, wood2);
    px.dot(nx + 10, ny + 8, wood4); // 取っ手
    px.dot(nx + 11, ny + 8, wood1);
    px.r(nx, ny + 17, 22, 2, wood4);
    // 脚
    px.r(nx + 1, ny + 19, 3, 3, wood4);
    px.r(nx + 18, ny + 19, 3, 3, wood4);
    // ランプ(明滅: 2段階で切り替え)
    final lit = flicker.value < 0.82 || flicker.value > 0.94;
    final lx = nx + 11.0, ly = ny - 14;
    final glow1 = lit ? const Color(0x2EFFE9A0) : const Color(0x1FFFE9A0);
    final glow2 = lit ? const Color(0x1FFFE9A0) : const Color(0x14FFE9A0);
    px.oval(lx, ly + 3, lit ? 17 : 15, lit ? 13 : 11, glow2);
    px.oval(lx, ly + 3, lit ? 11 : 9, lit ? 8 : 7, glow1);
    // 傘(3段) + 支柱 + 台座
    px.tri(lx, ly - 6, lx - 7, ly + 3, lx + 7, ly + 3,
        lit ? const Color(0xFFFBDA8C) : const Color(0xFFF0CC74));
    px.r(lx - 7, ly + 2, 14, 1, const Color(0xFFD8AE56));
    px.r(lx - 3, ly - 5, 2, 2, const Color(0xFFFDEBB4));
    px.r(lx - 1, ly + 3, 2, 8, wood3);
    px.r(lx - 4, ly + 11, 8, 2, wood4);
    px.dot(lx - 4, ly + 10, wood2);
  }

  void _paintPlant(Px px, double vw, double wallH) {
    final gx = vw - 12, gy = wallH + 9;
    // 鉢(2段)
    px.r(gx - 6, gy, 12, 3, const Color(0xFFC97A4A));
    px.tri(gx - 5, gy + 3, gx + 5, gy + 3, gx, gy + 10,
        const Color(0xFFA85C32));
    px.r(gx - 5, gy + 3, 10, 4, const Color(0xFFA85C32));
    px.r(gx - 5, gy + 3, 10, 1, const Color(0xFF8A4626));
    // 葉(3色)
    const leaf1 = Color(0xFF77B562);
    const leaf2 = Color(0xFF5E9B4E);
    const leaf3 = Color(0xFF477E3A);
    px.oval(gx, gy - 8, 7, 7, leaf2);
    px.oval(gx - 4, gy - 5, 4, 4, leaf3);
    px.oval(gx + 3, gy - 11, 4, 4, leaf1);
    px.oval(gx - 2, gy - 13, 3, 3, leaf2);
    px.dot(gx + 1, gy - 9, leaf1);
    px.dot(gx - 3, gy - 10, leaf1);
    px.r(gx - 1, gy - 4, 1, 5, leaf3);
  }

  void _paintBed(Px px, math.Random rng, double vw, double wallH, double vh) {
    const bx = 44.0;
    const bw = 72.0;
    final headTop = wallH - 26;
    final bedBottom = wallH + (vh - wallH) * 0.58;
    // 床への落ち影(2段)
    px.oval(vw / 2, bedBottom + 4, bw / 2 + 6, 5, const Color(0xFF9A6838));
    // ヘッドボード(木、3段 + 飾り玉)
    px.r(bx - 3, headTop - 1, bw + 6, 20, wood4);
    px.r(bx - 2, headTop, bw + 4, 18, wood2);
    px.r(bx - 2, headTop, bw + 4, 2, wood1);
    px.r(bx + 2, headTop + 4, bw - 4, 9, wood3);
    px.r(bx + 3, headTop + 5, bw - 6, 2, wood2);
    for (var i = 0; i < 5; i++) {
      px.r(bx + 6 + i * 15, headTop + 6, 2, 6, wood2);
    }
    px.oval(bx - 2, headTop - 1, 3, 3, wood1);
    px.oval(bx + bw + 2, headTop - 1, 3, 3, wood1);
    px.dot(bx - 3, headTop - 2, wallLight);
    px.dot(bx + bw + 1, headTop - 2, wallLight);
    // マットレス側面
    px.r(bx - 2, headTop + 18, bw + 4, 4, pillow2);
    // 枕(クリーム、縁を1段暗く)
    px.oval(vw / 2, headTop + 22, 17, 7, ink);
    px.oval(vw / 2, headTop + 21, 16, 6, pillow1);
    px.r(bx + bw / 2 - 15, headTop + 23, 30, 3, pillow2);
    px.dot(bx + bw / 2 - 13, headTop + 19, Colors.white);
    // ── 掛け布団(ピンクのチェック柄) ──
    final qy = headTop + 30;
    final qh = bedBottom - qy;
    px.r(bx - 4, qy - 1, bw + 8, qh + 2, ink); // 輪郭
    px.r(bx - 3, qy, bw + 6, qh, quilt2);
    // ギンガムチェック(8ドット角、3色)
    for (var yy = 0; yy < qh; yy += 8) {
      for (var xx = 0; xx < bw + 6; xx += 8) {
        final cxx = (xx ~/ 8) % 2, cyy = (yy ~/ 8) % 2;
        final c = cxx == cyy ? (cxx == 0 ? quilt1 : quilt3) : quilt2;
        px.r(bx - 3 + xx, qy + yy, math.min(8, bw + 6 - xx),
            math.min(8, qh - yy), c);
      }
    }
    // 交点のステッチ
    for (var yy = 8; yy < qh; yy += 8) {
      for (var xx = 8; xx < bw + 6; xx += 8) {
        px.dot(bx - 3 + xx, qy + yy, Colors.white);
      }
    }
    // 体のふくらみ(左右に暗い折り影2段)
    px.r(bx - 3, qy, 2, qh, quilt4);
    px.r(bx + bw + 1, qy, 2, qh, quilt4);
    px.r(bx - 1, qy + 6, 2, qh - 10, quilt3);
    px.r(bx + bw - 1, qy + 6, 2, qh - 10, quilt3);
    // 布団の折り返し(上端の白いシーツ)
    px.r(bx - 3, qy, bw + 6, 4, pillow1);
    px.r(bx - 3, qy + 4, bw + 6, 1, pillow2);
    px.r(bx - 3, qy + 5, bw + 6, 1, quilt4);
    // すそのフリル
    for (var i = 0; i < 10; i++) {
      px.oval(bx - 1 + i * 8, bedBottom + 1, 4, 2.4, quilt3);
      px.oval(bx - 1 + i * 8, bedBottom, 3, 1.6, quilt2);
    }
    // フットボード
    px.r(bx - 4, bedBottom + 3, bw + 8, 2, wood4);
    px.r(bx - 3, bedBottom + 4, bw + 6, 4, wood2);
    px.r(bx - 3, bedBottom + 4, bw + 6, 1, wood1);
    px.r(bx - 3, bedBottom + 7, bw + 6, 1, wood4);
    // ── 女の子(ちび2頭身・輪郭つき) ──
    if (mode == RoomMode.awake) {
      _paintGirlSitting(px, vw / 2, headTop - 3);
    } else {
      _paintGirl(px, vw / 2, headTop + 15);
      // 布団の上に出た腕
      final ax = vw / 2 - 12;
      px.r(ax - 1, qy + 3, 10, 5, ink);
      px.r(ax, qy + 4, 8, 3, const Color(0xFFFFDDC2));
      px.r(ax, qy + 6, 8, 1, const Color(0xFFF0C09E));
    }
  }

  /// 眠る女の子の顔(スプライト風に1マスずつ)。
  void _paintGirl(Px px, double cx, double top) {
    const o = '#'; // 輪郭
    const rows = [
      '....######....',
      '..##HHHHHH##..',
      '.#HHLLHHHHHH#.',
      '.#HLHHHHHHHHH#',
      '#HHHHSSSSSHHH#',
      '#HHSSSSSSSSH#.',
      '#HSSESSSSESS#.',
      '#HSSSSSSSSSS#.',
      '.#SBSSSSSSBS#.',
      '.#SSSSMMSSSS#.',
      '..#SSSSSSSS#..',
      '...########...',
    ];
    const pal = {
      '#': ink,
      'H': Color(0xFF9C6234),
      'L': Color(0xFFC08A50),
      'S': Color(0xFFFFDDC2),
      'E': Color(0xFF5A3A24),
      'B': Color(0xFFF49AA8),
      'M': Color(0xFFE87F6E),
    };
    const cell = 1.6;
    final left = cx - rows[0].length * cell / 2;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final ch = rows[y][x];
        if (ch == '.') continue;
        px.r(left + x * cell, top + y * cell, cell, cell,
            ch == o ? ink : pal[ch]!);
      }
    }
    // 髪のハイライトと閉じたまつ毛の下がり
    px.dot(cx - 6, top + 3, const Color(0xFFD8A468));
    px.dot(cx - 4, top + 2, const Color(0xFFD8A468));
    px.dot(cx - 4.5, top + 11, const Color(0xFF5A3A24));
    px.dot(cx + 3.5, top + 11, const Color(0xFF5A3A24));
  }

  /// 起き上がってスマホを見る女の子(p3)。
  void _paintGirlSitting(Px px, double cx, double top) {
    const rows = [
      '....######....',
      '..##HHHHHH##..',
      '.#HHLLHHHHHH#.',
      '.#HLHHHHHHHHH#',
      '#HHHHSSSSSHHH#',
      '#HHSSSSSSSSH#.',
      '#HSWESSSSWES#.',
      '#HSSSSSSSSSS#.',
      '.#SBSSooSSBS#.',
      '.#SSSSSSSSSS#.',
      '..#SSSSSSSS#..',
      '..##PPPPPP##..',
      '.#PPPPPPPPPP#.',
      '#SSPPPPPPPPSS#',
      '#SSPPFFFFPPSS#',
      '.##SSFFFFSS##.',
      '..###PPPP###..',
    ];
    const pal = {
      '#': ink,
      'H': Color(0xFF9C6234),
      'L': Color(0xFFC08A50),
      'S': Color(0xFFFFDDC2),
      'W': Colors.white,
      'E': Color(0xFF5A3A24),
      'B': Color(0xFFF49AA8),
      'o': Color(0xFFC96A5E),
      'P': Color(0xFFF9C7D3),
      'F': Color(0xFFBFE8FF),
    };
    const cell = 1.6;
    // スマホの光(顔を下から照らす)
    px.oval(cx, top + 14.5 * cell, 9, 6, const Color(0x2E9FD8FF));
    final left = cx - rows[0].length * cell / 2;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final ch = rows[y][x];
        if (ch == '.') continue;
        px.r(left + x * cell, top + y * cell, cell, cell, pal[ch]!);
      }
    }
    // びっくりマーク(頭の上)
    px.r(cx + 13, top - 5, 1.6, 4.5, const Color(0xFFE8C25A));
    px.dot(cx + 13, top + 1.2, const Color(0xFFE8C25A));
    // パジャマの陰影
    px.r(cx - 8, top + 12.5 * cell, 1.6, 3, const Color(0xFFE8A9BC));
    px.r(cx + 6.4, top + 12.5 * cell, 1.6, 3, const Color(0xFFE8A9BC));
  }

  void _paintProps(Px px, double wallH, double vh) {
    // 床に積んだ本(左手前)
    final byy = wallH + (vh - wallH) * 0.72;
    px.r(12, byy + 4, 16, 4, const Color(0xFF5C7ED9));
    px.r(12, byy + 4, 16, 1, const Color(0xFF88A4E8));
    px.r(14, byy, 14, 4, const Color(0xFFD95C5C));
    px.r(14, byy, 14, 1, const Color(0xFFE89090));
    px.r(13, byy + 3, 16, 1, ink);
    px.r(11, byy + 7, 18, 1, ink);
    // スリッパ(右手前)
    final sx = 126.0, sy = wallH + (vh - wallH) * 0.78;
    for (var i = 0; i < 2; i++) {
      px.oval(sx + i * 12, sy, 5, 3, quilt3);
      px.oval(sx + i * 12, sy - 1, 4, 2, quilt2);
      px.dot(sx + i * 12, sy - 2, Colors.white);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// 会話ウィンドウ・選択肢・ミッションカード(全ページ共通)。
// ─────────────────────────────────────────────────────────────

/// ピンクの小さなラベルチップ(話者名・見出し)。
class _PixelChip extends StatelessWidget {
  const _PixelChip(this.text,
      {this.fontSize = 11,
      this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4)});
  final String text;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PixelBoxPainter(
        fill: PixelTheme.pink,
        outline: PixelTheme.pinkDeep,
        highlight: PixelTheme.pinkLight,
      ),
      child: Padding(
        padding: padding,
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                height: 1.2,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// RPG会話ウィンドウ(話者チップ + 本文)。
class PixelMessageWindow extends StatelessWidget {
  const PixelMessageWindow({super.key, this.speaker, required this.text});
  final String? speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      dropShadow: PixelTheme.navyEdge,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (speaker != null) ...[
          _PixelChip(speaker!),
          const SizedBox(height: 6),
        ],
        Text(text,
            style: const TextStyle(
                color: PixelTheme.brown,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 選択肢パネル(どう答える？)。
class PixelChoicePanel extends StatelessWidget {
  const PixelChoicePanel({
    super.key,
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
    return PixelPanel(
      dropShadow: PixelTheme.navyEdge,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _PixelChip(prompt,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6)),
            ),
            const SizedBox(height: 12),
            for (final c in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(c),
                  child: PixelPanel(
                    fill: Colors.white,
                    outline: PixelTheme.pinkDark,
                    highlight: const Color(0xFFFFE3EA),
                    innerShadow: const Color(0xFFF2D8DE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Text(c.correct ? '💗' : '💬',
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(c.text,
                            style: const TextStyle(
                                color: PixelTheme.brown,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),
              ),
            if (feedback != null)
              Text(feedback!,
                  style: const TextStyle(
                      color: PixelTheme.pinkDark,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700)),
          ]),
    );
  }
}

/// ピクセルのチェックボックス。
class _PixelCheckbox extends StatelessWidget {
  const _PixelCheckbox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: const Size(18, 18), painter: _CheckboxPainter(checked));
  }
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter(this.checked);
  final bool checked;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final u = size.width / 6;
    p.color = PixelTheme.brown;
    _stepped(canvas, p, 0, 0, size.width, size.height, u);
    p.color = checked ? const Color(0xFFFFE3EA) : PixelTheme.cream;
    _stepped(canvas, p, u, u, size.width - 2 * u, size.height - 2 * u, u);
    if (checked) {
      p.color = PixelTheme.pinkDark;
      // 階段状のチェックマーク
      canvas.drawRect(Rect.fromLTWH(1.2 * u, 3.0 * u, u, u), p);
      canvas.drawRect(Rect.fromLTWH(2.0 * u, 3.8 * u, u, u), p);
      canvas.drawRect(Rect.fromLTWH(2.8 * u, 3.0 * u, u, u), p);
      canvas.drawRect(Rect.fromLTWH(3.6 * u, 2.2 * u, u, u), p);
      canvas.drawRect(Rect.fromLTWH(4.4 * u, 1.4 * u, u, u), p);
    }
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) => old.checked != checked;
}

/// ミッション発生カード。
class PixelMissionCard extends StatelessWidget {
  const PixelMissionCard({super.key, required this.mission});
  final StoryMission mission;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      outline: PixelTheme.brown,
      frame: PixelTheme.gold,
      dropShadow: PixelTheme.navyEdge,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Column(children: [
        Transform.translate(
          offset: const Offset(0, -13),
          child: _PixelChip('ミッション発生！',
              fontSize: 16,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6)),
        ),
        Text(mission.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: PixelTheme.brown,
                fontSize: 19,
                height: 1.35,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final (i, item) in mission.items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              _PixelCheckbox(checked: i == 0),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item,
                    style: const TextStyle(
                        color: PixelTheme.brown,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _reward('⭐ 経験値', '+${mission.xp}'),
          const SizedBox(width: 10),
          _reward('🪙 コイン', '+${mission.coins}'),
        ]),
      ]),
    );
  }

  Widget _reward(String label, String value) => PixelPanel(
        fill: PixelTheme.brown,
        outline: const Color(0xFF241A0E),
        highlight: PixelTheme.brownMid,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: const TextStyle(
                  color: PixelTheme.goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// 第1話 1ページ目の完成画面。
// ─────────────────────────────────────────────────────────────

class PixelStoryPageOne extends StatelessWidget {
  const PixelStoryPageOne({
    super.key,
    required this.pageNo,
    required this.totalPages,
    this.headerBadge,
    this.headerTitle,
    this.bubble,
    required this.onNext,
  });

  final int pageNo;
  final int totalPages;
  final String? headerBadge;
  final String? headerTitle;
  final String? bubble;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    // 中央寄せ(PC最大幅)は呼び出し側(StoryPlayerPage)が全ページ共通で行う
    return Stack(children: [
      const Positioned.fill(child: PixelRoomBackground()),
      SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: PixelTheme.padPage),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Row(children: [
                  PixelPageIndicator(page: pageNo, total: totalPages),
                  const Spacer(),
                ]),
                const SizedBox(height: 10),
                if (headerBadge != null || headerTitle != null)
                  PixelStoryHeader(badge: headerBadge, title: headerTitle),
                const SizedBox(height: 18),
                if (bubble != null) PixelSpeechBubble(text: bubble!),
                const Spacer(),
                SizedBox(
                  width: 232,
                  child: PixelButton(label: '次へ', onTap: onNext),
                ),
                const SizedBox(height: 14),
              ]),
        ),
      ),
    ]);
  }
}
