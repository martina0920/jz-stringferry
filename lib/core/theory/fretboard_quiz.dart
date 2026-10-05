import 'dart:math';

/// 吉他标准调弦（弦 1–6，midi：1 弦最高 E4）。
const List<int> openStringMidis = [64, 59, 55, 50, 45, 40];

/// 指板问答一道题：给定弦与品位，回答音名。
class FretboardQuestion {
  final int stringNo; // 1–6（1 = 最细）
  final int fret; // 0–12

  const FretboardQuestion({required this.stringNo, required this.fret});

  int get midi => openStringMidis[stringNo - 1] + fret;
}

/// 指板出题器（rng 可注入）。
class FretboardQuiz {
  final Random random;

  /// 出题品位范围（0–12 品）。
  final int maxFret;

  FretboardQuiz({Random? random, this.maxFret = 12})
      : random = random ?? Random();

  FretboardQuestion next() {
    final stringNo = 1 + random.nextInt(6);
    final fret = random.nextInt(maxFret + 1);
    return FretboardQuestion(stringNo: stringNo, fret: fret);
  }
}

/// 音名（含同音异名时答升号或降号均算对）。
const List<String> sharpNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
const List<String> flatNames = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
];

/// 判定答案：接受音名（大小写不敏感，#b 皆可）。
bool judgeFretAnswer(FretboardQuestion q, String input) {
  final pc = ((q.midi % 12) + 12) % 12;
  final normalized = input.trim().toUpperCase();
  return normalized == sharpNames[pc] ||
      normalized == flatNames[pc].toUpperCase();
}
