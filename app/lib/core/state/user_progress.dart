import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:design_kingdom/features/quest/domain/entities/quest.dart';

/// ユーザー進捗(DEMO: メモリ保持)。
/// Phase 10 で users/{uid} (Phase 5 §3.1) の購読 + Functions 反映に差し替える。
/// 本番では XP/コイン等の書き込みは deliverQuest(Functions) のみ — ここはその写像。
class UserProgress {
  const UserProgress({
    this.xp = 0,
    this.level = 1,
    this.coins = 0,
    this.streak = 0,
    this.keys = 0,
    this.reservedQuestId,
    this.reservedTeaser,
    this.deliveredQuestIds = const {},
    this.areaDelivered = const {},
    this.oneMoreUsedThisSession = false,
  });

  final int xp;
  final int level;
  final int coins;
  final int streak;
  final int keys;
  final String? reservedQuestId; // 1件制約(Phase 4 付録B)
  final String? reservedTeaser;
  final Set<String> deliveredQuestIds;
  final Map<String, int> areaDelivered; // areaId → 納品数(発展stage算出用)
  final bool oneMoreUsedThisSession; // 「あと1クエスト」は1セッション1回(Phase 4 §3)

  /// エリア発展 stage (Phase 5 §2.1 developmentStages: 0/6/12)
  int stageOf(String areaId) {
    final n = areaDelivered[areaId] ?? 0;
    if (n >= 12) return 3;
    if (n >= 6) return 2;
    return 1;
  }

  UserProgress copyWith({
    int? xp,
    int? level,
    int? coins,
    int? streak,
    int? keys,
    String? reservedQuestId,
    String? reservedTeaser,
    bool clearReservation = false,
    Set<String>? deliveredQuestIds,
    Map<String, int>? areaDelivered,
    bool? oneMoreUsedThisSession,
  }) =>
      UserProgress(
        xp: xp ?? this.xp,
        level: level ?? this.level,
        coins: coins ?? this.coins,
        streak: streak ?? this.streak,
        keys: keys ?? this.keys,
        reservedQuestId:
            clearReservation ? null : (reservedQuestId ?? this.reservedQuestId),
        reservedTeaser:
            clearReservation ? null : (reservedTeaser ?? this.reservedTeaser),
        deliveredQuestIds: deliveredQuestIds ?? this.deliveredQuestIds,
        areaDelivered: areaDelivered ?? this.areaDelivered,
        oneMoreUsedThisSession:
            oneMoreUsedThisSession ?? this.oneMoreUsedThisSession,
      );
}

class UserProgressNotifier extends Notifier<UserProgress> {
  @override
  UserProgress build() => const UserProgress(streak: 1);

  /// deliverQuest(Phase 6 §1.3) のレスポンスを状態へ反映
  void applyDelivery(Quest quest, DeliveryOutcome outcome) {
    final delivered = {...state.deliveredQuestIds, quest.questId};
    final area = {...state.areaDelivered};
    area[quest.areaId] = (area[quest.areaId] ?? 0) + 1;
    state = state.copyWith(
      xp: state.xp + outcome.reward.xp,
      coins: state.coins + outcome.reward.coins,
      level: outcome.levelUpTo ?? state.level,
      streak: outcome.streak,
      keys: state.keys + (outcome.droppedKey ? 1 : 0),
      deliveredQuestIds: delivered,
      areaDelivered: area,
    );
  }

  /// 受注予約(US-E1-07 / US-E6-02)。同時に1件のみ。
  void reserve(String questId, String teaser) =>
      state = state.copyWith(reservedQuestId: questId, reservedTeaser: teaser);

  void markOneMoreUsed() =>
      state = state.copyWith(oneMoreUsedThisSession: true);
}

final userProgressProvider =
    NotifierProvider<UserProgressNotifier, UserProgress>(
        UserProgressNotifier.new);
