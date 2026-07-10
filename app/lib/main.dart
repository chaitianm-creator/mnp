import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "core/firebase/firebase_bootstrap.dart";
import "core/router/app_router.dart";
import "core/theme/kd_theme.dart";
import "features/quest/data/firestore_quest_repository.dart";
import "features/quest/presentation/view_models/quest_play_view_model.dart";

class DesignKingdomApp extends StatelessWidget {
  const DesignKingdomApp({super.key, this.onboardingDone = true});
  final bool onboardingDone;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "デザイン王国",
      theme: KdTheme.light(),
      // Phase 8 §3.2: ダークモード非対応(羊皮紙の世界観維持のためライト固定)
      themeMode: ThemeMode.light,
      routerConfig: createRouter(onboardingDone: onboardingDone),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase(); // USE_FIREBASE=false なら no-op(DEMOモード)

  // Phase 4 §1 起動分岐: オンボーディング未完了なら /welcome へ
  bool onboardingDone = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool("onboarding_done") ?? false;
  } catch (_) {}

  runApp(ProviderScope(
    overrides: [
      if (useFirebase)
        questRepositoryProvider.overrideWith(
          (ref) => FirestoreQuestRepository(),
        ),
    ],
    child: DesignKingdomApp(onboardingDone: onboardingDone),
  ));
}
