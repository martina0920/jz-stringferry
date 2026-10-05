import 'package:sqflite/sqflite.dart';

import '../core/models/practice_note.dart';

/// 练习笔记的数据访问（notes 表，v0.5）。
class NoteRepository {
  final Database db;

  NoteRepository(this.db);

  /// 笔记列表：最近编辑在前。
  Future<List<PracticeNote>> list() async {
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(PracticeNote.fromMap).toList();
  }

  Future<PracticeNote?> byId(String id) async {
    final rows =
        await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : PracticeNote.fromMap(rows.first);
  }

  /// 新建/覆盖保存（自动刷 updatedAt），返回落库后的对象。
  Future<PracticeNote> save(PracticeNote note) async {
    final stamped = note.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert(
      'notes',
      stamped.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return stamped;
  }

  Future<void> delete(String id) =>
      db.delete('notes', where: 'id = ?', whereArgs: [id]);
}
