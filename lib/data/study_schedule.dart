import '../core/models/study_models.dart';

/// 周期任务在日历上的展开规则（纯函数，便于确定性单测）。
class StudySchedule {
  StudySchedule._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [day] 当天该任务是否应打卡。
  ///
  /// - none：仅截止日当天；
  /// - daily：创建日起每天；
  /// - weekly：以截止日（缺省用创建日）为锚点，每 7 天一次。
  static bool isScheduledOn(StudyTask task, DateTime day) {
    final d = _dateOnly(day);
    final start =
        _dateOnly(DateTime.fromMillisecondsSinceEpoch(task.createdAt));
    if (d.isBefore(start)) return false;

    switch (task.repeat) {
      case RepeatRule.none:
        return task.dueDate != null && DayKey.of(d) == task.dueDate;
      case RepeatRule.daily:
        return true;
      case RepeatRule.weekly:
        final anchor = _dateOnly(
            task.dueDate != null ? DayKey.parse(task.dueDate!) : start);
        if (d.isBefore(anchor)) return false;
        return d.difference(anchor).inDays % 7 == 0;
    }
  }

  /// [from]..[to]（含端点）之间的应打卡日期。
  static List<DateTime> scheduledDates(
    StudyTask task,
    DateTime from,
    DateTime to,
  ) {
    final f = _dateOnly(from);
    final t = _dateOnly(to);
    final result = <DateTime>[];
    for (var d = f; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
      if (isScheduledOn(task, d)) result.add(d);
    }
    return result;
  }
}
