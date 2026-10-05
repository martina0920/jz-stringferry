import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> openShareSheet(WidgetTester tester) async {
    await harness.pumpLocation(tester, AppRouter.arrangerEdit);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享导出'));
    await tester.pumpAndSettle();
  }

  String? previewText(WidgetTester tester) {
    final widget = tester.widget<SelectableText>(find.descendant(
      of: find.byKey(const Key('share_preview')),
      matching: find.byType(SelectableText),
    ));
    return widget.data;
  }

  group('分享导出弹层（T12/FR-18/FR-19）', () {
    testWidgets('默认 C 调预览两行逐字正确', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openShareSheet(tester);

      expect(
        previewText(tester),
        'J&Z 弦渡编曲分享｜C 大调（4/4 · 90BPM）\n'
        'C → Am → F → G（I → vi → IV → V）',
      );
    });

    testWidgets('切换 Bb 目标调：和弦与级数实时转调预览', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openShareSheet(tester);

      await tester.drag(find.byKey(const Key('share_key_list')),
          const Offset(-520, 0));
      await tester.pump();
      await tester
          .ensureVisible(find.byKey(const Key('share_key_chip_Bb')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('share_key_chip_Bb')));
      await tester.pump();

      expect(
        previewText(tester),
        'J&Z 弦渡编曲分享｜Bb 大调（4/4 · 90BPM）\n'
        'Bb → Gm → Eb → F（I → vi → IV → V）',
      );
      // 原曲不被改写。
      expect(harness.store.current!.chords, ['C', 'Am', 'F', 'G']);
    });

    testWidgets('复制：写入剪贴板的是当前预览文本', (tester) async {
      await reset(tester);
      await seed1645(tester);
      await openShareSheet(tester);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.tap(find.byKey(const Key('copy_share_text')));
      await tester.pump();

      expect(
        copied,
        'J&Z 弦渡编曲分享｜C 大调（4/4 · 90BPM）\n'
        'C → Am → F → G（I → vi → IV → V）',
      );
    });
  });
}
