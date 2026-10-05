import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';

/// v3 时代的 progressions 表结构（无 v4 四列）。
const String _v3Progressions = '''
CREATE TABLE progressions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  key_root_pc INTEGER NOT NULL,
  key_mode TEXT NOT NULL DEFAULT 'major',
  chords TEXT NOT NULL DEFAULT '[]',
  bpm INTEGER NOT NULL DEFAULT 90,
  time_signature TEXT NOT NULL DEFAULT '4/4',
  pattern TEXT NOT NULL DEFAULT 'strum',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''';

void main() {
  setUpAll(() => sqfliteFfiInit());

  test('DB v3 → v4 迁移：progressions 数据保留，新列带默认值，notes 可用', () async {
    final dir = await Directory.systemTemp.createTemp('jz_migration_v4_');
    final dbPath = p.join(dir.path, 'migration_v4_test.db');
    final factory = databaseFactoryFfi;

    // 1) 以 v3 结构建库并写一条进行数据。
    {
      final oldDb = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute(_v3Progressions);
          },
        ),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await oldDb.insert('progressions', {
        'id': 'p_old',
        'title': '旧库进行',
        'key_root_pc': 2,
        'key_mode': 'major',
        'chords': '["D","A","Bm","G"]',
        'bpm': 96,
        'created_at': now,
        'updated_at': now,
      });
      await oldDb.close();
    }

    // 2) 通过 AppDatabase 以 v4 重开，触发 onUpgrade。
    final appDb = AppDatabase.instance;
    await appDb.init(path: dbPath, factory: factory);

    // 3) 旧数据完整保留且新列带默认值。
    final rows = await appDb.database.query('progressions');
    expect(rows.length, 1);
    expect(rows.first['title'], '旧库进行');
    expect(rows.first['instrument_id'], 'guitar');
    expect(rows.first['drum_track'], 0);
    expect(rows.first['sections'], isNull);
    expect(rows.first['chord_beats'], isNull);

    // 4) notes 表可读写。
    await appDb.database.insert('notes', {
      'id': 'n1',
      'content': '今天练了 C 大调音阶',
      'updated_at': 123,
    });
    final notes = await appDb.database.query('notes');
    expect(notes.length, 1);
    expect(notes.first['content'], '今天练了 C 大调音阶');

    await appDb.disposeForTest();
    await dir.delete(recursive: true);
  });
}
