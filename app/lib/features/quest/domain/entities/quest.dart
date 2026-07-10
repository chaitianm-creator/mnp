/// Phase 5 §2.3 quests スキーマと 1:1 のドメインエンティティ(純Dart・Flutter非依存)。
/// ステップは sealed class — 新しい問題形式(kind)の追加はここと StepRenderer の2箇所のみ。
library;

/// Phase 4 §4 状態機械の11状態。名前は設計書の語彙と完全一致させる(Phase 7 §4)。
enum QuestStatus {
  offered,
  reserved,
  accepted,
  inProgress,
  paused,
  submitted,
  reviewing,
  reviewFailed,
  reviewed,
  retake,
  delivered,
}

enum QuestType { villager, merchant, guild, king, boss }

class Quest {
  const Quest({
    required this.questId,
    required this.areaId,
    required this.residentId,
    required this.residentName,
    required this.type,
    required this.sizeMinutes,
    required this.title,
    required this.brief,
    required this.reward,
    required this.steps,
    this.nextTeaser,
    this.version = 1,
  });

  final String questId;
  final String areaId;
  final String residentId;
  final String residentName;
  final QuestType type;
  final int sizeMinutes; // 3 | 7 | 15
  final String title;
  final String brief;
  final QuestReward reward;
  final List<QuestStep> steps;
  final String? nextTeaser; // 次話予告(クリフハンガー)
  final int version;
}

class QuestReward {
  const QuestReward({required this.xp, required this.coins, this.skillPoints = const {}});
  final int xp;
  final int coins;
  final Map<String, int> skillPoints;
}

// ── ステップ(問題エンジンの契約) ──────────────────────────────

sealed class QuestStep {
  const QuestStep({required this.stepId});
  final String stepId;
}

/// ヒアリング: 住民との対話 + 選択式質問(選択肢ごとにスコアとフィードバック)
class HearingStep extends QuestStep {
  const HearingStep({
    required super.stepId,
    required this.dialogue,
    required this.question,
    required this.choices,
  });
  final List<DialogueLine> dialogue;
  final String question;
  final List<HearingChoice> choices;
}

class DialogueLine {
  const DialogueLine({required this.speaker, required this.text});
  final String speaker;
  final String text;
}

class HearingChoice {
  const HearingChoice({
    required this.id,
    required this.text,
    required this.score,
    required this.feedback,
  });
  final String id;
  final String text;
  final int score; // 0-2
  final String feedback; // みぽりん先生のコメント
}

/// 選択問題(テキスト選択肢。画像版 choice_image は asset 参照を追加して拡張)
class ChoiceStep extends QuestStep {
  const ChoiceStep({
    required super.stepId,
    required this.question,
    required this.options,
  });
  final String question;
  final List<ChoiceOption> options;
}

class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.text,
    required this.correct,
    required this.feedback,
  });
  final String id;
  final String text;
  final bool correct;
  final String feedback;
}

/// 並び替え問題
class ReorderStep extends QuestStep {
  const ReorderStep({
    required super.stepId,
    required this.question,
    required this.items,
    required this.answerOrder,
  });
  final String question;
  final List<String> items;
  final List<String> answerOrder;
}

/// 提出ステップ(画像アップロード or 文章)。isDeliveryStep=true が納品対象。
class SubmitStep extends QuestStep {
  const SubmitStep({
    required super.stepId,
    required this.brief,
    this.acceptsImage = true,
    this.acceptsText = false,
  });
  final String brief;
  final bool acceptsImage;
  final bool acceptsText;
}

// ── 回答・添削 ────────────────────────────────────────────

class StepAnswer {
  const StepAnswer({required this.stepId, this.choiceId, this.order, this.text, this.imagePath});
  final String stepId;
  final String? choiceId;
  final List<String>? order;
  final String? text;
  final String? imagePath;
}

/// AI添削結果(Phase 6 §4 出力スキーマと1:1)
class ReviewResult {
  const ReviewResult({
    required this.goodPoints,
    required this.improvements,
    required this.nextAdvice,
    required this.scores,
  });
  final List<String> goodPoints; // ≤3
  final List<String> improvements; // ≤3
  final String nextAdvice;
  final Map<String, int> scores; // 6軸 0-5
}

/// deliverQuest のレスポンス(Phase 6 §1.3)。報酬演出に必要な情報一式。
class DeliveryOutcome {
  const DeliveryOutcome({
    required this.reward,
    this.levelUpTo,
    this.droppedKey = false,
    this.streak = 0,
    this.nextTeaser,
  });
  final QuestReward reward;
  final int? levelUpTo;
  final bool droppedKey;
  final int streak;
  final String? nextTeaser;
}
