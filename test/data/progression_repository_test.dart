import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/models/progression.dart';
import 'package:jz_stringferry/core/theory/key_harmony.dart';
import 'package:jz_stringferry/data/progression_repository.dart';

Progression _sample({
  String id = 'prog_a',
  String title = '练习一',
  int rootPc = 0,
  KeyMode mode = KeyMode.major,
  List<String> chords = const ['C', 'Am', 'F', 'G'],
  int bpm = 90,
  TimeSignature ts = TimeSignature.fourFour,
  AccomPattern pat = AccomPattern.strum,
  int t = 1000,
}) =>
    Progression(
      id: id,
      title: title,
      keyRootPc: rootPc,
      keyMode: mode,
      chords: chords,
      bpm: bpm,
      timeSignature: ts,
      pattern: pat,
      createdAt: t,
      updatedAt: t,
    );

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('ProgressionRepository（FR-15，AC-8）', () {
    late AppDatabase appDb;
    late ProgressionRepository repo;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      repo = ProgressionRepository(appDb.database);
    });

    tearDown(() => appDb.disposeForTest());

    test('insert + byId + list 按 updatedAt DESC', () async {
      await repo.insert(_sample(id: 'a', title: '旧', t: 1000));
      await repo.insert(_sample(id: 'b', title: '新', t: 2000));
      expect((await repo.byId('a'))!.title, '旧');
      expect(await repo.byId('missing'), isNull);
      final list = await repo.list();
      expect(list.map((e) => e.id).toList(), ['b', 'a']);
    });

    test('update 自动刷新 updatedAt', () async {
      await repo.insert(_sample(t: 1000));
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final saved = await repo.update(_sample(t: 1000).copyWith(title: '改名'));
      expect(saved.title, '改名');
      expect(saved.updatedAt > 1000, isTrue);
      expect((await repo.byId('prog_a'))!.updatedAt, saved.updatedAt);
    });

    test('delete', () async {
      await repo.insert(_sample());
      await repo.delete('prog_a');
      expect(await repo.byId('prog_a'), isNull);
      expect(await repo.list(), isEmpty);
    });

    test('duplicate：标题加副本、id 独立、内容一致', () async {
      final original = _sample(
        mode: KeyMode.minor,
        rootPc: 9,
        bpm: 120,
        ts: TimeSignature.threeFour,
        pat: AccomPattern.finger,
      );
      await repo.insert(original);
      final copy = await repo.duplicate(original);
      expect(copy.id, isNot(original.id));
      expect(copy.title, '练习一 副本');
      expect(copy.keyRootPc, 9);
      expect(copy.keyMode, KeyMode.minor);
      expect(copy.chords, ['C', 'Am', 'F', 'G']);
      expect(copy.bpm, 120);
      expect(copy.timeSignature, TimeSignature.threeFour);
      expect(copy.pattern, AccomPattern.finger);
      final list = await repo.list();
      expect(list.length, 2);
    });
  });

  group('Progression 序列化往返', () {
    test('全字段 fromMap(toMap) 守恒', () {
      final p = _sample(
        mode: KeyMode.minor,
        rootPc: 10,
        bpm: 40,
        ts: TimeSignature.threeFour,
        pat: AccomPattern.slowStrum,
        chords: const ['Bb', 'Gm', 'Ebmaj7', 'F7'],
      );
      final back = Progression.fromMap(p.toMap());
      expect(back.id, p.id);
      expect(back.title, p.title);
      expect(back.keyRootPc, 10);
      expect(back.keyMode, KeyMode.minor);
      expect(back.chords, ['Bb', 'Gm', 'Ebmaj7', 'F7']);
      expect(back.bpm, 40);
      expect(back.timeSignature, TimeSignature.threeFour);
      expect(back.pattern, AccomPattern.slowStrum);
      expect(back.createdAt, p.createdAt);
      expect(back.updatedAt, p.updatedAt);
      expect(back.key.displayName, 'Bb 小调');
    });

    test('chords 脏数据降级为空列表不抛错', () {
      final m = _sample().toMap()..['chords'] = 'not-json';
      expect(Progression.fromMap(m).chords, isEmpty);
    });
  });
}
