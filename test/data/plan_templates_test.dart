import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/models/study_models.dart';
import 'package:jz_stringferry/data/plan_templates.dart';
import 'package:jz_stringferry/data/study_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  test('模板：四类齐全、共 9 条任务、文案与 PRD 一致', () {
    expect(kPlanTemplates.map((p) => p.category), ['编曲类', '混音类', '分轨类', '乐器类']);
    final tasks = {
      for (final p in kPlanTemplates)
        p.category: p.tasks.map((t) => t.title).toList(),
    };
    expect(tasks['编曲类'], [
      '欧阳和杨磊的编曲课全部上完',
      '学会 Serum / Pro Tools / Auto-Tune',
      '人声编曲专题',
    ]);
    expect(tasks['混音类'], ['Alex 的混音课全部学完', '每天一章混音指南']);
    expect(tasks['分轨类'], ['两周完全扒带一首歌', '每天听五首歌研究编曲思路并记笔记']);
    expect(tasks['乐器类'], ['练绝对音感', '练吉他和弦']);
    expect(kPlanTemplates.fold<int>(0, (n, p) => n + p.tasks.length), 9);
  });

  test('首次导入写 4 计划 9 任务；重复导入跳过（幂等）', () async {
    final db = AppDatabase.instance.database;
    expect(await PlanTemplates.importIfEmpty(db, now: DateTime(2025, 1, 1)),
        isTrue);
    expect(await PlanTemplates.importIfEmpty(db, now: DateTime(2025, 1, 1)),
        isFalse);

    final repo = StudyRepository(db);
    final plans = await repo.plans();
    final tasks = await repo.tasks();
    expect(plans.length, 4);
    expect(tasks.length, 9);

    // 周期与截止日
    final daily = tasks.where((t) => t.repeat == RepeatRule.daily);
    expect(daily.map((t) => t.title), [
      '每天一章混音指南',
      '每天听五首歌研究编曲思路并记笔记',
      '练绝对音感',
      '练吉他和弦',
    ]);
    final coverTask = tasks.firstWhere((t) => t.title == '两周完全扒带一首歌');
    expect(coverTask.dueDate, '2025-01-15');
    expect(coverTask.estimatedMinutes, 60);
  });

  test('用户主动删光全部计划后重启，模板不会自动复活（M2 回归）', () async {
    final db = AppDatabase.instance.database;
    expect(await PlanTemplates.importIfEmpty(db, now: DateTime(2025, 1, 1)),
        isTrue);

    // 模拟用户删除全部计划（meta 标记保留）。
    final repo = StudyRepository(db);
    for (final p in await repo.plans()) {
      await repo.deletePlan(p.id);
    }
    expect(await repo.plans(), isEmpty);

    // 杀进程重启后的启动引导只调 importIfEmpty：不应再导入。
    expect(await PlanTemplates.importIfEmpty(db, now: DateTime(2025, 2, 1)),
        isFalse);
    expect(await repo.plans(), isEmpty);
  });

  test('reimport 清空旧打卡后重新导入模板', () async {
    final db = AppDatabase.instance.database;
    await PlanTemplates.importIfEmpty(db, now: DateTime(2025, 1, 1));
    final repo = StudyRepository(db);
    final first = (await repo.tasks()).first;
    await repo.checkIn(first.id, day: DateTime(2025, 1, 2));

    await PlanTemplates.reimport(db, now: DateTime(2025, 2, 1));
    expect(await repo.checkinsBetween('2025-01-01', '2025-12-31'), isEmpty);
    expect((await repo.plans()).length, 4);
  });
}
