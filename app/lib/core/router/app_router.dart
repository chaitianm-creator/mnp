import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../features/growth/placeholder_pages.dart";
import "../../features/home/presentation/daily_request_page.dart";
import "../../features/home/presentation/home_page.dart";
import "../../features/home/presentation/notices_page.dart";
import "../../features/onboarding/presentation/enrollment_complete_page.dart";
import "../../features/onboarding/presentation/goal_page.dart";
import "../../features/onboarding/presentation/guild_page.dart";
import "../../features/onboarding/presentation/meeting_page.dart";
import "../../features/onboarding/presentation/story_player_page.dart";
import "../../features/onboarding/presentation/student_register_page.dart";
import "../../features/onboarding/presentation/teacher_login_page.dart";
import "../../features/onboarding/presentation/welcome_page.dart";
import "../../features/quest/presentation/pages/practice_quests_page.dart";
import "../../features/quest/presentation/pages/quest_play_page.dart";
import "../../features/settings/presentation/settings_page.dart";
import "../../features/teacher/presentation/teacher_pages.dart";
import "../../features/workshop/presentation/workshop_page.dart";
import "../../features/world/presentation/island_field_page.dart";
import "../../features/world/presentation/village_page.dart";
import "../../features/world/presentation/world_map_page.dart";
import "../theme/kd_colors.dart";

/// Phase 3 §0: ボトムタブ4つ / 起動分岐は main.dart の resolveInitialLocation。
final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({required String initialLocation}) => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        // ── オンボーディング(シェル外) ──
        GoRoute(
          path: "/welcome", // SC-02 タイトル画面
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const WelcomePage(),
        ),
        GoRoute(
          path: "/story/:ep", // SC-02b オンボーディング(表紙→1〜17ページ→島)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) =>
              StoryPlayerPage(episodeId: state.pathParameters["ep"]!),
        ),
        GoRoute(
          path: "/meeting", // SC-03 みぽりん先生との出会い(初回のみ/設定から再生可)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) =>
              MeetingPage(replay: state.uri.queryParameters["replay"] == "1"),
        ),
        GoRoute(
          path: "/student-register", // SC-04 入団手続き(生徒登録)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const StudentRegisterPage(),
        ),
        GoRoute(
          path: "/enrollment-complete", // SC-05 入団完了
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const EnrollmentCompletePage(),
        ),
        GoRoute(
          path: "/teacher-login", // 先生・スタッフ用(DEMO: 先生コード)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const TeacherLoginPage(),
        ),
        GoRoute(
          path: "/goal", // SC-06 (旧フロー互換)
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
          path: "/quests", // 練習クエスト一覧
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const PracticeQuestsPage(),
        ),
        GoRoute(
          path: "/daily-request", // 今日の依頼(練習3つクリアで解放)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const DailyRequestPage(),
        ),
        GoRoute(
          path: "/workshop", // 工房(つくったもの)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const WorkshopPage(),
        ),
        GoRoute(
          path: "/notices", // お知らせ
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const NoticesPage(),
        ),
        GoRoute(
          path: "/progress", // 成長記録(スキルタブへ)
          redirect: (_, __) => "/skills",
        ),
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
          path: "/island", // 実践デザイナー島の村フィールド(タイルマップ試作)
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const IslandFieldPage(),
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
        // ── 先生用(シェル外・roleガードは各ページ内) ──
        GoRoute(
          path: "/teacher",
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const TeacherDashboardPage(),
        ),
        GoRoute(
          path: "/teacher/students",
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, __) => const TeacherStudentsPage(),
        ),
        GoRoute(
          path: "/teacher/students/:id",
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) =>
              TeacherStudentDetailPage(studentId: state.pathParameters["id"]!),
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
