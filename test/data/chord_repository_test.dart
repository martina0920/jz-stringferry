import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('AC-1 种子规模与幂等', () {
    late AppDatabase appDb;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
    });

    tearDown(() => appDb.disposeForTest());

    test('首次种子写入 >=500 条', () async {
      final inserted = await ChordSeeder.seedIfEmpty(appDb.database);
      expect(inserted, isTrue);

      final count =
          (await appDb.database.rawQuery('SELECT COUNT(*) AS c FROM chords'))
              .first['c'] as int;
      expect(count, greaterThanOrEqualTo(500));
    });

    test('重复 seed 不产生重复数据（幂等）', () async {
      await ChordSeeder.seedIfEmpty(appDb.database);
      final again = await ChordSeeder.seedIfEmpty(appDb.database);
      expect(again, isFalse);
      final count =
          (await appDb.database.rawQuery('SELECT COUNT(*) AS c FROM chords'))
              .first['c'] as int;
      expect(count, 510);
    });

    test('510 条事务插入耗时 < 3 秒', () async {
      final sw = Stopwatch()..start();
      await ChordSeeder.seedIfEmpty(appDb.database);
      sw.stop();
      // ignore: avoid_print
      print('种子写入耗时: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });
  });

  group('AC-3 多维度检索', () {
    late ChordRepository repo;

    setUp(() async {
      final appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      await ChordSeeder.seedIfEmpty(appDb.database);
      repo = ChordRepository(appDb.database);
    });

    tearDown(() => AppDatabase.instance.disposeForTest());

    test('名称精确：am7 首条命中 Am7', () async {
      final r = await repo.search('am7');
      expect(r, isNotEmpty);
      expect(r.first.name, 'Am7');
    });

    test('中文别名「小七」结果包含 Am7 且全部属于 m7 家族', () async {
      final r = await repo.search('小七');
      expect(r.map((c) => c.name), contains('Am7'));
      expect(r, isNotEmpty);
      expect(r.every((c) => c.quality.id == 'm7'), isTrue,
          reason: '别名「小七」不应混入其他性质');
    });

    test('中文俗称单词：七/挂留/增/减 都能命中（review Minor-5）', () async {
      final seven = await repo.search('七');
      expect(seven, isNotEmpty);
      expect(seven.every((c) => c.quality.id == 'seven'), isTrue);

      final sus = await repo.search('挂留');
      expect(sus.map((c) => c.quality.id).toSet(), {'sus2', 'sus4'});

      final aug = await repo.search('增');
      expect(aug, isNotEmpty);
      expect(aug.every((c) => c.quality.id == 'aug'), isTrue);

      final dim = await repo.search('减');
      expect(dim, isNotEmpty);
      expect(dim.every((c) => c.quality.id == 'dim'), isTrue);
    });

    test('脏 token 不进入组成音反查：「Am7 C」不会被静默当成 {A,C}', () async {
      // 旧实现把 Am7 的首字符当 A，会以组成音 rank 命中大量含 A/C 的和弦；
      // 严格音名校验后该查询既无法解析为和弦名，也不产生组成音命中。
      final r = await repo.search('Am7 C');
      expect(r, isEmpty);
    });

    test('组成音反查 A C E G 命中 Am7', () async {
      final r = await repo.search('A C E G');
      expect(r.map((c) => c.name), contains('Am7'));
      // 完全一致的 Am7 应排在被包含的和弦之前（如 C6 含 C E G A）。
      expect(r.first.tones.toSet().length, 4);
    });

    test('F#m7b5 持久化后组成音为 F# A C E', () async {
      final c = await repo.byName('F#m7b5');
      expect(c, isNotNull);
      expect(c!.tones, ['F#', 'A', 'C', 'E']);
      expect(c.fingerings, isNotEmpty);
    });

    test('家族筛选只返回该家族', () async {
      final r = await repo.all(family: '七和弦');
      expect(r, isNotEmpty);
      expect(r.every((c) => c.family == '七和弦'), isTrue);
      final families = await repo.families();
      expect(families, containsAll(['三和弦', '七和弦', '挂留和弦']));
    });

    test('空关键字返回全量且按 sort_key 排序', () async {
      final r = await repo.search('');
      expect(r.length, 510);
      expect(r.first.name, 'C');
    });
  });
}
