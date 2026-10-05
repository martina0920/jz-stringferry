import 'package:sqflite/sqflite.dart';

/// 音感训练每日统计（ear_training_stats 表），按「自然日 x 模式」累加。
class EarTrainingRepository {
  final Database db;

  EarTrainingRepository(this.db);

  /// 记一次答题结果（正确与否各计 1 total）。
  Future<void> record({
    required String date, // ISO yyyy-MM-dd
    required String mode,
    required bool correct,
  }) async {
    await db.rawInsert('''
INSERT INTO ear_training_stats (date, mode, correct, total)
VALUES (?, ?, ?, 1)
ON CONFLICT(date, mode) DO UPDATE SET
  correct = correct + ?,
  total = total + 1
''', [date, mode, correct ? 1 : 0, correct ? 1 : 0]);
  }

  /// 某日的各模式统计：mode -> (correct, total)。
  Future<Map<String, (int, int)>> dayStats(String date) async {
    final rows = await db.query('ear_training_stats',
        where: 'date = ?', whereArgs: [date]);
    return {
      for (final r in rows)
        r['mode'] as String: (
          (r['correct'] as int?) ?? 0,
          (r['total'] as int?) ?? 0,
        ),
    };
  }

  /// 全部统计（供汇总展示）：mode -> (correct, total) 累计。
  Future<Map<String, (int, int)>> totalStats() async {
    final rows = await db.rawQuery('''
SELECT mode, SUM(correct) AS c, SUM(total) AS t
FROM ear_training_stats GROUP BY mode
''');
    return {
      for (final r in rows)
        (r['mode'] as String): (
          (r['c'] as int?) ?? 0,
          (r['t'] as int?) ?? 0,
        ),
    };
  }
}
