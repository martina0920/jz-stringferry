import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/metronome_engine.dart';

void main() {
  group('MetronomeEngine.buildBarTicks', () {
    test('4/4 四分：4 个 tick，第 1 拍 kick，其余 hat', () {
      final ticks = MetronomeEngine.buildBarTicks(bpm: 60, beatsPerBar: 4);
      expect(ticks.length, 4);
      expect(ticks[0].asset, endsWith('kick.wav'));
      for (var i = 1; i < 4; i++) {
        expect(ticks[i].asset, endsWith('hat.wav'));
      }
      // 60BPM 每拍 1000ms。
      expect([0, 1000, 2000, 3000], ticks.map((t) => t.timeMs).toList());
    });

    test('自定义重音拍：0/2 重音', () {
      final ticks = MetronomeEngine.buildBarTicks(
          bpm: 60, beatsPerBar: 4, accentBeats: {0, 2});
      expect(ticks[0].asset, endsWith('kick.wav'));
      expect(ticks[1].asset, endsWith('hat.wav'));
      expect(ticks[2].asset, endsWith('kick.wav'));
      expect(ticks[3].asset, endsWith('hat.wav'));
    });

    test('八分细分：每拍 2 tick，反拍 hat', () {
      final ticks = MetronomeEngine.buildBarTicks(
          bpm: 60, beatsPerBar: 2, subdivision: MetronomeSubdivision.eighth);
      expect(ticks.length, 4);
      expect(ticks.map((t) => t.timeMs).toList(), [0, 500, 1000, 1500]);
      expect(ticks[0].asset, endsWith('kick.wav'));
      expect(ticks[1].asset, endsWith('hat.wav'));
    });

    test('十六分细分：每拍 4 tick，第 3 反拍 snare', () {
      final ticks = MetronomeEngine.buildBarTicks(
          bpm: 60, beatsPerBar: 1, subdivision: MetronomeSubdivision.sixteenth);
      expect(ticks.length, 4);
      expect(ticks.map((t) => t.timeMs).toList(), [0, 250, 500, 750]);
      expect(ticks[0].asset, endsWith('kick.wav'));
      expect(ticks[1].asset, endsWith('hat.wav'));
      expect(ticks[2].asset, endsWith('snare.wav'));
      expect(ticks[3].asset, endsWith('hat.wav'));
    });

    test('拍号边界：1 拍与 7 拍', () {
      expect(
          MetronomeEngine.buildBarTicks(bpm: 120, beatsPerBar: 1).length, 1);
      expect(
          MetronomeEngine.buildBarTicks(bpm: 120, beatsPerBar: 7).length, 7);
    });

    test('3/4 拍 90BPM 小节时长 = 2000ms', () {
      expect(MetronomeEngine.barMs(90, 3), 2000);
    });
  });

  group('TapTempo.estimateBpm', () {
    int bpmOf(List<int> taps) => TapTempo.estimateBpm(taps)!;

    test('稳定 500ms 间隔 → 120BPM', () {
      expect(bpmOf([0, 500, 1000, 1500]), 120);
    });

    test('稳定 1000ms 间隔 → 60BPM', () {
      expect(bpmOf([0, 1000, 2000]), 60);
    });

    test('取最近 4 个间隔，早期点击不影响', () {
      // 最后 5 次点击间隔 600ms → 100BPM。
      expect(
        bpmOf([0, 100000, 100600, 101200, 101800, 102400]),
        100,
      );
    });

    test('超过 2s 的旧间隔被「重新开始」截断', () {
      expect(bpmOf([0, 3000, 3500, 4000]), 120); // 0-3000 被忽略
    });

    test('区间外夹紧：超快点击夹到 300，2000ms 间隔得下限 30', () {
      expect(bpmOf([0, 100, 200]), 300);
      expect(bpmOf([0, 2000, 4000]), 30);
    });

    test('不足 2 次或间隔全部超时 → null', () {
      expect(TapTempo.estimateBpm([0]), isNull);
      expect(TapTempo.estimateBpm([]), isNull);
      expect(TapTempo.estimateBpm([0, 5000, 10000]), isNull);
    });
  });
}
