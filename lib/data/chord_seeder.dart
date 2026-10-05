import 'package:sqflite/sqflite.dart';

import '../core/models/chord_spec.dart';
import '../core/theory/chord_builder.dart';
import '../core/theory/chord_quality.dart';
import '../core/theory/fingering.dart';
import '../core/theory/note.dart';

/// 和弦库种子：17 根音名（含升降异拼）x 30 性质 = 510 条，
/// 全部由乐理引擎 + 指法引擎在首次启动时程序化生成。
class ChordSeeder {
  ChordSeeder._();

  static const String seedVersion = '1';
  static const String metaKey = 'chord_seed_version';

  /// 生成全部 510 条记录（纯函数，便于测试）。
  static List<ChordSpec> generateAll() {
    final result = <ChordSpec>[];
    var sort = 0;
    for (final root in allRootNames) {
      for (final quality in allQualities) {
        final built = ChordBuilder.build(root, quality);
        final fingerings = fingeringsFor(root, quality);

        result.add(ChordSpec(
          name: built.name,
          root: root,
          rootPc: Note.pitchClassOf(root),
          quality: ChordQualityRef(quality.id),
          family: quality.family,
          tones: built.toneNames,
          intervals: built.tones.map((t) => t.intervalLabel).toList(),
          fingerings: fingerings
              .map((f) => FingeringSpec(
                    f.strings,
                    barreFret: f.barreFret,
                    barreThickestString: f.barreThickestString,
                  ))
              .toList(),
          sortKey: sort++,
        ));
      }
    }
    return result;
  }

  /// 仅在 chords 表为空时写入种子（幂等）。
  static Future<bool> seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM chords'),
    );
    if (count != null && count > 0) return false;

    final records = generateAll();
    await db.transaction((txn) async {
      // 防御性清理。
      await txn.delete('chords');
      for (final r in records) {
        await txn.insert('chords', r.toMap()..remove('id'));
      }
      await txn.insert('meta', {'k': metaKey, 'v': seedVersion},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return true;
  }
}
