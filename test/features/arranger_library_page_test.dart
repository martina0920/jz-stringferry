import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/router/app_router.dart';
import 'package:jz_stringferry/core/theory/key_harmony.dart';
import 'package:jz_stringferry/core/theory/progression_template.dart';
import 'arranger_test_harness.dart';

void main() {
  final harness = ArrangerHarness();

  setUpAll(() async {
    await harness.setUp();
  });

  tearDownAll(() => harness.tearDown());

  Future<void> reset(WidgetTester tester) async {
    await tester.runAsync(harness.reset);
  }

  Future<void> seed1645(WidgetTester tester) async {
    await tester.runAsync(
      () => harness.store.createFromTemplate(
        templateById('p1645')!,
        const MusicKey(0, KeyMode.major),
      ),
    );
  }

  Future<void> openLibrary(WidgetTester tester) =>
      harness.pumpLocation(tester, AppRouter.arranger);

  group('编曲库列表页（T8）', () {
    testWidgets('空态：说明与「新建第一个进行」', (tester) async {
      await reset(tester);
      await openLibrary(tester);

      expect(find.text('编曲工作台'), findsOneWidget);
      expect(find.text('还没有编曲进行'), findsOneWidget);
      expect(find.byKey(const Key('create_first')), findsOneWidget);
    });

    testWidgets('新建面板：空白项 + 7 模板（大 5 小 2）', (tester) async {
      await reset(tester);
      await openLibrary(tester);

      await tester.tap(find.byKey(const Key('new_progression')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('new_blank_progression')), findsOneWidget);
      expect(find.text('1645 流行进行'), findsOneWidget);
      expect(find.text('小调万能进行'), findsOneWidget);
      expect(find.byKey(const Key('new_template_p1645')), findsOneWidget);
      expect(find.byKey(const Key('new_template_minor1645')), findsOneWidget);
    });

    testWidgets('模板新建后进入编辑器且序列正确', (tester) async {
      await reset(tester);
      await openLibrary(tester);

      await tester.tap(find.byKey(const Key('new_progression')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new_template_p1645')));
      // 先让弹层完全关闭（此时 FFI 已在假时区挂起），再在真实 zone 等
      // createFromTemplate 完成并触发 push，最后推进转场动画。
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('和弦序列'), findsOneWidget);
      for (final name in ['C', 'Am', 'F', 'G']) {
        expect(find.text(name), findsWidgets);
      }
    });

    testWidgets('卡片菜单：重命名', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openLibrary(tester);

      final id = harness.store.items.first.id;
      await tester.tap(find.byKey(Key('prog_menu_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('rename_field')), '我的练习');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rename_confirm')));
      await tester.pumpAndSettle();
      await harness.settle(tester);

      expect(find.text('我的练习'), findsOneWidget);
    });

    testWidgets('卡片菜单：复制一份', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openLibrary(tester);

      final id = harness.store.items.first.id;
      await tester.tap(find.byKey(Key('prog_menu_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制一份'));
      await harness.settle(tester);

      expect(find.text('1645 流行进行'), findsOneWidget);
      expect(find.text('1645 流行进行 副本'), findsOneWidget);
    });

    testWidgets('卡片菜单：删除需二次确认，确认后消失', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openLibrary(tester);

      expect(find.byKey(const Key('confirm_delete_progression')), findsNothing);

      final id = harness.store.items.first.id;
      await tester.tap(find.byKey(Key('prog_menu_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_delete_progression')),
          findsOneWidget);
      // 先取消：仍在。
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('1645 流行进行'), findsOneWidget);

      // 再打开并确认删除。
      await tester.tap(find.byKey(Key('prog_menu_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('confirm_delete_progression')));
      await harness.settle(tester);

      expect(find.text('1645 流行进行'), findsNothing);
      expect(find.text('还没有编曲进行'), findsOneWidget);
    });
  });
}
