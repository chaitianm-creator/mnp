import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// クリア済みの練習クエスト数(「今日の依頼」の解放条件に使う)
  int get practiceClearedCount =>
      deliveredQuestIds.where((id) => id.startsWith('q_practice')).length;

  /// 「今日の依頼」(お客様からの実依頼)が解放済みか。
  /// 練習クエスト3つクリアで解放。既に実依頼を納品済みの既存ユーザーは解放済み扱い。
  bool get dailyRequestUnlocked =>
      practiceClearedCount >= 3 ||
      deliveredQuestIds.any((id) => !id.startsWith('q_practice'));

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'level': level,
        'coins': coins,
        'streak': streak,
        'keys': keys,
        'deliveredQuestIds': deliveredQuestIds.toList(),
        'areaDelivered': areaDelivered,
      };

  static UserProgress fromJson(Map<String, dynamic> j) => UserProgress(
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 1,
        keys: (j['keys'] as num?)?.toInt() ?? 0,
        deliveredQuestIds:
            ((j['deliveredQuestIds'] as List? ?? const []).cast<String>())
                .toSet(),
        areaDelivered: ((j['areaDelivered'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );

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

const kProgressPrefsKey = 'progress_json';

/// 起動時に main() が読み込んだ進捗(ProviderScope override で注入)。
final initialProgressProvider =
    Provider<UserProgress>((_) => const UserProgress(streak: 1));

class UserProgressNotifier extends Notifier<UserProgress> {
  @override
  UserProgress build() => ref.watch(initialProgressProvider);

  /// リロードしても練習クエストの解放状態が保たれるよう永続化(DEMO)。
  /// 保存失敗(テスト環境等)でもゲーム進行は止めない。
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kProgressPrefsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

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
    _persist();
  }

  /// ギルド入団ボーナス(SC-07: 練習クエスト成功時に一度だけ)
  void grantGuildBonus() {
    state = state.copyWith(xp: state.xp + 20);
    _persist();
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
