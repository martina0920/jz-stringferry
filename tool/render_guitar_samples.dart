// 吉他单音采样离线渲染器（Karplus-Strong 物理建模）。
//
// 背景：v0.2 需要随包的吉他单音（MIDI 40=E2 … 76=E5），且
// 不得依赖网络/Key。公开 CC0 真实采样无法稳定获取与核验时，
// 用 Karplus-Strong 拨弦算法本地预渲染 22050Hz/16bit/单声道 wav，
// 音色为合成拨弦（非真人录音），在「设置-采样来源说明」中如实标注。
//
// 用法（工程根目录）：dart run tool/render_guitar_samples.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 22050;
  final dir = Directory('assets/audio/guitar');
  dir.createSync(recursive: true);

  var totalBytes = 0;
  for (var midi = 40; midi <= 76; midi++) {
    final freq = 440.0 * pow(2.0, (midi - 69.0) / 12.0);
    // 低音留长、高音短：1.8s 线性降到 0.8s。
    final seconds = 1.8 - (midi - 40) * (1.0 / 36);
    final samples = karplusStrong(
      freq: freq.toDouble(),
      sampleRate: sampleRate,
      seconds: seconds,
      seed: midi,
    );
    final file = File('${dir.path}${Platform.pathSeparator}$midi.wav');
    final bytes = encodeWavPcm16(samples, sampleRate);
    file.writeAsBytesSync(bytes);
    totalBytes += bytes.length;
  }

  stdout.writeln(
      'rendered 37 wav files, total = ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB');
}

/// Karplus-Strong 拨弦合成：噪声环 + 平均反馈，指数衰减包络。
List<double> karplusStrong({
  required double freq,
  required int sampleRate,
  required double seconds,
  int seed = 0,
  double damping = 0.4985,
}) {
  final total = (sampleRate * seconds).round();
  final period = max(2, (sampleRate / freq).round());
  final rnd = Random(seed);

  // 初始激励：经简单一阶低通的白噪声，模拟拨弦偏暖的起音。
  final ring = List<double>.generate(period, (_) => rnd.nextDouble() * 2 - 1);
  var prev = 0.0;
  for (var i = 0; i < period; i++) {
    ring[i] = prev = 0.55 * ring[i] + 0.45 * prev;
  }

  final out = List<double>.filled(total, 0.0);
  var pos = 0;
  for (var i = 0; i < total; i++) {
    final v = ring[pos];
    out[i] = v;
    final next = ring[(pos + 1) % period];
    ring[pos] = damping * (v + next);
    pos = (pos + 1) % period;
  }

  // 起音 8ms 防爆音 + 指数衰减。
  final attack = (sampleRate * 0.008).round();
  for (var i = 0; i < total; i++) {
    final a = i < attack ? i / attack : 1.0;
    final decay = exp(-4.2 * i / total);
    out[i] *= a * decay;
  }

  // 归一化到 0.9 峰值。
  var peak = 0.0;
  for (final v in out) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak > 0) {
    final g = 0.9 / peak;
    for (var i = 0; i < out.length; i++) {
      out[i] *= g;
    }
  }
  return out;
}

/// 标准 PCM16 单声道 WAV（44 字节头）。
List<int> encodeWavPcm16(List<double> samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final bytes = BytesBuilder(copy: false)
    ..add(_ascii('RIFF'))
    ..add(_u32(36 + dataSize))
    ..add(_ascii('WAVE'))
    ..add(_ascii('fmt '))
    ..add(_u32(16))
    ..add(_u16(1)) // PCM
    ..add(_u16(1)) // mono
    ..add(_u32(sampleRate))
    ..add(_u32(sampleRate * 2))
    ..add(_u16(2))
    ..add(_u16(16))
    ..add(_ascii('data'))
    ..add(_u32(dataSize));

  final pcm = Uint8List(samples.length * 2);
  final bd = ByteData.sublistView(pcm);
  var offset = 0;
  for (final s in samples) {
    final v = (s * 32767).clamp(-32768, 32767).round();
    bd.setInt16(offset, v, Endian.little);
    offset += 2;
  }
  bytes.add(pcm);
  return bytes.takeBytes();
}

List<int> _ascii(String s) => s.codeUnits;

List<int> _u32(int v) {
  final b = ByteData(4)..setUint32(0, v, Endian.little);
  return b.buffer.asUint8List();
}

List<int> _u16(int v) {
  final b = ByteData(2)..setUint16(0, v, Endian.little);
  return b.buffer.asUint8List();
}
