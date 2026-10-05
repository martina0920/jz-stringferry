import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/models/study_models.dart';
import 'package:jz_stringferry/data/study_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  late AppDatabase appDb;
  late StudyRepository repo;
  final fixedNow = DateTime(2025, 3, 1, 9, 0).millisecondsSinceEpoch;

  StudyPlan buildPlan() => StudyPlan(
        id: 'p1',
        title: '测试计划',
        category: '编曲类',
        sortKey: 0,
        createdAt: fixedNow,
      );

  StudyTask buildTask({
    String id = 't1',
    String planId = 'p1',
    String title = '任务一',
    RepeatRule repeat = RepeatRule.none,
  }) =>
      StudyTask(
        id: id,
        planId: planId,
        title: title,
        dueDate: '2025-03-10',
        repeat: repeat,
        priority: TaskPriority.high,
        estimatedMinutes: 30,
        createdAt: fixedNow,
      );

  setUp(() async {
    appDb = AppDatabase.instance;
    await appDb.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repo = StudyRepository(appDb.database);
  });

  tearDown(() => appDb.disposeForTest());

  test('AC-6 计划/任务 CRUD 与编辑', () async {
    await repo.upsertPlan(buildPlan());
    await repo.upsertTask(buildTask());

    final plans = await repo.plans();
    expect(plans.single.title, '测试计划');

    final tasks = await repo.tasks(planId: 'p1');
    expect(tasks.single.priority, TaskPriority.high);

    // 编辑任务
    await repo.upsertTask(
        buildTask().copyWith(title: '任务一(改)', estimatedMinutes: 45));
    final updated = await repo.taskById('t1');
    expect(updated!.title, '任务一(改)');
    expect(updated.estimatedMinutes, 45);

    // 编辑计划
    await repo.upsertPlan(buildPlan().copyWith(title: '测试计划2'));
    expect((await repo.planById('p1'))!.title, '测试计划2');
  });

  test('AC-6 打卡写入、查询与取消（同一自然日唯一）', () async {
    await repo.upsertPlan(buildPlan());
    await repo.upsertTask(buildTask());
    final day = DateTime(2025, 3, 5);

    expect(await repo.toggleCheckin('t1', day: day), isTrue);
    expect(await repo.isChecked('t1', day), isTrue);

    await repo.checkIn('t1', day: day); // 幂等
    final dates =
        await repo.checkinDates('t1', from: '2025-03-01', to: '2025-03-31');
    expect(dates, {'2025-03-05'});

    expect(await repo.toggleCheckin('t1', day: day), isFalse);
    expect(await repo.isChecked('t1', day), isFalse);
  });

  test('删除任务连带打卡；删除计划连带任务与打卡', () async {
    await repo.upsertPlan(buildPlan());
    await repo.upsertTask(buildTask());
    await repo.checkIn('t1', day: DateTime(2025, 3, 5));

    await repo.deleteTask('t1');
    expect(await repo.taskById('t1'), isNull);
    final left = await appDb.database
        .rawQuery("SELECT COUNT(*) AS c FROM checkins WHERE task_id='t1'");
    expect(left.first['c'], 0);

    await repo.upsertTask(buildTask(id: 't2'));
    await repo.checkIn('t2', day: DateTime(2025, 3, 6));
    await repo.deletePlan('p1');
    final t =
        await appDb.database.rawQuery('SELECT COUNT(*) AS c FROM study_tasks');
    final c =
        await appDb.database.rawQuery('SELECT COUNT(*) AS c FROM checkins');
    expect(t.first['c'], 0);
    expect(c.first['c'], 0);
  });

  test('AC-6 关闭重开数据库后数据一致（文件库）', () async {
    final tmp = await Directory.systemTemp.createTemp('jz_study_test');
    final dbPath = '${tmp.path}${Platform.pathSeparator}study.db';

    try {
      await appDb.disposeForTest();
      await appDb.init(path: dbPath, factory: databaseFactoryFfi);
      final r1 = StudyRepository(appDb.database);
      await r1.upsertPlan(buildPlan());
      await r1.upsertTask(buildTask());
      await r1.checkIn('t1', day: DateTime(2025, 3, 5), nowMs: fixedNow);
      await appDb.disposeForTest();

      // 模拟应用重启：重新 open 同一文件。
      await appDb.init(path: dbPath, factory: databaseFactoryFfi);
      final r2 = StudyRepository(appDb.database);
      expect((await r2.plans()).single.title, '测试计划');
      expect((await r2.tasks(planId: 'p1')).single.title, '任务一');
      expect(await r2.isChecked('t1', DateTime(2025, 3, 5)), isTrue);
      await appDb.disposeForTest();
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  });
}
