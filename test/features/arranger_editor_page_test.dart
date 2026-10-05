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

  Future<void> blankDraft(WidgetTester tester) async {
    await tester.runAsync(() => harness.store.createBlank());
  }

  Future<void> openEditor(WidgetTester tester) =>
      harness.pumpLocation(tester, AppRouter.arrangerEdit);

  Finder inSequence(String text) => find.descendant(
        of: find.byKey(const Key('chord_sequence_list')),
        matching: find.text(text),
      );

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_chord_card')));
    await tester.pumpAndSettle();
  }

  group('编曲编辑器（T9-T11）', () {
    testWidgets('同模式转调：C 大调 1645 → 降B 大调整体转写', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      for (final name in ['C', 'Am', 'F', 'G']) {
        expect(inSequence(name), findsOneWidget);
      }

      // Bb 在 12 调 chip 第 11 个，离屏未构建，先横向滚动两屏。
      await tester.drag(
          find.byKey(const Key('key_chips_list')), const Offset(-520, 0));
      await tester.pump();
      await tester
          .ensureVisible(find.byKey(const Key('key_chip_Bb_major')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('key_chip_Bb_major')));
      await harness.settle(tester);

      for (final name in ['Bb', 'Gm', 'Eb', 'F']) {
        expect(inSequence(name), findsOneWidget);
      }
      expect(inSequence('C'), findsNothing);
    });

    testWidgets('跨模式切换：改小调不重写已有序列', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      await tester.tap(find.text('小调'));
      await harness.settle(tester);

      // 序列保持 C / Am / F / G，但调性区已切为小调和声。
      for (final name in ['C', 'Am', 'F', 'G']) {
        expect(inSequence(name), findsOneWidget);
      }
      expect(find.byKey(const Key('key_chip_C_minor')), findsOneWidget);
    });

    testWidgets('顺阶三和弦追加：Dm 加到序列末尾', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      await openPicker(tester);
      expect(find.byKey(const Key('diatonic_chip_Dm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('diatonic_chip_Dm')));
      await harness.settle(tester);

      expect(inSequence('Dm'), findsOneWidget);
      expect(find.byKey(const ValueKey('chord_card_4')), findsOneWidget);
    });

    testWidgets('顺阶七和弦分段：切到七和弦并追加 G7', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      await openPicker(tester);
      await tester.tap(find.text('顺阶七和弦'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diatonic_chip_G7')), findsOneWidget);
      await tester.tap(find.byKey(const Key('diatonic_chip_G7')));
      await harness.settle(tester);

      expect(inSequence('G7'), findsOneWidget);
    });

    testWidgets('全库搜索：搜 G7 经防抖后从结果追加', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      await openPicker(tester);
      await tester.enterText(
          find.byKey(const Key('chord_search_field')), 'G7');
      // 推进 150ms 防抖；Timer 回调内的 FFI 随后在真实 zone 完成。
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();

      expect(find.byKey(const Key('search_result_G7')), findsOneWidget);
      await tester.tap(find.byKey(const Key('search_result_G7')));
      await harness.settle(tester);

      expect(inSequence('G7'), findsOneWidget);
    });

    testWidgets('删除：移除首张卡后序列前移', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      await tester.tap(find.byKey(const Key('remove_chord_0')));
      await harness.settle(tester);

      expect(inSequence('C'), findsNothing);
      expect(inSequence('Am'), findsOneWidget);
      expect(find.byKey(const ValueKey('chord_card_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('chord_card_3')), findsNothing);
    });

    testWidgets('空序列：播放钮禁用', (tester) async {
      await reset(tester);
      await blankDraft(tester);
      await openEditor(tester);

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('play_toggle')),
      );
      expect(btn.onPressed, isNull);
      expect(find.text('加一个和弦，或套用下方模板'), findsOneWidget);
    });

    testWidgets('播放：点播放变停止，再点恢复', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('play_toggle')));
      await harness.settle(tester, wait: const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(harness.scheduler.scheduled, isNotEmpty);

      await tester.tap(find.byKey(const Key('play_toggle')));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('模板替换：取消不改，确认后整段替换', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openEditor(tester);

      // 取消：序列不变。
      await tester.tap(find.byKey(const Key('template_chip_p1564')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('template_replace_dialog')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('template_replace_cancel')));
      await tester.pumpAndSettle();
      for (final name in ['C', 'Am', 'F', 'G']) {
        expect(inSequence(name), findsOneWidget);
      }

      // 确认：替换为 1564（C G Am F）。
      await tester.tap(find.byKey(const Key('template_chip_p1564')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('template_replace_confirm')));
      await harness.settle(tester);

      expect(inSequence('C'), findsOneWidget);
      expect(inSequence('G'), findsOneWidget);
      expect(inSequence('Am'), findsOneWidget);
      expect(inSequence('F'), findsOneWidget);
    });
  });
}
