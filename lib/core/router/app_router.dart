import 'package:go_router/go_router.dart';

import '../../features/ai/ai_assistant_page.dart';
import '../../features/arranger/arranger_page.dart';
import '../../features/chord/chord_query_page.dart';
import '../../features/cover/cover_band_page.dart';
import '../../features/home/home_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/study/study_plan_page.dart';
import '../../features/toolbox/toolbox_page.dart';

/// 路由表
///
/// 首版路由对应七大功能模块，全部挂在首页之下。
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String chord = '/chord';
  static const String study = '/study';
  static const String ai = '/ai';
  static const String arranger = '/arranger';
  static const String cover = '/cover';
  static const String toolbox = '/toolbox';
  static const String settings = '/settings';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(path: home, builder: (_, __) => const HomePage()),
      GoRoute(path: chord, builder: (_, __) => const ChordQueryPage()),
      GoRoute(path: study, builder: (_, __) => const StudyPlanPage()),
      GoRoute(path: ai, builder: (_, __) => const AiAssistantPage()),
      GoRoute(path: arranger, builder: (_, __) => const ArrangerPage()),
      GoRoute(path: cover, builder: (_, __) => const CoverBandPage()),
      GoRoute(path: toolbox, builder: (_, __) => const ToolboxPage()),
      GoRoute(path: settings, builder: (_, __) => const SettingsPage()),
    ],
  );
}
