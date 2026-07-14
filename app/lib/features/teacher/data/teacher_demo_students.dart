import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 先生画面用の生徒データ(DEMO: メモリ保持)。
/// 本番は users(role=student) + submissions + teacherNotes の購読に差し替える。
/// メールなどのPIIは詳細画面でもマスク表示する(account.dart の maskEmail)。
class StudentSubmission {
  const StudentSubmission({
    required this.questTitle,
    required this.status, // waiting(添削待ち) / reviewed(添削済み) / resubmit(再提出依頼中)
    required this.submittedAt,
    this.comment,
  });
  final String questTitle;
  final String status;
  final String submittedAt;
  final String? comment;

  StudentSubmission copyWith({String? status, String? comment}) =>
      StudentSubmission(
        questTitle: questTitle,
        status: status ?? this.status,
        submittedAt: submittedAt,
        comment: comment ?? this.comment,
      );
}

class DemoStudent {
  const DemoStudent({
    required this.id,
    required this.nickname,
    required this.email,
    required this.level,
    required this.xp,
    required this.streak,
    required this.practiceCleared,
    required this.deliveredCount,
    required this.lastLogin,
    required this.learningInterests,
    this.isActive = true,
    this.submissions = const [],
    this.teacherNote = '',
    this.assignedQuest,
  });

  final String id;
  final String nickname;
  final String email;
  final int level;
  final int xp;
  final int streak;
  final int practiceCleared;
  final int deliveredCount;
  final String lastLogin;
  final List<String> learningInterests;
  final bool isActive;
  final List<StudentSubmission> submissions;
  final String teacherNote;
  final String? assignedQuest;

  DemoStudent copyWith({
    bool? isActive,
    List<StudentSubmission>? submissions,
    String? teacherNote,
    String? assignedQuest,
  }) =>
      DemoStudent(
        id: id,
        nickname: nickname,
        email: email,
        level: level,
        xp: xp,
        streak: streak,
        practiceCleared: practiceCleared,
        deliveredCount: deliveredCount,
        lastLogin: lastLogin,
        learningInterests: learningInterests,
        isActive: isActive ?? this.isActive,
        submissions: submissions ?? this.submissions,
        teacherNote: teacherNote ?? this.teacherNote,
        assignedQuest: assignedQuest ?? this.assignedQuest,
      );
}

const _seedStudents = [
  DemoStudent(
    id: 'stu_01',
    nickname: 'さくらこ',
    email: 'sakurako@example.com',
    level: 3,
    xp: 260,
    streak: 6,
    practiceCleared: 3,
    deliveredCount: 4,
    lastLogin: 'きょう 09:12',
    learningInterests: ['バナー', 'SNS画像'],
    submissions: [
      StudentSubmission(
          questTitle: '新商品『もちもち王国パン』のPOP',
          status: 'waiting',
          submittedAt: 'きょう 09:05'),
      StudentSubmission(
          questTitle: 'お店の看板、どっちがいい？',
          status: 'reviewed',
          submittedAt: 'きのう 18:30',
          comment: '色のコントラストが良くなりました！'),
    ],
  ),
  DemoStudent(
    id: 'stu_02',
    nickname: 'ゆうた',
    email: 'yuta.design@example.com',
    level: 2,
    xp: 130,
    streak: 2,
    practiceCleared: 2,
    deliveredCount: 1,
    lastLogin: 'きょう 07:48',
    learningInterests: ['チラシ', 'POP'],
    submissions: [
      StudentSubmission(
          questTitle: 'はじめの一歩　文字を見やすく並べてみよう',
          status: 'reviewed',
          submittedAt: '2日前',
          comment: '優先順位のつけ方がバッチリです'),
    ],
  ),
  DemoStudent(
    id: 'stu_03',
    nickname: 'みおん',
    email: 'mion_87@example.com',
    level: 1,
    xp: 45,
    streak: 1,
    practiceCleared: 1,
    deliveredCount: 0,
    lastLogin: 'きのう 21:15',
    learningInterests: ['ロゴ', 'Webデザイン'],
  ),
  DemoStudent(
    id: 'stu_04',
    nickname: 'けんじ',
    email: 'kenji.works@example.com',
    level: 4,
    xp: 410,
    streak: 12,
    practiceCleared: 3,
    deliveredCount: 7,
    lastLogin: 'きょう 06:02',
    learningInterests: ['POP', 'チラシ', 'バナー'],
    submissions: [
      StudentSubmission(
          questTitle: '美容室のメニュー表デザイン',
          status: 'waiting',
          submittedAt: 'きょう 05:58'),
    ],
  ),
  DemoStudent(
    id: 'stu_05',
    nickname: 'あかり',
    email: 'akari.pn@example.com',
    level: 1,
    xp: 15,
    streak: 0,
    practiceCleared: 0,
    deliveredCount: 0,
    lastLogin: '5日前',
    learningInterests: ['SNS画像'],
    isActive: false,
  ),
];

class TeacherStudentsNotifier extends Notifier<List<DemoStudent>> {
  @override
  List<DemoStudent> build() => _seedStudents;

  DemoStudent? byId(String id) =>
      state.where((s) => s.id == id).firstOrNull;

  void _update(String id, DemoStudent Function(DemoStudent) fn) {
    state = [for (final s in state) s.id == id ? fn(s) : s];
  }

  void addComment(String id, int submissionIndex, String comment) {
    _update(id, (s) {
      final subs = [...s.submissions];
      subs[submissionIndex] = subs[submissionIndex]
          .copyWith(status: 'reviewed', comment: comment);
      return s.copyWith(submissions: subs);
    });
  }

  void requestResubmission(String id, int submissionIndex) {
    _update(id, (s) {
      final subs = [...s.submissions];
      subs[submissionIndex] =
          subs[submissionIndex].copyWith(status: 'resubmit');
      return s.copyWith(submissions: subs);
    });
  }

  void assignQuest(String id, String questTitle) =>
      _update(id, (s) => s.copyWith(assignedQuest: questTitle));

  void setSuspended(String id, bool suspended) =>
      _update(id, (s) => s.copyWith(isActive: !suspended));

  void saveNote(String id, String note) =>
      _update(id, (s) => s.copyWith(teacherNote: note));
}

final teacherStudentsProvider =
    NotifierProvider<TeacherStudentsNotifier, List<DemoStudent>>(
        TeacherStudentsNotifier.new);
