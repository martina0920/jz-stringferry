import '../core/models/study_models.dart';

/// 单个分类的完成统计。
class CategoryStat {
  final String category;
  final int taskCount;
  final int completedCount;

  /// 0..1。
  final double completionRate;
  final int plannedMinutes;
  final int completedMinutes;

  const CategoryStat({
    required this.category,
    required this.taskCount,
    required this.completedCount,
    required this.completionRate,
    required this.plannedMinutes,
    required this.completedMinutes,
  });
}

/// 学习分析报告（AC-5）。
class AnalyticsReport {
  final List<CategoryStat> categories;

  /// 近 7 天（最早→今天）每日打卡条数。
  final List<int> last7DailyCounts;
  final List<String> last7Dates;

  /// 当日往前连续有打卡的自然日数（今天没打卡即 0）。
  final int streakDays;
  final int totalPlannedMinutes;
  final int completedMinutes;

  /// 完成率最低且任务数 ≥1 的分类（并列取任务多者）。
  final String? weakestCategory;

  /// 截止日在今天起 3 天内且当天未打卡。
  final List<StudyTask> dueSoon;

  /// 截止日早于今天且未完成。
  final List<StudyTask> overdue;

  const AnalyticsReport({
    required this.categories,
    required this.last7DailyCounts,
    required this.last7Dates,
    required this.streakDays,
    required this.totalPlannedMinutes,
    required this.completedMinutes,
    required this.weakestCategory,
    required this.dueSoon,
    required this.overdue,
  });
}

/// 纯函数式学习分析：输入 repository 快照，输出确定性报告。
class StudyAnalytics {
  StudyAnalytics._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 近 7 天窗口（含今天）。
  static List<DateTime> _window(DateTime now) {
    final today = _dateOnly(now);
    return [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  }

  static AnalyticsReport build({
    required List<StudyPlan> plans,
    required List<StudyTask> tasks,
    required List<Checkin> checkins,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final window = _window(today);
    final windowKeys = window.map(DayKey.of).toSet();

    final byTask = <String, List<Checkin>>{};
    for (final c in checkins) {
      byTask.putIfAbsent(c.taskId, () => []).add(c);
    }

    bool hasAnyCheckin(StudyTask t) => (byTask[t.id]?.isNotEmpty ?? false);

    /// 完成口径（T9 定义）：
    /// 无周期=任意一次打卡；每天/每周=窗口内至少一次打卡。
    bool isCompleted(StudyTask t) {
      final list = byTask[t.id];
      if (list == null || list.isEmpty) return false;
      if (t.repeat == RepeatRule.none) return true;
      return list.any((c) => windowKeys.contains(c.date));
    }

    bool checkedOn(StudyTask t, String dateKey) =>
        byTask[t.id]?.any((c) => c.date == dateKey) ?? false;

    // 分类聚合
    final categoryOf = <String, String>{
      for (final p in plans) p.id: p.category,
    };
    final statMap = <String, CategoryStat>{};
    var totalPlanned = 0;
    var totalCompleted = 0;

    final tasksByCategory = <String, List<StudyTask>>{};
    for (final t in tasks) {
      final cat = categoryOf[t.planId] ?? '未分类';
      tasksByCategory.putIfAbsent(cat, () => []).add(t);
    }

    for (final entry in tasksByCategory.entries) {
      var done = 0;
      var planned = 0;
      var completedMin = 0;
      for (final t in entry.value) {
        planned += t.estimatedMinutes;
        if (isCompleted(t)) {
          done += 1;
          completedMin += t.estimatedMinutes;
        }
      }
      totalPlanned += planned;
      totalCompleted += completedMin;
      statMap[entry.key] = CategoryStat(
        category: entry.key,
        taskCount: entry.value.length,
        completedCount: done,
        completionRate: entry.value.isEmpty ? 0 : done / entry.value.length,
        plannedMinutes: planned,
        completedMinutes: completedMin,
      );
    }
    final categories = statMap.values.toList()
      ..sort((a, b) => a.category.compareTo(b.category));

    // 薄弱分类：完成率最低，并列取任务数多者。
    String? weakest;
    CategoryStat? weakestStat;
    for (final s in categories) {
      if (weakestStat == null ||
          s.completionRate < weakestStat.completionRate ||
          (s.completionRate == weakestStat.completionRate &&
              s.taskCount > weakestStat.taskCount)) {
        weakest = s.category;
        weakestStat = s;
      }
    }

    // 近 7 天趋势
    final countByDate = <String, int>{};
    for (final c in checkins) {
      if (windowKeys.contains(c.date)) {
        countByDate[c.date] = (countByDate[c.date] ?? 0) + 1;
      }
    }
    final last7Counts = [
      for (final d in window) countByDate[DayKey.of(d)] ?? 0,
    ];
    final last7Keys = [for (final d in window) DayKey.of(d)];

    // 连续天数：今天起往前，遇到无打卡的自然日即止。
    var streak = 0;
    for (var d = today;; d = d.subtract(const Duration(days: 1))) {
      final key = DayKey.of(d);
      if (checkins.any((c) => c.date == key)) {
        streak += 1;
      } else {
        break;
      }
    }

    // 临期 / 逾期（均针对设置了截止日的任务）。
    final dueSoon = <StudyTask>[];
    final overdue = <StudyTask>[];
    final soonEnd = today.add(const Duration(days: 3));
    for (final t in tasks) {
      final due = t.dueDate;
      if (due == null) continue;
      final dueDay = _dateOnly(DayKey.parse(due));
      if (!dueDay.isBefore(today) && !dueDay.isAfter(soonEnd)) {
        if (!checkedOn(t, due)) dueSoon.add(t);
      } else if (dueDay.isBefore(today)) {
        final unfinished = t.repeat == RepeatRule.none
            ? !hasAnyCheckin(t)
            : !checkedOn(t, due);
        if (unfinished) overdue.add(t);
      }
    }

    return AnalyticsReport(
      categories: categories,
      last7DailyCounts: last7Counts,
      last7Dates: last7Keys,
      streakDays: streak,
      totalPlannedMinutes: totalPlanned,
      completedMinutes: totalCompleted,
      weakestCategory: weakest,
      dueSoon: dueSoon,
      overdue: overdue,
    );
  }
}
