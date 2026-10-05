import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/models/practice_note.dart';
import 'package:jz_stringferry/data/note_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('NoteRepository（v0.5 练习笔记）', () {
    late AppDatabase appDb;
    late NoteRepository repo;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      repo = NoteRepository(appDb.database);
    });

    tearDown(() async {
      await appDb.disposeForTest();
    });

    test('新建保存 + 最近编辑在前', () async {
      final a = await repo
          .save(PracticeNote(id: PracticeNote.newId(), content: '第一条', updatedAt: 0));
      await Future.delayed(const Duration(milliseconds: 5));
      final b = await repo
          .save(PracticeNote(id: PracticeNote.newId(), content: '第二条', updatedAt: 0));
      expect(a.updatedAt, greaterThan(0));

      final items = await repo.list();
      expect(items.length, 2);
      expect(items.first.id, b.id, reason: '最近编辑的应排在最前');
    });

    test('覆盖保存刷新 updatedAt', () async {
      final a = await repo.save(
          const PracticeNote(id: 'n_fix', content: '草稿', updatedAt: 0));
      await Future.delayed(const Duration(milliseconds: 5));
      final again = await repo.save(a.copyWith(content: '改好的稿'));
      expect(again.updatedAt, greaterThan(a.updatedAt));
      final got = await repo.byId('n_fix');
      expect(got!.content, '改好的稿');
    });

    test('删除', () async {
      await repo.save(const PracticeNote(
          id: 'n_del', content: '待删', updatedAt: 1));
      await repo.delete('n_del');
      expect(await repo.byId('n_del'), isNull);
    });

    test('preview 截断与空内容', () async {
      const empty = PracticeNote(id: 'x', content: '  ', updatedAt: 0);
      expect(empty.preview, '(空笔记)');
      final long =
          PracticeNote(id: 'y', content: '一' * 60, updatedAt: 0);
      expect(long.preview.length, 41); // 40 + 省略号
      expect(long.preview.endsWith('…'), isTrue);
    });
  });
}
