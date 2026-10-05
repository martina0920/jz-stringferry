import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/progression_player.dart';
import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/models/progression.dart';
import 'package:jz_stringferry/core/theory/key_harmony.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';
import 'package:jz_stringferry/data/progression_repository.dart';
import 'package:jz_stringferry/features/arranger/state/arranger_store.dart';

class _RecordingPlayer implements TonePlayer {
  final List<String> assets = [];
  @override
  Future<void> playAsset(String assetPath) async => assets.add(assetPath);
  @override
  Future<void> stopAll() async => assets.clear();
}

/// 队列式假调度器：只记录不触发，测试里手动 firePass 消费一遍事件。
/// （同步触发会让 player 的下一遍重排程无限递归爆栈。）
class _QueuedScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];
  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }

  /// 触发当前已排程的全部事件一遍（循环重排程的下一遍留在队列里）。
  void firePass() {
    final batch = List.of(scheduled);
    scheduled.clear();
    for (final s in batch) {
      if (!s.isCanceled) s.callback();
    }
  }
}

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('ArrangerStore v0.5：音色 / 鼓轨 / 段落 / 拍数', () {
    late AppDatabase appDb;
    late ArrangerStore store;
    late ProgressionRepository repo;
    late _RecordingPlayer player;
    late _QueuedScheduler scheduler;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      await ChordSeeder.seedIfEmpty(appDb.database);
      repo = ProgressionRepository(appDb.database);
      player = _RecordingPlayer();
      scheduler = _QueuedScheduler();
      store = ArrangerStore(
        repo: repo,
        chordRepo: ChordRepository(appDb.database),
        player: ProgressionPlayer(player, scheduler: scheduler),
      );
    });

    tearDown(() async {
      store.dispose();
      await appDb.disposeForTest();
    });

    Future<void> seedChords() async {
      await store.createBlank(key: const MusicKey(0, KeyMode.major));
      await store.addChord('C');
      await store.addChord('Am');
      await store.addChord('F');
      await store.addChord('G');
    }

    test('setInstrument 随进行落库，播放走对应音色采样', () async {
      await seedChords();
      await store.setInstrument('piano');
      expect((await repo.byId(store.current!.id))!.instrumentId, 'piano');

      await store.playCurrent();
      scheduler.firePass();
      expect(player.assets, isNotEmpty);
      expect(player.assets.every((a) => a.startsWith('assets/audio/piano/')),
          isTrue,
          reason: '实际播放路径: ${player.assets.take(3)}');
    });

    test('toggleDrums 落库，播放叠加鼓组采样', () async {
      await seedChords();
      await store.toggleDrums();
      expect((await repo.byId(store.current!.id))!.drumTrack, isTrue);

      await store.playCurrent();
      scheduler.firePass();
      expect(
          player.assets.any((a) => a == 'assets/audio/drums/kick.wav'),
          isTrue,
          reason: '应包含底鼓采样: ${player.assets.take(5)}');
      expect(
          player.assets.any((a) => a == 'assets/audio/drums/snare.wav'),
          isTrue);
      // 再切一次 → 关闭。
      await store.toggleDrums();
      expect(store.current!.drumTrack, isFalse);
    });

    test('段落标记：设置/删除随库持久化', () async {
      await seedChords();
      await store.setSectionMark(2, '副歌');
      expect(store.current!.sections.single.label, '副歌');
      expect(store.current!.sections.single.index, 2);
      expect(
          (await repo.byId(store.current!.id))!.sections.single.label, '副歌');

      // 重复设置同 index 覆盖。
      await store.setSectionMark(2, '桥段');
      expect(store.current!.sections.single.label, '桥段');

      await store.setSectionMark(2, null);
      expect(store.current!.sections, isEmpty);
    });

    test('editChordAt：改属性 + 拍数一次落库', () async {
      await seedChords();
      await store.editChordAt(1, 'Am7', 8);
      final saved = (await repo.byId(store.current!.id))!;
      expect(saved.chords[1], 'Am7');
      expect(saved.chordBeats, [4, 8, 4, 4]);

      // 恢复默认：全部为默认时 chordBeats 归 null。
      await store.editChordAt(1, 'Am', null);
      expect(
          (await repo.byId(store.current!.id))!.chordBeats, isNull);
    });

    test('removeAt 保持 chordBeats 对齐', () async {
      await seedChords();
      await store.editChordAt(1, 'Am7', 8);
      await store.removeAt(0);
      expect(store.current!.chords, ['Am7', 'F', 'G']);
      expect(store.current!.chordBeats, [8, 4, 4]);
    });

    test('replaceAll / clear 重置拍数与段落', () async {
      await seedChords();
      await store.editChordAt(0, 'C7', 8);
      await store.setSectionMark(1, '主歌');
      await store.replaceAll(['C', 'G', 'Am', 'F']);
      expect(store.current!.chordBeats, isNull);
      expect(store.current!.sections, isEmpty);
    });

    test('playFrom 从段落起播：高亮偏移正确', () async {
      await seedChords();
      await store.playFrom(2);
      scheduler.firePass(); // 触发一遍事件，最后高亮落在最后一个和弦
      expect(store.highlightIndex, 3);
      await store.stopPlay();
      expect(store.highlightIndex, -1);
    });

    test('Progression 新字段序列化 roundtrip', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final p = Progression(
        id: 'p_rt',
        title: '全字段',
        keyRootPc: 0,
        keyMode: KeyMode.major,
        chords: const ['C', 'Am'],
        instrumentId: 'bass',
        drumTrack: true,
        sections: const [
          SectionMark(index: 1, label: '副歌'),
        ],
        chordBeats: const [4, 8],
        createdAt: now,
        updatedAt: now,
      );
      final back = Progression.fromMap(p.toMap());
      expect(back.instrumentId, 'bass');
      expect(back.drumTrack, isTrue);
      expect(back.sections.single.index, 1);
      expect(back.sections.single.label, '副歌');
      expect(back.chordBeats, [4, 8]);
    });

    test('SectionMark JSON 脏数据降级为空', () {
      expect(SectionMark.decodeList(null), isEmpty);
      expect(SectionMark.decodeList(''), isEmpty);
      expect(SectionMark.decodeList('not json'), isEmpty);
    });
  });
}
