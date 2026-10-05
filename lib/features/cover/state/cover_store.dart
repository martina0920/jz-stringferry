import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/transcribe_models.dart';
import '../../../data/transcribe_song_repository.dart';
import '../audio_import_source.dart';
import '../recording_source.dart';

/// 扒带曲库状态：列表 + 本地导入 + 应用内录音。
class CoverStore extends ChangeNotifier {
  final TranscribeSongRepository repo;
  final AudioImportSource importSource;
  final RecordingSource recordingSource;

  /// 时长探测（首装后第一次播放回填 durationMs；注入便于测试）。
  final Future<int> Function(String path)? probeDurationMs;

  List<TranscribeSong> _items = [];

  /// 导入/保存录音等耗时操作的互斥标志。
  bool _busy = false;
  bool _recording = false;

  /// 最近一次失败的用户可读原因（null = 无）。
  String? error;

  CoverStore({
    required this.repo,
    required this.importSource,
    required this.recordingSource,
    this.probeDurationMs,
  });

  List<TranscribeSong> get items => List.unmodifiable(_items);
  bool get busy => _busy;
  bool get recording => _recording;

  Future<void> load() async {
    _items = await repo.list();
    notifyListeners();
  }

  /// 从系统文件选择器导入一首本地音频；成功返回新歌 id。
  Future<String?> importAudio() async {
    if (_busy || _recording) return null;
    _busy = true;
    error = null;
    notifyListeners();
    try {
      final imported = await importSource.pickAndCopy();
      if (imported == null) return null;
      final id = await _saveSong(
        title: imported.title,
        path: imported.path,
        source: 'import',
      );
      return id;
    } catch (e) {
      error = '导入失败：$e';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 开始录音；返回是否成功启动（权限被拒为 false）。
  Future<bool> startRecording() async {
    if (_busy || _recording) return false;
    final ok = await recordingSource.start();
    _recording = ok;
    notifyListeners();
    return ok;
  }

  /// 停止录音并入库；成功返回新歌 id，失败/取消返回 null。
  Future<String?> stopRecording() async {
    if (!_recording) return null;
    _busy = true;
    error = null;
    notifyListeners();
    try {
      final path = await recordingSource.stop();
      if (path == null || !await File(path).exists()) {
        error = '录音文件保存失败';
        return null;
      }
      final now = DateTime.now();
      final title = '录音 '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';
      return await _saveSong(title: title, path: path, source: 'record');
    } catch (e) {
      error = '录音保存失败：$e';
      return null;
    } finally {
      _recording = false;
      _busy = false;
      notifyListeners();
    }
  }

  /// 删除歌曲：级联删分段 + 删音频文件。
  Future<void> deleteSong(TranscribeSong song) async {
    await repo.delete(song.id);
    try {
      final f = File(song.filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 文件清理失败不影响列表一致性。
    }
    await load();
  }

  Future<String> _saveSong({
    required String title,
    required String path,
    required String source,
  }) async {
    var durationMs = 0;
    final probe = probeDurationMs;
    if (probe != null) {
      try {
        durationMs = await probe(path);
      } catch (_) {
        // 探测失败按未知时长入库，详情页播放后会回填。
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final song = TranscribeSong(
      id: const Uuid().v4(),
      title: title,
      filePath: path,
      durationMs: durationMs,
      source: source,
      createdAt: now,
      updatedAt: now,
    );
    await repo.insert(song);
    await load();
    return song.id;
  }
}
