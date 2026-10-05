import 'dart:math';

/// 音感训练五模式。
enum EarMode {
  singleNote('single', '单音'),
  interval('interval', '音程'),
  chordQuality('chord', '和弦'),
  rhythm('rhythm', '节奏'),
  scale('scale', '音阶');

  final String id;
  final String label;
  const EarMode(this.id, this.label);
}

/// 音程（半音数 + 中文名）。
enum Interval {
  minor2(1, '小二度'),
  major2(2, '大二度'),
  minor3(3, '小三度'),
  major3(4, '大三度'),
  perfect4(5, '纯四度'),
  tritone(6, '三全音'),
  perfect5(7, '纯五度'),
  minor6(8, '小六度'),
  major6(9, '大六度'),
  minor7(10, '小七度'),
  major7(11, '大七度'),
  octave(12, '八度');

  final int semitones;
  final String label;
  const Interval(this.semitones, this.label);

  static Interval bySemitones(int s) =>
      Interval.values.firstWhere((i) => i.semitones == s);
}

/// 常用和弦性质。
enum ChordQualityQuiz {
  major('大三和弦', 'M'),
  minor('小三和弦', 'm'),
  dim('减三和弦', 'dim'),
  aug('增三和弦', 'aug'),
  maj7('大七和弦', 'maj7'),
  m7('小七和弦', 'm7'),
  dom7('属七和弦', '7');

  final String label;

  /// 组成音半音距（相对根音）。
  final String suffix;
  const ChordQualityQuiz(this.label, this.suffix);

  List<int> get pcs => switch (this) {
        ChordQualityQuiz.major => const [0, 4, 7],
        ChordQualityQuiz.minor => const [0, 3, 7],
        ChordQualityQuiz.dim => const [0, 3, 6],
        ChordQualityQuiz.aug => const [0, 4, 8],
        ChordQualityQuiz.maj7 => const [0, 4, 7, 11],
        ChordQualityQuiz.m7 => const [0, 3, 7, 10],
        ChordQualityQuiz.dom7 => const [0, 4, 7, 10],
      };
}

/// 大调音阶听辨选项。
enum ScaleQuiz {
  major('自然大调'),
  naturalMinor('自然小调'),
  harmonicMinor('和声小调'),
  pentatonic('五声（大调）');

  final String label;
  const ScaleQuiz(this.label);

  /// 相对主音的音级半音距。
  List<int> get pcs => switch (this) {
        ScaleQuiz.major => const [0, 2, 4, 5, 7, 9, 11],
        ScaleQuiz.naturalMinor => const [0, 2, 3, 5, 7, 8, 10],
        ScaleQuiz.harmonicMinor => const [0, 2, 3, 5, 7, 8, 11],
        ScaleQuiz.pentatonic => const [0, 2, 4, 7, 9],
      };
}

/// 一道音感题。
class EarQuestion {
  final EarMode mode;

  /// 单音/音程：根音 MIDI；和弦：根音 MIDI；节奏：-1。
  final int rootMidi;

  /// 音程题的第二个音（上行或下行）。
  final int? secondMidi;

  /// 正确答案对象（single=目标音名，interval/chord/scale=枚举，rhythm=网格）。
  final Object answer;

  /// 节奏题：播放的 16 格网格（true=有声）。其他模式为空。
  final List<bool> rhythmGrid;

  /// 节奏题每格毫秒数（其他模式忽略）。
  final int cellMs;

  const EarQuestion({
    required this.mode,
    required this.rootMidi,
    this.secondMidi,
    required this.answer,
    this.rhythmGrid = const [],
    this.cellMs = 125,
  });
}

/// 出题器（rng 可注入，固定 seed 测试确定性）。
class EarQuizGenerator {
  final Random random;

  /// 单音题音域（吉他中音区）。
  static const int lowMidi = 52;
  static const int highMidi = 72;

  EarQuizGenerator({Random? random}) : random = random ?? Random();

  EarQuestion singleNote() {
    final midi = lowMidi + random.nextInt(highMidi - lowMidi + 1);
    return EarQuestion(
        mode: EarMode.singleNote, rootMidi: midi, answer: midi);
  }

  EarQuestion interval({bool allowDownward = true}) {
    final iv = Interval.values[random.nextInt(Interval.values.length)];
    final root = lowMidi + random.nextInt(highMidi - lowMidi - 12 + 1);
    final up = random.nextBool();
    if (!allowDownward || up) {
      return EarQuestion(
        mode: EarMode.interval,
        rootMidi: root,
        secondMidi: root + iv.semitones,
        answer: iv,
      );
    }
    return EarQuestion(
      mode: EarMode.interval,
      rootMidi: root + iv.semitones,
      secondMidi: root,
      answer: iv,
    );
  }

  EarQuestion chordQuality() {
    final q = ChordQualityQuiz.values[random.nextInt(ChordQualityQuiz.values.length)];
    final root = lowMidi + random.nextInt(highMidi - lowMidi + 1);
    return EarQuestion(
        mode: EarMode.chordQuality, rootMidi: root, answer: q);
  }

  /// 节奏：以 [bpm] 演算 2 拍 × 每拍 4 格（八格网格），返回播放时长 ms。
  EarQuestion rhythm({int bpm = 90}) {
    // 生成 8 格网格：保证至少 3 声、不超 6 声，末格必有声收束。
    const gridLen = 8;
    final grid = List<bool>.filled(gridLen, false);
    var count = 0;
    while (count < 3) {
      final i = random.nextInt(gridLen);
      if (!grid[i]) {
        grid[i] = true;
        count++;
      }
    }
    if (!grid[gridLen - 1]) {
      // 收束：把末格置声（若因此超 6 声则去掉一个中部声）。
      if (count >= 6) {
        for (var i = 1; i < gridLen - 1; i++) {
          if (grid[i]) {
            grid[i] = false;
            break;
          }
        }
      }
      grid[gridLen - 1] = true;
    }
    final gridMsPerCell = (60000 / bpm / 4).round();
    return EarQuestion(
      mode: EarMode.rhythm,
      rootMidi: -1,
      answer: grid,
      rhythmGrid: grid,
      cellMs: gridMsPerCell,
    );
  }

  EarQuestion scale() {
    final s = ScaleQuiz.values[random.nextInt(ScaleQuiz.values.length)];
    final root = 48 + random.nextInt(12); // C3–B3 起的大调音阶
    return EarQuestion(mode: EarMode.scale, rootMidi: root, answer: s);
  }

  EarQuestion next(EarMode mode) => switch (mode) {
        EarMode.singleNote => singleNote(),
        EarMode.interval => interval(),
        EarMode.chordQuality => chordQuality(),
        EarMode.rhythm => rhythm(),
        EarMode.scale => scale(),
      };
}

/// 答题判定（纯函数）。
class EarJudge {
  EarJudge._();

  static bool singleNote(EarQuestion q, int chosenMidi) =>
      q.answer == chosenMidi;

  static bool interval(EarQuestion q, Interval chosen) => q.answer == chosen;

  static bool chordQuality(EarQuestion q, ChordQualityQuiz chosen) =>
      q.answer == chosen;

  static bool scale(EarQuestion q, ScaleQuiz chosen) => q.answer == chosen;

  /// 节奏：用户逐格点出的网格与答案完全一致才算对。
  static bool rhythm(EarQuestion q, List<bool> userGrid) {
    final ans = q.rhythmGrid;
    if (userGrid.length != ans.length) return false;
    for (var i = 0; i < ans.length; i++) {
      if (userGrid[i] != ans[i]) return false;
    }
    return true;
  }
}
