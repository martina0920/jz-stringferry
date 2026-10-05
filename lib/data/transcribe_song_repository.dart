import 'package:sqflite/sqflite.dart';

import '../core/models/transcribe_models.dart';

/// 扒带曲库数据访问（transcribe_songs + transcribe_segments）。
class TranscribeSongRepository {
  final Database db;

  TranscribeSongRepository(this.db);

  // ---- 歌曲 ----

  /// 曲库列表：最近编辑在前。
  Future<List<TranscribeSong>> list() async {
    final rows =
        await db.query('transcribe_songs', orderBy: 'updated_at DESC');
    return rows.map(TranscribeSong.fromMap).toList();
  }

  Future<TranscribeSong?> byId(String id) async {
    final rows = await db.query('transcribe_songs',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : TranscribeSong.fromMap(rows.first);
  }

  Future<void> insert(TranscribeSong s) => db.insert(
        'transcribe_songs',
        s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// 更新：自动刷新 updatedAt 并返回落库后的对象。
  Future<TranscribeSong> update(TranscribeSong s) async {
    final stamped = s.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await insert(stamped);
    return stamped;
  }

  /// 删除歌曲及其全部分段（音频文件由调用方负责删除）。
  Future<void> delete(String id) async {
    await db.transaction((txn) async {
      await txn
          .delete('transcribe_segments', where: 'song_id = ?', whereArgs: [id]);
      await txn
          .delete('transcribe_songs', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---- 分段 ----

  /// 某首歌的全部分段，按 sort_key 升序。
  Future<List<TranscribeSegment>> segmentsOf(String songId) async {
    final rows = await db.query('transcribe_segments',
        where: 'song_id = ?',
        whereArgs: [songId],
        orderBy: 'sort_key ASC, id ASC');
    return rows.map(TranscribeSegment.fromMap).toList();
  }

  /// 新建分段：sort_key 自动接到末尾。
  Future<TranscribeSegment> insertSegment(TranscribeSegment seg) async {
    final maxRow = await db.query('transcribe_segments',
        columns: ['MAX(sort_key) AS mk'],
        where: 'song_id = ?',
        whereArgs: [seg.songId],
        limit: 1);
    final nextKey = ((maxRow.first['mk'] as int?) ?? -1) + 1;
    final withKey = seg.copyWith(sortKey: seg.sortKey == 0 ? nextKey : seg.sortKey);
    final id = await db.insert('transcribe_segments', withKey.toMap());
    return TranscribeSegment(
      id: id,
      songId: withKey.songId,
      startMs: withKey.startMs,
      endMs: withKey.endMs,
      label: withKey.label,
      chordsText: withKey.chordsText,
      sortKey: withKey.sortKey,
    );
  }

  Future<void> updateSegment(TranscribeSegment seg) => db.update(
        'transcribe_segments',
        seg.toMap(),
        where: 'id = ?',
        whereArgs: [seg.id],
      );

  Future<void> deleteSegment(int id) =>
      db.delete('transcribe_segments', where: 'id = ?', whereArgs: [id]);
}
