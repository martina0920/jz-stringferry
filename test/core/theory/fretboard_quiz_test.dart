import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/theory/fretboard_quiz.dart';

void main() {
  test('openStringMidis 与弦号对应（1 弦 = E4=64）', () {
    expect(openStringMidis, [64, 59, 55, 50, 45, 40]);
  });

  test('FretboardQuestion.midi = 空弦 + 品位', () {
    expect(const FretboardQuestion(stringNo: 1, fret: 0).midi, 64);
    expect(const FretboardQuestion(stringNo: 6, fret: 12).midi, 52);
    expect(const FretboardQuestion(stringNo: 3, fret: 5).midi, 60);
  });

  test('出题范围：弦 1–6、品 0–maxFret；固定 seed 确定性', () {
    final a = FretboardQuiz(random: Random(7))..next();
    final b = FretboardQuiz(random: Random(7))..next();
    final qa = FretboardQuiz(random: Random(7)).next();
    final qb = FretboardQuiz(random: Random(7)).next();
    expect(qa.stringNo, qb.stringNo);
    expect(qa.fret, qb.fret);
    expect(a, isNotNull);
    expect(b, isNotNull);

    final gen = FretboardQuiz(random: Random(9));
    for (var i = 0; i < 60; i++) {
      final q = gen.next();
      expect(q.stringNo, inInclusiveRange(1, 6));
      expect(q.fret, inInclusiveRange(0, 12));
    }
  });

  test('judgeFretAnswer：升降号、大小写、空白皆可，错误判否', () {
    const q = FretboardQuestion(stringNo: 6, fret: 6); // A#/Bb
    expect(judgeFretAnswer(q, 'A#'), isTrue);
    expect(judgeFretAnswer(q, 'Bb'), isTrue);
    expect(judgeFretAnswer(q, 'a#'), isTrue);
    expect(judgeFretAnswer(q, ' bb '), isTrue);
    expect(judgeFretAnswer(q, 'A'), isFalse);
    expect(judgeFretAnswer(q, 'B'), isFalse);
    expect(judgeFretAnswer(q, ''), isFalse);
    expect(judgeFretAnswer(q, 'H'), isFalse);
  });
}
