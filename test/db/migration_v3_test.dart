import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/db/tables.dart';
import 'package:jz_stringferry/core/models/transcribe_models.dart';
import 'package:jz_stringferry/data/ear_training_repository.dart';
import 'package:jz_stringferry/data/settings_repository.dart';
import 'package:jz_stringferry/data/transcribe_song_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  test('DB v2 → v3 迁移：progressions 保留，四张新表可用', () async {
    final dir = await Directory.systemTemp.createTemp('jz_migration_v3_');
    final dbPath = p.join(dir.path, 'migration_v3_test.db');
    final factory = databaseFactoryFfi;

    // 1) 以 v2 结构（无 settings/transcribe/ear 表）建库并写旧数据。
    {
      final oldDb = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            for (final ddl in Tables.createDdl.take(8)) {
              await db.execute(ddl);
            }
          },
        ),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await oldDb.insert('progressions', {
        'id': 'p_keep',
        'title': '旧进行',
        'key_root_pc': 0,
        'key_mode': 'major',
        'chords': '["C","G"]',
        'created_at': now,
        'updated_at': now,
      });
      await oldDb.close();
    }

    // 2) 以 v3 重开，触发 onUpgrade。
    final appDb = AppDatabase.instance;
    await appDb.init(path: dbPath, factory: factory);

    // 3) 旧数据完整保留。
    final keep = await appDb.database.query('progressions');
    expect(keep.length, 1);
    expect(keep.first['title'], '旧进行');

    // 4) 新表可读写。
    await appDb.database
        .insert('settings', {'k': 'probe', 'v': '1'});
    final settingsRepo = SettingsRepository(appDb.database);
    expect(await settingsRepo.get('probe'), '1');

    final now = DateTime.now().millisecondsSinceEpoch;
    await appDb.database.insert('transcribe_songs', {
      'id': 's1',
      'title': '一首歌',
      'file_path': '/tmp/a.wav',
      'created_at': now,
      'updated_at': now,
    });
    final songRows = await appDb.database.query('transcribe_songs');
    expect(songRows.first['source'], 'import');
    expect(songRows.first['duration_ms'], 0);

    await appDb.database.insert('transcribe_segments', {
      'song_id': 's1',
      'start_ms': 0,
      'end_ms': 1000,
    });
    expect(
        (await appDb.database.query('transcribe_segments')).first['label'], '');

    await appDb.database
        .insert('ear_training_stats', {'date': '2026-10-05', 'mode': 'interval'});
    expect(
        (await appDb.database.query('ear_training_stats')).first['correct'], 0);

    await appDb.disposeForTest();
    await dir.delete(recursive: true);
  });

  test('全新安装直接得到含 v3 四张新表的库', () async {
    final appDb = AppDatabase.instance;
    await appDb.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final tables = await appDb.database
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((e) => e['name'] as String).toSet();
    for (final name in [
      'settings',
      'transcribe_songs',
      'transcribe_segments',
      'ear_training_stats',
    ]) {
      expect(names.contains(name), isTrue, reason: '缺少表 $name');
    }
    await appDb.disposeForTest();
  });

  group('SettingsRepository', () {
    late AppDatabase appDb;
    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
          path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    });
    tearDown(() => appDb.disposeForTest());

    test('set/get/remove 往返', () async {
      final repo = SettingsRepository(appDb.database);
      expect(await repo.get('missing'), isNull);
      await repo.set(SettingsRepository.dashscopeApiKey, 'sk-abc');
      expect(await repo.get(SettingsRepository.dashscopeApiKey), 'sk-abc');
      await repo.set(SettingsRepository.dashscopeApiKey, 'sk-xyz'); // 覆盖
      expect(await repo.get(SettingsRepository.dashscopeApiKey), 'sk-xyz');
      await repo.remove(SettingsRepository.dashscopeApiKey);
      expect(await repo.get(SettingsRepository.dashscopeApiKey), isNull);
    });

    test('resetUserData 不清 settings（API key 豁免）', () async {
      final repo = SettingsRepository(appDb.database);
      await repo.set(SettingsRepository.dashscopeApiKey, 'sk-keep');
      await appDb.resetUserData();
      expect(await repo.get(SettingsRepository.dashscopeApiKey), 'sk-keep');
    });
  });

  group('TranscribeSongRepository', () {
    late AppDatabase appDb;
    late TranscribeSongRepository repo;
    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
          path: inMemoryDatabasePath, factory: databaseFactoryFfi);
      repo = TranscribeSongRepository(appDb.database);
    });
    tearDown(() => appDb.disposeForTest());

    TranscribeSong song(String id, {int updatedAt = 1}) => TranscribeSong(
          id: id,
          title: '歌 $id',
          filePath: '/doc/$id.wav',
          source: 'import',
          createdAt: 1,
          updatedAt: updatedAt,
        );

    test('list 按 updated_at 倒序；byId 未命中返回 null', () async {
      await repo.insert(song('a', updatedAt: 100));
      await repo.insert(song('b', updatedAt: 200));
      expect((await repo.list()).map((s) => s.id).toList(), ['b', 'a']);
      expect(await repo.byId('a'), isNotNull);
      expect(await repo.byId('zzz'), isNull);
    });

    test('update 刷新 updatedAt；delete 级联删分段', () async {
      await repo.insert(song('a', updatedAt: 100));
      final updated = await repo.update(song('a').copyWith(title: '改名'));
      expect(updated.updatedAt, greaterThanOrEqualTo(100));
      expect(updated.title, '改名');

      await repo.insertSegment(const TranscribeSegment(
          songId: 'a', startMs: 0, endMs: 500, sortKey: 0));
      await repo.delete('a');
      expect(await repo.byId('a'), isNull);
      expect(await repo.segmentsOf('a'), isEmpty);
    });

    test('insertSegment 自动递增 sort_key；分段 CRUD 往返', () async {
      await repo.insert(song('a'));
      final s1 = await repo.insertSegment(const TranscribeSegment(
          songId: 'a', startMs: 0, endMs: 1, sortKey: 0));
      final s2 = await repo.insertSegment(const TranscribeSegment(
          songId: 'a', startMs: 1, endMs: 2, sortKey: 0));
      expect(s1.sortKey, 0);
      expect(s2.sortKey, 1);
      expect(s1.id, isNotNull);

      await repo.updateSegment(
          s1.copyWith(label: '主歌', chordsText: 'C Am'));
      final segs = await repo.segmentsOf('a');
      expect(segs.first.label, '主歌');
      expect(segs.first.chordsText, 'C Am');

      await repo.deleteSegment(s1.id!);
      expect((await repo.segmentsOf('a')).length, 1);
    });
  });

  group('EarTrainingRepository', () {
    late AppDatabase appDb;
    late EarTrainingRepository repo;
    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
          path: inMemoryDatabasePath, factory: databaseFactoryFfi);
      repo = EarTrainingRepository(appDb.database);
    });
    tearDown(() => appDb.disposeForTest());

    test('record 累加 correct/total；dayStats 与 totalStats 一致', () async {
      await repo.record(date: '2026-10-05', mode: 'interval', correct: true);
      await repo.record(date: '2026-10-05', mode: 'interval', correct: false);
      await repo.record(date: '2026-10-05', mode: 'interval', correct: true);

      final day = await repo.dayStats('2026-10-05');
      expect(day['interval'], (2, 3));

      await repo.record(date: '2026-10-04', mode: 'interval', correct: false);
      final total = await repo.totalStats();
      expect(total['interval'], (2, 4));

      expect((await repo.dayStats('2099-01-01')), isEmpty);
    });
  });
}
