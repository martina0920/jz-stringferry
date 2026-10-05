import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/app.dart';
import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/progression_player.dart';
import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/core/router/app_router.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';
import 'package:jz_stringferry/data/progression_repository.dart';
import 'package:jz_stringferry/features/arranger/state/arranger_store.dart';

/// 记录式假音频播放器。
class HarnessTonePlayer implements TonePlayer {
  final List<String> playedAssets = [];
  int stopCount = 0;

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> stopAll() async => stopCount++;
}

/// 记录延迟不真正计时的调度器。
class HarnessScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }
}

/// arranger widget 测试共用环境：FFI 内存库（已 seed）+ 假播放器 + 真实路由。
class ArrangerHarness {
  late AppDatabase appDb;
  late ArrangerStore store;
  late HarnessTonePlayer player;
  late HarnessScheduler scheduler;

  Future<void> setUp() async {
    sqfliteFfiInit();
    appDb = AppDatabase.instance;
    await appDb.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await ChordSeeder.seedIfEmpty(appDb.database);
    player = HarnessTonePlayer();
    scheduler = HarnessScheduler();
    store = ArrangerStore(
      repo: ProgressionRepository(appDb.database),
      chordRepo: ChordRepository(appDb.database),
      player: ProgressionPlayer(player, scheduler: scheduler),
    );
  }

  Future<void> tearDown() async {
    store.dispose();
    await appDb.disposeForTest();
  }

  /// 清空全部业务表（含和弦库）后重新 seed，保证每个用例数据干净。
  Future<void> reset() async {
    await appDb.resetUserData();
    await ChordSeeder.seedIfEmpty(appDb.database);
    await store.loadList();
  }

  /// 仅挂载应用（不导航、不等待）。
  Widget appShell() => MultiProvider(
        providers: [
          ChangeNotifierProvider<ArrangerStore>.value(value: store),
        ],
        child: const JzStringFerryApp(),
      );

  /// pump 应用并导航到 [location]，等转场走完后留一个 FFI 等待窗口。
  ///
  /// 注意：runAsync 必须在路由转场动画结束之后调用（动画中途进入真实 zone
  /// 会死锁，v0.3 widget 测试实测）。
  Future<void> pumpLocation(WidgetTester tester, String location) async {
    await tester.pumpWidget(appShell());
    AppRouter.router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }

  /// tap 后的等待：先推进转场/动画，再在真实 zone 等 FFI 完成，最后补帧。
  Future<void> settle(WidgetTester tester,
      {Duration wait = const Duration(milliseconds: 200)}) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() => Future<void>.delayed(wait));
    await tester.pump();
  }
}
