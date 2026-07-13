import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_celebration.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';
import 'package:design_kingdom/features/quest/presentation/widgets/step_renderer.dart';

/// クエストプレイ(フルスクリーンフロー)。
/// Phase 4 §4: 「状態が画面を決める」— status への switch が本ページの全て。
/// SC-20(受注) / SC-21〜24(ステップ) / SC-25(添削待ち) / SC-26(添削結果)
/// / SC-27(納品演出オーバーレイ) / SC-28(セッション終了)
class QuestPlayPage extends ConsumerWidget {
  const QuestPlayPage({super.key, required this.questId});
  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questPlayViewModelProvider(questId));
    final vm = ref.read(questPlayViewModelProvider(questId).notifier);

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // SC-27/28: 納品後は AppBar なしの専用フロー(バック不可 = Phase 4 §7-4)
    if (state.status == QuestStatus.delivered) {
      return _DeliveredFlow(state: state);
    }

    final body = switch (state.status) {
      QuestStatus.offered || QuestStatus.reserved => _QuestDetail(state: state, vm: vm),
      QuestStatus.accepted ||
      QuestStatus.inProgress ||
      QuestStatus.paused ||
      QuestStatus.retake =>
        _StepFlow(state: state, vm: vm),
      QuestStatus.submitted || QuestStatus.reviewing => const _Reviewing(),
      QuestStatus.reviewed => _ReviewResultView(state: state, vm: vm),
      QuestStatus.reviewFailed => _ReviewFailed(state: state, vm: vm),
      QuestStatus.delivered => const SizedBox.shrink(), // 上で処理済み
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(state.quest.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          // Phase 4 §7-2: 中断確認は「1タップで抜けられる軽いもの」
          onPressed: () => _confirmPause(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: KdProgressBar(value: _progressFor(state)),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(20), child: body),
      ),
    );
  }

  double _progressFor(QuestPlayState s) => switch (s.status) {
        QuestStatus.offered || QuestStatus.reserved => 0,
        QuestStatus.delivered => 1,
        QuestStatus.submitted ||
        QuestStatus.reviewing ||
        QuestStatus.reviewed ||
        QuestStatus.reviewFailed =>
          0.95,
        _ => s.progress * 0.9,
      };

  void _confirmPause(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KdColors.surface,
        title: const Text('ここまでにする？'),
        content: const Text('進み具合は保存されるよ。いつでも続きからできるからね。'),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('つづける')),
          TextButton(
            onPressed: () {
              ctx.pop();
              context.go('/home');
            },
            child: const Text('あとで'),
          ),
        ],
      ),
    );
  }
}

// ── SC-20 依頼詳細(受注) ──────────────────────────────────
class _QuestDetail extends StatelessWidget {
  const _QuestDetail({required this.state, required this.vm});
  final QuestPlayState state;
  final QuestPlayViewModel vm;

  @override
  Widget build(BuildContext context) {
    final q = state.quest;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        KdChip('${q.sizeMinutes}分', icon: Icons.schedule),
        const SizedBox(width: 8),
        const KdChip('はじまりの街', icon: Icons.place),
      ]),
      const SizedBox(height: 16),
      // 依頼主の吹き出し(ポートレート内蔵)
      KdDialogueBubble(speaker: q.residentName, text: q.brief),
      const SizedBox(height: 16),
      // クエストボックス様式の依頼メモ
      KdParchmentCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.star, size: 18, color: KdColors.gold500),
          const SizedBox(width: 8),
          Expanded(
            child: Text('メインクエスト: ${q.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KdTheme.dot(size: 13, color: KdColors.heading)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const Spacer(),
      // ほうしゅうプレート(ごほうびは金の額)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: KdColors.parchmentLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.gold500, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFFB88A18), offset: Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.star, color: KdColors.reward),
          const SizedBox(width: 8),
          Text('ほうしゅう  XP ${q.reward.xp} ／ コイン ${q.reward.coins}',
              style: KdTheme.dot(size: 15, color: KdColors.ink900)),
        ]),
      ),
      const SizedBox(height: 16),
      KdPrimaryButton(label: 'この仕事を引き受ける', onPressed: vm.accept),
    ]);
  }
}

// ── SC-21〜24 ステップフロー ───────────────────────────────
class _StepFlow extends StatelessWidget {
  const _StepFlow({required this.state, required this.vm});
  final QuestPlayState state;
  final QuestPlayViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (state.resumed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KdParchmentCard(
            padding: const EdgeInsets.all(12),
            child: Text('おかえり！つづきからだよ',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      Expanded(
        child: StepRenderer(
          key: ValueKey(state.currentStep.stepId),
          step: state.currentStep,
          onAnswered: (answer, feedback) {
            final isLast = state.isLastStep;
            if (state.currentStep is SubmitStep) {
              vm.submitStep(answer);
              vm.submitForReview(answer);
            } else if (isLast) {
              // 最終ステップが提出型でないクエスト(3分ミニ等)も添削へ進める
              // (テスト作成中に発見: 従来はここで進行が止まっていた)
              vm.submitStep(answer, feedback: feedback);
              vm.submitForReview(answer);
            } else {
              vm.submitStep(answer, feedback: feedback);
            }
          },
        ),
      ),
      if (state.lastFeedback != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _TeacherFeedback(
              text: state.lastFeedback!, onDismiss: vm.clearFeedback),
        ),
    ]);
  }
}

