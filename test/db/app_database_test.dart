import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';

void main() {
  setUpAll(() {
    // 在 Dart VM（Windows/macOS/Linux 主机）上用 ffi 跑内存 SQLite。
    sqfliteFfiInit();
  });

  group('AppDatabase 建表', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.instance;
      await db.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await db.disposeForTest();
    });

    test('onCreate 后 7 张表全部存在', () async {
      final rows = await db.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = rows.map((r) => r['name'] as String).toSet();

      expect(
        names,
        containsAll(<String>[
          'meta',
          'chords',
          'favorites',
          'recent_queries',
          'study_plans',
          'study_tasks',
          'checkins',
        ]),
      );
    });

    test('resetAll 后表清空且可再次写入', () async {
      await db.database.insert('study_plans', {
        'id': 'p1',
        'title': '测试计划',
        'category': '编曲',
        'sort_key': 0,
        'created_at': 0,
      });
      await db.database.insert('meta', {'k': 'chord_seed_version', 'v': '1'});

      await db.resetAll();

      expect(
        (await db.database.rawQuery('SELECT COUNT(*) AS c FROM study_plans'))
            .first['c'],
        0,
      );
      expect(
        (await db.database.rawQuery('SELECT COUNT(*) AS c FROM meta'))
            .first['c'],
        0,
      );

      // 重置后结构仍可正常写入。
      await db.database.insert('study_plans', {
        'id': 'p2',
        'title': '重置后的计划',
        'category': '混音',
        'sort_key': 1,
        'created_at': 1,
      });
      expect(
        (await db.database.rawQuery('SELECT COUNT(*) AS c FROM study_plans'))
            .first['c'],
        1,
      );
    });

    test('resetUserData 保留表结构但清空全部业务数据', () async {
      await db.database.insert('favorites', {'chord_id': 1, 'created_at': 0});
      await db.resetUserData();

      expect(
        (await db.database.rawQuery('SELECT COUNT(*) AS c FROM favorites'))
            .first['c'],
        0,
      );
      // 表本身仍然存在。
      final tables = await db.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='favorites'",
      );
      expect(tables, hasLength(1));
    });
  });
}
