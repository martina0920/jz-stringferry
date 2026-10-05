import 'dart:math' as math;
import 'dart:typed_data';

/// 六根弦的标准频率（A4=440）。
class TunerTargets {
  TunerTargets._();

  static double freqOf(int midi) => 440.0 * math.pow(2.0, (midi - 69) / 12.0);

  static const List<(int, String, int)> strings = [
    (1, '1 弦 E4', 64),
    (2, '2 弦 B3', 59),
    (3, '3 弦 G3', 55),
    (4, '4 弦 D3', 50),
    (5, '5 弦 A2', 45),
    (6, '6 弦 E2', 40),
  ];
}

/// 音高检测结果。
class PitchDetection {
  /// 基频（Hz）；未检出为 null。
  final double? freq;

  /// 音量（RMS）；用于判断是否在吹/弹。
  final double rms;

  const PitchDetection({this.freq, required this.rms});

  bool get hasPitch => freq != null && rms > 0.01;
}

/// 自相关音高检测（归一化方差的方波不敏感，适合吉他单音）。
///
/// 纯函数：输入 Float32 单声道 buffer（如 2048 样本 @44.1k）。
class PitchDetector {
  final int sampleRate;

  /// 搜索的基频范围（Hz）：覆盖吉他 E2(82)–E4(330) 再留裕量。
  final double minFreq;
  final double maxFreq;

  PitchDetector({
    required this.sampleRate,
    this.minFreq = 70,
    this.maxFreq = 400,
  });

  PitchDetection detect(Float32List samples) {
    final n = samples.length;
    var sumSq = 0.0;
    for (var i = 0; i < n; i++) {
      sumSq += samples[i] * samples[i];
    }
    final rms = math.sqrt(sumSq / n);
    if (rms < 0.01) {
      return PitchDetection(rms: rms);
    }

    final minLag = (sampleRate / maxFreq).floor().clamp(1, n - 2);
    final maxLag = math.min((sampleRate / minFreq).floor(), n - 2);
    if (maxLag <= minLag) return PitchDetection(rms: rms);

    // 归一化自相关（按重叠长度平均，补偿长 lag 衰减）。
    final lags = maxLag - minLag + 1;
    final corr = Float64List(lags);
    for (var idx = 0; idx < lags; idx++) {
      final lag = minLag + idx;
      var c = 0.0;
      for (var i = 0; i < n - lag; i++) {
        c += samples[i] * samples[i + lag];
      }
      corr[idx] = c / (n - lag);
    }

    var corrMax = 0.0;
    for (final c in corr) {
      if (c > corrMax) corrMax = c;
    }
    // 相关性太弱 → 视为无明确音高。
    if (corrMax < rms * rms * 0.3) {
      return PitchDetection(rms: rms);
    }

    // 第一个显著局部峰（>= 0.9·最大值），避免跳到更高倍周期处。
    var peak = -1;
    for (var idx = 1; idx < lags - 1; idx++) {
      if (corr[idx] >= corr[idx - 1] &&
          corr[idx] >= corr[idx + 1] &&
          corr[idx] >= 0.9 * corrMax) {
        peak = idx;
        break;
      }
    }
    if (peak < 0) return PitchDetection(rms: rms);

    // 抛物线插值细化峰位（亚 lag 精度）。
    final yPrev = corr[peak - 1], y = corr[peak], yNext = corr[peak + 1];
    final denom = yPrev - 2 * y + yNext;
    final delta = denom == 0 ? 0.0 : (0.5 * (yPrev - yNext) / denom).clamp(-0.5, 0.5);
    final bestLag = minLag + peak + delta;

    final freq = sampleRate / bestLag;
    if (freq < minFreq || freq > maxFreq) {
      return PitchDetection(rms: rms);
    }
    return PitchDetection(freq: freq, rms: rms);
  }
}

/// 偏差工具（纯函数）。
class TunerMath {
  TunerMath._();

  /// 检测频率相对目标频率的偏差音分（正=偏高）。
  static double centsOff(double measured, double target) =>
      1200 * (math.log(measured / target) / math.log(2));

  /// 就位判定：±5 音分内算准。
  static bool inTune(double cents) => cents.abs() <= 5;

  /// 指针/彩条位置：-50..50 音分映射到 -1..1（越界截断）。
  static double gauge(double cents) => (cents / 50).clamp(-1.0, 1.0);
}
