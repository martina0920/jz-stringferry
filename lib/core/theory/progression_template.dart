import 'key_harmony.dart';

/// 模板中的一个和弦：级号 0–6（I/i … VII/vii），[seventh] 取顺阶七和弦。
class DegreeChord {
  final int degree;
  final bool seventh;

  const DegreeChord(this.degree, {this.seventh = false})
      : assert(degree >= 0 && degree < 7);
}

/// 常用和弦进行模板（以级数定义，选调入后实时实例化，不写死和弦名）。
class ProgressionTemplate {
  final String id;
  final String name;

  /// 仅可在该调式下实例化（大调模板配大调、小调模板配小调）。
  final KeyMode mode;
  final List<DegreeChord> degrees;

  /// 展示用级数串，如 I–vi–IV–V。
  final String numerals;
  final String hint;

  const ProgressionTemplate({
    required this.id,
    required this.name,
    required this.mode,
    required this.degrees,
    required this.numerals,
    required this.hint,
  });

  /// 在指定调性上实例化为和弦名序列。调用方保证 key.mode 与 [mode] 相同。
  List<String> instantiate(MusicKey key) => [
        for (final d in degrees)
          key.degreeChordName(d.degree, seventh: d.seventh),
      ];
}

/// 7 个内置模板（FR-6）。
const List<ProgressionTemplate> progressionTemplates = [
  ProgressionTemplate(
    id: 'p1645',
    name: '1645 流行进行',
    mode: KeyMode.major,
    degrees: [
      DegreeChord(0),
      DegreeChord(5),
      DegreeChord(3),
      DegreeChord(4),
    ],
    numerals: 'I – vi – IV – V',
    hint: '最常见的流行走向，分解或扫弦循环练习',
  ),
  ProgressionTemplate(
    id: 'p1564',
    name: '1564 抒情进行',
    mode: KeyMode.major,
    degrees: [
      DegreeChord(0),
      DegreeChord(4),
      DegreeChord(5),
      DegreeChord(3),
    ],
    numerals: 'I – V – vi – IV',
    hint: '大量抒情金曲使用，适合柱式和弦入门',
  ),
  ProgressionTemplate(
    id: 'p4536251',
    name: '4536251 华语流行',
    mode: KeyMode.major,
    degrees: [
      DegreeChord(3),
      DegreeChord(4),
      DegreeChord(2),
      DegreeChord(5),
      DegreeChord(1),
      DegreeChord(4),
      DegreeChord(0),
    ],
    numerals: 'IV – V – iii – vi – ii – V – I',
    hint: '华语流行金曲常客，情绪推进感强',
  ),
  ProgressionTemplate(
    id: 'canon',
    name: '卡农进行',
    mode: KeyMode.major,
    degrees: [
      DegreeChord(0),
      DegreeChord(4),
      DegreeChord(5),
      DegreeChord(2),
      DegreeChord(3),
      DegreeChord(0),
      DegreeChord(3),
      DegreeChord(4),
    ],
    numerals: 'I – V – vi – iii – IV – I – IV – V',
    hint: '帕赫贝尔卡农式下行，经典循环',
  ),
  ProgressionTemplate(
    id: 'p251',
    name: '251 爵士终止',
    mode: KeyMode.major,
    degrees: [
      DegreeChord(1, seventh: true),
      DegreeChord(4, seventh: true),
      DegreeChord(0, seventh: true),
    ],
    numerals: 'ii7 – V7 – Imaj7',
    hint: '爵士最核心的终止式，七和弦版',
  ),
  ProgressionTemplate(
    id: 'minor1645',
    name: '小调万能进行',
    mode: KeyMode.minor,
    degrees: [
      DegreeChord(0),
      DegreeChord(5),
      DegreeChord(2),
      DegreeChord(6),
    ],
    numerals: 'i – VI – III – VII',
    hint: '小调抒情常用，沉静有故事感',
  ),
  ProgressionTemplate(
    id: 'minorWalk',
    name: '小调走向',
    mode: KeyMode.minor,
    degrees: [
      DegreeChord(0),
      DegreeChord(6),
      DegreeChord(5),
      DegreeChord(4),
    ],
    numerals: 'i – VII – VI – v',
    hint: '小调流行/摇滚常用走向',
  ),
];

/// 按 id 取模板。
ProgressionTemplate? templateById(String id) {
  for (final t in progressionTemplates) {
    if (t.id == id) return t;
  }
  return null;
}
