import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/ai_assistant_page.dart';
import '../../features/arranger/arranger_editor_page.dart';
import '../../features/arranger/arranger_library_page.dart';
import '../../features/chord/chord_query_page.dart';
import '../../features/cover/cover_band_page.dart';
import '../../features/cover/song_detail_page.dart';
import '../../features/home/home_page.dart';
import '../../features/notes/note_editor_page.dart';
import '../../features/notes/notes_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/study/study_plan_page.dart';
import '../../features/toolbox/ear_training/ear_training_page.dart';
import '../../features/toolbox/fretboard/fretboard_page.dart';
import '../../features/toolbox/metronome/metronome_page.dart';
import '../../features/toolbox/toolbox_page.dart';
import '../../features/toolbox/tuner/tuner_page.dart';

/// 路由表
///
/// v0.5 起顶层为 StatefulShellRoute（底部 4 Tab：首页 / 编曲 / 工具箱 / 我的），
/// 二级功能页挂在 shell 之外以整屏 push 打开（自带返回与播放条）。
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String chord = '/chord';
  static const String study = '/study';
  static const String ai = '/ai';
  static const String arranger = '/arranger';
  static const String arrangerEdit = '/arranger/edit';
  static const String cover = '/cover';
  static const String coverSong = '/cover/song';
  static const String toolbox = '/toolbox';
  static const String toolboxMetronome = '/toolbox/metronome';
  static const String toolboxEar = '/toolbox/ear';
  static const String toolboxFretboard = '/toolbox/fretboard';
  static const String toolboxTuner = '/toolbox/tuner';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String notes = '/notes';
  static const String noteEdit = '/notes/edit';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      // 底部导航壳：4 个相互独立、各自保活的分支。
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => _ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: home, builder: (_, __) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: arranger,
                builder: (_, __) => const ArrangerLibraryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: toolbox, builder: (_, __) => const ToolboxPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: profile, builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),
      // —— shell 之外的整屏页面 ——
      GoRoute(path: chord, builder: (_, __) => const ChordQueryPage()),
      GoRoute(path: study, builder: (_, __) => const StudyPlanPage()),
      GoRoute(path: ai, builder: (_, __) => const AiAssistantPage()),
      GoRoute(path: arrangerEdit,
          builder: (_, __) => const ArrangerEditorPage()),
      GoRoute(path: cover, builder: (_, __) => const CoverBandPage()),
      GoRoute(
        path: coverSong,
        builder: (_, state) =>
            SongDetailPage(songId: state.extra as String?),
      ),
      GoRoute(path: toolboxMetronome,
          builder: (_, __) => const MetronomePage()),
      GoRoute(path: toolboxEar, builder: (_, __) => const EarTrainingPage()),
      GoRoute(path: toolboxFretboard,
          builder: (_, __) => const FretboardPage()),
      GoRoute(path: toolboxTuner, builder: (_, __) => const TunerPage()),
      GoRoute(path: settings, builder: (_, __) => const SettingsPage()),
      GoRoute(path: notes, builder: (_, __) => const NotesPage()),
      GoRoute(
        path: noteEdit,
        builder: (_, state) =>
            NoteEditorPage(noteId: state.extra as String?),
      ),
    ],
  );
}

/// 底部导航骨架：Material 3 NavigationBar，4 个 Tab。
class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        key: const Key('app_bottom_nav'),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music_rounded),
            label: '编曲',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets_rounded),
            label: '工具箱',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
