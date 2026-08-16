import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// お困りの村人「パン屋さん」練習ワークの一覧。
/// ①お困りごとヒアリング → ②デザインの方向性 → (③ワイヤー制作: 近日公開)
class WorksPage extends StatelessWidget {
  const WorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    const works = [
      (
        'STEP 1',
        'ヒアリング① お困りごと',
        'パン屋さんが何に困っているのか、チラシを作る目的やターゲットを聞いてみよう！',
        '/hearing',
        false,
      ),
      (
        'STEP 2',
        'ヒアリング② デザインの方向性',
        '参考チラシを見せながら、色・写真・雰囲気などデザインの方向性を一緒に決めよう！',
        '/hearing2',
        false,
      ),
      (
        'STEP 3',
        'ワイヤー制作',
        'ヒアリングした内容をもとに、チラシのワイヤーフレームを作ってみよう！',
        null,
        true,
      ),
    ];

    return Scaffold(
      backgroundColor: pnBg,
      appBar: AppBar(
        backgroundColor: pnBg,
        foregroundColor: pnInk,
        elevation: 0,
        title: const Text('お困りの村人「パン屋さん」',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── 導入 ──
                PnPanel(
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: pnYellow, shape: BoxShape.circle),
                      child: PixelSprite(
                          rows: bakerRows, palette: bakerPalette, width: 40),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                          'パン屋さんのチラシ制作をお手伝いしよう！\n練習ワークを順番に進めてね。',
                          style: TextStyle(
                              color: pnInk,
                              fontSize: 13.5,
                              height: 1.6,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                for (final (step, title, desc, route, locked) in works) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: pnCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: locked ? pnLine : const Color(0xFFE8D48A),
                          width: locked ? 1 : 1.6),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: locked
                                    ? pnBg
                                    : pnYellow.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(step,
                                  style: TextStyle(
                                      color: locked ? pnSub : pnInk,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(title,
                                  style: TextStyle(
                                      color: locked ? pnSub : pnInk,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900)),
                            ),
                            if (locked)
                              const Icon(Icons.lock_rounded,
                                  size: 16, color: pnSub),
                          ]),
                          const SizedBox(height: 8),
                          Text(desc,
                              style: const TextStyle(
                                  color: pnSub,
                                  fontSize: 12.5,
                                  height: 1.6)),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: locked
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: pnBg,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      border: Border.all(color: pnLine),
                                    ),
                                    child: const Text('近日公開',
                                        style: TextStyle(
                                            color: pnSub,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800)),
                                  )
                                : FilledButton(
                                    onPressed: () => context.push(route!),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: pnGreen,
                                        foregroundColor: pnGreenInk),
                                    child: const Text('はじめる',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900)),
                                  ),
                          ),
                        ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