class _TeacherFeedback extends StatelessWidget {
  const _TeacherFeedback({required this.text, required this.onDismiss});
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // メッセージウィンドウ(先生からのメッセージ)様式
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KdColors.pink50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.pink500, width: 2),
          boxShadow: const [
            BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KdColors.pink100,
              shape: BoxShape.circle,
              border: Border.all(color: KdColors.pink500, width: 2),
            ),
            child:
                const Icon(Icons.favorite, size: 18, color: KdColors.pink500),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text('みぽりん先生「$text」',
                  style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      ),
    );
  }
}

// ── SC-25 添削待ち ────────────────────────────────────────
class _Reviewing extends StatelessWidget {
  const _Reviewing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // みぽりん先生のポートレート
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: KdColors.pink100,
            shape: BoxShape.circle,
            border: Border.all(color: KdColors.pink500, width: 3),
            boxShadow: const [
              BoxShadow(color: KdColors.pink700, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.favorite, size: 44, color: KdColors.pink500),
        ),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: KdColors.pink500),
        const SizedBox(height: 24),
        Text('みぽりん先生が見ているよ…ふむふむ',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 6),
        Text('とどけたさくひんを、ていねいに見てくれているよ',
            style: KdTheme.dot(size: 12, color: KdColors.ink900)),
      ]),
    );
  }
}

// ── SC-26 添削結果 ────────────────────────────────────────
class _ReviewResultView extends StatelessWidget {
  const _ReviewResultView({required this.state, required this.vm});
  final QuestPlayState state;
  final QuestPlayViewModel vm;

  @override
  Widget build(BuildContext context) {
    final r = state.review!;
    return ListView(children: [
      Center(child: KdRibbonBanner('みぽりん先生のおてがみ', fontSize: 14)),
      const SizedBox(height: 12),
      _ReviewSection(
          title: 'よかったところ',
          icon: Icons.favorite,
          color: KdColors.pink500,
          items: r.goodPoints),
      const SizedBox(height: 12),
      _ReviewSection(
          title: 'もっと良くなるところ',
          icon: Icons.wb_sunny,
          color: KdColors.gold500,
          items: r.improvements),
      const SizedBox(height: 12),
      // メッセージウィンドウ様式のアドバイス
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KdColors.pink50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.pink500, width: 2),
          boxShadow: const [
            BoxShadow(color: KdColors.pink700, offset: Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KdColors.pink100,
                shape: BoxShape.circle,
                border: Border.all(color: KdColors.pink500, width: 2),
              ),
              child: const Icon(Icons.favorite,
                  size: 16, color: KdColors.pink500),
            ),
            const SizedBox(width: 8),
            Text('つぎへのアドバイス',
                style: KdTheme.dot(size: 14, color: KdColors.heading)
                    .copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(r.nextAdvice, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
      const SizedBox(height: 20),
      KdPrimaryButton(label: '納品する', onPressed: vm.deliver),
      const SizedBox(height: 8),
      TextButton(
        onPressed: vm.retake,
        child: const Text('リテイクする（改善力ボーナスあり！）',
            style: TextStyle(color: KdColors.ink900)),
      ),
    ]);
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection(
      {required this.title,
      required this.icon,
      required this.color,
      required this.items});
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return KdParchmentCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: KdColors.wood900, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: KdTheme.dot(size: 14, color: KdColors.ink900)
                  .copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child:
                Text('・$item', style: Theme.of(context).textTheme.bodyLarge),
          ),
      ]),
    );
  }
}

// ── 添削失敗(進行を止めない = US-E3-07) ─────────────────────
class _ReviewFailed extends StatelessWidget {
  const _ReviewFailed({required this.state, required this.vm});
  final QuestPlayState state;
  final QuestPlayViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('あれれ、荷物が届かなかったみたい。',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text('あとでもう一度みぽりん先生に届けるね。今日はここまでよく頑張ったよ！',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        KdPrimaryButton(
            label: 'ホームへもどる', onPressed: () => context.go('/home')),
      ]),
    );
  }
}

// ══ SC-27(納品演出) → SC-28(セッション終了) ═══════════════════
// Phase 4 §7-4: この間はバック不可(一方通行)。
class _DeliveredFlow extends ConsumerStatefulWidget {
  const _DeliveredFlow({required this.state});
  final QuestPlayState state;

  @override
  ConsumerState<_DeliveredFlow> createState() => _DeliveredFlowState();
}

class _DeliveredFlowState extends ConsumerState<_DeliveredFlow> {
  bool _celebrationDone = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.state.outcome!;

