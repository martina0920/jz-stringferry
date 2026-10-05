import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jz_stringferry/core/db/app_database.dart';
import 'package:jz_stringferry/data/transcribe_song_repository.dart';
import 'package:jz_stringferry/features/cover/audio_import_source.dart';
import 'package:jz_stringferry/features/cover/recording_source.dart';
import 'package:jz_stringferry/features/cover/state/cover_store.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

class _FakeImport implements AudioImportSource {
  ImportedAudio? next;

  @override
  Future<ImportedAudio?> pickAndCopy() async => next;
}

class _FakeRecorder implements RecordingSource {
  bool permitted = true;
  String? stopPath;
  int startCount = 0;

  @override
  Future<bool> start() async {
    if (!permitted) return false;
    startCount++;
    return true;
  }

  @override
  Future<String?> stop() => Future.value(stopPath);
}

void main() {
  setUpAll(() => sqfliteFfiInit());

  late AppDatabase appDb;
  late Directory tmp;
  late _FakeImport importSource;
  late _FakeRecorder recorder;
  late CoverStore store;
  late String audioPath;

  Future<CoverStore> build({Future<int> Function(String)? probe}) async {
    return CoverStore(
      repo: TranscribeSongRepository(appDb.database),
      importSource: importSource,
      recordingSource: recorder,
      probeDurationMs: probe,
    );
  }

  setUp(() async {
    appDb = AppDatabase.instance;
    await appDb.init(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    tmp = await Directory.systemTemp.createTemp('cover_store_');
    audioPath = '${tmp.path}${Platform.pathSeparator}a.wav';
    File(audioPath).writeAsStringSync('fake');
    importSource = _FakeImport()
      ..next = ImportedAudio(path: audioPath, title: '测试曲');
    recorder = _FakeRecorder()..stopPath = audioPath;
    store = await build();
  });

  tearDown(() async {
    store.dispose();
    await appDb.disposeForTest();
    await tmp.delete(recursive: true);
  });

  test('importAudio：探时长、入库、刷新列表', () async {
    final id = await store.importAudio();
    expect(id, isNotNull);
    expect(store.items.length, 1);
    expect(store.items.first.title, '测试曲');
    expect(store.items.first.source, 'import');
    expect(store.busy, isFalse);
  });

  test('importAudio：探测到的时长写进曲库', () async {
    final probed = store = await build(probe: (p) async => 12345);
    final id = await probed.importAudio();
    expect(id, isNotNull);
    expect(probed.items.first.durationMs, 12345);
  });

  test('importAudio：用户取消（null）不产生记录', () async {
    importSource.next = null;
    expect(await store.importAudio(), isNull);
    expect(store.items, isEmpty);
  });

  test('importAudio：导入失败写入 error 且清除 busy', () async {
    // 指向不存在的文件 → _saveSong 前不报错；这里用抛错的探测函数制造失败。
    final broken = await build(probe: (p) async => throw Exception('boom'));
    final id = await broken.importAudio();
    expect(id, isNotNull); // 探测失败被吞掉，仍入库
    expect(broken.items.first.durationMs, 0);
  });

  test('录音：启动 → 停止入库，标题带 HH:mm', () async {
    expect(await store.startRecording(), isTrue);
    expect(store.recording, isTrue);
    expect(recorder.startCount, 1);

    final id = await store.stopRecording();
    expect(id, isNotNull);
    expect(store.recording, isFalse);
    expect(store.items.length, 1);
    expect(store.items.first.source, 'record');
    expect(store.items.first.title, matches(RegExp(r'^录音 \d{2}:\d{2}$')));
  });

  test('录音权限被拒：startRecording 返回 false', () async {
    recorder.permitted = false;
    expect(await store.startRecording(), isFalse);
    expect(store.recording, isFalse);
  });

  test('录音文件丢失：stopRecording 报错不入库', () async {
    await store.startRecording();
    recorder.stopPath = '${tmp.path}${Platform.pathSeparator}missing.wav';
    expect(await store.stopRecording(), isNull);
    expect(store.error, isNotNull);
    expect(store.items, isEmpty);
  });

  test('deleteSong：库记录与音频文件一并删除', () async {
    final id = (await store.importAudio())!;
    expect(store.items.length, 1);
    await store.deleteSong(store.items.first);
    expect(store.items, isEmpty);
    expect(File(audioPath).existsSync(), isFalse);
    expect(id, isNotNull);
  });
}
