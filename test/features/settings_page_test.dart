import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/chat_service.dart';
import 'package:jz_stringferry/data/chord_collection_repository.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';
import 'package:jz_stringferry/data/plan_templates.dart';
import 'package:jz_stringferry/data/study_repository.dart';
import 'package:jz_stringferry/features/chord/state/chord_collection_store.dart';
import 'package:jz_stringferry/features/settings/settings_page.dart';
import 'package:jz_stringferry/features/study/state/study_plan_store.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  late ChordCollectionStore collectionStore;
  late StudyPlanStore studyStore;
  late ChatService chat;

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await ChordSeeder.seedIfEmpty(AppDatabase.instance.database);
    await PlanTemplates.importIfEmpty(AppDatabase.instance.database);
    collectionStore = ChordCollectionStore(
        ChordCollectionRepository(AppDatabase.instance.database));
    studyStore = StudyPlanStore(StudyRepository(AppDatabase.instance.database));
    chat = LocalChatService(
        chordRepo: ChordRepository(AppDatabase.instance.database));
    await Future.wait([collectionStore.load(), studyStore.load()]);
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ChordCollectionStore>.value(
              value: collectionStore),
          ChangeNotifierProvider<StudyPlanStore>.value(value: studyStore),
          Provider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('恢复示例数据：确认后收藏清空、2025 模板重新出现', (tester) async {
    // 预置一个收藏（FFI 调用须在真实事件循环中完成）。
    final firstId = await tester.runAsync(() async {
      final id = (await ChordRepository(AppDatabase.instance.database).all())
          .first
          .id!;
      await collectionStore.toggleFavorite(id);
      return id;
    });
    expect(collectionStore.favoriteIds, contains(firstId));
    expect(studyStore.plans.length, 4);

    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('恢复示例数据'));
    await tester.pump();
    expect(find.text('确认恢复'), findsOneWidget);

    // 点击在假时区完成以触发手势回调，随后放行真实事件循环让 FFI 重置链跑完，
    // 最后再补帧（FFI 未完成时 pump 会与真实 I/O 死锁）。
    await tester.tap(find.text('确认恢复'));
    // 轮询等待重置链完成（并行测试负载下 1.5s 可能不够），上限 8s。
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (collectionStore.favoriteIds.isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(collectionStore.favoriteIds, isEmpty);
    expect(studyStore.plans.length, 4);
    expect(studyStore.tasks.length, 9);
    expect(find.text('已恢复示例数据'), findsOneWidget);
  });

  testWidgets('关于试听采样：展示 Karplus-Strong 合成说明', (tester) async {
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('关于试听采样'));
    await tester.pump(const Duration(milliseconds: 300));

    // 列表项与对话框标题同名，内容文案只可能出现在弹窗内。
    expect(find.textContaining('Karplus-Strong'), findsOneWidget);
    expect(find.textContaining('并非真人录音'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
  });
}
