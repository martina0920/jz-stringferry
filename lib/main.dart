import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/audio/just_audio_tone_player.dart';
import 'core/audio/local_audio_player.dart';
import 'core/audio/progression_player.dart';
import 'core/db/app_database.dart';
import 'core/db/database_provider.dart';
import 'data/chat_service.dart';
import 'data/chord_collection_repository.dart';
import 'data/chord_repository.dart';
import 'data/chord_seeder.dart';
import 'data/plan_templates.dart';
import 'data/progression_repository.dart';
import 'data/qwen_omni_transcribe_service.dart';
import 'data/settings_repository.dart';
import 'data/study_repository.dart';
import 'data/transcribe_service.dart';
import 'data/transcribe_song_repository.dart';
import 'features/arranger/state/arranger_store.dart';
import 'features/chord/state/chord_collection_store.dart';
import 'features/cover/audio_import_source.dart';
import 'features/cover/recording_source.dart';
import 'features/cover/state/cover_store.dart';
import 'features/study/state/study_plan_store.dart';
import 'features/toolbox/metronome/state/metronome_store.dart';
import 'features/toolbox/tuner/state/tuner_store.dart';
import 'features/toolbox/tuner/tuner_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await AppDatabase.instance.init();
    // 首次启动写入 510 条程序化生成的和弦库（已存在则跳过）。
    await ChordSeeder.seedIfEmpty(AppDatabase.instance.database);
    // 首次启动导入 2025 学习计划模板（四类九条，已存在则跳过）。
    await PlanTemplates.importIfEmpty(AppDatabase.instance.database);
  } catch (e) {
    initError = e;
  }

  runApp(
    initError == null
        ? MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DatabaseProvider()),
              ChangeNotifierProvider(
                create: (_) => ChordCollectionStore(
                  ChordCollectionRepository(AppDatabase.instance.database),
                )..load(),
              ),
              ChangeNotifierProvider(
                create: (_) => StudyPlanStore(
                  StudyRepository(AppDatabase.instance.database),
                )..load(),
              ),
              ChangeNotifierProvider(
                create: (_) => ArrangerStore(
                  repo: ProgressionRepository(
                      AppDatabase.instance.database),
                  chordRepo:
                      ChordRepository(AppDatabase.instance.database),
                  player: ProgressionPlayer(JustAudioTonePlayer()),
                )..loadList(),
              ),
              Provider<ChatService>(
                create: (_) => LocalChatService(
                  chordRepo: ChordRepository(AppDatabase.instance.database),
                ),
              ),
              // ---- v0.4 工具箱 / 扒带 ----
              ChangeNotifierProvider(
                create: (_) => MetronomeStore(JustAudioTonePlayer()),
              ),
              ChangeNotifierProvider(
                create: (_) => TunerStore(
                  source: RecordTunerSource(),
                  player: JustAudioTonePlayer(),
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => CoverStore(
                  repo: TranscribeSongRepository(
                      AppDatabase.instance.database),
                  importSource: FilePickerAudioImportSource(),
                  recordingSource: MicRecordingSource(),
                  probeDurationMs: _probeAudioDurationMs,
                )..load(),
              ),
              Provider<SettingsRepository>(
                create: (_) =>
                    SettingsRepository(AppDatabase.instance.database),
              ),
              Provider<TranscribeService>(
                create: (_) => QwenOmniTranscribeService(),
              ),
            ],
            child: const JzStringFerryApp(),
          )
        : _BootErrorApp(error: initError),
  );
}

/// 用 just_audio 探测音频文件时长（毫秒）；失败返回 0。
Future<int> _probeAudioDurationMs(String path) async {
  final probe = JustAudioLocalPlayer();
  try {
    return await probe.setFilePath(path);
  } catch (_) {
    return 0;
  } finally {
    await probe.disposePlayer();
  }
}

/// 数据库初始化失败时的兜底页：避免白屏，给出可重试之外的明确提示。
class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '本地数据库初始化失败',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                const Text(
                  '请重启应用；若反复出现，请在设置中尝试「恢复示例数据」或重新安装。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
