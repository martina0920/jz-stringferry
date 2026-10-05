import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// 麦克风 PCM 流抽象（调音器用；测试注入 Fake 喂正弦波）。
///
/// 产物为单声道 [-1, 1] 浮点样本，采样率固定 [sampleRate]。
abstract class TunerSource {
  /// 声明的采样率（与 [start] 产出的流一致）。
  int get sampleRate;

  /// 请求权限并开始采集；失败（权限被拒/无麦克风）返回 null，
  /// 成功返回 PCM 样本流。
  Future<Stream<Float32List>?> start();

  Future<void> stop();

  Future<void> dispose();
}

/// 生产实现：record 7.x 流式录音（PCM16 单声道 44.1k）。
class RecordTunerSource implements TunerSource {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  int get sampleRate => 44100;

  @override
  Future<Stream<Float32List>?> start() async {
    try {
      // hasPermission 在未授权时会拉起系统授权弹窗。
      if (!await _recorder.hasPermission()) return null;
      final bytes = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 44100,
      ));
      return bytes.map(pcm16ToFloat32);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _recorder.stop();
    } catch (_) {
      // 已停止/未开始时忽略。
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// PCM16 小端字节流 → [-1, 1] 浮点样本。
Float32List pcm16ToFloat32(Uint8List bytes) {
  final n = bytes.length ~/ 2;
  final out = Float32List(n);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < n; i++) {
    out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}
