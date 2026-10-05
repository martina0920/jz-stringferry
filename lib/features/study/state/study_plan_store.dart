import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/study_models.dart';
import '../../../data/plan_templates.dart';
import '../../../data/study_repository.dart';

/// 学习计划的应用状态：计划/任务列表、区间打卡状态与全部写操作。
class StudyPlanStore extends ChangeNotifier {
  final StudyRepository repo;

  List<StudyPlan> _plans = [];
  List<StudyTask> _tasks = [];

  /// taskId -> 全量历史已打卡日期集合。
  final Map<String, Set<String>> _checkins = {};

  bool _loaded = false;

  StudyPlanStore(this.repo);

  List<StudyPlan> get plans => List.unmodifiable(_plans);
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  bool get loaded => _loaded;

  List<String> get categories {
    final seen = <String>{};
    final ordered = <String>[];
    for (final p in _plans) {
      if (seen.add(p.category)) ordered.add(p.category);
    }
    return ordered;
  }

  List<StudyPlan> plansOf(String category) =>
      _plans.where((p) => p.category == category).toList();

  List<StudyTask> tasksOf(String category) =>
      _tasks.where((t) => planCategory(t.planId) == category).toList();

  String? planCategory(String planId) {
    for (final p in _plans) {
      if (p.id == planId) return p.category;
    }
    return null;
  }

  StudyPlan? planById(String id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isCheckedOn(String taskId, DateTime day) =>
      _checkins[taskId]?.contains(DayKey.of(day)) ?? false;

  Set<String> checkinDatesOf(String taskId) => _checkins[taskId] ?? <String>{};

  /// 打卡快照（供 StudyAnalytics 使用；createdAt 不参与统计）。
  List<Checkin> get checkinSnapshot => [
        for (final entry in _checkins.entries)
          for (final date in entry.value)
            Checkin(taskId: entry.key, date: date, createdAt: 0),
      ];

  /// 加载计划/任务与全量历史打卡。
  ///
  /// 必须加载全量打卡：StudyAnalytics 对单次任务「任意一次打卡即完成」、
  /// 逾期判定依赖「历史是否打过卡」，窗口截断会让很久以前完成的任务
  /// 在 60 天后重新变成未完成/逾期（见 review M3）。
  Future<void> load() async {
    final results = await Future.wait([
      repo.plans(),
      repo.tasks(),
      repo.allCheckins(),
    ]);
    _plans = results[0] as List<StudyPlan>;
    _tasks = results[1] as List<StudyTask>;

    _checkins.clear();
    for (final c in results[2] as List<Checkin>) {
      _checkins.putIfAbsent(c.taskId, () => <String>{}).add(c.date);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> savePlan(StudyPlan plan) async {
    await repo.upsertPlan(plan);
    await load();
  }

  Future<void> deletePlan(String planId) async {
    await repo.deletePlan(planId);
    await load();
  }

  /// 重命名分类（分类是计划上的冗余字段：同一分类下可能有多个计划）。
  /// 返回 null 表示成功；否则为用户可见的错误原因。
  Future<String?> renameCategory(String oldName, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return '分类名称不能为空';
    if (name == oldName) return null;
    if (categories.contains(name)) return '已存在同名分类';
    for (final p in plansOf(oldName)) {
      await repo.upsertPlan(p.copyWith(category: name));
    }
    await load();
    return null;
  }

  /// 删除整个分类：级联删除其下全部计划、任务与打卡（事务由仓库保证）。
  Future<void> deleteCategory(String name) async {
    for (final p in plansOf(name)) {
      await repo.deletePlan(p.id);
    }
    await load();
  }

  Future<void> saveTask(StudyTask task) async {
    await repo.upsertTask(task);
    await load();
  }

  Future<void> deleteTask(String taskId) async {
    await repo.deleteTask(taskId);
    await load();
  }

  Future<void> toggleCheckin(String taskId, DateTime day) async {
    final checked = await repo.toggleCheckin(taskId, day: day);
    final set = _checkins.putIfAbsent(taskId, () => <String>{});
    final key = DayKey.of(day);
    if (checked) {
      set.add(key);
    } else {
      set.remove(key);
    }
    notifyListeners();
  }

  /// 恢复 2025 模板（会清空全部计划数据；调用方需先二次确认）。
  Future<void> restoreTemplates() async {
    await PlanTemplates.reimport(AppDatabase.instance.database);
    await load();
  }
}
