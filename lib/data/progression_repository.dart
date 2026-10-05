import 'package:sqflite/sqflite.dart';

import '../core/models/progression.dart';

/// 编曲进行的数据访问（progressions 表）。
class ProgressionRepository {
  final Database db;

  ProgressionRepository(this.db);

  /// 曲库列表：最近编辑在前。
  Future<List<Progression>> list() async {
    final rows =
        await db.query('progressions', orderBy: 'updated_at DESC');
    return rows.map(Progression.fromMap).toList();
  }

  Future<Progression?> byId(String id) async {
    final rows = await db.query('progressions',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Progression.fromMap(rows.first);
  }

  /// 新建入库（尊重调用方给定的 createdAt/updatedAt）。
  Future<void> insert(Progression p) => db.insert(
        'progressions',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// 更新入库：自动刷新 updatedAt，并返回落库后的对象（供调用方对齐时间戳）。
  Future<Progression> update(Progression p) async {
    final stamped = p.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert(
      'progressions',
      stamped.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return stamped;
  }

  Future<void> delete(String id) =>
      db.delete('progressions', where: 'id = ?', whereArgs: [id]);

  /// 复制一条：标题追加「 副本」，其余内容一致；返回新对象。
  Future<Progression> duplicate(Progression p) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = Progression(
      id: ProgressionIds.newId(),
      title: '${p.title} 副本',
      keyRootPc: p.keyRootPc,
      keyMode: p.keyMode,
      chords: List<String>.of(p.chords),
      bpm: p.bpm,
      timeSignature: p.timeSignature,
      pattern: p.pattern,
      createdAt: now,
      updatedAt: now,
    );
    await insert(copy);
    return copy;
  }
}
