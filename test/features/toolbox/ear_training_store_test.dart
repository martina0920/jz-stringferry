import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/theory/ear_training.dart';
import 'package:jz_stringferry/data/ear_training_repository.dart';
import 'package:jz_stringferry/features/toolbox/ear_training/state/ear_training_store.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

class _FakePlayer implements TonePlayer {
  final List<String> played = [];

  @override
  Future<void> playAsset(String assetPath) async => played.add(assetPath);

  @override
  Future<void> stopAll() async {}
}

class _RecordingScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }

  void fireAll() {
    for (final s in scheduled.where((s) => !s.isCanceled).toList()) {
      s.callback();
    }
  }
}

/// 固定出根音 60 的题；各模式给出播放所需的完整字段。
class _StubGen extends EarQuizGenerator {
  _StubGen() : super(random: Random(1));

  @override
  EarQuestion next(EarMode mode) => switch (mode) {
        EarMode.interval => const EarQuestion(
            mode: EarMode.interval,
            rootMidi: 60,
            secondMidi: 62,
            answer: Interval.minor2,
          ),
        EarMode.chordQuality => const EarQuestion(
            mode: EarMode.chordQuality,
            rootMidi: 60,
            answer: ChordQualityQuiz.major,
          ),
        EarMode.scale => const EarQuestion(
            mode: EarMode.scale,
            rootMidi: 60,
            answer: ScaleQuiz.major,
          ),
        EarMode.rhythm => EarQuestion(
            mode: EarMode.rhythm,
            rootMidi: -1,
            answer: List<bool>.filled(8, true),
            rhythmGrid: List<bool>.filled(8, true),
          ),
        _ => const EarQuestion(mode: EarMode.singleNote, rootMidi: 60,
            answer: 60),
      };
}

void main() {
  setUpAll(() => sqfliteFfiInit());

  late AppDatabase appDb;
  late _FakePlayer player;
  late _RecordingScheduler scheduler;
  late GuitarAudioService audio;
  late EarTrainingStore store;
  late EarTrainingRepository repo;

  setUp(() async {
    appDb = AppDatabase.instance;
    await appDb.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    player = _FakePlayer();
    scheduler = _RecordingScheduler();
    audio = GuitarAudioService(player, scheduler: scheduler);
    repo = EarTrainingRepository(appDb.database);
    store = EarTrainingStore(
      generator: _StubGen(),
      audio: audio,
      statsRepo: repo,
    );
  });

  test('nextQuestion：出题并调度播放，未答状态', () async {
    store.nextQuestion();
    expect(store.question, isNotNull);
    expect(store.question!.mode, EarMode.singleNote);
    expect(store.lastCorrect, isNull);

    // 延迟 0 的播放任务落地后触发调度器
    await Future<void>.delayed(Duration.zero);
    scheduler.fireAll();
    expect(player.played, isNotEmpty);
    expect(player.played.first, 'assets/audio/guitar/60.wav');
  });

  test('submit 答对：计数入库 lastCorrect=true', () async {
    store.nextQuestion();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // AppDatabase 单例使内存库跨测试共享，统计断言用增量。
    final before = await repo.dayStats(today);
    await store.submit(60);
    expect(store.lastCorrect, isTrue);
    expect(store.correct, 1);
    expect(store.total, 1);

    final after = await repo.dayStats(today);
    final b = before['single'] ?? (0, 0);
    final a = after['single'] ?? (0, 0);
    expect(a.$1 - b.$1, 1);
    expect(a.$2 - b.$2, 1);
  });

  test('submit 答错：total 增 correct 不变，入库 correct=0', () async {
    store.nextQuestion();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final before = await repo.dayStats(today);
    await store.submit(61);
    expect(store.lastCorrect, isFalse);
    expect(store.correct, 0);
    expect(store.total, 1);

    final after = await repo.dayStats(today);
    final b = before['single'] ?? (0, 0);
    final a = after['single'] ?? (0, 0);
    expect(a.$1 - b.$1, 0);
    expect(a.$2 - b.$2, 1);
  });

  test('同一题重复 submit 被忽略', () async {
    store.nextQuestion();
    await store.submit(60);
    await store.submit(61);
    expect(store.total, 1);
    expect(store.correct, 1);
  });

  test('无题时 submit 无效果', () async {
    await store.submit(60);
    expect(store.total, 0);
  });

  test('setMode 清空题目与答题状态', () async {
    store.nextQuestion();
    await store.submit(60);
    store.setMode(EarMode.interval);
    expect(store.mode, EarMode.interval);
    expect(store.question, isNull);
    expect(store.lastCorrect, isNull);

    // 新题按新模式出
    store.nextQuestion();
    expect(store.question!.mode, EarMode.interval);
  });
}
