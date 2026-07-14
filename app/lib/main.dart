import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "core/firebase/firebase_bootstrap.dart";
import "core/router/app_router.dart";
import "core/state/account.dart";
import "core/state/user_progress.dart";
import "core/theme/kd_theme.dart";
import "features/quest/data/firestore_quest_repository.dart";
import "features/quest/presentation/view_models/quest_play_view_model.dart";

class DesignKingdomApp extends StatelessWidget {
  const DesignKingdomApp({super.key, this.initialLocation = "/home"});
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "デザイン王国",
      theme: KdTheme.light(),
      // Phase 8 §3.2: ダークモード非対応(羊皮紙の世界観維持のためライト固定)
      themeMode: ThemeMode.light,
      routerConfig: createRouter(initialLocation: initialLocation),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 起動分岐:
///   未ログイン(アカウントなし) → /welcome
///   登録が途中(onboardingCompleted=false) → /student-register
///   role=teacher/admin → /teacher
///   生徒 → /home
String resolveInitialLocation(UserAccount? account) {
  if (account == null) return "/welcome";
  if (!account.onboardingCompleted) return "/student-register";
  if (account.isTeacher) return "/teacher";
  return "/home";
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase(); // USE_FIREBASE=false なら no-op(DEMOモード)

  UserAccount? account;
  UserProgress progress = const UserProgress(streak: 1);
  try {
    final prefs = await SharedPreferences.getInstance();
    final accountJson = prefs.getString(kAccountPrefsKey);
    if (accountJson != null) {
      account = UserAccount.fromJson(
          (jsonDecode(accountJson) as Map).cast<String, dynamic>());
    }
    final progressJson = prefs.getString(kProgressPrefsKey);
    if (progressJson != null) {
      progress = UserProgress.fromJson(
          (jsonDecode(progressJson) as Map).cast<String, dynamic>());
    }
  } catch (_) {}

  runApp(ProviderScope(
    overrides: [
      initialAccountProvider.overrideWithValue(account),
      initialProgressProvider.overrideWithValue(progress),
      if (useFirebase)
        questRepositoryProvider.overrideWith(
          (ref) => FirestoreQuestRepository(),
        ),
    ],
    child: DesignKingdomApp(initialLocation: resolveInitialLocation(account)),
  ));
}
