import 'dart:convert';

import '../theory/key_harmony.dart';

/// 拍号（编曲台仅支持 4/4 与 3/4）。
enum TimeSignature {
  fourFour('4/4'),
  threeFour('3/4');

  final String wire;
  const TimeSignature(this.wire);

  static TimeSignature fromWire(String? v) => TimeSignature.values.firstWhere(
        (t) => t.wire == v,
        orElse: () => TimeSignature.fourFour,
      );

  /// 每小节拍数（四分音符为一拍）。
  int get beatsPerBar => this == TimeSignature.fourFour ? 4 : 3;

  String get label => wire;
}

/// 内置伴奏型。
enum AccomPattern {
  /// 柱式扫弦（每拍整弦齐奏）。
  strum('strum'),

  /// 慢扫弦（下上扫分解）。
  slowStrum('slowStrum'),

  /// 分解和弦（拨弦）。
  finger('finger');

  final String wire;
  const AccomPattern(this.wire);

  static AccomPattern fromWire(String? v) => AccomPattern.values.firstWhere(
        (p) => p.wire == v,
        orElse: () => AccomPattern.strum,
      );

  String get label => switch (this) {
        AccomPattern.strum => '柱式扫弦',
        AccomPattern.slowStrum => '慢扫弦',
        AccomPattern.finger => '分解和弦',
      };
}

/// 编曲进行（progressions 表一行）。
class Progression {
  final String id;
  final String title;

  /// 调性主音 pitch class（0–11）。
  final int keyRootPc;
  final KeyMode keyMode;

  /// 和弦名有序序列（每个和弦占一小节，最多 32 个）。
  final List<String> chords;

  final int bpm;
  final TimeSignature timeSignature;
  final AccomPattern pattern;

  final int createdAt;
  final int updatedAt;

  const Progression({
    required this.id,
    required this.title,
    required this.keyRootPc,
    required this.keyMode,
    required this.chords,
    this.bpm = 90,
    this.timeSignature = TimeSignature.fourFour,
    this.pattern = AccomPattern.strum,
    required this.createdAt,
    required this.updatedAt,
  });

  MusicKey get key => MusicKey(keyRootPc, keyMode);

  factory Progression.fromMap(Map<String, Object?> m) => Progression(
        id: m['id'] as String,
        title: m['title'] as String,
        keyRootPc: m['key_root_pc'] as int,
        keyMode: (m['key_mode'] as String) == 'minor'
            ? KeyMode.minor
            : KeyMode.major,
        chords: _decodeChords(m['chords'] as String?),
        bpm: (m['bpm'] as int?) ?? 90,
        timeSignature: TimeSignature.fromWire(m['time_signature'] as String?),
        pattern: AccomPattern.fromWire(m['pattern'] as String?),
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'key_root_pc': keyRootPc,
        'key_mode': keyMode == KeyMode.minor ? 'minor' : 'major',
        'chords': _encodeChords(chords),
        'bpm': bpm,
        'time_signature': timeSignature.wire,
        'pattern': pattern.wire,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Progression copyWith({
    String? title,
    int? keyRootPc,
    KeyMode? keyMode,
    List<String>? chords,
    int? bpm,
    TimeSignature? timeSignature,
    AccomPattern? pattern,
    int? updatedAt,
  }) =>
      Progression(
        id: id,
        title: title ?? this.title,
        keyRootPc: keyRootPc ?? this.keyRootPc,
        keyMode: keyMode ?? this.keyMode,
        chords: chords ?? this.chords,
        bpm: bpm ?? this.bpm,
        timeSignature: timeSignature ?? this.timeSignature,
        pattern: pattern ?? this.pattern,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 业务 id 生成（与 StudyIds 同风格的文本主键）。
class ProgressionIds {
  ProgressionIds._();

  static int _seq = 0;

  static String newId() {
    _seq += 1;
    return 'prog_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }
}

String _encodeChords(List<String> chords) => jsonEncode(chords);

List<String> _decodeChords(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is List) return list.map((e) => e.toString()).toList();
  } catch (_) {
    // 历史脏数据降级为空序列，不阻断曲库加载。
  }
  return const [];
}
