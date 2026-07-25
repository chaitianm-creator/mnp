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
  static const _nextPortrait = Rect.fromLTRB(0.17, 0.88, 0.83, 0.98);
  static const _skipPortrait = Rect.fromLTRB(0.78, 0.010, 0.995, 0.062);
  static const _nextLandscape = Rect.fromLTRB(0.29, 0.855, 0.71, 0.98);
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
          // 画像内ボタン「つぎへ」→ みぽりん先生との出会いへ
          tapZone(nextZone, 'つぎへ', () => context.go('/meeting')),
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
