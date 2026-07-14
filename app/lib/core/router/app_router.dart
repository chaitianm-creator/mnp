import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../features/growth/placeholder_pages.dart";
import "../../features/home/presentation/home_page.dart";
import "../../features/onboarding/presentation/goal_page.dart";
import "../../features/onboarding/presentation/guild_page.dart";
import "../../features/onboarding/presentation/welcome_page.dart";
import "../../features/quest/presentation/pages/quest_play_page.dart";
import "../../features/settings/presentation/settings_page.dart";
import "../../features/world/presentation/village_page.dart";
import "../../features/world/presentation/world_map_page.dart";
import "../theme/kd_colors.dart";

/// Phase 3 §0: ボトムタブ4つ / Phase 4 §1: 起動分岐(オンボーディング未完了→/welcome)。
final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({required bool onboardingDone}) => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: onboardingDone ? "/home" : "/welcome",
      routes: [
        // ── オンボーディング(シェル外) ──
        GoRoute(
          path: "/welcome", // SC-02
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const WelcomePage(),
        ),
        GoRoute(
          path: "/goal", // SC-06
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const GoalPage(),
        ),
        GoRoute(
          path: "/guild", // SC-07 ギルド入団(物語パート)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const GuildPage(),
        ),
        // ── 4タブシェル ──
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: "/home", builder: (_, __) => const HomePage()), // SC-10
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: "/map", builder: (_, __) => const WorldMapPage()), // SC-30
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: "/skills", builder: (_, __) => const SkillsPage()), // SC-40
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: "/profile", builder: (_, __) => const ProfilePage()), // SC-50
            ]),
          ],
        ),
        // ── フルスクリーン(シェル外) ──
        GoRoute(
          path: "/quest/:id", // SC-20〜28
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) =>
              QuestPlayPage(questId: state.pathParameters["id"]!),
        ),
        GoRoute(
          path: "/area/:id", // SC-31(エリアガイド)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) =>
              AreaDetailPage(areaId: state.pathParameters["id"]!),
        ),
        GoRoute(
          path: "/village", // SC-31(みぽりん村の町ビュー)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const VillagePage(),
        ),
        GoRoute(
          path: "/settings", // SC-53/54
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const SettingsPage(),
        ),
      ],
    );

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: KdColors.surface,
        indicatorColor: KdColors.pink100,
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: "ホーム"),
          NavigationDestination(icon: Icon(Icons.map), label: "マップ"),
          NavigationDestination(icon: Icon(Icons.park), label: "スキル"),
          NavigationDestination(icon: Icon(Icons.person), label: "わたし"),
        ],
      ),
    );
  }
}
