import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/db/tables.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  test('DB v1 → v2 迁移：旧数据保留，progressions 新表可用（FR-15）', () async {
    final dir = await Directory.systemTemp.createTemp('jz_migration_');
    final dbPath = p.join(dir.path, 'migration_test.db');
    final factory = databaseFactoryFfi;

    // 1) 以 v1 结构（无 progressions）建库并写一条旧业务数据。
    {
      final oldDb = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final ddl in Tables.createDdl.take(7)) {
              await db.execute(ddl);
            }
          },
        ),
      );
      await oldDb.insert('recent_queries',
          {'chord_id': 5, 'queried_at': 123456});
      await oldDb.close();
    }

    // 2) 通过 AppDatabase 以 v2 重开，触发 onUpgrade。
    final appDb = AppDatabase.instance;
    await appDb.init(path: dbPath, factory: factory);

    // 3) 旧数据完整保留。
    final rows = await appDb.database.query('recent_queries');
    expect(rows.length, 1);
    expect(rows.first['chord_id'], 5);

    // 4) 新表可读写且默认值正确。
    final now = DateTime.now().millisecondsSinceEpoch;
    await appDb.database.insert('progressions', {
      'id': 'p1',
      'title': '我的练习',
      'key_root_pc': 0,
      'key_mode': 'major',
      'chords': '["C","Am","F","G"]',
      'created_at': now,
      'updated_at': now,
    });
    final pRows = await appDb.database.query('progressions');
    expect(pRows.length, 1);
    expect(pRows.first['bpm'], 90);
    expect(pRows.first['time_signature'], '4/4');
    expect(pRows.first['pattern'], 'strum');

    await appDb.disposeForTest();
    await dir.delete(recursive: true);
  });

  test('全新安装直接得到含 progressions 的 v2 库', () async {
    final appDb = AppDatabase.instance;
    await appDb.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final tables = await appDb.database
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((e) => e['name'] as String).toSet();
    for (final name in [
      'meta',
      'chords',
      'favorites',
      'recent_queries',
      'study_plans',
      'study_tasks',
      'checkins',
      'progressions',
    ]) {
      expect(names.contains(name), isTrue, reason: '缺少表 $name');
    }
    await appDb.disposeForTest();
  });
}
