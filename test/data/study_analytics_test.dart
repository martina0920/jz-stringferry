import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/models/study_models.dart';
import 'package:jz_stringferry/data/study_analytics.dart';

void main() {
  // 分析基准日
  final now = DateTime(2025, 3, 10);
  final created = DateTime(2025, 2, 1).millisecondsSinceEpoch;

  const planA = StudyPlan(
      id: 'pA', title: '编曲', category: '编曲类', sortKey: 0, createdAt: 0);
  const planB = StudyPlan(
      id: 'pB', title: '混音', category: '混音类', sortKey: 1, createdAt: 0);

  final tA1 = StudyTask(
      id: 'tA1',
      planId: 'pA',
      title: '编曲课',
      dueDate: '2025-03-20',
      priority: TaskPriority.high,
      estimatedMinutes: 30,
      createdAt: created);
  final tA2 = StudyTask(
      id: 'tA2',
      planId: 'pA',
      title: '每日练耳',
      repeat: RepeatRule.daily,
      estimatedMinutes: 20,
      createdAt: created);
  final tA3 = StudyTask(
      id: 'tA3',
      planId: 'pA',
      title: '过期作业',
      dueDate: '2025-03-09',
      estimatedMinutes: 40,
      createdAt: created);
  final tB1 = StudyTask(
      id: 'tB1',
      planId: 'pB',
      title: '每周混音',
      dueDate: '2025-03-12',
      repeat: RepeatRule.weekly,
      estimatedMinutes: 30,
      createdAt: created);
  final tB2 = StudyTask(
      id: 'tB2',
      planId: 'pB',
      title: '临期单次',
      dueDate: '2025-03-12',
      estimatedMinutes: 10,
      createdAt: created);
  final tB3 = StudyTask(
      id: 'tB3',
      planId: 'pB',
      title: '无打卡每日',
      repeat: RepeatRule.daily,
      estimatedMinutes: 15,
      createdAt: created);

  Checkin ci(String taskId, String date) =>
      Checkin(taskId: taskId, date: date, createdAt: 0);

  final checkins = [
    ci('tA1', '2025-03-08'), // 单次任务窗口内打卡→完成
    ci('tA2', '2025-03-08'),
    ci('tA2', '2025-03-09'),
    ci('tA2', '2025-03-10'), // 连续 3 天
    ci('tB1', '2025-02-26'), // 周任务窗口外打卡→不计完成
  ];

  test('AC-5 分类完成率、薄弱分类、耗时合计', () {
    final r = StudyAnalytics.build(
      plans: [planA, planB],
      tasks: [tA1, tA2, tA3, tB1, tB2, tB3],
      checkins: checkins,
      now: now,
    );

    final byCat = {for (final s in r.categories) s.category: s};
    expect(byCat['编曲类']!.completedCount, 2);
    expect(byCat['编曲类']!.taskCount, 3);
    expect(byCat['编曲类']!.completionRate, closeTo(2 / 3, 1e-9));
    expect(byCat['混音类']!.completedCount, 0);
    expect(byCat['混音类']!.completionRate, 0);

    // 并列规则：混音 0/3 为薄弱
    expect(r.weakestCategory, '混音类');

    expect(r.totalPlannedMinutes, 145);
    expect(r.completedMinutes, 50); // tA1 30 + tA2 20
  });

  test('AC-5 近 7 天趋势与连续天数（含中断后重连口径）', () {
    final r = StudyAnalytics.build(
      plans: [planA, planB],
      tasks: [tA1, tA2, tA3, tB1, tB2, tB3],
      checkins: checkins,
      now: now,
    );

    // 3/4..3/10：3/8=2，3/9=1，3/10=1（tB1 的打卡在 2/26，窗口外）
    expect(r.last7Dates, [
      '2025-03-04',
      '2025-03-05',
      '2025-03-06',
      '2025-03-07',
      '2025-03-08',
      '2025-03-09',
      '2025-03-10',
    ]);
    expect(r.last7DailyCounts, [0, 0, 0, 0, 2, 1, 1]);

    // 3/10、3/9、3/8 连续，3/7 中断
    expect(r.streakDays, 3);
  });

  test('AC-5 今天无打卡时连续天数为 0（中断后不自动接昨天）', () {
    final r = StudyAnalytics.build(
      plans: [planA],
      tasks: [tA1],
      checkins: [ci('tA1', '2025-03-08'), ci('tA1', '2025-03-09')],
      now: now,
    );
    expect(r.streakDays, 0);
  });

  test('AC-5 临期（3 天内未打卡）与逾期列表', () {
    final r = StudyAnalytics.build(
      plans: [planA, planB],
      tasks: [tA1, tA2, tA3, tB1, tB2, tB3],
      checkins: checkins,
      now: now,
    );

    expect(r.overdue.map((t) => t.id), ['tA3']); // 3/9 已过且无任何打卡

    final dueSoonIds = r.dueSoon.map((t) => t.id).toSet();
    expect(dueSoonIds, {'tB1', 'tB2'}); // 3/12 当天均未打卡
  });

  test('周期任务在截止当天已打卡则不再算临期/逾期', () {
    final r = StudyAnalytics.build(
      plans: [planB],
      tasks: [tB1, tB2],
      checkins: [
        ci('tB1', '2025-03-12'),
        ci('tB2', '2025-03-12'),
      ],
      now: now,
    );
    expect(r.dueSoon, isEmpty);
    expect(r.overdue, isEmpty);
  });
}
