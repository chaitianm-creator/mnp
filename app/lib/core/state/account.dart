import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アカウント(役割つき)。DEMO: SharedPreferences に JSON で永続化。
/// 本番は Firebase Auth + users/{userId} (下記スキーマ) に差し替える:
///   users/{userId}: role, nickname, email, avatarId, designExperience,
///     learningInterests[], level, xp, coins, streakDays, completedQuestIds[],
///     currentQuestId, createdAt, lastLoginAt, isActive, onboardingCompleted
/// 注意: role は本番では custom claims(サーバー付与)で判定し、
/// クライアント側の値は表示分岐のみに使う(firestore.rules 参照)。
enum UserRole { student, teacher, admin }

/// 診断タイプ(入団手続きの「つよみ・よわみ」)。
enum DiagnosisType { warrior, mage, priest, merchant }

extension DiagnosisTypeLabel on DiagnosisType {
  String get label => switch (this) {
        DiagnosisType.warrior => '戦士',
        DiagnosisType.mage => '魔法使い',
        DiagnosisType.priest => '僧侶',
        DiagnosisType.merchant => '商人',
      };

  String get trait => switch (this) {
        DiagnosisType.warrior => 'つき進む行動力',
        DiagnosisType.mage => 'ひらめきと発想力',
        DiagnosisType.priest => 'ていねいさと思いやり',
        DiagnosisType.merchant => '伝える力とお客さん目線',
      };
}

class UserAccount {
  const UserAccount({
    required this.role,
    required this.nickname,
    required this.email,
    this.avatarId = 'avatar_01',
    this.strongType,
    this.weakType,
    this.designExperience,
    this.learningInterests = const [],
    this.onboardingCompleted = false,
    this.isActive = true,
    this.createdAt,
    this.lastLoginAt,
  });

  final UserRole role;
  final String nickname;
  final String email;
  final String avatarId;
  final DiagnosisType? strongType; // 診断: つよみ
  final DiagnosisType? weakType; // 診断: よわみ
  final String? designExperience; // none / little / work / pro
  final List<String> learningInterests; // banner / sns / flyer / pop / web / logo / other
  final bool onboardingCompleted;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  bool get isTeacher => role == UserRole.teacher || role == UserRole.admin;

  UserAccount copyWith({
    bool? onboardingCompleted,
    DateTime? lastLoginAt,
  }) =>
      UserAccount(
        role: role,
        nickname: nickname,
        email: email,
        avatarId: avatarId,
        strongType: strongType,
        weakType: weakType,
        designExperience: designExperience,
        learningInterests: learningInterests,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        isActive: isActive,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'nickname': nickname,
        'email': email,
        'avatarId': avatarId,
        'strongType': strongType?.name,
        'weakType': weakType?.name,
        'designExperience': designExperience,
        'learningInterests': learningInterests,
        'onboardingCompleted': onboardingCompleted,
        'isActive': isActive,
        'createdAt': createdAt?.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
      };

  static UserAccount? fromJson(Map<String, dynamic> j) {
    final nickname = j['nickname'] as String?;
    if (nickname == null) return null;
    DiagnosisType? diag(String? v) => v == null
        ? null
        : DiagnosisType.values.where((d) => d.name == v).firstOrNull;
    return UserAccount(
      role: UserRole.values.firstWhere((r) => r.name == j['role'],
          orElse: () => UserRole.student),
      nickname: nickname,
      email: j['email'] as String? ?? '',
      avatarId: j['avatarId'] as String? ?? 'avatar_01',
      strongType: diag(j['strongType'] as String?),
      weakType: diag(j['weakType'] as String?),
      designExperience: j['designExperience'] as String?,
      learningInterests:
          (j['learningInterests'] as List? ?? const []).cast<String>(),
      onboardingCompleted: j['onboardingCompleted'] as bool? ?? false,
      isActive: j['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      lastLoginAt: DateTime.tryParse(j['lastLoginAt'] as String? ?? ''),
    );
  }
}

/// メールのマスク表示(PII保護: 一覧などでフル表示しない)。
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return '***${email.substring(at < 0 ? email.length : at)}';
  return '${email[0]}***${email.substring(at)}';
}

const kAccountPrefsKey = 'account_json';

/// 起動時に main() が読み込んだアカウント(ProviderScope override で注入)。
final initialAccountProvider = Provider<UserAccount?>((_) => null);

class AccountNotifier extends Notifier<UserAccount?> {
  @override
  UserAccount? build() => ref.watch(initialAccountProvider);

  /// 保存失敗(テスト環境等)でも操作は止めない。
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = state;
      if (a == null) {
        await prefs.remove(kAccountPrefsKey);
      } else {
        await prefs.setString(kAccountPrefsKey, jsonEncode(a.toJson()));
      }
    } catch (_) {}
  }

  /// 入団手続き(生徒登録)。本番は Auth 作成 + onUserCreated(Functions)。
  Future<void> registerStudent(UserAccount account) async {
    state = account;
    await _persist();
  }

  /// 先生ログイン(DEMO: 先生コード一致でローカルに teacher アカウント作成)。
  Future<void> loginTeacher({required String nickname}) async {
    state = UserAccount(
      role: UserRole.teacher,
      nickname: nickname,
      email: '',
      onboardingCompleted: true,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    await _persist();
  }

  /// ログアウト(アカウントのみ削除。進捗は端末に残す)。
  Future<void> logout() async {
    state = null;
    await _persist();
  }

  /// 入団完了画面で押した瞬間に確定(以降の起動は /home へ)。
  Future<void> completeOnboarding() async {
    state = state?.copyWith(onboardingCompleted: true);
    await _persist();
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, UserAccount?>(AccountNotifier.new);
