import 'chord_quality.dart';
import 'note.dart';

/// 组成音中的单个音（音 + 相对根音的音程信息）。
class ChordTone {
  final Note note;

  /// 展示用音名（拼写倾向跟随根音），如 F#、Db。
  final String name;

  /// 相对根音半音数。
  final int offset;

  /// 音程中文标签，如「大三度」。
  final String intervalLabel;

  const ChordTone({
    required this.note,
    required this.name,
    required this.offset,
    required this.intervalLabel,
  });

  @override
  String toString() => '$name($intervalLabel)';
}

/// 一个已构建的和弦：名称 + 有序组成音。
class BuiltChord {
  final String root;
  final ChordQuality quality;

  /// 从低到高的组成音（根音在 C4 附近，仅用于取音名/音程）。
  final List<ChordTone> tones;

  const BuiltChord({
    required this.root,
    required this.quality,
    required this.tones,
  });

  /// 完整和弦名，如 Am7、F#m7b5。
  String get name => '$root${quality.suffix}';

  /// 组成音音名列表，如 [A, C, E, G]。
  List<String> get toneNames => tones.map((t) => t.name).toList();

  /// 音程构成的展示串，如「根音 · 小三度 · 纯五度 · 小七度」。
  String get intervalText => tones.map((t) => t.intervalLabel).join(' · ');

  @override
  String toString() => '$name: ${toneNames.join(' ')}';
}

/// 乐理引擎入口：根音 + 性质 -> 组成音。
class ChordBuilder {
  const ChordBuilder._();

  /// 构建和弦。
  ///
  /// [baseOctave] 为根音所在八度（默认 4，即中央 C 所在八度），
  /// 只影响内部音高，组成音音名与该值无关。
  static BuiltChord build(
    String rootName,
    ChordQuality quality, {
    int baseOctave = 4,
  }) {
    final flat = Note.prefersFlat(rootName);
    final root = Note.fromName(rootName, octave: baseOctave);

    final tones = quality.intervals.map((iv) {
      final n = root.transpose(iv.semitones);
      return ChordTone(
        note: n,
        name: n.name(flat: flat),
        offset: iv.semitones,
        intervalLabel: iv.label,
      );
    }).toList(growable: false);

    return BuiltChord(root: rootName, quality: quality, tones: tones);
  }
}

/// 和弦名解析结果。
class ParsedChordName {
  final String root;
  final ChordQuality quality;
  const ParsedChordName(this.root, this.quality);
}

/// 和弦名解析：把 "Am7"、"F#m7b5"、"c maj7" 等字符串拆成根音 + 性质。
class ChordNameParser {
  ChordNameParser._();

  static final Map<String, ChordQuality> _bySuffix = {
    for (final q in allQualities) q.suffix.toLowerCase(): q,
  };

  static final Map<String, ChordQuality> _byAlias = {
    for (final q in allQualities)
      for (final a in q.aliases) a.toLowerCase(): q,
  };

  /// 解析失败返回 null。
  static ParsedChordName? parse(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    // 根音 = 首字母 + 可选升降号。
    final rootLen = (s.length > 1 && (s[1] == '#' || s[1] == 'b')) ? 2 : 1;
    if (rootLen > s.length) return null;

    final root = s.substring(0, rootLen);
    // 校验根音合法。
    try {
      Note.pitchClassOf(root);
    } catch (_) {
      return null;
    }

    final rest = s.substring(rootLen).trim();
    final key = rest.toLowerCase();

    // 大三和弦空后缀。
    if (key.isEmpty) {
      return ParsedChordName(root, qualitiesById['maj']!);
    }

    final q = _bySuffix[key] ?? _byAlias[key];
    if (q == null) return null;
    return ParsedChordName(root, q);
  }
}
