import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 入団手続きの「配布パスワード」設定と照合ロジック。
///
/// ★ 配布パスワードを変更する場合はここ(kDistributedPassword)を書き換える。
/// 画面ファイルにはパスワードを直接書かない。
const String kDistributedPassword = '2026';

/// 先生・スタッフ用ログインの先生コード(DEMO)。
/// 画面には表示しない。変更する場合はここを書き換える。
/// 本番は Firebase Auth + custom claims に置き換える。
const String kTeacherCode = 'sensei';

/// 配布パスワード照合の抽象。
/// 将来 Firebase Functions(招待コード検証 Callable) や Firestore の
/// 招待コードコレクション照合に差し替えるときは、この interface を実装した
/// クラスを作り enrollmentCodeVerifierProvider を override するだけでよい。
abstract interface class EnrollmentCodeVerifier {
  /// [rawInput] の前後空白を除去したうえで照合する。
  /// 大文字・小文字は区別する(完全一致)。
  Future<bool> verify(String rawInput);
}

/// DEMO実装: 固定パスワード方式。
class FixedEnrollmentCodeVerifier implements EnrollmentCodeVerifier {
  const FixedEnrollmentCodeVerifier();

  @override
  Future<bool> verify(String rawInput) async =>
      rawInput.trim() == kDistributedPassword;
}

final enrollmentCodeVerifierProvider = Provider<EnrollmentCodeVerifier>(
    (_) => const FixedEnrollmentCodeVerifier());
