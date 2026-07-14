import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:design_kingdom/features/quest/domain/entities/quest.dart';
import 'package:design_kingdom/features/quest/data/quest_repository.dart';

/// 本番実装(Phase 10)。Phase 6 の Callable と 1:1。
/// DEMO(Fake) との切替は main.dart の Provider オーバーライドで行う。
class FirestoreQuestRepository implements QuestRepository {
  FirestoreQuestRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _fn = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('auth/unauthenticated');
    return uid;
  }

  @override
  Future<List<Quest>> fetchTodayOffers() async {
    // users/{uid}.todayOffers.questIds(dailyBatch生成) → quests を取得。
    // MVP初期: todayOffers 未生成時はエリア①の公開クエストからフォールバック。
    final user = await _db.doc('users/$_uid').get();
    final ids = ((user.data()?['todayOffers']?['questIds']) as List?)
        ?.cast<String>();
    if (ids != null && ids.isNotEmpty) {
      final docs = await Future.wait(ids.map((id) => _db.doc('quests/$id').get()));
      return [
        for (final d in docs)
          if (d.exists) _questFromDoc(d.id, d.data()!),
      ];
    }
    final snap = await _db
        .collection('quests')
        .where('areaId', isEqualTo: 'area_01_hajimari')
        .where('isPublished', isEqualTo: true)
        .orderBy('order')
        .limit(3)
        .get();
    return [for (final d in snap.docs) _questFromDoc(d.id, d.data())];
  }

  @override
  Future<List<Quest>> fetchPracticeQuests() async {
    // 練習クエスト = type: guild の公開クエスト(先生の基礎レッスン)
    final snap = await _db
        .collection('quests')
        .where('type', isEqualTo: 'guild')
        .where('isPublished', isEqualTo: true)
        .orderBy('order')
        .get();
    return [for (final d in snap.docs) _questFromDoc(d.id, d.data())];
  }

  @override
  Future<Quest> fetchQuest(String questId) async {
    final doc = await _db.doc('quests/$questId').get();
    if (!doc.exists) throw StateError('quest/not-found');
    return _questFromDoc(doc.id, doc.data()!);
  }

  @override
  Future<void> acceptQuest(String questId) async {
    await _fn.httpsCallable('acceptQuest').call<Map<String, dynamic>>(
      {'questId': questId},
    );
  }

  @override
  Future<ReviewResult> submitForReview(
      String questId, StepAnswer submission) async {
    await _fn.httpsCallable('submitForReview').call<Map<String, dynamic>>({
      'questId': questId,
      'submission': submission.imagePath != null
          ? {'type': 'image', 'storagePath': submission.imagePath}
          : {'type': 'text', 'text': submission.text ?? ''},
    });

    // SC-25: quest_progress をポーリング(Phase 4: 強制終了→復帰でも同じ経路)。
    // 60秒で打ち切り → reviewFailed 経路(ViewModel の catch)。
    final progressRef = _db.doc('users/$_uid/quest_progress/$questId');
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final snap = await progressRef.get();
      final data = snap.data();
      if (data == null) continue;
      switch (data['status'] as String?) {
        case 'reviewed':
          return _reviewFromMap(
              (data['review'] as Map).cast<String, dynamic>());
        case 'review_failed':
          throw StateError('review/failed');
      }
    }
    throw StateError('review/timeout');
  }

  @override
  Future<DeliveryOutcome> deliverQuest(String questId) async {
    final res = await _fn
        .httpsCallable('deliverQuest')
        .call<Map<String, dynamic>>({'questId': questId});
    final data = (res.data['data'] as Map).cast<String, dynamic>();
    final rewards = (data['rewards'] as Map).cast<String, dynamic>();
    return DeliveryOutcome(
      reward: QuestReward(
        xp: (rewards['xp'] as num?)?.toInt() ?? 0,
        coins: (rewards['coins'] as num?)?.toInt() ?? 0,
        skillPoints: ((rewards['skillPoints'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      ),
      levelUpTo: ((data['levelUp'] as Map?)?['to'] as num?)?.toInt(),
      droppedKey: ((data['drops'] as Map?)?['key'] as bool?) ?? false,
      streak: ((data['streak'] as Map?)?['current'] as num?)?.toInt() ?? 0,
      nextTeaser: (data['nextTeaser'] as Map?)?['text'] as String?,
    );
  }

  // ── DTO → エンティティ(Phase 5 §2.3 スキーマと1:1) ─────────
  Quest _questFromDoc(String id, Map<String, dynamic> d) {
    return Quest(
      questId: id,
      areaId: d['areaId'] as String? ?? '',
      residentId: d['residentId'] as String? ?? '',
      residentName: d['residentName'] as String? ?? _fallbackName(d),
      type: QuestType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => QuestType.villager,
      ),
      sizeMinutes: (d['sizeMinutes'] as num?)?.toInt() ?? 7,
      title: d['title'] as String? ?? '',
      brief: d['brief'] as String? ?? '',
      reward: QuestReward(
        xp: (d['reward']?['xp'] as num?)?.toInt() ?? 0,
        coins: (d['reward']?['coins'] as num?)?.toInt() ?? 0,
        skillPoints: ((d['reward']?['skillPoints'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      ),
      steps: [
        for (final s in (d['steps'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          _stepFromMap(s),
      ],
      nextTeaser: (d['nextTeaser'] as Map?)?['text'] as String?,
      version: (d['version'] as num?)?.toInt() ?? 1,
    );
  }

  String _fallbackName(Map<String, dynamic> d) {
    // 本番は residents を join(キャッシュ)する。骨格では residentId を表示名に。
    return (d['residentId'] as String? ?? '住民').replaceFirst('res_', '');
  }

  QuestStep _stepFromMap(Map<String, dynamic> s) {
    final stepId = s['stepId'] as String;
    switch (s['kind'] as String?) {
      case 'hearing':
        return HearingStep(
          stepId: stepId,
          dialogue: [
            for (final l in (s['dialogue'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
              DialogueLine(
                  speaker: l['speaker'] as String? ?? '',
                  text: l['text'] as String? ?? ''),
          ],
          question: s['question'] as String? ?? '',
          choices: [
            for (final c in (s['choices'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
              HearingChoice(
                id: c['id'] as String,
                text: c['text'] as String? ?? '',
                score: (c['score'] as num?)?.toInt() ?? 0,
                feedback: c['feedback'] as String? ?? '',
              ),
          ],
        );
      case 'choice_text':
      case 'choice_image': // 骨格では画像選択もテキスト表示(Phase 9後半で画像UI)
        return ChoiceStep(
          stepId: stepId,
          question: s['question'] as String? ?? '',
          options: [
            for (final o in (s['options'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
              ChoiceOption(
                id: o['id'] as String,
                text: o['text'] as String? ?? '',
                correct: o['correct'] as bool? ?? false,
                feedback: o['feedback'] as String? ?? '',
              ),
          ],
        );
      case 'reorder':
        return ReorderStep(
          stepId: stepId,
          question: s['question'] as String? ?? '',
          items: (s['items'] as List? ?? const []).cast<String>(),
          answerOrder:
              (s['answerOrder'] as List? ?? const []).cast<String>(),
        );
      case 'upload':
      case 'writing':
      default:
        return SubmitStep(
          stepId: stepId,
          brief: s['brief'] as String? ?? '',
          acceptsText: s['kind'] == 'writing',
        );
    }
  }

  ReviewResult _reviewFromMap(Map<String, dynamic> r) => ReviewResult(
        goodPoints: (r['goodPoints'] as List? ?? const []).cast<String>(),
        improvements:
            (r['improvements'] as List? ?? const []).cast<String>(),
        nextAdvice: r['nextAdvice'] as String? ?? '',
        scores: ((r['scores'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}
