import '../models/progression.dart';

/// 一次齐发事件：[beat] 为小节内拍位（四分音符为 1 拍，可小数），
/// [stringIndexes] 为本次发声的弦（0 = 最低音弦，4 = 最高音弦）。
class StrumEvent {
  final double beat;
  final List<int> stringIndexes;

  const StrumEvent(this.beat, this.stringIndexes);
}

/// 鼓件类型（v0.5 鼓组伴奏轨）。
enum DrumKind {
  kick('kick'),
  snare('snare'),
  hat('hat');

  final String wire;
  const DrumKind(this.wire);

  /// 对应采样资产路径。
  String get assetPath => 'assets/audio/drums/$wire.wav';
}

/// 进入播放队列的一个齐发音（绝对相对时间）。
class ScheduledNote {
  /// 所属和弦（小节）序号；鼓件音为 -1（无高亮）。
  final int chordIndex;

  /// 相对序列起点的毫秒数。
  final int timeMs;

  /// 本次齐发的 MIDI 音（严格上行）；鼓件音为空。
  final List<int> midis;

  /// 非空时本音为鼓组采样（v0.5）。
  final DrumKind? drumKind;

  const ScheduledNote({
    required this.chordIndex,
    required this.timeMs,
    required this.midis,
    this.drumKind,
  });
}

/// 整段进行的排程结果。
class ProgressionSchedule {
  final List<ScheduledNote> notes;

  /// 一遍循环总时长（毫秒）。
  final int totalMs;

  const ProgressionSchedule(this.notes, this.totalMs);
}

/// 伴奏型时序纯函数（无音频依赖，便于单测）。
class StrumPatterns {
  StrumPatterns._();

  /// 全 5 根弦。
  static const List<int> allStrings = [0, 1, 2, 3, 4];

  /// 上扫只发较高 3 弦。
  static const List<int> upStrings = [2, 3, 4];

  /// 把和弦音排成 5 弦上的严格上行 MIDI（默认采样范围 40–76，E2–E5）。
  ///
  /// [pitchClasses] 为和弦音高集合（无序亦可，内部按和弦组成轮取），
  /// [rootPc] 为根音 pc；[lowMidi]/[highMidi] 可换成其他乐器音区
  /// （音区宽 36 半音时 5 音上行必在界内）。
  static List<int> voiceGuitarStrings({
    required int rootPc,
    required List<int> pitchClasses,
    int lowMidi = 40,
    int highMidi = 76,
  }) {
    final anchor = lowMidi + (((rootPc - lowMidi) % 12) + 12) % 12;
    final ordered = _rotateToRoot(rootPc, pitchClasses);
    final result = <int>[anchor];
    var prev = anchor;
    var i = 1;
    while (result.length < 5) {
      final pc = ordered[i % ordered.length];
      var target = prev + (((pc - (prev % 12)) % 12) + 12) % 12;
      if (target <= prev) target += 12; // 同音（跨八度）时继续上推
      result.add(target);
      prev = target;
      i++;
    }
    return result;
  }

  /// 将和弦音排列成从根音起的上行 pc 环（去重）。
  static List<int> _rotateToRoot(int rootPc, List<int> pcs) {
    final unique = pcs.toSet().toList()..sort();
    final fromRoot = <int>[];
    for (final pc in unique) {
      if (pc >= rootPc) fromRoot.add(pc);
    }
    for (final pc in unique) {
      if (pc < rootPc) fromRoot.add(pc);
    }
    return fromRoot;
  }

  /// 单小节事件表（拍位 + 弦组）。
  static List<StrumEvent> buildBarSchedule(
    AccomPattern pattern,
    TimeSignature ts,
  ) {
    final beats = ts.beatsPerBar;
    return switch (pattern) {
      AccomPattern.strum => [
          for (var b = 0; b < beats; b++) StrumEvent(b.toDouble(), allStrings),
        ],
      AccomPattern.slowStrum => _slowStrum(beats),
      AccomPattern.finger => _finger(beats),
    };
  }

  /// 慢扫弦。
  static List<StrumEvent> _slowStrum(int beats) {
    // 4/4（六拍点）：0↓ 2↓ 2.5↑ 3↓ 3.5↑ 3.75↑
    if (beats == 4) {
      return const [
        StrumEvent(0, allStrings),
        StrumEvent(2, allStrings),
        StrumEvent(2.5, upStrings),
        StrumEvent(3, allStrings),
        StrumEvent(3.5, upStrings),
        StrumEvent(3.75, upStrings),
      ];
    }
    // 3/4 等比缩减：0↓ 1.5↓ 2↑ 2.5↑ 2.75↑
    return const [
      StrumEvent(0, allStrings),
      StrumEvent(1.5, allStrings),
      StrumEvent(2, upStrings),
      StrumEvent(2.5, upStrings),
      StrumEvent(2.75, upStrings),
    ];
  }

