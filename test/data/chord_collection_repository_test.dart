import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/chord_collection_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await ChordSeeder.seedIfEmpty(AppDatabase.instance.database);
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  Future<List<int>> chordIds(int count) async {
    final rows = await AppDatabase.instance.database
        .rawQuery('SELECT id FROM chords ORDER BY sort_key LIMIT $count');
    return rows.map((r) => r['id'] as int).toList();
  }

  test('AC-4 收藏写入后新仓库实例读取一致，再次切换则取消', () async {
    final ids = await chordIds(1);
    final id = ids.first;

    final repo1 = ChordCollectionRepository(AppDatabase.instance.database);
    await repo1.toggleFavorite(id);
    expect(await repo1.favoriteIds(), {id});
    expect(await repo1.favoriteChordIds(), [id]);

    // 模拟重开：新实例读同一库。
    final repo2 = ChordCollectionRepository(AppDatabase.instance.database);
    expect(await repo2.favoriteIds(), {id});

    await repo2.toggleFavorite(id);
    expect(await repo2.favoriteIds(), isEmpty);
  });

  test('AC-4 最近 51 次仅保留 50 条且最旧淘汰、重复访问置顶', () async {
    final ids = await chordIds(51);
    final repo = ChordCollectionRepository(AppDatabase.instance.database);
    final base = DateTime(2025, 1, 1);

    for (var i = 0; i < ids.length; i++) {
      await repo.recordQuery(ids[i], at: base.add(Duration(minutes: i)));
    }

    var recent = await repo.recentChordIds();
    expect(recent.length, 50);
    expect(recent.first, ids.last); // 最新在前
    expect(recent.contains(ids.first), isFalse); // 最旧被淘汰
    expect(recent.contains(ids[1]), isTrue);

    // 重复访问旧记录：时间更新并置顶，总数不变。
    await repo.recordQuery(ids[5], at: base.add(const Duration(minutes: 60)));
    recent = await repo.recentChordIds();
    expect(recent.length, 50);
    expect(recent.first, ids[5]);
  });
}
