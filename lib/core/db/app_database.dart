import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'tables.dart';

/// 应用唯一的 sqflite 数据库句柄（单例）。
///
/// 生产环境使用默认 [databaseFactory]（Android/iOS 原生 sqlite）；
/// 测试环境通过 [init] 注入 `sqflite_common_ffi` 的内存工厂。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String dbName = 'stringferry.db';
  static const int schemaVersion = 3;

  Database? _db;

  /// 未初始化时访问会抛 [StateError]，强制调用方先 await [init]。
  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError(
          'AppDatabase 尚未初始化，请先 await AppDatabase.instance.init()');
    }
    return db;
  }

  bool get isOpen => _db != null;

  /// 打开数据库并在首次创建时建表。
  ///
  /// [path] 与 [factory] 仅供测试注入（内存库 + ffi 工厂）。
  Future<void> init({
    String? path,
    DatabaseFactory? factory,
  }) async {
    if (_db != null) return;

    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join((await getApplicationDocumentsDirectory()).path, dbName);

    _db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, _) => _createAll(db),
        onUpgrade: (db, oldVersion, _) async {
          // 增量迁移：每个旧版本只补其之后新增的 DDL，既有数据保持不动。
          if (oldVersion < 2) {
            for (final ddl in Tables.migrationV2Ddl) {
              await db.execute(ddl);
            }
          }
          if (oldVersion < 3) {
            for (final ddl in Tables.migrationV3Ddl) {
              await db.execute(ddl);
            }
          }
        },
      ),
    );
  }

  Future<void> _createAll(Database db) async {
    for (final ddl in Tables.createDdl) {
      await db.execute(ddl);
    }
  }

  /// 清空并重建全部表（保留库本身）。
  Future<void> resetAll() async {
    final db = database;
    await db.transaction((txn) async {
      for (final name in Tables.dropNames) {
        await txn.execute('DROP TABLE IF EXISTS $name');
      }
      for (final ddl in Tables.createDdl) {
        await txn.execute(ddl);
      }
    });
  }

  /// 重置用户数据：清空业务表但保留表结构（meta 一并清空，
  /// 使和弦种子与 2025 模板在下一次启动/调用时重新写入）。
  /// settings 豁免（存 API key，见 [Tables.resetExempt]）。
  Future<void> resetUserData() async {
    final db = database;
    await db.transaction((txn) async {
      for (final name in Tables.dropNames) {
        if (Tables.resetExempt.contains(name)) continue;
        await txn.delete(name);
      }
    });
  }

  /// 关闭并 forget 句柄。仅测试使用。
  Future<void> disposeForTest() async {
    await _db?.close();
    _db = null;
  }
}
