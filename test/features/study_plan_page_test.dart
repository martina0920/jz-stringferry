import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/plan_templates.dart';
import 'package:jz_stringferry/data/study_repository.dart';
import 'package:jz_stringferry/features/study/state/study_plan_store.dart';
import 'package:jz_stringferry/features/study/study_plan_page.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  late StudyPlanStore store;

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await PlanTemplates.importIfEmpty(AppDatabase.instance.database);
    store = StudyPlanStore(StudyRepository(AppDatabase.instance.database));
    await store.load();
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  Future<void> settleReal(WidgetTester tester, {int waitMs = 300}) async {
    await tester.runAsync(() => Future.delayed(Duration(milliseconds: waitMs)));
    await tester.pump();
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<StudyPlanStore>.value(
        value: store,
        child: const MaterialApp(home: StudyPlanPage()),
      ),
    );
    await settleReal(tester);
  }

  String taskIdByTitle(String title) =>
      store.tasks.firstWhere((t) => t.title == title).id;

  Icon cardIcon(WidgetTester tester, String taskId) {
    final btn = tester.widget<IconButton>(find.descendant(
      of: find.byKey(ValueKey('task_$taskId')),
      matching: find.byKey(Key('check_$taskId')),
    ));
    return btn.icon as Icon;
  }

  testWidgets('打卡按钮点击后变勾选态，再次点击取消', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('乐器类'));
    await tester.pumpAndSettle();
    final id = taskIdByTitle('练吉他和弦');

    expect(cardIcon(tester, id).icon, Icons.radio_button_unchecked_rounded);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key('check_$id')));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(cardIcon(tester, id).icon, Icons.check_circle_rounded);
    expect(store.isCheckedOn(id, DateTime.now()), isTrue);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key('check_$id')));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(cardIcon(tester, id).icon, Icons.radio_button_unchecked_rounded);
  });

  testWidgets('删除出现确认对话框，点取消后任务仍在', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('乐器类'));
    await tester.pumpAndSettle();
    final id = taskIdByTitle('练绝对音感');

    await tester.tap(find.byKey(Key('delete_$id')));
    await tester.pumpAndSettle();

    expect(find.text('确认删除'), findsOneWidget);
    expect(find.textContaining('练绝对音感'), findsWidgets);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('确认删除'), findsNothing);
    expect(store.tasks.any((t) => t.id == id), isTrue);
  });

  testWidgets('分析视图显示完成率文字与连续天数（今日无打卡为 0）', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('segment_分析')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('streak_value')), findsOneWidget);
    final streak = tester.widget<Text>(find.byKey(const Key('streak_value')));
    expect(streak.data, '0');
    expect(find.byKey(const Key('rate_编曲类')), findsOneWidget);
    final rate = tester.widget<Text>(find.byKey(const Key('rate_编曲类')));
    expect(rate.data, '0%');

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('薄弱项'), findsOneWidget);
  });

  testWidgets('M5：重命名分类后 chip 更新、任务保留', (tester) async {
    await pumpPage(tester);
    const keptTask = '欧阳和杨磊的编曲课全部上完';
    expect(store.tasks.any((t) => t.title == keptTask), isTrue);

    await tester.tap(find.byKey(const Key('manage_category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_rename')));
    await tester.pumpAndSettle();

    expect(find.text('重命名分类'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('rename_category_field')), '作曲类');
    await tester.tap(find.text('保存'));
    await settleReal(tester);
    await tester.pumpAndSettle();

    expect(find.text('作曲类'), findsOneWidget);
    expect(find.text('编曲类'), findsNothing);
    expect(store.categories, contains('作曲类'));
    expect(store.categories, isNot(contains('编曲类')));
    expect(store.tasks.any((t) => t.title == keptTask), isTrue);
  });

  testWidgets('M5：删除分类经二次确认后级联清空', (tester) async {
    await pumpPage(tester);
    expect(store.plansOf('编曲类').length, 1);
    expect(store.tasksOf('编曲类').length, 3);

    await tester.tap(find.byKey(const Key('manage_category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('删除分类'), findsWidgets);

    await tester.tap(find.byKey(const Key('confirm_delete_category')));
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('编曲类'), findsNothing);
    expect(store.plansOf('编曲类'), isEmpty);
    expect(store.tasksOf('编曲类'), isEmpty);
    expect(store.categories, isNot(contains('编曲类')));
    // 其他分类不受影响。
    expect(store.tasksOf('混音类').length, 2);
  });

  testWidgets('新建任务表单保存后任务出现在列表', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('new_task_fab')));
    await tester.pumpAndSettle();
    expect(find.text('新建任务'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '我的测试任务');
    await tester.tap(find.text('创建'));
    await settleReal(tester);
    await tester.pumpAndSettle();

    expect(find.text('我的测试任务'), findsOneWidget);
    expect(store.tasks.any((t) => t.title == '我的测试任务'), isTrue);
  });
}
