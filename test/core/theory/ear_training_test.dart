import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/theory/ear_training.dart';

void main() {
  group('EarQuizGenerator（固定 seed 确定性）', () {
    test('同 seed 出题序列完全一致，不同 seed 大概率不同', () {
      final a = EarQuizGenerator(random: Random(42)).interval();
      final b = EarQuizGenerator(random: Random(42)).interval();
      final c = EarQuizGenerator(random: Random(43)).interval();
      expect(a.rootMidi, b.rootMidi);
      expect(a.answer, b.answer);
      expect(a == c || a.answer != c.answer || a.rootMidi != c.rootMidi,
          isTrue);
    });

    test('singleNote：音域 52–72', () {
      final gen = EarQuizGenerator(random: Random(1));
      for (var i = 0; i < 50; i++) {
        final q = gen.singleNote();
        expect(q.rootMidi, inInclusiveRange(52, 72));
        expect(q.answer, q.rootMidi);
      }
    });

    test('interval：第二音=根音±音程，音域不越界', () {
      final gen = EarQuizGenerator(random: Random(2));
      for (var i = 0; i < 50; i++) {
        final q = gen.interval();
        expect(q.secondMidi, isNotNull);
        final diff = (q.secondMidi! - q.rootMidi).abs();
        expect(diff, inInclusiveRange(1, 12));
        expect(q.answer, isA<Interval>());
        expect(q.rootMidi, inInclusiveRange(52, 72));
        expect(q.secondMidi!, inInclusiveRange(40, 84));
      }
    });

    test('chordQuality / scale：答案在枚举范围内', () {
      final gen = EarQuizGenerator(random: Random(3));
      for (var i = 0; i < 20; i++) {
        expect(gen.chordQuality().answer, isA<ChordQualityQuiz>());
        expect(gen.scale().answer, isA<ScaleQuiz>());
      }
    });

    test('rhythm：8 格、3–6 声、末格必有声、cellMs 与 bpm 匹配', () {
      final gen = EarQuizGenerator(random: Random(4));
      for (var i = 0; i < 50; i++) {
        final q = gen.rhythm();
        expect(q.rhythmGrid.length, 8);
        expect(q.rhythmGrid.where((b) => b).length, inInclusiveRange(3, 6));
        expect(q.rhythmGrid.last, isTrue);
        expect(q.cellMs, (60000 / 90 / 4).round());
      }
    });

    test('next 分发五模式', () {
      final gen = EarQuizGenerator(random: Random(5));
      for (final m in EarMode.values) {
        expect(gen.next(m).mode, m);
      }
    });
  });

  group('EarJudge', () {
    test('singleNote：同 midi 对，异 midi 错', () {
      const q = EarQuestion(mode: EarMode.singleNote, rootMidi: 60, answer: 60);
      expect(EarJudge.singleNote(q, 60), isTrue);
      expect(EarJudge.singleNote(q, 61), isFalse);
    });

    test('interval/chord/scale：枚举相等判定', () {
      const iv = EarQuestion(
          mode: EarMode.interval,
          rootMidi: 60,
          secondMidi: 64,
          answer: Interval.major3);
      expect(EarJudge.interval(iv, Interval.major3), isTrue);
      expect(EarJudge.interval(iv, Interval.perfect4), isFalse);

      const ch = EarQuestion(
          mode: EarMode.chordQuality, rootMidi: 60, answer: ChordQualityQuiz.m7);
      expect(EarJudge.chordQuality(ch, ChordQualityQuiz.m7), isTrue);
      expect(EarJudge.chordQuality(ch, ChordQualityQuiz.dom7), isFalse);

      const sc = EarQuestion(
          mode: EarMode.scale, rootMidi: 60, answer: ScaleQuiz.harmonicMinor);
      expect(EarJudge.scale(sc, ScaleQuiz.harmonicMinor), isTrue);
      expect(EarJudge.scale(sc, ScaleQuiz.naturalMinor), isFalse);
    });

    test('rhythm：逐格比对，任何一格差异都算错', () {
      final grid = [true, false, false, true, false, false, true, true];
      final q = EarQuestion(
          mode: EarMode.rhythm,
          rootMidi: -1,
          answer: grid,
          rhythmGrid: grid);
      expect(EarJudge.rhythm(q, grid), isTrue);
      expect(EarJudge.rhythm(q, List<bool>.of(grid)..[1] = true), isFalse);
      expect(EarJudge.rhythm(q, grid.sublist(0, 7)), isFalse);
    });
  });

  test('ChordQualityQuiz 组成音与音名后缀一致', () {
    expect(ChordQualityQuiz.major.pcs, [0, 4, 7]);
    expect(ChordQualityQuiz.m7.pcs, [0, 3, 7, 10]);
    expect(ChordQualityQuiz.dom7.suffix, '7');
  });

  test('Interval.bySemitones 反查', () {
    expect(Interval.bySemitones(7), Interval.perfect5);
    expect(Interval.bySemitones(12), Interval.octave);
  });
}
