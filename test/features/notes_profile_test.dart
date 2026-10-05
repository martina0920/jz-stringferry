import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/note_repository.dart';
import 'package:jz_stringferry/features/notes/note_editor_page.dart';
import 'package:jz_stringferry/features/notes/notes_page.dart';
import 'package:jz_stringferry/features/notes/state/notes_store.dart';
import 'package:jz_stringferry/features/profile/profile_page.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('练习笔记页面 smoke（v0.5）', () {
    late AppDatabase appDb;
    late NotesStore store;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      store = NotesStore(repo: NoteRepository(appDb.database));
    });

    tearDown(() async {
      await appDb.disposeForTest();
    });

    testWidgets('列表空态 + FAB 新建入口', (tester) async {
      // FFI 须在真实事件循环中完成（假异步区 pump 会与真实 I/O 死锁）。
      await tester.runAsync(() => store.load());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: NotesPage()),
        ),
      );
      await tester.pump(); // initState 的 load() 已因 loaded 早退，无 FFI
      expect(find.byKey(const Key('notes_add')), findsOneWidget);
      expect(find.textContaining('还没有笔记'), findsOneWidget);
    });

    testWidgets('有条目时显示卡片预览', (tester) async {
      await tester.runAsync(() async {
        await store.saveContent('n1', '第一条练习心得');
        await store.load();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: NotesPage()),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('note_card_n1')), findsOneWidget);
      expect(find.text('第一条练习心得'), findsOneWidget);
    });

    testWidgets('编辑页可输入并保存', (tester) async {
      await tester.runAsync(() async {
        await store.createBlank();
        await store.load();
      });
      final id = store.items.first.id;
      // 编辑页保存后走 context.pop()，须经真实 GoRouter（与生产路由一致）。
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('占位'))),
          GoRoute(
              path: '/edit',
              builder: (_, __) => NoteEditorPage(noteId: id)),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.push('/edit');
      await tester.pumpAndSettle(); // 等转场完成（本页初始化无 FFI、无常驻动画）
      await tester.enterText(
          find.byKey(const Key('note_content_field')), '写点什么');
      await tester.tap(find.byKey(const Key('note_save')));
      // 放行真实事件循环让 FFI 保存链跑完，再补帧处理 pop。
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      final saved = await tester.runAsync(() => store.repo.byId(id));
      expect(saved!.content, '写点什么');
    });
  });

  testWidgets('「我的」页 smoke：品牌卡与三个入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    expect(find.text('一人一弦，合奏成曲'), findsOneWidget);
    expect(find.byKey(const Key('profile_settings')), findsOneWidget);
    expect(find.byKey(const Key('profile_ai')), findsOneWidget);
    expect(find.byKey(const Key('profile_about')), findsOneWidget);
  });
}
