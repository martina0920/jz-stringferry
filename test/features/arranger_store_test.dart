import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/progression_player.dart';
import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/theory/key_harmony.dart';
import 'package:jz_stringferry/core/theory/progression_template.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';
import 'package:jz_stringferry/data/progression_repository.dart';
import 'package:jz_stringferry/features/arranger/state/arranger_store.dart';

class _FakePlayer implements TonePlayer {
  int stopCount = 0;
  @override
  Future<void> playAsset(String assetPath) async {}
  @override
  Future<void> stopAll() async => stopCount++;
}

class _RecordingScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];
  final Set<ScheduledTone> _fired = {};

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }

  void fireUpTo(Duration maxDelay) {
    final snapshot = scheduled
        .where((s) =>
            !s.isCanceled && !_fired.contains(s) && s.delay <= maxDelay)
        .toList();
    for (final s in snapshot) {
      _fired.add(s);
      if (!s.isCanceled) s.callback();
    }
  }
}

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('ArrangerStore 曲库与编辑（FR-6/FR-10/FR-15，AC-4）', () {
    late AppDatabase appDb;
    late ArrangerStore store;
    late ProgressionRepository repo;
    late _RecordingScheduler scheduler;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      await ChordSeeder.seedIfEmpty(appDb.database);
      repo = ProgressionRepository(appDb.database);
      scheduler = _RecordingScheduler();
      store = ArrangerStore(
        repo: repo,
        chordRepo: ChordRepository(appDb.database),
        player: ProgressionPlayer(_FakePlayer(), scheduler: scheduler),
      );
    });

    tearDown(() async {
      store.dispose();
      await appDb.disposeForTest();
    });

    test('模板新建：current 与 items 正确', () async {
      final p = await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      expect(p.chords, ['C', 'Am', 'F', 'G']);
      expect(store.current!.chords, ['C', 'Am', 'F', 'G']);
      expect(store.items.length, 1);
      expect(store.items.first.title, '1645 流行进行');
    });

    test('changeKey C→Bb 同模式转调并落库（FR-4，AC-2）', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      await store.changeKey(const MusicKey(10, KeyMode.major));
      expect(store.current!.chords, ['Bb', 'Gm', 'Eb', 'F']);
      expect(store.current!.keyRootPc, 10);

      final reloaded = await repo.byId(store.current!.id);
      expect(reloaded!.chords, ['Bb', 'Gm', 'Eb', 'F']);
      expect(reloaded.keyRootPc, 10);
    });

    test('大→小切换模式：只改 mode，不重写序列', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      await store.changeKey(const MusicKey(9, KeyMode.minor));
      expect(store.current!.keyMode, KeyMode.minor);
      expect(store.current!.keyRootPc, 9);
      expect(store.current!.chords, ['C', 'Am', 'F', 'G']);
    });

    test('add/remove/reorder 后重新 open 数据一致', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      final id = store.current!.id;

      expect(await store.addChord('Dm'), isTrue);
      await store.removeAt(0); // 去掉 C
      await store.reorder(0, 2); // [Am,F,G,Dm] → [F,G,Am,Dm]

      await store.open(id);
      expect(store.current!.chords, ['F', 'G', 'Am', 'Dm']);
    });

    test('32 和弦上限（FR-10）', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      await store.replaceAll(List<String>.filled(32, 'C'));
      expect(store.current!.chords.length, 32);
      expect(await store.addChord('G'), isFalse);
      expect(store.current!.chords.length, 32);
    });

    test('空白草稿首次编辑才入库', () async {
      final p = await store.createBlank();
      expect(await repo.byId(p.id), isNull);
      await store.addChord('C');
      expect(await repo.byId(p.id), isNotNull);
      expect(store.items.length, 1);
    });

    test('BPM 夹紧 40–200（FR-7）', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      await store.setBpm(10);
      expect(store.current!.bpm, 40);
      await store.setBpm(999);
      expect(store.current!.bpm, 200);
    });

    test('duplicate / remove 曲库操作', () async {
      final p = await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      await store.duplicate(p.id);
      expect(store.items.length, 2);
      expect(store.items.any((e) => e.title == '1645 流行进行 副本'), isTrue);

      await store.remove(p.id);
      expect(store.items.length, 1);
      expect(store.current, isNull);
    });
  });

  group('ArrangerStore 播放联动（FR-9/FR-17，AC-5）', () {
    late AppDatabase appDb;
    late ArrangerStore store;
    late _FakePlayer fakePlayer;
    late _RecordingScheduler scheduler;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      await ChordSeeder.seedIfEmpty(appDb.database);
      fakePlayer = _FakePlayer();
      scheduler = _RecordingScheduler();
      store = ArrangerStore(
        repo: ProgressionRepository(appDb.database),
        chordRepo: ChordRepository(appDb.database),
        player: ProgressionPlayer(fakePlayer, scheduler: scheduler),
      );
    });

    tearDown(() async {
      store.dispose();
      await appDb.disposeForTest();
    });

    test('playCurrent：播放态与高亮回调；stop 复位', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      final highlights = <int>[];
      store.addListener(() {
        if (store.highlightIndex >= 0) highlights.add(store.highlightIndex);
      });

      await store.playCurrent();
      expect(store.isPlaying, isTrue);
      expect(store.canPlay, isFalse);

      // 1645 = 4 和弦 × 4 拍 × 666.67ms ≈ 10667ms/遍。
      scheduler.fireUpTo(const Duration(milliseconds: 10667));
      expect(highlights, [0, 1, 2, 3]);
      expect(store.highlightIndex, 3);

      await store.stopPlay();
      expect(store.isPlaying, isFalse);
      expect(store.highlightIndex, noChordHighlight);
      expect(fakePlayer.stopCount, greaterThanOrEqualTo(1));
    });

    test('播放中编辑（setBpm）自动停止（FR-17）', () async {
      await store.createFromTemplate(
          templateById('p1645')!, const MusicKey(0, KeyMode.major));
      await store.playCurrent();
      expect(store.isPlaying, isTrue);
      final stopsBefore = fakePlayer.stopCount;

      await store.setBpm(110);
      expect(store.isPlaying, isFalse);
      expect(fakePlayer.stopCount, greaterThan(stopsBefore));
      expect(store.current!.bpm, 110);
    });

    test('空序列不可播放', () async {
      await store.createBlank();
      await store.playCurrent();
      expect(store.isPlaying, isFalse);
      expect(scheduler.scheduled, isEmpty);
    });
  });
}
