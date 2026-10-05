import 'chord_builder.dart';
import 'chord_quality.dart';
import 'note.dart';

/// 调式：大调 / 自然小调。
enum KeyMode {
  major,
  minor;

  String get label => this == KeyMode.major ? '大调' : '小调';
}

/// 调性：主音音级 + 调式，如 C 大调、Bb 大调、A 小调。
///
/// 顺阶和弦的拼写（升号/降号）由调号决定，而不是简单按根音名判断：
/// F 大调根音名不带变音记号，但其顺阶和弦必须出现 Bb；
/// D 小调按关系大调 F 的调号记谱，顺阶出现 Bb 而非 A#。
class MusicKey {
  /// 主音 pitch class（C=0 … B=11）。
  final int rootPc;

  final KeyMode mode;

  const MusicKey(this.rootPc, this.mode)
      : assert(rootPc >= 0 && rootPc < 12);

  /// pc 0..11 对应的大调规范调名。
  ///
  /// 等音调按调号升降数 + 吉他惯例取一：Db/Eb/Ab/Bb 取降号侧，
  /// pc=6 取 F#（与 Gb 等音，吉他常用 F#）。
  static const List<String> majorRootNames = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  /// pc 0..11 对应的小调规范调名（自然小调）。
  ///
  /// pc1 取 C#（关系 E，4 升号）、pc3 取 Eb（避免 D# 调的重升号记谱）、
  /// pc8 取 G#、pc10 取 Bb。
  static const List<String> minorRootNames = [
    'C',
    'C#',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'Bb',
    'B',
  ];

  /// 关系大调中使用降号记谱的主音 pc 集合（白键名调靠这张表判）：
  /// Db=1、Eb=3、F=5、Ab=8、Bb=10。
  static const Set<int> flatKeySignaturePcs = {1, 3, 5, 8, 10};

  /// 大调顺阶根音相对主音的半音偏移（Ionian）。
  static const List<int> majorOffsets = [0, 2, 4, 5, 7, 9, 11];

  /// 自然小调顺阶根音偏移（Aeolian）。
  static const List<int> minorOffsets = [0, 2, 3, 5, 7, 8, 10];

  /// 大调顺阶三和弦性质（I ii iii IV V vi vii°）。
  static const List<String> majorTriadQualityIds = [
    'maj',
    'min',
    'min',
    'maj',
    'maj',
    'min',
    'dim',
  ];

  /// 自然小调顺阶三和弦性质（i ii° III iv v VI VII）。
  static const List<String> minorTriadQualityIds = [
    'min',
    'dim',
    'maj',
    'min',
    'min',
    'maj',
    'maj',
  ];

  /// 大调顺阶七和弦性质（Imaj7 ii7 iii7 IVmaj7 V7 vi7 vii°7）。
  static const List<String> majorSeventhQualityIds = [
    'maj7',
    'm7',
    'm7',
    'maj7',
    'seven',
    'm7',
    'm7b5',
  ];

  /// 自然小调顺阶七和弦性质（i7 ii°7 IIImaj7 iv7 v7 VImaj7 VII7）。
  static const List<String> minorSeventhQualityIds = [
    'm7',
    'm7b5',
    'maj7',
    'm7',
    'm7',
    'maj7',
    'seven',
  ];

  /// 主音规范名（不带「大调/小调」后缀），如 Bb、F#。
  String get rootName => mode == KeyMode.major
      ? majorRootNames[rootPc]
      : minorRootNames[rootPc];

  /// 展示名，如「C 大调」「Bb 大调」「A 小调」。
  String get displayName => '$rootName ${mode.label}';

  /// 该调顺阶音/和弦使用哪套拼写。
  ///
  /// 规则：调名显式带 b/# 直接决定；白键名调（无变音记号）按调号判定——
  /// 大调 F 用降号；小调看关系大调（rootPc+3）的调号。
  bool get useFlats {
    if (rootName.contains('b')) return true;
    if (rootName.contains('#')) return false;
    if (mode == KeyMode.major) {
      return rootPc == 5; // F 大调
    }
    return flatKeySignaturePcs.contains((rootPc + 3) % 12);
  }

  /// 七个顺阶级的根音 pitch class（I/ii/iii/IV/V/vi/vii 顺序）。
  List<int> get degreePitchClasses {
    final offsets =
        mode == KeyMode.major ? majorOffsets : minorOffsets;
    return [for (final o in offsets) (rootPc + o) % 12];
  }

  /// 七个顺阶三和弦名，如 C 大调 → C Dm Em F G Am Bdim。
  List<String> diatonicTriads() => mode == KeyMode.major
      ? _buildDiatonic(majorTriadQualityIds)
      : _buildDiatonic(minorTriadQualityIds);

  /// 七个顺阶七和弦名，如 C 大调 → Cmaj7 Dm7 Em7 Fmaj7 G7 Am7 Bm7b5。
  List<String> diatonicSevenths() => mode == KeyMode.major
      ? _buildDiatonic(majorSeventhQualityIds)
      : _buildDiatonic(minorSeventhQualityIds);

  List<String> _buildDiatonic(List<String> qualityIds) {
    final pcs = degreePitchClasses;
    final spell = useFlats ? flatNames : sharpNames;
    return [
      for (var i = 0; i < 7; i++)
        '${spell[pcs[i]]}${qualitiesById[qualityIds[i]]!.suffix}',
    ];
  }

