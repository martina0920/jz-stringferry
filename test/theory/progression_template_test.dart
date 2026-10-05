import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/theory/key_harmony.dart';
import 'package:jz_stringferry/core/theory/progression_template.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('模板实例化（FR-6，AC-1/AC-4）', () {
    test('C 大调各模板', () {
      const c = MusicKey(0, KeyMode.major);
      expect(templateById('p1645')!.instantiate(c), ['C', 'Am', 'F', 'G']);
      expect(templateById('p1564')!.instantiate(c), ['C', 'G', 'Am', 'F']);
      expect(templateById('p4536251')!.instantiate(c),
          ['F', 'G', 'Em', 'Am', 'Dm', 'G', 'C']);
      expect(templateById('canon')!.instantiate(c),
          ['C', 'G', 'Am', 'Em', 'F', 'C', 'F', 'G']);
      expect(templateById('p251')!.instantiate(c), ['Dm7', 'G7', 'Cmaj7']);
    });

    test('A 小调两个模板（AC-1）', () {
      const am = MusicKey(9, KeyMode.minor);
      expect(templateById('minor1645')!.instantiate(am), ['Am', 'F', 'C', 'G']);
      expect(templateById('minorWalk')!.instantiate(am), ['Am', 'G', 'F', 'Em']);
    });

    test('Bb 大调 1645（AC-1）与降号拼写', () {
      const bb = MusicKey(10, KeyMode.major);
      expect(templateById('p1645')!.instantiate(bb), ['Bb', 'Gm', 'Eb', 'F']);
      // 4536251 含 Ab/Eb 等降号音。
      expect(templateById('p4536251')!.instantiate(bb),
          ['Eb', 'F', 'Dm', 'Gm', 'Cm', 'F', 'Bb']);
    });

    test('D 小调万能模板含 Bb 不含 A#', () {
      const dm = MusicKey(2, KeyMode.minor);
      final r = templateById('minor1645')!.instantiate(dm);
      // D 自然小调：D E F G A Bb C → i-VI-III-VII = Dm Bb F C
      expect(r, ['Dm', 'Bb', 'F', 'C']);
      expect(r.join(' '), isNot(contains('A#')));
    });

    test('模板数量与基本字段', () {
      expect(progressionTemplates.length, 7);
      for (final t in progressionTemplates) {
        expect(t.degrees, isNotEmpty);
        expect(t.numerals, isNotEmpty);
        expect(t.hint, isNotEmpty);
      }
    });
  });

  group('模板产物与 510 和弦库名称一致性（FR-6/FR-18）', () {
    late AppDatabase appDb;
    late ChordRepository repo;

    setUp(() async {
      appDb = AppDatabase.instance;
      await appDb.init(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      await ChordSeeder.seedIfEmpty(appDb.database);
      repo = ChordRepository(appDb.database);
    });

    tearDown(() => appDb.disposeForTest());

    test('24 调 × 7 模板实例化的每个和弦都能在库中按名查到', () async {
      final missing = <String>[];
      for (final key in [...MusicKey.allMajor, ...MusicKey.allMinor]) {
        for (final t in progressionTemplates) {
          if (t.mode != key.mode) continue;
          for (final name in t.instantiate(key)) {
            final spec = await repo.byName(name);
            if (spec == null) missing.add('${key.displayName} ${t.id}: $name');
          }
        }
      }
      expect(missing, isEmpty, reason: '以下和弦名在库中缺失:\n${missing.join('\n')}');
    });
  });
}
