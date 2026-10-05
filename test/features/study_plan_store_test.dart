import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/models/study_models.dart';
import 'package:jz_stringferry/data/study_analytics.dart';
import 'package:jz_stringferry/data/study_repository.dart';
import 'package:jz_stringferry/features/study/state/study_plan_store.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  test('M3 回归：60 天窗口外的历史打卡仍计入完成、不算逾期', () async {
    // 固定"现在"为 2025-06-01，避免依赖真实日期。
    final now = DateTime(2025, 6, 1);
    final repo = StudyRepository(AppDatabase.instance.database);
    final store = StudyPlanStore(repo);

    const planId = 'plan_test';
    // 截止日在 100 天前的单次任务（若没打过卡属于严重逾期）。
    await repo.upsertPlan(const StudyPlan(
      id: planId,
      title: '测试计划',
      category: '编曲类',
      sortKey: 0,
      createdAt: 0,
    ));
    await repo.upsertTask(StudyTask(
      id: 'task_old',
      planId: planId,
      title: '早就完成的单次任务',
      dueDate: DayKey.of(now.subtract(const Duration(days: 100))),
      repeat: RepeatRule.none,
      priority: TaskPriority.high,
      estimatedMinutes: 45,
      createdAt: 0,
    ));
    // 90 天前打过卡——落在旧实现 ±60 天窗口之外。
    await repo.toggleCheckin('task_old',
        day: now.subtract(const Duration(days: 90)));

    await store.load();

    final report = StudyAnalytics.build(
      plans: store.plans,
      tasks: store.tasks,
      checkins: store.checkinSnapshot,
      now: now,
    );
    final cat = report.categories.single;
    expect(cat.taskCount, 1);
    expect(cat.completedCount, 1, reason: '窗口外历史打卡仍应判定完成');
    expect(report.overdue, isEmpty, reason: '已完成任务不应再进逾期列表');
    expect(report.completedMinutes, 45);
    expect(report.totalPlannedMinutes, 45);
  });
}
