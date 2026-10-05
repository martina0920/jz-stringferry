import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/router/app_router.dart';
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

  Future<void> openAi(WidgetTester tester) =>
      harness.pumpLocation(tester, AppRouter.ai);

  group('AI 助手 → 编曲台联动（T12/FR-21）', () {
    testWidgets('进行类回答出现「发送到编曲台」，点击进入编辑器',
        (tester) async {
      await reset(tester);
      await openAi(tester);

      await tester.tap(find.text('推荐一个 C 调的常用和弦进行'));
      await harness.settle(tester);

      final button = find.byKey(const Key('send_to_arranger'));
      expect(button, findsOneWidget);
      expect(find.textContaining('C · Am · F · G'), findsOneWidget);
      // 非编辑器。
      expect(find.text('和弦序列'), findsNothing);

      await tester.tap(button);
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 已进入编曲编辑器且序列为 C/Am/F/G。
      expect(find.text('和弦序列'), findsOneWidget);
      expect(harness.store.current, isNotNull);
      expect(harness.store.current!.chords, ['C', 'Am', 'F', 'G']);
      expect(harness.store.current!.title, 'C 大调 1645');
    });

    testWidgets('非进行类回答不显示发送按钮', (tester) async {
      await reset(tester);
      await openAi(tester);

      await tester.enterText(find.byType(TextField), '分析我的学习进度');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await harness.settle(tester);

      expect(find.byKey(const Key('send_to_arranger')), findsNothing);
    });
  });
}