  /// 该调某一级（0=I/i … 6=vii/VII）上的和弦名。
  String degreeChordName(int degree, {bool seventh = false}) {
    final ids = mode == KeyMode.major
        ? (seventh ? majorSeventhQualityIds : majorTriadQualityIds)
        : (seventh ? minorSeventhQualityIds : minorTriadQualityIds);
    final pc = (rootPc +
            (mode == KeyMode.major ? majorOffsets : minorOffsets)[degree]) %
        12;
    final spell = useFlats ? flatNames : sharpNames;
    return '${spell[pc]}${qualitiesById[ids[degree]]!.suffix}';
  }

  @override
  bool operator ==(Object other) =>
      other is MusicKey && other.rootPc == rootPc && other.mode == mode;

  @override
  int get hashCode => Object.hash(rootPc, mode);

  @override
  String toString() => displayName;

  /// 12 个大调（pc 升序）。
  static List<MusicKey> get allMajor =>
      [for (var pc = 0; pc < 12; pc++) MusicKey(pc, KeyMode.major)];

  /// 12 个自然小调（pc 升序）。
  static List<MusicKey> get allMinor =>
      [for (var pc = 0; pc < 12; pc++) MusicKey(pc, KeyMode.minor)];
}

/// 同模式两调之间的半音差（to 相对 from，0–11）。
///
/// 编辑器只在同调式间转调（大↔大、小↔小）；跨调式由调用方规避。
int semitonesBetween(MusicKey from, MusicKey to) =>
    (to.rootPc - from.rootPc + 12) % 12;

/// 把和弦名整体移动 [semitones] 个半音，性质后缀保持不变。
///
/// 根音拼写由 [targetUseFlats] 决定（取目标调的 [MusicKey.useFlats]）。
/// 无法解析的输入原样返回（防御性，正常流程的名称全部来自和弦库）。
String transposeChordName(
  String name,
  int semitones, {
  required bool targetUseFlats,
}) {
  final parsed = ChordNameParser.parse(name);
  if (parsed == null) return name;
  final pc = (Note.pitchClassOf(parsed.root) + semitones) % 12;
  final newRoot = targetUseFlats ? flatNames[pc] : sharpNames[pc];
  return '$newRoot${parsed.quality.suffix}';
}

const List<String> _romanUpper = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
const List<String> _romanLower = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii'];

/// quality id → 罗马数字语境下的后缀（大小写本身已表达大小三性质）。
const Map<String, String> _romanQualitySuffix = {
  'maj': '',
  'min': '',
  'dim': '°',
  'aug': '+',
  'sus2': 'sus2',
  'sus4': 'sus4',
  'sevenSus4': '7sus4',
  'six': '6',
  'm6': 'm6',
  'sixNine': '6/9',
  'seven': '7',
  'm7': '7',
  'maj7': 'maj7',
  'm7b5': 'ø7',
  'dim7': '°7',
  'mMaj7': 'mMaj7',
  'sevenFlat5': '7b5',
  'sevenSharp5': '7#5',
  'sevenFlat9': '7b9',
  'sevenSharp9': '7#9',
  'add9': 'add9',
  'add11': 'add11',
  'nine': '9',
  'm9': '9',
  'maj9': 'maj9',
  'eleven': '11',
  'm11': '11',
  'maj11': 'maj11',
  'thirteen': '13',
  'maj13': 'maj13',
};

/// 和弦相对调性的罗马级数，如 C 调：C→I、Am→vi、G7→V7、Bb→♭VII。
///
/// 算法按「音名字母 → 调内音级」映射：调内七个音级对应主音字母起的
/// 七个连续字母（C 大调 C D E F G A B），和弦根音字母落在哪一级就是
/// 哪一级，再比较根音 pc 与该级自然 pc 决定 ♯/♭ 记号。这样等音异拼
/// （Db/C#）会得到乐理上不同但各自正确的记法（♭II / ♯I）。
String romanNumeral(String chordName, MusicKey key) {
  final parsed = ChordNameParser.parse(chordName);
  if (parsed == null) return chordName;

  // 主音字母与和弦根音字母在 C D E F G A B 七字母环上的序号。
  const letterOrder = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final keyLetter = letterOrder.indexOf(key.rootName[0]);
  final chordLetter = letterOrder.indexOf(parsed.root[0].toUpperCase());
  final degree = (chordLetter - keyLetter + 7) % 7;

  final offsets =
      key.mode == KeyMode.major ? MusicKey.majorOffsets : MusicKey.minorOffsets;
  final naturalPc = (key.rootPc + offsets[degree]) % 12;
  final chordPc = Note.pitchClassOf(parsed.root);
  final diff = (chordPc - naturalPc + 12) % 12;
  final accidental = switch (diff) {
    1 => '♯',
    11 => '♭',
    _ => '',
  };

  // 三度音为小三度（3 半音）的性质用小写，其余大写（含 sus/aug）。
  final intervals = parsed.quality.intervals;
  final isMinor = intervals.length >= 2 && intervals[1].semitones == 3;
  final base =
      isMinor ? _romanLower[degree] : _romanUpper[degree];
  final suffix = _romanQualitySuffix[parsed.quality.id] ?? '';

  return '$accidental$base$suffix';
}
