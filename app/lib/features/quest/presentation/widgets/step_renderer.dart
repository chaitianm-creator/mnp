import 'package:flutter/material.dart';

import 'package:design_kingdom/core/firebase/firebase_bootstrap.dart';
import 'package:design_kingdom/core/firebase/submission_uploader.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';

typedef OnAnswered = void Function(StepAnswer answer, String? feedback);

/// ステップUIの振り分け(Phase 7 §4)。
/// QuestStep(sealed) への switch — 新しい問題形式はエンティティ追加 + ここに1分岐。
class StepRenderer extends StatelessWidget {
  const StepRenderer({super.key, required this.step, required this.onAnswered});
  final QuestStep step;
  final OnAnswered onAnswered;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      HearingStep s => _HearingStepView(step: s, onAnswered: onAnswered),
      ChoiceStep s => _ChoiceStepView(step: s, onAnswered: onAnswered),
      ReorderStep s => _ReorderStepView(step: s, onAnswered: onAnswered),
      SubmitStep s => _SubmitStepView(step: s, onAnswered: onAnswered),
    };
  }
}

// ── ヒアリング(SC-21): 会話 → 選択式質問 ─────────────────────
class _HearingStepView extends StatelessWidget {
  const _HearingStepView({required this.step, required this.onAnswered});
  final HearingStep step;
  final OnAnswered onAnswered;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      for (final line in step.dialogue) ...[
        KdDialogueBubble(speaker: line.speaker, text: line.text),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 8),
      Text(step.question, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      for (final c in step.choices) ...[
        _ChoiceButton(
          text: c.text,
          onTap: () => onAnswered(
            StepAnswer(stepId: step.stepId, choiceId: c.id),
            c.feedback,
          ),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

// ── 選択問題(SC-22) ───────────────────────────────────────
class _ChoiceStepView extends StatelessWidget {
  const _ChoiceStepView({required this.step, required this.onAnswered});
  final ChoiceStep step;
  final OnAnswered onAnswered;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Text(step.question, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      for (final o in step.options) ...[
        _ChoiceButton(
          text: o.text,
          onTap: () => onAnswered(
            StepAnswer(stepId: step.stepId, choiceId: o.id),
            o.feedback,
          ),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: KdParchmentCard(
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

// ── 並び替え(SC-22): ReorderableListView ───────────────────
class _ReorderStepView extends StatefulWidget {
  const _ReorderStepView({required this.step, required this.onAnswered});
  final ReorderStep step;
  final OnAnswered onAnswered;

  @override
  State<_ReorderStepView> createState() => _ReorderStepViewState();
}

class _ReorderStepViewState extends State<_ReorderStepView> {
  late List<String> _items = [...widget.step.items];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(widget.step.question, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Expanded(
        child: ReorderableListView(
          buildDefaultDragHandles: true,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
          },
          children: [
            for (final item in _items)
              Padding(
                key: ValueKey(item),
                padding: const EdgeInsets.only(bottom: 8),
                child: KdParchmentCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    const Icon(Icons.drag_indicator, color: KdColors.wood700),
                    const SizedBox(width: 8),
                    Text(item, style: Theme.of(context).textTheme.bodyLarge),
                  ]),
                ),
              ),
          ],
        ),
      ),
      KdPrimaryButton(
        label: 'これでけってい！',
        onPressed: () {
          final correct = _sameOrder(_items, widget.step.answerOrder);
          widget.onAnswered(
            StepAnswer(stepId: widget.step.stepId, order: _items),
            correct
                ? '大正解！一番伝えたいことを、思いきり大きく。それがジャンプ率だよ'
                : 'おしい！「一番伝えたいことは何か」からもう一度考えてみよ？',
          );
        },
      ),
    ]);
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── 提出(SC-24): 本番=画像アップロード / DEMO=テキスト代替 ──
class _SubmitStepView extends StatefulWidget {
  const _SubmitStepView({required this.step, required this.onAnswered});
  final SubmitStep step;
  final OnAnswered onAnswered;

  @override
  State<_SubmitStepView> createState() => _SubmitStepViewState();
}

class _SubmitStepViewState extends State<_SubmitStepView> {
  final _controller = TextEditingController();
  String? _uploadedPath;
  bool _uploading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final path = await SubmissionUploader()
          .pickAndUpload(questId: widget.step.stepId);
      if (mounted) setState(() => _uploadedPath = path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('あれれ、荷物が届かなかったみたい。もう一度ためしてみて')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      KdParchmentCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('制作ブリーフ',
              style: TextStyle(fontWeight: FontWeight.w700, color: KdColors.pink700)),
          const SizedBox(height: 8),
          Text(widget.step.brief, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
      const SizedBox(height: 16),
      if (useFirebase) ...[
        // 本番: 画像提出(選択→1280px/80%圧縮→Storage)
        KdParchmentCard(
          child: Column(children: [
            Icon(
              _uploadedPath != null ? Icons.check_circle : Icons.add_photo_alternate,
              size: 48,
              color: _uploadedPath != null ? KdColors.grass500 : KdColors.wood700,
            ),
            const SizedBox(height: 8),
            Text(
              _uploadedPath != null
                  ? '作品を受け取ったよ！'
                  : '作った作品の画像を選んでね',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _uploading
                ? const CircularProgressIndicator(color: KdColors.pink500)
                : TextButton(
                    onPressed: _pickAndUpload,
                    child: Text(_uploadedPath != null ? '選びなおす' : '画像を選ぶ',
                        style: const TextStyle(color: KdColors.pink700)),
                  ),
          ]),
        ),
      ] else ...[
        // DEMO: テキスト提出で代替
        KdParchmentCard(
          child: TextField(
            controller: _controller,
            maxLines: 5,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'どんなPOPを作ったか、説明してみよう\n（本番では画像をアップロードします）',
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      KdPrimaryButton(
        label: 'みぽりん先生に提出する',
        onPressed: (useFirebase && _uploadedPath == null)
            ? null // 画像未選択では提出不可
            : () => widget.onAnswered(
                  StepAnswer(
                    stepId: widget.step.stepId,
                    text: useFirebase ? null : _controller.text,
                    imagePath: _uploadedPath,
                  ),
                  null,
                ),
      ),
    ]);
  }
}
