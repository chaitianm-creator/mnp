import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/features/quest/data/quest_local_source.dart';
import 'package:design_kingdom/features/quest/data/quest_repository.dart';
import 'package:design_kingdom/features/quest/domain/entities/quest.dart';

/// リポジトリDI。DEMO モードでは Fake、Phase 10 で Firestore 実装に差し替え。
final questRepositoryProvider =
    Provider<QuestRepository>((ref) => FakeQuestRepository());

final todayOffersProvider = FutureProvider<List<Quest>>(
    (ref) => ref.watch(questRepositoryProvider).fetchTodayOffers());

/// 練習クエスト(みぽりん先生の基礎レッスン)。3つクリアで「今日の依頼」解放。
final practiceQuestsProvider = FutureProvider<List<Quest>>(
    (ref) => ref.watch(questRepositoryProvider).fetchPracticeQuests());

/// クエストプレイの UI 状態。
/// status は Phase 4 §4 状態機械そのもの。画面はこの状態に従属する。
class QuestPlayState {
  const QuestPlayState({
    required this.quest,
    this.status = QuestStatus.offered,
    this.stepIndex = 0,
    this.answers = const {},
    this.lastFeedback,
    this.review,
    this.outcome,
    this.resumed = false,
    this.errorKey,
  });

  final Quest quest;
  final QuestStatus status;
  final int stepIndex;
  final Map<String, StepAnswer> answers;
  final String? lastFeedback; // 直近の選択へのみぽりん先生コメント
  final ReviewResult? review;
  final DeliveryOutcome? outcome;
  final bool resumed; // 中断再開で復帰したか(復帰メッセージ表示用)
  final String? errorKey; // Phase 6 §5.2 messageKey → 世界観文言へ変換

  QuestStep get currentStep => quest.steps[stepIndex];
  bool get isLastStep => stepIndex == quest.steps.length - 1;
  double get progress =>
      quest.steps.isEmpty ? 0 : (stepIndex + 1) / quest.steps.length;

  QuestPlayState copyWith({
    QuestStatus? status,
    int? stepIndex,
    Map<String, StepAnswer>? answers,
    String? lastFeedback,
    bool clearFeedback = false,
    ReviewResult? review,
    DeliveryOutcome? outcome,
    bool? resumed,
    String? errorKey,
  }) =>
      QuestPlayState(
        quest: quest,
        status: status ?? this.status,
        stepIndex: stepIndex ?? this.stepIndex,
        answers: answers ?? this.answers,
        lastFeedback: clearFeedback ? null : (lastFeedback ?? this.lastFeedback),
        review: review ?? this.review,
        outcome: outcome ?? this.outcome,
        resumed: resumed ?? this.resumed,
        errorKey: errorKey,
      );
}

/// ViewModel(MVVM)。**メソッド名は Phase 4 状態機械の矢印と一致**(Phase 7 §4)。
class QuestPlayViewModel extends AutoDisposeFamilyNotifier<QuestPlayState?, String> {
  QuestRepository get _repo => ref.read(questRepositoryProvider);
  QuestLocalSource get _local => ref.read(questLocalSourceProvider);

  @override
  QuestPlayState? build(String questId) {
    _load(questId);
    return null; // ロード中
  }

  Future<void> _load(String questId) async {
    final quest = await _repo.fetchQuest(questId);
    // 中断再開(US-E2-06): Paused → InProgress
    final saved = await _local.load();
    if (saved != null && saved.questId == questId) {
      state = QuestPlayState(
        quest: quest,
        status: QuestStatus.inProgress,
        stepIndex: saved.stepIndex.clamp(0, quest.steps.length - 1),
        answers: saved.answers,
        resumed: true,
      );
      return;
    }
    state = QuestPlayState(quest: quest);
  }

  /// InProgress の間だけローカルへ保存(Paused からの復帰用)
  Future<void> _persist() async {
    final s = state;
    if (s == null || s.status != QuestStatus.inProgress) return;
    await _local.save(SavedProgress(
      questId: s.quest.questId,
      stepIndex: s.stepIndex,
      answers: s.answers,
    ));
  }

  /// offered/reserved → accepted → inProgress
  Future<void> accept() async {
    final s = state;
    if (s == null || s.status != QuestStatus.offered) return;
    await _repo.acceptQuest(s.quest.questId);
    state = s.copyWith(status: QuestStatus.inProgress);
    await _persist();
  }

  /// inProgress → inProgress (ステップ回答・前進)
  void submitStep(StepAnswer answer, {String? feedback}) {
    final s = state;
    if (s == null || s.status != QuestStatus.inProgress) return;
    final answers = {...s.answers, answer.stepId: answer};
    if (s.isLastStep) {
      state = s.copyWith(answers: answers, lastFeedback: feedback);
    } else {
      state = s.copyWith(
        answers: answers,
        stepIndex: s.stepIndex + 1,
        lastFeedback: feedback,
      );
    }
    _persist();
  }

  void clearFeedback() => state = state?.copyWith(clearFeedback: true);

  /// inProgress → submitted → reviewing → reviewed / reviewFailed
  Future<void> submitForReview(StepAnswer submission) async {
    final s = state;
    if (s == null || s.status != QuestStatus.inProgress) return;
    state = s.copyWith(status: QuestStatus.reviewing);
    try {
      final review = await _repo.submitForReview(s.quest.questId, submission);
      state = state?.copyWith(status: QuestStatus.reviewed, review: review);
    } catch (_) {
      // Phase 4: 添削失敗でも進行を止めない(定型励まし → 後日再添削)
      state = state?.copyWith(status: QuestStatus.reviewFailed);
    }
  }

  /// reviewed → retake → inProgress (提出ステップへ戻る)
  void retake() {
    final s = state;
    if (s == null || s.status != QuestStatus.reviewed) return;
    state = s.copyWith(
        status: QuestStatus.inProgress, stepIndex: s.quest.steps.length - 1);
  }

  /// reviewed → delivered (報酬付与は唯一 deliverQuest 経由 = Phase 6 §1.3)
  Future<void> deliver() async {
    final s = state;
    if (s == null || s.status != QuestStatus.reviewed) return;
    final outcome = await _repo.deliverQuest(s.quest.questId);
    // ユーザー進捗へ反映(本番は users/{uid} の購読で自動反映)
    ref.read(userProgressProvider.notifier).applyDelivery(s.quest, outcome);
    await _local.clear(); // 納品済みの中断データは破棄
    state = s.copyWith(status: QuestStatus.delivered, outcome: outcome);
  }
}

final questPlayViewModelProvider = NotifierProvider.autoDispose
    .family<QuestPlayViewModel, QuestPlayState?, String>(QuestPlayViewModel.new);
