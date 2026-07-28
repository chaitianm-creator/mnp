import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/features/onboarding/data/story_repository.dart';

/// オンボーディング/ストーリー再生(/story/:ep)。
/// 表紙「スタート」→ 1〜17ページを1枚ずつ表示 → 最終ページの
/// 「島へ行く」で実践デザイナー島(マップ)へ遷移する。
/// ページ内容は story.json(assets/story)でデータ管理 — 第2話以降も追加可能。
class StoryPlayerPage extends ConsumerStatefulWidget {
  const StoryPlayerPage({super.key, required this.episodeId});
  final String episodeId;

  @override
  ConsumerState<StoryPlayerPage> createState() => _StoryPlayerPageState();
}

class _StoryPlayerPageState extends ConsumerState<StoryPlayerPage> {
  int _index = 0;

  Future<void> _finish(StoryEpisode ep) async {
    // オンボーディング完了を記録(以降の起動判定に利用)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
    if (!mounted) return;
    context.go(ep.finishRoute);
  }

  @override
  Widget build(BuildContext context) {
    final episodes = ref.watch(storyEpisodesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1B6BD6),
      body: episodes.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => const Center(
            child: Text('ストーリーを読み込めなかったよ',
                style: TextStyle(color: Colors.white))),
        data: (list) {
          final ep = list.where((e) => e.id == widget.episodeId).firstOrNull;
          if (ep == null || ep.pages.isEmpty) {
            return const Center(
                child: Text('このお話は準備中だよ',
                    style: TextStyle(color: Colors.white)));
          }
          final page = ep.pages[_index.clamp(0, ep.pages.length - 1)];
          final isLast = _index >= ep.pages.length - 1;

          // ページ内ボタンの位置は毎ページ異なるため、画面のどこをタップしても
          // 前進する(画像内の「次へ」「くわしく見る」等のボタンもそのまま押せる)
          void advance() {
            if (isLast) {
              _finish(ep);
            } else {
              setState(() => _index++);
            }
          }

          return Semantics(
            button: true,
            label: isLast ? ep.finishLabel : '次へ',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: advance,
              child: Stack(children: [
                // ── ページ画像(全画面・contain) ──
                Positioned.fill(
                  child: Image.asset(
                    page.image,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) =>
                        _MissingPagePlaceholder(no: page.no, title: ep.title),
                  ),
                ),
                // ── ページ番号 ──
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: KdColors.wood900, width: 1.5),
                        ),
                        child: Text('${page.no} / ${ep.pages.length}',
                            style:
                                KdTheme.dot(size: 12, color: KdColors.ink900)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// ページ画像が未配置のときの差し替え待ちプレースホルダ。
class _MissingPagePlaceholder extends StatelessWidget {
  const _MissingPagePlaceholder({required this.no, required this.title});
  final int no;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B6BD6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: KdColors.parchmentLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: KdColors.wood900, width: 3),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: KdTheme.dot(size: 13, color: KdColors.heading)),
            const SizedBox(height: 12),
            Text('ページ $no',
                style: KdTheme.dot(size: 28, color: KdColors.ink900)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('この番号の画像を assets/images/story/ に配置してください',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      ),
    );
  }
}
