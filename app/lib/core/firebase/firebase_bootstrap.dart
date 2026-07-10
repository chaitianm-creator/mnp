import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:cloud_functions/cloud_functions.dart";

/// --dart-define=USE_FIREBASE=true で本番モード。
/// 未指定(デフォルト)は DEMO モード = Firebase を初期化しない。
const useFirebase = bool.fromEnvironment("USE_FIREBASE");

/// 匿名認証(US-E1-02: 登録前に体験クエスト → 後に本認証へリンク昇格)。
Future<void> bootstrapFirebase() async {
  if (!useFirebase) return;
  // 事前に `flutterfire configure` で firebase_options.dart を生成し、
  // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform) に差し替える。
  await Firebase.initializeApp();
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  // 初期ユーザードキュメント(冪等)
  await FirebaseFunctions.instanceFor(region: "asia-northeast1")
      .httpsCallable("initUser")
      .call<Map<String, dynamic>>();
  // TODO(phase10次段): App Check activate / Analytics / Messaging
}

/// SC-54 退会: deleteAccount(Functions) を呼び、Authからもサインアウト。
Future<void> callDeleteAccount() async {
  if (!useFirebase) return;
  await FirebaseFunctions.instanceFor(region: "asia-northeast1")
      .httpsCallable("deleteAccount")
      .call<Map<String, dynamic>>();
  await FirebaseAuth.instance.signOut();
}