  /// 分解和弦：八分音拨弦，弦序按拍号固定。
  static List<StrumEvent> _finger(int beats) {
    final order = beats == 4
        ? const [0, 2, 1, 2, 4, 2, 1, 2]
        : const [0, 2, 1, 4, 1, 2];
    return [
      for (var i = 0; i < order.length; i++)
        StrumEvent(i / 2, [order[i]]),
    ];
  }

  /// 整段进行排程：每个和弦默认占一小节。
  ///
  /// [stringVoicings] 与和弦序列一一对应，每项为该和弦的 5 弦 MIDI
  /// （由 [voiceGuitarStrings] 生成）。
  /// [perChordBeats] 可为每个和弦单独指定拍数（v0.5），小节模式在该时长内
  /// 循环铺满；为 null 时每和弦按拍号一小节（与旧行为完全一致）。
  static ProgressionSchedule buildProgressionSchedule({
    required List<List<int>> stringVoicings,
    required int bpm,
    required AccomPattern pattern,
    required TimeSignature timeSignature,
    List<int>? perChordBeats,
  }) {
    final beatMs = 60000 / bpm;
    final beatsPerBar = timeSignature.beatsPerBar;
    final barEvents = buildBarSchedule(pattern, timeSignature);
    final notes = <ScheduledNote>[];

    var chordStartBeat = 0.0;
    for (var c = 0; c < stringVoicings.length; c++) {
      final strings = stringVoicings[c];
      final chordBeats =
          (perChordBeats != null && c < perChordBeats.length)
              ? perChordBeats[c].clamp(1, 32)
              : beatsPerBar;
      final reps = (chordBeats / beatsPerBar).ceil();
      for (var r = 0; r < reps; r++) {
        for (final e in barEvents) {
          final beatInChord = r * beatsPerBar + e.beat;
          if (beatInChord >= chordBeats) continue;
          final timeMs = ((chordStartBeat + beatInChord) * beatMs).round();
          notes.add(ScheduledNote(
            chordIndex: c,
            timeMs: timeMs,
            midis: [for (final i in e.stringIndexes) strings[i]],
          ));
        }
      }
      chordStartBeat += chordBeats;
    }

    final totalMs = (chordStartBeat * beatMs).round();
    return ProgressionSchedule(notes, totalMs);
  }

  /// 鼓组伴奏排程（v0.5）：与和弦排程等长，在 [durationMs] 内按小节循环。
  ///
  /// 规则：kick 每小节第 1 拍；snare 落 4/4 第 2/4 拍、3/4 第 2/3 拍；
  /// hat 每 8 分音符。chordIndex = -1（不参与高亮）。
  static ProgressionSchedule buildDrumSchedule({
    required int bpm,
    required TimeSignature timeSignature,
    required int durationMs,
  }) {
    final beatMs = 60000 / bpm;
    final beatsPerBar = timeSignature.beatsPerBar;
    // durationMs 为整数拍换算后的毫秒（含舍入误差），用容错取整避免
    // 2667/666.67=4.0005 被 ceil 成 5 导致循环尾部多出鼓点。
    final totalBeats = ((durationMs / beatMs) + 0.01).floor();
    final notes = <ScheduledNote>[];

    for (var b = 0; b < totalBeats; b++) {
      final beatInBar = b % beatsPerBar;
      final t = (b * beatMs).round();
      if (beatInBar == 0) {
        notes.add(ScheduledNote(
            chordIndex: -1, timeMs: t, midis: const [], drumKind: DrumKind.kick));
      }
      final snareBeats = beatsPerBar == 4 ? const [1, 3] : const [1, 2];
      if (snareBeats.contains(beatInBar)) {
        notes.add(ScheduledNote(
            chordIndex: -1,
            timeMs: t,
            midis: const [],
            drumKind: DrumKind.snare));
      }
      // hat：每 8 分音符（整拍 + 半拍）。
      notes.add(ScheduledNote(
          chordIndex: -1, timeMs: t, midis: const [], drumKind: DrumKind.hat));
      notes.add(ScheduledNote(
          chordIndex: -1,
          timeMs: (b * beatMs + beatMs / 2).round(),
          midis: const [],
          drumKind: DrumKind.hat));
    }
    return ProgressionSchedule(notes, durationMs);
  }

  /// 前 [upTo] 个和弦的累计时长（毫秒）；用于从中间起播时鼓轨平移。
  static int leadingBeatsMs({
    required List<int>? perChordBeats,
    required int upTo,
    required int beatsPerBar,
    required int bpm,
  }) {
    final beatMs = 60000 / bpm;
    var beats = 0.0;
    for (var i = 0; i < upTo; i++) {
      beats += (perChordBeats != null && i < perChordBeats.length)
          ? perChordBeats[i].clamp(1, 32)
          : beatsPerBar;
    }
    return (beats * beatMs).round();
  }
}
