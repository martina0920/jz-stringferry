import 'package:sqflite/sqflite.dart';

/// 收藏 / 最近查询的数据访问（favorites、recent_queries 两表）。
class ChordCollectionRepository {
  final Database db;

  /// 最近查询保留上限（AC-4）。
  static const int recentLimit = 50;

  ChordCollectionRepository(this.db);

  Future<Set<int>> favoriteIds() async {
    final rows = await db.query('favorites', columns: ['chord_id']);
    return rows.map((r) => r['chord_id'] as int).toSet();
  }

  /// 收藏列表（最近收藏在前）。
  Future<List<int>> favoriteChordIds() async {
    final rows = await db.query('favorites',
        columns: ['chord_id'], orderBy: 'created_at DESC');
    return rows.map((r) => r['chord_id'] as int).toList();
  }

  /// 收藏 → 取消；未收藏 → 加入。
  Future<void> toggleFavorite(int chordId, {DateTime? at}) async {
    final existing = await db.query('favorites',
        where: 'chord_id = ?', whereArgs: [chordId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('favorites', {
        'chord_id': chordId,
        'created_at': (at ?? DateTime.now()).millisecondsSinceEpoch,
      });
    } else {
      await db.delete('favorites', where: 'chord_id = ?', whereArgs: [chordId]);
    }
  }

  /// 最近查询 id（最近访问在前）。
  Future<List<int>> recentChordIds() async {
    final rows = await db.query('recent_queries',
        columns: ['chord_id'], orderBy: 'queried_at DESC');
    return rows.map((r) => r['chord_id'] as int).toList();
  }

  /// 记录一次查询：重复访问置顶（覆盖时间），超 50 条淘汰最旧（AC-4）。
  ///
  /// 整体一个事务，且同时间戳以 rowid（插入先后）决胜，
  /// 避免淘汰到同毫秒刚插入的记录。
  Future<void> recordQuery(int chordId, {DateTime? at}) async {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert(
        'recent_queries',
        {'chord_id': chordId, 'queried_at': ts},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final count = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM recent_queries'),
          ) ??
          0;
      if (count > recentLimit) {
        await txn.rawDelete(
          'DELETE FROM recent_queries WHERE rowid NOT IN ('
          'SELECT rowid FROM recent_queries '
          'ORDER BY queried_at DESC, rowid DESC LIMIT ?)',
          [recentLimit],
        );
      }
    });
  }
}
