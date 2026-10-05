import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';
import 'package:jz_stringferry/features/chord/chord_detail_page.dart';
import 'package:jz_stringferry/features/chord/chord_query_page.dart';
import 'package:jz_stringferry/features/chord/widgets/fretboard_diagram.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await ChordSeeder.seedIfEmpty(AppDatabase.instance.database);
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  /// widget 测试运行在 FakeAsync 区，FFI 回调用真实事件循环放行，再补帧渲染。
  Future<void> settleReal(WidgetTester tester, {int waitMs = 300}) async {
    await tester.runAsync(() => Future.delayed(Duration(milliseconds: waitMs)));
    await tester.pump();
  }

  Future<void> pumpQueryPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChordQueryPage()));
    await settleReal(tester);
  }

  Future<void> search(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(TextField), input);
    // 推进防抖计时器（150ms）
    await tester.pump(const Duration(milliseconds: 200));
    // 放行 FFI 查询并渲染结果
    await settleReal(tester);
  }

  testWidgets('输入 am7 后结果出现 Am7', (tester) async {
    await pumpQueryPage(tester);
    await search(tester, 'am7');

    expect(find.text('Am7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('输入不存在的 zzz 显示空状态', (tester) async {
    await pumpQueryPage(tester);
    await search(tester, 'zzz');

    expect(find.text('没有匹配的和弦'), findsOneWidget);
  });

  testWidgets('点击结果进入详情，展示组成音/音程/指法图', (tester) async {
    await pumpQueryPage(tester);
    await search(tester, 'am7');

    await tester.tap(find.text('Am7'));
    await tester.pumpAndSettle();

    expect(find.byType(ChordDetailPage), findsOneWidget);
    expect(find.text('组成音'), findsOneWidget);
    expect(find.text('音程构成'), findsOneWidget);
    expect(find.byType(FretboardDiagram), findsWidgets);
  });

  testWidgets('C 开放指型渲染无异常（AC-10 局部）', (tester) async {
    final repo = ChordRepository(AppDatabase.instance.database);
    final c = await tester.runAsync(() => repo.byName('C'));
    expect(c, isNotNull);
    expect(c!.fingerings.first.tabString, 'X32010');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: FretboardDiagram(fingering: c.fingerings.first)),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(FretboardDiagram), findsOneWidget);
  });

  testWidgets('F 横按指型渲染无异常（AC-10 局部）', (tester) async {
    final repo = ChordRepository(AppDatabase.instance.database);
    final f = await tester.runAsync(() => repo.byName('F'));
    expect(f, isNotNull);
    expect(f!.fingerings.first.tabString, '133211');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: FretboardDiagram(fingering: f.fingerings.first)),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(FretboardDiagram), findsOneWidget);
  });
}
