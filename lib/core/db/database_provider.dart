import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// 数据库初始化状态的全局状态载体。
///
/// 启动流程在 runApp 前完成首次初始化（见 main.dart）；
/// 后续「恢复示例数据」等操作通过本 provider 通知 UI 刷新。
class DatabaseProvider extends ChangeNotifier {
  bool get isReady => AppDatabase.instance.isOpen;

  Database get database => AppDatabase.instance.database;

  /// 清空全部用户数据（和弦库/收藏/最近/计划/打卡）并重建表结构。
  /// 后续任务会在此之后重新执行种子写入与模板导入。
  Future<void> resetUserData() async {
    await AppDatabase.instance.resetUserData();
    notifyListeners();
  }

  /// 清空并重建全部表（含 meta），测试或深度排错时使用。
  Future<void> resetAll() async {
    await AppDatabase.instance.resetAll();
    notifyListeners();
  }
}
