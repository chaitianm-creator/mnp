import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// SC-02 タイトル/オープニング(PRO NAVI ワイヤーフレーム5a/5b準拠)。
/// 全画面イラスト(島・お店・キャラクター=コード描画のドット絵)の上に、
/// ようこそチップ+ロゴカード+コピー+スタート+スタッフ導線を重ねる。
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final spriteW = (size.width * 0.20).clamp(64.0, 110.0);

    return Scaffold(
      backgroundColor: pnBg,
      body: Stack(children: [
        // ── 背景イラスト(村の道・家々) ──
        buildStoryScene('village_path_plain'),
        // ── キャラクター(みぽりん先生 & 主人公) ──
        Positioned(
          left: size.width * 0.07,
          bottom: size.height * 0.20,
          child: IgnorePointer(
            child: PixelSprite(
                rows: miporinRows(0),
                palette: miporinPalette,
                width: spriteW),
          ),
        ),
        Positioned(
          right: size.width * 0.07,
          bottom: size.height * 0.19,
          child: IgnorePointer(
            child: PixelSprite(
                rows: heroineFrontRows,
                palette: heroinePalette,
                width: spriteW * 0.92),
          ),
        ),
        // ── オーバーレイUI ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(children: [
              // スキップ(右上)
              Row(children: [
                const Spacer(),
                Material(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => context.go('/student-register'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pnLine),
                      ),
                      child: const Text('スキップ',
                          style: TextStyle(
                              color: pnSub,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
              const Spacer(flex: 2),
              // 中央: ようこそチップ + ロゴカード + コピー
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCFE3F2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFAFCBE4)),
                      ),
                      child: const Text('👑 ようこそ 👑',
                          style: TextStyle(
                              color: Color(0xFF44607A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 14),
                    // ロゴカード(ロゴ画像が用意できたら差し替え)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: pnLine),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x1A4A443A),
                              blurRadius: 14,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Text('実践デザイナー物語',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: pnInk,
                              fontSize: 30,
                              height: 1.4,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4C6D2).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                          'ここは、デザインの力で\nみんなの困りごとを解決する島。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF8E4A62),
                              fontSize: 14,
                              height: 1.7,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
              const Spacer(flex: 3),
              // スタート → オンボーディング(第1話)へ
              SizedBox(
                width: 300,
                height: 58,
                child: FilledButton(
                  onPressed: () => context.go('/story/ep1'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF2AFC1),
                    foregroundColor: const Color(0xFF8E4A62),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    textStyle: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  child: const Text('スタート ▶'),
                ),
              ),
              const SizedBox(height: 8),
              // 先生・スタッフ用の控えめな導線
              TextButton(
                onPressed: () => context.go('/teacher-login'),
                child: const Text('先生・スタッフの方はこちら',
                    style: TextStyle(
                        color: pnSub,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