    // SC-27: 納品演出オーバーレイ(ピーク)
    if (!_celebrationDone) {
      return Scaffold(
        body: KdCelebrationOverlay(
          icon: Icons.celebration,
          title: '納品完了！',
          lines: [
            '${widget.state.quest.residentName}「ありがとう！すごく助かったよ！」',
            'XP +${o.reward.xp}   コイン +${o.reward.coins}',
            if (o.levelUpTo != null) '★ レベル ${o.levelUpTo} になった！',
            if (o.droppedKey) '★ 宝箱のカギを拾った！',
          ],
          onDone: () => setState(() => _celebrationDone = true),
        ),
      );
    }

    // SC-28: セッション終了(エンド=予告の固定フォーマット)
    return _SessionEndView(state: widget.state);
  }
}

/// SC-28: ①今日の成果 ②昨日の自分との比較 ③明日の予告+受注予約
/// ④「あと1クエスト」提案(3分・1セッション1回のみ = Phase 4 §3)
class _SessionEndView extends ConsumerWidget {
  const _SessionEndView({required this.state});
  final QuestPlayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final o = state.outcome!;
    final teaser = o.nextTeaser;
    final reserved = progress.reservedQuestId != null;
    // 「あと1クエスト」: 未使用 かつ 未納品の3分依頼があるときのみ
    final canOneMore = !progress.oneMoreUsedThisSession &&
        !progress.deliveredQuestIds.contains('q_mini_001') &&
        state.quest.questId != 'q_mini_001';

    return Scaffold(
      appBar: AppBar(
          title: const Text('きょうのまとめ'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          // ① 今日の成果(レベルアップ・演出素材様式: リボン + ステータスタイル)
          Center(child: KdRibbonBanner('きょうの成果', fontSize: 14)),
          const SizedBox(height: 12),
          KdParchmentCard(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const _ResultTile(
                      icon: Icons.inventory,
                      color: KdColors.pink500,
                      label: 'のうひん',
                      value: '1件'),
                  _ResultTile(
                      icon: Icons.auto_awesome,
                      color: KdColors.gold500,
                      label: 'けいけんち',
                      value: 'EXP+${o.reward.xp}'),
                  _ResultTile(
                      icon: Icons.favorite,
                      color: KdColors.pink700,
                      label: 'れんぞく',
                      value: '${o.streak}日'),
                ]),
          ),
          const SizedBox(height: 12),
          // ② 昨日の自分との比較(DEMO: 固定文。本番は daily_log 差分)
          KdParchmentCard(
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: KdColors.grass500,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KdColors.wood900, width: 2),
                ),
                child: const Icon(Icons.trending_up,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('きのうのあなたより、ヒアリング力が +1 育ったよ',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            ]),
          ),
          // ③ 明日の予告 + 受注予約(ツァイガルニク + 一貫性の原理)
          if (teaser != null) ...[
            const SizedBox(height: 16),
            KdParchmentCard(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const KdSectionHeader('あしたの予告'),
                const SizedBox(height: 10),
                KdDialogueBubble(
                    speaker: state.quest.residentName, text: teaser),
                const SizedBox(height: 12),
                reserved
                    ? Row(children: [
                        const Icon(Icons.mark_email_read,
                            color: KdColors.grass500),
                        const SizedBox(width: 8),
                        Text('予約したよ！あした手紙が届くからね',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ])
                    : KdPrimaryButton(
                        label: 'この依頼を受注予約する',
                        onPressed: () => ref
                            .read(userProgressProvider.notifier)
                            .reserve('q_marco_02', teaser),
                      ),
              ]),
            ),
          ],
          // ④ あと1クエスト(1回のみ。2回目は「ボタン自体を表示しない」= Phase 4 §3)
          if (canOneMore) ...[
            const SizedBox(height: 16),
            KdParchmentCard(
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: KdColors.ocean500,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KdColors.wood900, width: 2),
                    ),
                    child:
                        const Icon(Icons.bolt, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('まだ少しだけ時間ある？3分のミニ依頼が1件あるよ',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ]),
                const SizedBox(height: 12),
                KdPrimaryButton(
                  label: 'あと1クエストだけやる（3分）',
                  onPressed: () {
                    ref.read(userProgressProvider.notifier).markOneMoreUsed();
                    context.pushReplacement('/quest/q_mini_001');
                  },
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          const KdBandMessage('きょうもよくがんばったね！また明日、王国で会おうね♪'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('きょうはここまで！ホームへ',
                style: TextStyle(color: KdColors.ink900, fontSize: 17)),
          ),
        ]),
      ),
    );
  }
}

/// きょうの成果のステータスタイル(アイコンタイル + 数値 + ラベル)。
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: KdColors.wood900, width: 2),
          boxShadow: [
            BoxShadow(
                color: Color.lerp(color, KdColors.wood900, 0.35)!,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      const SizedBox(height: 8),
      Text(value,
          style: KdTheme.dot(size: 15, color: KdColors.heading)
              .copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: KdTheme.dot(size: 11, color: KdColors.ink900)),
    ]);
  }
}
