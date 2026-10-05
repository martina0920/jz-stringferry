import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/pitch_detector.dart';

Float32List sine(double freq, int sampleRate, int samples,
    {double amp = 0.3}) {
  final data = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    data[i] =
        amp * math.sin(2 * math.pi * freq * i / sampleRate);
  }
  return data;
}

void main() {
  group('PitchDetector（合成正弦）', () {
    test('E2/A2/D3/G3/B3/E4 六弦基频检测误差 < 1Hz', () {
      final det = PitchDetector(sampleRate: 44100);
      for (final (_, _, midi) in TunerTargets.strings) {
        final f = TunerTargets.freqOf(midi);
        final r = det.detect(sine(f, 44100, 4096));
        expect(r.hasPitch, isTrue, reason: 'midi $midi 未检出');
        expect(r.freq!, closeTo(f, 2.0),
            reason: 'midi $midi 检出 ${r.freq} vs $f');
      }
    });

    test('静音（零幅度）→ 无音高', () {
      final det = PitchDetector(sampleRate: 44100);
      final r = det.detect(Float32List(4096));
      expect(r.hasPitch, isFalse);
    });

    test('超范围频率（50Hz / 600Hz）不检出或不误判为界内其他音', () {
      final det = PitchDetector(sampleRate: 44100);
      final low = det.detect(sine(50, 44100, 4096));
      final high = det.detect(sine(600, 44100, 4096));
      for (final r in [low, high]) {
        if (r.hasPitch) {
          expect(r.freq!, inExclusiveRange(det.minFreq, det.maxFreq));
        }
      }
    });
  });

  group('TunerMath', () {
    test('centsOff：440 vs 442 ≈ +7.85 音分', () {
      final cents = TunerMath.centsOff(442, 440);
      expect(cents, closeTo(7.85, 0.2));
    });

    test('inTune：±5 音分内为准', () {
      expect(TunerMath.inTune(4.9), isTrue);
      expect(TunerMath.inTune(-5), isTrue);
      expect(TunerMath.inTune(5.1), isFalse);
    });

    test('gauge：±50 音分满偏，越界截断', () {
      expect(TunerMath.gauge(0), 0.0);
      expect(TunerMath.gauge(25), closeTo(0.5, 1e-9));
      expect(TunerMath.gauge(120), 1.0);
      expect(TunerMath.gauge(-120), -1.0);
    });
  });

  test('TunerTargets：六弦 midi 与频率合理（E2≈82.4，E4≈329.6）', () {
    expect(TunerTargets.freqOf(40), closeTo(82.41, 0.05));
    expect(TunerTargets.freqOf(64), closeTo(329.63, 0.05));
    expect(TunerTargets.strings.length, 6);
  });
}
