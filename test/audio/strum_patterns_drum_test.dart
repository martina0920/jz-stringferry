import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/strum_patterns.dart';
import 'package:jz_stringferry/core/models/progression.dart';

const List<List<int>> _voices = [
  [48, 52, 55, 60, 64],
  [45, 48, 52, 57, 60],
];

void main() {
  group('buildDrumSchedule（v0.5 鼓组伴奏轨）', () {
    test('4/4 90BPM 单小节：kick 第1拍、snare 2/4 拍、hat 每8分音', () {
      final s = StrumPatterns.buildDrumSchedule(
        bpm: 90,
        timeSignature: TimeSignature.fourFour,
        durationMs: 2667, // 4 拍 x 666.67ms
      );
      const beatMs = 60000 / 90;

      final kicks = s.notes.where((n) => n.drumKind == DrumKind.kick).toList();
      expect(kicks.length, 1);
      expect(kicks.single.timeMs, 0);
      expect(kicks.single.chordIndex, -1);

      final snares =
          s.notes.where((n) => n.drumKind == DrumKind.snare).toList();
      expect(snares.map((n) => n.timeMs),
          [(1 * beatMs).round(), (3 * beatMs).round()]);

      final hats = s.notes.where((n) => n.drumKind == DrumKind.hat).toList();
      expect(hats.length, 8); // 4 拍 x 2 半拍
      // hat 落点严格递增。
      for (var i = 1; i < hats.length; i++) {
        expect(hats[i].timeMs, greaterThan(hats[i - 1].timeMs));
      }
    });

    test('3/4：snare 落第 2/3 拍', () {
      final s = StrumPatterns.buildDrumSchedule(
        bpm: 120,
        timeSignature: TimeSignature.threeFour,
        durationMs: 1500,
      );
      final snares =
          s.notes.where((n) => n.drumKind == DrumKind.snare).toList();
      expect(snares.map((n) => n.timeMs), [500, 1000]);
    });

    test('多小节覆盖：kick 每小节一次', () {
      final s = StrumPatterns.buildDrumSchedule(
        bpm: 60,
        timeSignature: TimeSignature.fourFour,
        durationMs: 8000, // 8 拍 = 2 小节
      );
      final kicks = s.notes.where((n) => n.drumKind == DrumKind.kick).toList();
      expect(kicks.length, 2);
      expect(kicks.map((n) => n.timeMs), [0, 4000]);
    });

    test('DrumKind 资产路径', () {
      expect(DrumKind.kick.assetPath, 'assets/audio/drums/kick.wav');
      expect(DrumKind.snare.assetPath, 'assets/audio/drums/snare.wav');
      expect(DrumKind.hat.assetPath, 'assets/audio/drums/hat.wav');
    });
  });

  group('buildProgressionSchedule perChordBeats（v0.5）', () {
    test('默认行为不变（null = 每和弦一小节）', () {
      final s = StrumPatterns.buildProgressionSchedule(
        stringVoicings: _voices,
        bpm: 120,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
      );
      expect(s.totalMs, 2 * 4 * 500);
    });

    test('指定拍数：8 拍和弦内模式循环铺满，totalMs 累计', () {
      final s = StrumPatterns.buildProgressionSchedule(
        stringVoicings: _voices,
        bpm: 60,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
        perChordBeats: const [8, 4],
      );
      // 拍长 1000ms；和弦0 事件落 0..7 拍共 8 次，和弦1 落 8..11 拍 4 次。
      final chord0 = s.notes.where((n) => n.chordIndex == 0).toList();
      final chord1 = s.notes.where((n) => n.chordIndex == 1).toList();
      expect(chord0.length, 8);
      expect(chord0.last.timeMs, 7000);
      expect(chord1.length, 4);
      expect(chord1.first.timeMs, 8000);
      expect(s.totalMs, 12000);
    });

    test('拍数不足一小节：只播小节开头的事件', () {
      final s = StrumPatterns.buildProgressionSchedule(
        stringVoicings: _voices,
        bpm: 60,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
        perChordBeats: const [2, 2],
      );
      expect(s.notes.length, 4); // 每和弦拍 0、1，共 2×2
      expect(s.totalMs, 4000);
    });

    test('leadingBeatsMs 用于鼓轨平移', () {
      final ms = StrumPatterns.leadingBeatsMs(
        perChordBeats: const [8, 4],
        upTo: 1,
        beatsPerBar: 4,
        bpm: 60,
      );
      expect(ms, 8000);
      expect(
        StrumPatterns.leadingBeatsMs(
          perChordBeats: null,
          upTo: 2,
          beatsPerBar: 3,
          bpm: 120,
        ),
        3000,
      );
    });
  });
}
