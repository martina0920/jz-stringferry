/// 12 平均律音高模型。
///
/// 同一个音高（pitch class）在升号系与降号系有两种拼写，
/// 如 pc=1 既写作 C# 也写作 Db。根音决定整组和弦音的拼写倾向。
library;

/// 12 个音级（以 C 为 0）的升号拼写。
const List<String> sharpNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

/// 12 个音级的降号拼写。
const List<String> flatNames = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

/// 生成库时使用的 17 个根音名：白键 7 个 + 黑键升降两套拼写 10 个。
/// 同名异拼（C#/Db）作为不同名称的和弦分别入库，二者均为真实记法。
const List<String> allRootNames = [
  'C',
  'C#',
  'Db',
  'D',
  'D#',
  'Eb',
  'E',
  'F',
  'F#',
  'Gb',
  'G',
  'G#',
  'Ab',
  'A',
  'A#',
  'Bb',
  'B',
];

/// 一个确定音高（含八度，MIDI 序号）。
class Note {
  /// MIDI 序号，如中央 C(C4)=60。
  final int midi;

  const Note(this.midi);

  Note.fromName(String name, {int octave = 4})
      : this(pitchClassOf(name) + 12 * (octave + 1));

  int get pitchClass => midi % 12;

  /// MIDI 八度编号（中央 C 为第 4 八度）。
  int get octave => (midi ~/ 12) - 1;

  /// 按根音拼写倾向取音名。
  String name({bool flat = false}) =>
      (flat ? flatNames : sharpNames)[pitchClass];

  /// 是否为降号拼写（决定组成音用哪套记法）。
  static bool prefersFlat(String rootName) => rootName.contains('b');

  Note transpose(int semitones) => Note(midi + semitones);

  @override
  bool operator ==(Object other) => other is Note && other.midi == midi;

  @override
  int get hashCode => midi.hashCode;

  @override
  String toString() => '${sharpNames[pitchClass]}$octave';

  /// 根音名 -> pitch class（支持大小写与 b/# 记号）。
  static int pitchClassOf(String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('音名不能为空');
    final letter = n[0].toUpperCase();
    final accidental = n.length > 1 ? n[1] : '';

    const base = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final pc = base[letter];
    if (pc == null) throw ArgumentError('无法解析音名: $name');

    var value = pc;
    if (accidental == '#') {
      value += 1;
    } else if (accidental == 'b') {
      value -= 1;
    }
    return value % 12;
  }
}
