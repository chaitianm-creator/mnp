import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/presentation/view_models/quest_play_view_model.dart';

/// Phase 4 §4 状態機械の不変条件テスト。
/// 「状態が画面を決める」の前提となる遷移ルールをここで担保する。
void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  Future<QuestPlayViewModel> loadedVm(ProviderContainer c) async {
    final sub = c.listen(questPlayViewModelProvider('q_marco_01'), (_, __) {});
    // FakeQuestRepository のロード完了を待つ
    while (sub.read() == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return c.read(questPlayViewModelProvider('q_marco_01').notifier);
  }

  test('offered → accept() → inProgress', () async {
    final c = makeContainer();
    final vm = await loadedVm(c);
    expect(c.read(questPlayViewModelProvider('q_marco_01'))!.status,
        QuestStatus.offered);
    await vm.accept();
    expect(c.read(questPlayViewModelProvider('q_marco_01'))!.status,
        QuestStatus.inProgress);
  });

  test('submitStep はステップを前進させ、回答を保持する', () async {
    final c = makeContainer();
    final vm = await loadedVm(c);
    await vm.accept();
    vm.submitStep(const StepAnswer(stepId: 's1', choiceId: 'a'));
    final s = c.read(questPlayViewModelProvider('q_marco_01'))!;
    expect(s.stepIndex, 1);
    expect(s.answers['s1']!.choiceId, 'a');
  });

  test('inProgress 以外からの submitStep は無効(状態機械の防御)', () async {
    final c = makeContainer();
    final vm = await loadedVm(c);
    // accept していない = offered のまま
    vm.submitStep(const StepAnswer(stepId: 's1', choiceId: 'a'));
    final s = c.read(questPlayViewModelProvider('q_marco_01'))!;
    expect(s.stepIndex, 0);
    expect(s.answers, isEmpty);
  });

  test('submitForReview → reviewed、deliver → delivered(報酬つき)', () async {
    final c = makeContainer();
    final vm = await loadedVm(c);
    await vm.accept();
    // 最終ステップまで前進
    vm.submitStep(const StepAnswer(stepId: 's1', choiceId: 'a'));
    vm.submitStep(const StepAnswer(stepId: 's2', choiceId: 'b'));
    vm.submitStep(const StepAnswer(stepId: 's3', order: []));
    await vm.submitForReview(const StepAnswer(stepId: 's4', text: 'POP案'));
    var s = c.read(questPlayViewModelProvider('q_marco_01'))!;
    expect(s.status, QuestStatus.reviewed);
    expect(s.review, isNotNull);

    await vm.deliver();
    s = c.read(questPlayViewModelProvider('q_marco_01'))!;
    expect(s.status, QuestStatus.delivered);
    expect(s.outcome!.reward.xp, 50);
  });

  test('reviewed → retake() → inProgress(提出ステップへ戻る)', () async {
    final c = makeContainer();
    final vm = await loadedVm(c);
    await vm.accept();
    vm.submitStep(const StepAnswer(stepId: 's1', choiceId: 'a'));
    vm.submitStep(const StepAnswer(stepId: 's2', choiceId: 'b'));
    vm.submitStep(const StepAnswer(stepId: 's3', order: []));
    await vm.submitForReview(const StepAnswer(stepId: 's4', text: 'POP案'));
    vm.retake();
    final s = c.read(questPlayViewModelProvider('q_marco_01'))!;
    expect(s.status, QuestStatus.inProgress);
    expect(s.currentStep, isA<SubmitStep>());
  });

  test('reviewed 以外からの deliver は無効(報酬二重付与の防御)', () async {
    final c = makeContainer();
    final vm = await loadedVm(c);
    await vm.accept();
    await vm.deliver(); // inProgress からは不可
    final s = c.read(questPlayViewModelProvider('q_marco_01'))!;
    expect(s.status, QuestStatus.inProgress);
    expect(s.outcome, isNull);
  });
}
