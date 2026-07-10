import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:design_kingdom/features/quest/domain/entities/quest.dart';

/// 中断再開(US-E2-06)のローカル保存。
/// Phase 7 §4: 進行中は常に1件・構造単純のため DB ではなく単純な JSON。
/// 本番ではサーバ(quest_progress)にも二重保存し、オンライン復帰で同期(Phase 5 §3.2)。
class SavedProgress {
  const SavedProgress({
    required this.questId,
    required this.stepIndex,
    required this.answers,
  });

  final String questId;
  final int stepIndex;
  final Map<String, StepAnswer> answers;
}

abstract interface class QuestLocalSource {
  Future<void> save(SavedProgress progress);
  Future<SavedProgress?> load();
  Future<void> clear();
}

class SharedPrefsQuestLocalSource implements QuestLocalSource {
  static const _key = 'quest_progress_v1';

  @override
  Future<void> save(SavedProgress p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'questId': p.questId,
          'stepIndex': p.stepIndex,
          'answers': [
            for (final a in p.answers.values)
              {
                'stepId': a.stepId,
                'choiceId': a.choiceId,
                'order': a.order,
                'text': a.text,
              }
          ],
        }),
      );
    } catch (_) {
      // ローカル保存は best-effort。失敗しても進行は止めない
    }
  }

  @override
  Future<SavedProgress?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final answers = <String, StepAnswer>{};
      for (final a in (json['answers'] as List).cast<Map<String, dynamic>>()) {
        answers[a['stepId'] as String] = StepAnswer(
          stepId: a['stepId'] as String,
          choiceId: a['choiceId'] as String?,
          order: (a['order'] as List?)?.cast<String>(),
          text: a['text'] as String?,
        );
      }
      return SavedProgress(
        questId: json['questId'] as String,
        stepIndex: json['stepIndex'] as int,
        answers: answers,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

final questLocalSourceProvider =
    Provider<QuestLocalSource>((ref) => SharedPrefsQuestLocalSource());
