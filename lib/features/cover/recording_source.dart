import 'dart:io';

import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'audio_import_source.dart';

/// 应用内录音抽象（测试注入 Fake）。
abstract class RecordingSource {
  /// 请求权限并开始录音；失败（权限被拒/启动异常）返回 false。
  Future<bool> start();

  /// 停止录音并返回音频文件路径；未在录音/失败返回 null。
  Future<String?> stop();
}

/// 生产实现：record 7.x 文件录音（AAC m4a，just_audio 可直接播放）。
class MicRecordingSource implements RecordingSource {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;

  @override
  Future<bool> start() async {
    if (_recording) return true;
    try {
      // hasPermission 在未授权时会拉起系统授权弹窗。
      if (!await _recorder.hasPermission()) return false;
      final dir = await coverAudioDir();
      final path = '${dir.path}${Platform.pathSeparator}'
          '${const Uuid().v4()}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
        ),
        path: path,
      );
      _recording = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> stop() async {
    if (!_recording) return null;
    _recording = false;
    try {
      return await _recorder.stop();
    } catch (_) {
      return null;
    }
  }
}
