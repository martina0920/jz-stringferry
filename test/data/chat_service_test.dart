import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/chat_service.dart';
import 'package:jz_stringferry/data/chord_repository.dart';
import 'package:jz_stringferry/data/chord_seeder.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  late LocalChatService chat;

  setUp(() async {
    await AppDatabase.instance.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await ChordSeeder.seedIfEmpty(AppDatabase.instance.database);
    chat = LocalChatService(
      chordRepo: ChordRepository(AppDatabase.instance.database),
    );
  });

  tearDown(() => AppDatabase.instance.disposeForTest());

  test('和弦意图：返回 Am7 正确组成音（查库）', () async {
    final reply = await chat.ask('Am7 和弦的组成音是什么？');
    expect(reply, contains('Am7'));
    expect(reply, contains('A'));
    expect(reply, contains('C'));
    expect(reply, contains('E'));
    expect(reply, contains('G'));
  });

  test('进行意图：C 调 1645 与 1564 级数文本', () async {
    final r1 = await chat.ask('推荐一个 C 调的 1645 进行');
    expect(r1, contains('C → Am → F → G'));
    expect(r1, contains('I–vi–IV–V'));

    final r2 = await chat.ask('1564 进行是什么？');
    expect(r2, contains('C → G → Am → F'));
    expect(r2, contains('I–V–vi–IV'));
  });

  test('进行意图：G 调顺阶和弦随调号转调', () async {
    final r = await chat.ask('G调 1645');
    // G vi=Em, IV=C, V=D
    expect(r, contains('G → Em → C → D'));
  });

  test('M1 回归：UI 快捷指令原句（含「和弦」）不被查和弦意图截胡', () async {
    final r = await chat.ask('推荐一个 C 调的常用和弦进行');
    expect(r, contains('C → Am → F → G'));
    expect(r, isNot(contains('组成音是')));

    // 裸和弦名仍按查和弦处理。
    final bare = await chat.ask('Am7');
    expect(bare, contains('组成音是'));
  });

  test('降号调进行按降号记谱输出（Bb 调：Bb、Eb 而非 A#、D#）', () async {
    final r = await chat.ask('Bb 调 1645 进行');
    expect(r, contains('Bb → Gm → Eb → F'));
    expect(r, isNot(contains('A#')));
  });

  test('进度意图：注入快照返回统计摘要，无数据时引导建计划', () async {
    const snap = StudySnapshot(
      taskCount: 9,
      completedCount: 3,
      streakDays: 5,
      completedMinutes: 70,
      totalPlannedMinutes: 210,
      overdueCount: 1,
      weakestCategory: '混音类',
    );
    final r = await chat.ask('分析我的学习进度', study: snap);
    expect(r, contains('9 个任务'));
    expect(r, contains('3 个'));
    expect(r, contains('33%'));
    expect(r, contains('连续打卡 5 天'));
    expect(r, contains('混音类'));
    expect(r, contains('1 个任务已逾期'));

    final empty = await chat.ask('我的计划怎么样');
    expect(empty, contains('导入 2025 模板'));
  });

  test('其他意图：离线本地模式兜底文案', () async {
    final r = await chat.ask('今天天气怎么样');
    expect(r, LocalChatService.offlineHint);
  });

  group('suggestProgression（FR-21）', () {
    test('口语 C 调进行 → 1645 草稿', () {
      final d = chat.suggestProgression('推荐一个 C 调的常用和弦进行');
      expect(d, isNotNull);
      expect(d!.title, 'C 大调 1645');
      expect(d.key.rootPc, 0);
      expect(d.chords, ['C', 'Am', 'F', 'G']);
    });

    test('1564 句式 → 1564 草稿', () {
      final d = chat.suggestProgression('1564 进行是什么？');
      expect(d, isNotNull);
      expect(d!.title, 'C 大调 1564');
      expect(d.chords, ['C', 'G', 'Am', 'F']);
    });

    test('G 调 1645 草稿随调转调', () {
      final d = chat.suggestProgression('推荐 G调 1645 进行');
      expect(d, isNotNull);
      expect(d!.chords, ['G', 'Em', 'C', 'D']);
    });

    test('小调问句 → 小调草稿', () {
      final d = chat.suggestProgression('推荐一个 A 小调的进行');
      expect(d, isNotNull);
      expect(d!.key.mode.name, 'minor');
      expect(d.chords.first, 'Am');
    });

    test('非进行问题 → null', () {
      expect(chat.suggestProgression('Am7 和弦的组成音是什么？'), isNull);
      expect(chat.suggestProgression('分析我的学习进度'), isNull);
      expect(chat.suggestProgression('什么是和弦级数？'), isNull);
      expect(chat.suggestProgression('今天天气怎么样'), isNull);
    });

    test('静态断言：AI 纯本地部分无 dio/http/dart:io 引用；http 白名单仅限云端识别', () {
      // 1) chat_service 与 AI UI 保持零网络依赖。
      final localTargets = [
        File('lib/data/chat_service.dart'),
        ...Directory('lib/features/ai').listSync().whereType<File>(),
      ];
      for (final f in localTargets) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('dio')), reason: '${f.path} 不应引用 dio');
        expect(src, isNot(contains('HttpClient')),
            reason: '${f.path} 不应引用 HttpClient');
        expect(src, isNot(contains("dart:io")),
            reason: '${f.path} 不应 import dart:io');
        expect(src, isNot(contains('package:http')),
            reason: '${f.path} 不应引用 http 包');
      }

      // 2) 全 lib 范围内 package:http 只允许出现在云端识别白名单文件。
      const whitelist = {
        'lib\\data\\transcribe_service.dart',
        'lib\\data\\qwen_omni_transcribe_service.dart',
      };
      final libFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in libFiles) {
        final src = f.readAsStringSync();
        if (src.contains('package:http')) {
          expect(whitelist.contains(f.path), isTrue,
              reason: '${f.path} 引用 http 包但不在白名单');
        }
      }
      // 白名单文件必须真实存在（防改名后断言空转）。
      for (final w in whitelist) {
        expect(File(w).existsSync(), isTrue, reason: '白名单文件缺失 $w');
      }
    });
  });
}
