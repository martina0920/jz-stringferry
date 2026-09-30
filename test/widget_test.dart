import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/app.dart';

void main() {
  testWidgets('App 启动冒烟测试', (WidgetTester tester) async {
    await tester.pumpWidget(const JzStringFerryApp());
    await tester.pumpAndSettle();

    // 首页标题与品牌标语可见
    expect(find.text('J&Z 弦渡'), findsOneWidget);
    expect(find.text('一人一弦，合奏成曲'), findsOneWidget);

    // 首屏可见的模块入口
    expect(find.text('和弦查询'), findsOneWidget);
    expect(find.text('学习计划'), findsOneWidget);
    expect(find.text('AI 助手'), findsOneWidget);

    // 滚动后检查下方模块
    await tester.scrollUntilVisible(find.text('扒带助手'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('扒带助手'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('吉他工具箱'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('吉他工具箱'), findsOneWidget);
  });
}
