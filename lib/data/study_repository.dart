import 'package:sqflite/sqflite.dart';

import '../core/models/study_models.dart';

/// 学习计划/任务/打卡的数据访问。
class StudyRepository {
  final Database db;

  StudyRepository(this.db);

  // ---------- 计划 ----------

  Future<List<StudyPlan>> plans({String? category}) async {
    final rows = await db.query(
      'study_plans',
      where: category == null ? null : 'category = ?',
      whereArgs: category == null ? null : [category],
      orderBy: 'sort_key ASC, created_at ASC',
    );
    return rows.map(StudyPlan.fromMap).toList();
  }

  Future<StudyPlan?> planById(String id) async {
    final rows = await db.query('study_plans',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : StudyPlan.fromMap(rows.first);
  }

  Future<void> upsertPlan(StudyPlan plan) =>
      db.insert('study_plans', plan.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  /// 删除计划：连带其任务与打卡（事务）。
  Future<void> deletePlan(String planId) async {
    await db.transaction((txn) async {
      final taskRows = await txn.query('study_tasks',
          columns: ['id'], where: 'plan_id = ?', whereArgs: [planId]);
      final taskIds = taskRows.map((r) => r['id'] as String).toList();
      if (taskIds.isNotEmpty) {
        final ph = List.filled(taskIds.length, '?').join(',');
        await txn.delete('checkins',
            where: 'task_id IN ($ph)', whereArgs: taskIds);
      }
      await txn
          .delete('study_tasks', where: 'plan_id = ?', whereArgs: [planId]);
      await txn.delete('study_plans', where: 'id = ?', whereArgs: [planId]);
    });
  }

  // ---------- 任务 ----------

  Future<List<StudyTask>> tasks({String? planId, String? category}) async {
    if (category != null) {
      final rows = await db.rawQuery('''
        SELECT t.* FROM study_tasks t
        JOIN study_plans p ON p.id = t.plan_id
        WHERE p.category = ?
        ORDER BY p.sort_key ASC, t.created_at ASC
      ''', [category]);
      return rows.map(StudyTask.fromMap).toList();
    }
    final rows = await db.query(
      'study_tasks',
      where: planId == null ? null : 'plan_id = ?',
      whereArgs: planId == null ? null : [planId],
      orderBy: 'created_at ASC',
    );
    return rows.map(StudyTask.fromMap).toList();
  }

  Future<StudyTask?> taskById(String id) async {
    final rows = await db.query('study_tasks',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : StudyTask.fromMap(rows.first);
  }

  Future<void> upsertTask(StudyTask task) =>
      db.insert('study_tasks', task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  /// 删除任务：连带其打卡。
  Future<void> deleteTask(String taskId) async {
    await db.transaction((txn) async {
      await txn.delete('checkins', where: 'task_id = ?', whereArgs: [taskId]);
      await txn.delete('study_tasks', where: 'id = ?', whereArgs: [taskId]);
    });
  }

  // ---------- 打卡 ----------

  Future<bool> isChecked(String taskId, DateTime day) async {
    final rows = await db.query('checkins',
        where: 'task_id = ? AND date = ?',
        whereArgs: [taskId, DayKey.of(day)],
        limit: 1);
    return rows.isNotEmpty;
  }

  /// 当天打卡；已存在则不重复写。
  Future<void> checkIn(String taskId, {DateTime? day, int? nowMs}) async {
    final key = DayKey.of(day ?? DateTime.now());
    await db.insert(
      'checkins',
      {
        'task_id': taskId,
        'date': key,
        'created_at': nowMs ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> uncheck(String taskId, {DateTime? day}) => db.delete('checkins',
      where: 'task_id = ? AND date = ?',
      whereArgs: [taskId, DayKey.of(day ?? DateTime.now())]);

  /// 切换打卡状态，返回切换后的状态。
  ///
  /// 读改写放在同一个事务内：SQLite 写事务串行执行，
  /// 极快双击时第二次调用一定能读到第一次的插入，不会双双返回 true。
  Future<bool> toggleCheckin(String taskId, {DateTime? day}) async {
    final key = DayKey.of(day ?? DateTime.now());
    return db.transaction<bool>((txn) async {
      final existing = await txn.query(
        'checkins',
        where: 'task_id = ? AND date = ?',
        whereArgs: [taskId, key],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.delete('checkins',
            where: 'task_id = ? AND date = ?', whereArgs: [taskId, key]);
        return false;
      }
      await txn.insert('checkins', {
        'task_id': taskId,
        'date': key,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  /// 任务在 [from]..[to]（含端点，yyyy-MM-dd）内的打卡日期集合。
  Future<Set<String>> checkinDates(
    String taskId, {
    required String from,
    required String to,
  }) async {
    final rows = await db.query(
      'checkins',
      columns: ['date'],
      where: 'task_id = ? AND date >= ? AND date <= ?',
      whereArgs: [taskId, from, to],
    );
    return rows.map((r) => r['date'] as String).toSet();
  }

  /// 区间内全部打卡记录。
  Future<List<Checkin>> checkinsBetween(String from, String to) async {
    final rows = await db.query(
      'checkins',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from, to],
      orderBy: 'date ASC',
    );
    return rows.map(Checkin.fromMap).toList();
  }

  /// 全量历史打卡。打卡是「任务×日期」一行的小数据（每天每任务至多 1 行），
  /// 完成/逾期/连续天数等统计需要完整历史，不能按窗口截断。
  Future<List<Checkin>> allCheckins() async {
    final rows = await db.query('checkins', orderBy: 'date ASC');
    return rows.map(Checkin.fromMap).toList();
  }

  Future<int> checkinCountOn(DateTime day) async {
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM checkins WHERE date = ?', [DayKey.of(day)]);
    return rows.first['c'] as int;
  }
}

/// 业务 id 生成（文本主键，避免与 autoincrement 混淆）。
class StudyIds {
  StudyIds._();

  static int _seq = 0;

  static String _gen(String prefix) {
    _seq += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  static String plan() => _gen('p');
  static String task() => _gen('t');
}
