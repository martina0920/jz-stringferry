import 'package:sqflite/sqflite.dart';

/// 设置键值存取（settings 表）。API key 等敏感配置存这里，
/// 恢复示例数据（resetUserData）不会清掉本表。
class SettingsRepository {
  final Database db;

  SettingsRepository(this.db);

  /// 百炼云端识别 API Key 的存储键。
  static const String dashscopeApiKey = 'ai.dashscope_api_key';

  Future<String?> get(String k) async {
    final rows = await db.query('settings',
        where: 'k = ?', whereArgs: [k], limit: 1);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  Future<void> set(String k, String v) async {
    await db.insert('settings', {'k': k, 'v': v},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String k) =>
      db.delete('settings', where: 'k = ?', whereArgs: [k]);
}
