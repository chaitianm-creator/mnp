import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';

/// SC-02 タイトル画面。
/// 支給されたタイトルイラスト(縦: スマホ / 横: タブレット)を全画面表示する。
/// 「つぎへ」「スキップ」は画像内に描かれたボタンをそのまま使い、
/// その位置に透明なタップ領域(Semanticsラベル付き)を重ねる。
/// 画像全体の表示を優先(BoxFit.contain)。余白はイラストの海の青で埋める。
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  // アセット実寸(タップ領域の座標計算に使用)
  static const _portraitSize = Size(853, 1844);
  static const _landscapeSize = Size(1448, 1086);

  // 画像内ボタンの位置(画像に対する割合: L,T,R,B)
  // 「つぎへ」は画像内ボタンの真上に同デザインの「スタート」ボタンを重ねて置き換える
  static const _nextPortrait = Rect.fromLTRB(0.185, 0.884, 0.815, 0.972);
  static const _skipPortrait = Rect.fromLTRB(0.78, 0.010, 0.995, 0.062);
  static const _nextLandscape = Rect.fromLTRB(0.305, 0.868, 0.700, 0.970);
  static const _skipLandscape = Rect.fromLTRB(0.865, 0.012, 0.995, 0.088);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // レターボックス帯はイラストの海の青と馴染む色
      backgroundColor: const Color(0xFF1B6BD6),
      body: LayoutBuilder(builder: (context, c) {
        final isLandscape = c.maxWidth > c.maxHeight;
        final asset = isLandscape
            ? 'assets/images/title_landscape.webp'
            : 'assets/images/title_portrait.webp';
        final imgSize = isLandscape ? _landscapeSize : _portraitSize;
        final nextZone = isLandscape ? _nextLandscape : _nextPortrait;
        final skipZone = isLandscape ? _skipLandscape : _skipPortrait;

        // BoxFit.contain の表示矩形を計算(タップ領域を画像に正確に合わせるため)
        final aspect = imgSize.width / imgSize.height;
        final double dw, dh;
        if (c.maxWidth / c.maxHeight > aspect) {
          dh = c.maxHeight;
          dw = dh * aspect;
        } else {
          dw = c.maxWidth;
          dh = dw / aspect;
        }
        final left = (c.maxWidth - dw) / 2;
        final top = (c.maxHeight - dh) / 2;

        Widget tapZone(Rect f, String label, VoidCallback onTap) => Positioned(
              left: left + f.left * dw,
              top: top + f.top * dh,
              width: (f.right - f.left) * dw,
              height: (f.bottom - f.top) * dh,
              child: Semantics(
                button: true,
                label: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                ),
              ),
            );

        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            width: dw,
            height: dh,
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          // 「スタート」→ みぽりん先生との出会いへ
          // (画像内の「つぎへ」ボタンの上に同デザインのボタンを重ねて文言を差し替え)
          Positioned(
            left: left + nextZone.left * dw,
            top: top + nextZone.top * dh,
            width: (nextZone.right - nextZone.left) * dw,
            height: (nextZone.bottom - nextZone.top) * dh,
            child: _StartButton(onTap: () => context.go('/meeting')),
          ),
          // 画像内ボタン「スキップ」→ 物語を飛ばして入団手続きへ
          tapZone(skipZone, 'スキップ', () => context.go('/student-register')),
          // 先生・スタッフ用の控えめな導線(最下端の細い帯のみ)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => context.go('/teacher-login'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: Colors.white.withOpacity(0.55),
                  child: Text('先生・スタッフの方はこちら',
                      style: KdTheme.dot(size: 10, color: KdColors.ink900)
                          .copyWith(decoration: TextDecoration.underline)),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// 画像内の「つぎへ」ボタンと同じ意匠のスタートボタン。
/// 濃ピンクの角丸 + 内側の白フチ + 白抜き太字(イラストのボタンを覆い隠す)。
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'スタート',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(builder: (context, c) {
          final r = c.maxHeight * 0.32;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEE5A77),
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: const Color(0xFFB93B55), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xFF8E2C41), offset: Offset(0, 3)),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r - 4),
                border: Border.all(
                    color: Colors.white.withOpacity(0.45), width: 1.6),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'スタート ▶',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: c.maxHeight * 0.42,
                        shadows: const [
                          Shadow(color: Color(0xFF8E2C41), offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
