import 'package:sqflite/sqflite.dart';

import '../core/models/study_models.dart';
import 'study_repository.dart';

/// 2025 内置学习计划模板（PRD 11.3.3.1），四类九条。
class TaskTemplate {
  final String title;
  final RepeatRule repeat;
  final TaskPriority priority;
  final int estimatedMinutes;

  /// 相对导入日的截止偏移（天）；可空。
  final int? dueInDays;

  const TaskTemplate(
    this.title, {
    this.repeat = RepeatRule.none,
    this.priority = TaskPriority.mid,
    this.estimatedMinutes = 30,
    this.dueInDays,
  });
}

class PlanTemplate {
  final String category;
  final String planTitle;
  final int sortKey;
  final List<TaskTemplate> tasks;

  const PlanTemplate(
    this.category,
    this.planTitle,
    this.tasks, {
    this.sortKey = 0,
  });
}

/// 模板唯一事实源（文案与 PRD/旧骨架一致；测试据此断言）。
const List<PlanTemplate> kPlanTemplates = [
  PlanTemplate(
      '编曲类',
      '2025 编曲学习计划',
      [
        TaskTemplate('欧阳和杨磊的编曲课全部上完',
            priority: TaskPriority.high, estimatedMinutes: 30),
        TaskTemplate('学会 Serum / Pro Tools / Auto-Tune', estimatedMinutes: 30),
        TaskTemplate('人声编曲专题', estimatedMinutes: 30),
      ],
      sortKey: 0),
  PlanTemplate(
      '混音类',
      '2025 混音学习计划',
      [
        TaskTemplate('Alex 的混音课全部学完',
            priority: TaskPriority.high, estimatedMinutes: 30),
        TaskTemplate('每天一章混音指南',
            repeat: RepeatRule.daily, estimatedMinutes: 20),
      ],
      sortKey: 1),
  PlanTemplate(
      '分轨类',
      '2025 扒带训练计划',
      [
        TaskTemplate('两周完全扒带一首歌',
            priority: TaskPriority.high, estimatedMinutes: 60, dueInDays: 14),
        TaskTemplate('每天听五首歌研究编曲思路并记笔记',
            repeat: RepeatRule.daily, estimatedMinutes: 20),
      ],
      sortKey: 2),
  PlanTemplate(
      '乐器类',
      '2025 乐器基本功计划',
      [
        TaskTemplate('练绝对音感', repeat: RepeatRule.daily, estimatedMinutes: 15),
        TaskTemplate('练吉他和弦', repeat: RepeatRule.daily, estimatedMinutes: 20),
      ],
      sortKey: 3),
];

class PlanTemplates {
  PlanTemplates._();

  static const String metaKey = 'plan_templates_version';
  static const String version = '1';

  /// 仅在「本版本从未做过首次导入」时导入模板（以 meta 版本键为判据）。
  ///
  /// 不能只按 study_plans 行数判定：用户主动删光全部计划后重启，
  /// 若见 0 行就导入，模板会复活，删除状态无法保持。设置页「恢复示例数据」
  /// 走 resetUserData（会清空 meta）后再调用本方法，故仍会重新导入。
  /// 返回是否执行了导入。
  static Future<bool> importIfEmpty(Database db, {DateTime? now}) async {
    final marked = await db.query(
      'meta',
      where: 'k = ?',
      whereArgs: [metaKey],
      limit: 1,
    );
    if (marked.isNotEmpty) return false;
    await apply(db, now: now);
    return true;
  }

  /// 清空用户计划数据并重新导入模板（设置页「恢复示例数据」使用）。
  static Future<void> reimport(Database db, {DateTime? now}) async {
    await db.transaction((txn) async {
      await txn.delete('checkins');
      await txn.delete('study_tasks');
      await txn.delete('study_plans');
    });
    await apply(db, now: now);
  }

  static Future<void> apply(Database db, {DateTime? now}) async {
    final t = now ?? DateTime.now();
    final createdAt = t.millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (final tpl in kPlanTemplates) {
        final planId = StudyIds.plan();
        await txn.insert('study_plans', {
          'id': planId,
          'title': tpl.planTitle,
          'category': tpl.category,
          'sort_key': tpl.sortKey,
          'created_at': createdAt,
        });
        for (final tt in tpl.tasks) {
          String? dueDate;
          if (tt.dueInDays != null) {
            dueDate = DayKey.of(t.add(Duration(days: tt.dueInDays!)));
          }
          await txn.insert('study_tasks', {
            'id': StudyIds.task(),
            'plan_id': planId,
            'title': tt.title,
            'due_date': dueDate,
            'repeat_rule': tt.repeat.wire,
            'priority': tt.priority.wire,
            'estimated_minutes': tt.estimatedMinutes,
            'note': '',
            'created_at': createdAt,
          });
        }
      }
      await txn.insert('meta', {'k': metaKey, 'v': version},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
