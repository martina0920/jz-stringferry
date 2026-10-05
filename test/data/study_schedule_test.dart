import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/models/study_models.dart';
import 'package:jz_stringferry/data/study_schedule.dart';

void main() {
  StudyTask task(
    RepeatRule rule, {
    String? dueDate,
    int createdAtDay = 1,
  }) =>
      StudyTask(
        id: 't',
        planId: 'p',
        title: 't',
        dueDate: dueDate,
        repeat: rule,
        createdAt: DateTime(2025, 3, createdAtDay).millisecondsSinceEpoch,
      );

  test('none：仅截止日当天应打卡', () {
    final t = task(RepeatRule.none, dueDate: '2025-03-10');
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 9)), isFalse);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 10)), isTrue);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 11)), isFalse);
  });

  test('daily：创建日起区间内每天都应打卡', () {
    final t = task(RepeatRule.daily, createdAtDay: 5);
    final dates = StudySchedule.scheduledDates(
        t, DateTime(2025, 3, 1), DateTime(2025, 3, 10));
    expect(dates.length, 6); // 3/5..3/10
    expect(dates.first, DateTime(2025, 3, 5));
  });

  test('weekly：以截止日为锚点每 7 天一次，早于锚点不生成', () {
    final t = task(RepeatRule.weekly, dueDate: '2025-03-03', createdAtDay: 1);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 2, 24)), isFalse);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 3)), isTrue);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 10)), isTrue);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 17)), isTrue);
    expect(StudySchedule.isScheduledOn(t, DateTime(2025, 3, 11)), isFalse);

    final dates = StudySchedule.scheduledDates(
        t, DateTime(2025, 3, 1), DateTime(2025, 3, 31));
    expect(dates, [
      DateTime(2025, 3, 3),
      DateTime(2025, 3, 10),
      DateTime(2025, 3, 17),
      DateTime(2025, 3, 24),
      DateTime(2025, 3, 31),
    ]);
  });
}
