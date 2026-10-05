import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/strum_patterns.dart';
import 'package:jz_stringferry/core/models/progression.dart';

void main() {
  group('voiceGuitarStrings 5 弦排列（FR-8）', () {
    test('C 大三 = C3 E3 G3 C4 E4', () {
      final r = StrumPatterns.voiceGuitarStrings(rootPc: 0, pitchClasses: [0, 4, 7]);
      expect(r, [48, 52, 55, 60, 64]);
    });

    test('Am 小三 = A2 C3 E3 A3 C4', () {
      final r = StrumPatterns.voiceGuitarStrings(rootPc: 9, pitchClasses: [9, 0, 4]);
      expect(r, [45, 48, 52, 57, 60]);
    });

    test('F 大三 = F2 A2 C3 F3 A3', () {
      final r = StrumPatterns.voiceGuitarStrings(rootPc: 5, pitchClasses: [5, 9, 0]);
      expect(r, [41, 45, 48, 53, 57]);
    });

    test('G 大三 = G2 B2 D3 G3 B3', () {
      final r = StrumPatterns.voiceGuitarStrings(rootPc: 7, pitchClasses: [7, 11, 2]);
      expect(r, [43, 47, 50, 55, 59]);
    });

    test('输入乱序/七和弦也恒为 5 个严格上行音且在采样范围 40–76', () {
      for (final (root, pcs) in <(int, List<int>)>[
        (0, [7, 11, 2, 5]), // G7 乱序
        (11, [11, 2, 6]), // Bm
        (3, [3, 7, 10, 2]), // EbMaj7
        (8, [8, 11, 2]), // G#m
      ]) {
        final r = StrumPatterns.voiceGuitarStrings(rootPc: root, pitchClasses: pcs);
        expect(r.length, 5, reason: 'root=$root');
        for (var i = 0; i < 5; i++) {
          expect(r[i], inInclusiveRange(40, 76), reason: 'root=$root i=$i');
          if (i > 0) expect(r[i] > r[i - 1], isTrue, reason: 'root=$root i=$i');
        }
        expect(r.first % 12, root, reason: '最低音必须是根音 root=$root');
      }
    });
  });

  group('buildBarSchedule 单小节时序（FR-8，AC-5）', () {
    test('柱式扫弦 4/4 = 每拍全弦；3/4 = 三拍', () {
      final b4 = StrumPatterns.buildBarSchedule(AccomPattern.strum, TimeSignature.fourFour);
      expect(b4.map((e) => e.beat), [0.0, 1.0, 2.0, 3.0]);
      expect(b4.every((e) => e.stringIndexes.length == 5), isTrue);

      final b3 = StrumPatterns.buildBarSchedule(AccomPattern.strum, TimeSignature.threeFour);
      expect(b3.map((e) => e.beat), [0.0, 1.0, 2.0]);
      expect(b3.every((e) => e.stringIndexes.length == 5), isTrue);
    });

    test('慢扫弦 4/4 拍点与上扫弦组', () {
      final b = StrumPatterns.buildBarSchedule(AccomPattern.slowStrum, TimeSignature.fourFour);
      expect(b.map((e) => e.beat), [0.0, 2.0, 2.5, 3.0, 3.5, 3.75]);
      expect(b[0].stringIndexes, StrumPatterns.allStrings);
      expect(b[1].stringIndexes, StrumPatterns.allStrings);
      expect(b[3].stringIndexes, StrumPatterns.allStrings);
      for (final i in [2, 4, 5]) {
        expect(b[i].stringIndexes, StrumPatterns.upStrings);
      }
    });

    test('慢扫弦 3/4 事件落在小节内', () {
      final b = StrumPatterns.buildBarSchedule(AccomPattern.slowStrum, TimeSignature.threeFour);
      for (final e in b) {
        expect(e.beat, inInclusiveRange(0, 2.999));
        expect(e.stringIndexes.every((i) => i >= 0 && i < 5), isTrue);
      }
    });

    test('分解和弦 4/4 八分音弦序；3/4 六音', () {
      final b4 = StrumPatterns.buildBarSchedule(AccomPattern.finger, TimeSignature.fourFour);
      expect(b4.length, 8);
      expect(b4.map((e) => e.beat), [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]);
      expect(b4.map((e) => e.stringIndexes.single), [0, 2, 1, 2, 4, 2, 1, 2]);

      final b3 = StrumPatterns.buildBarSchedule(AccomPattern.finger, TimeSignature.threeFour);
      expect(b3.length, 6);
      expect(b3.map((e) => e.beat), [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]);
      expect(b3.map((e) => e.stringIndexes.single), [0, 2, 1, 4, 1, 2]);
    });
  });

  group('buildProgressionSchedule 整段时序（FR-7/FR-8，AC-5/AC-6）', () {
    final cStrings = StrumPatterns.voiceGuitarStrings(rootPc: 0, pitchClasses: [0, 4, 7]);
    final amStrings = StrumPatterns.voiceGuitarStrings(rootPc: 9, pitchClasses: [9, 0, 4]);

    test('C–Am 柱式扫弦 90BPM 4/4：拍长 667ms，两小节 5333ms', () {
      final s = StrumPatterns.buildProgressionSchedule(
        stringVoicings: [cStrings, amStrings],
        bpm: 90,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
      );
      expect(s.totalMs, 5333);
      expect(s.notes.length, 8);
      expect(s.notes.map((n) => n.timeMs),
          [0, 667, 1333, 2000, 2667, 3333, 4000, 4667]);
      // 首音是 C 的 5 弦齐奏，第 5 个音是 Am 的 5 弦齐奏。
      expect(s.notes.first.midis, cStrings);
      expect(s.notes[4].chordIndex, 1);
      expect(s.notes[4].midis, amStrings);
    });

    test('分解和弦单和弦：8 个单弦音，时间间隔 333ms（90BPM）', () {
      final s = StrumPatterns.buildProgressionSchedule(
        stringVoicings: [cStrings],
        bpm: 90,
        pattern: AccomPattern.finger,
        timeSignature: TimeSignature.fourFour,
      );
      expect(s.notes.length, 8);
      expect(s.notes.every((n) => n.midis.length == 1), isTrue);
      expect(s.notes[1].timeMs, 333);
      expect(s.notes.first.midis.single, cStrings[0]);
      expect(s.notes[4].midis.single, cStrings[4]); // 弦序第 5 音 = 最高弦
    });

    test('3/4 120BPM：拍长 500ms，单小总时长 1500ms（AC-6）', () {
      final s = StrumPatterns.buildProgressionSchedule(
        stringVoicings: [cStrings],
        bpm: 120,
        pattern: AccomPattern.finger,
        timeSignature: TimeSignature.threeFour,
      );
      expect(s.totalMs, 1500);
      expect(s.notes.map((n) => n.timeMs), [0, 250, 500, 750, 1000, 1250]);
    });

    test('BPM 边界 40 / 200（FR-7）', () {
      for (final bpm in [40, 200]) {
        final s = StrumPatterns.buildProgressionSchedule(
          stringVoicings: [cStrings, cStrings],
          bpm: bpm,
          pattern: AccomPattern.strum,
          timeSignature: TimeSignature.fourFour,
        );
        final beatMs = 60000 / bpm;
        expect(s.totalMs, (8 * beatMs).round());
        expect(s.notes.first.timeMs, 0);
        expect(s.notes.last.timeMs, (7 * beatMs).round());
      }
    });
  });
}
