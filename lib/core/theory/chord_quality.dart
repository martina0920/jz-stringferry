/// 和弦性质（quality）定义：后缀、家族、中文别名、相对根音的音程。
library;

/// 相对根音的单个音程定义。
class IntervalDef {
  /// 相对根音的半音数。
  final int semitones;

  /// 音程的中文名称，如「大三度」。
  final String label;

  const IntervalDef(this.semitones, this.label);
}

/// 和弦性质。
class ChordQuality {
  /// 稳定 id，如 m7、maj7、sevenSharp9。
  final String id;

  /// 和弦名后缀，如 m7；大三和弦为空串。
  final String suffix;

  /// 用于筛选的家族（中文）。
  final String family;

  /// 中文/常见写法别名，用于模糊搜索。
  final List<String> aliases;

  /// 相对根音的音程列表（含根音本身，按半音升序）。
  final List<IntervalDef> intervals;

  const ChordQuality({
    required this.id,
    required this.suffix,
    required this.family,
    required this.aliases,
    required this.intervals,
  });
}

const _root = IntervalDef(0, '根音');

/// 全部 30 种和弦性质（17 个根音名 x 30 = 510 个唯一和弦名，满足 >=500）。
const List<ChordQuality> allQualities = [
  // —— 三和弦 ——
  ChordQuality(
    id: 'maj',
    suffix: '',
    family: '三和弦',
    aliases: ['大三和弦', '大三', 'major'],
    intervals: [_root, IntervalDef(4, '大三度'), IntervalDef(7, '纯五度')],
  ),
  ChordQuality(
    id: 'min',
    suffix: 'm',
    family: '三和弦',
    aliases: ['小三和弦', '小三', 'minor', 'min'],
    intervals: [_root, IntervalDef(3, '小三度'), IntervalDef(7, '纯五度')],
  ),
  ChordQuality(
    id: 'dim',
    suffix: 'dim',
    family: '三和弦',
    aliases: ['减三和弦', '减和弦', '减三', '减'],
    intervals: [_root, IntervalDef(3, '小三度'), IntervalDef(6, '减五度')],
  ),
  ChordQuality(
    id: 'aug',
    suffix: 'aug',
    family: '三和弦',
    aliases: ['增三和弦', '增和弦', '增三', '增'],
    intervals: [_root, IntervalDef(4, '大三度'), IntervalDef(8, '增五度')],
  ),
  // —— 挂留 ——
  ChordQuality(
    id: 'sus2',
    suffix: 'sus2',
    family: '挂留和弦',
    aliases: ['挂二和弦', '挂二', '挂留二', '挂留'],
    intervals: [_root, IntervalDef(2, '大二度'), IntervalDef(7, '纯五度')],
  ),
  ChordQuality(
    id: 'sus4',
    suffix: 'sus4',
    family: '挂留和弦',
    aliases: ['挂四和弦', '挂四', '挂留四', '挂留'],
    intervals: [_root, IntervalDef(5, '纯四度'), IntervalDef(7, '纯五度')],
  ),
  ChordQuality(
    id: 'sevenSus4',
    suffix: '7sus4',
    family: '挂留和弦',
    aliases: ['属七挂四', '七挂四'],
    intervals: [
      _root,
      IntervalDef(5, '纯四度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
    ],
  ),
  // —— 六和弦 ——
  ChordQuality(
    id: 'six',
    suffix: '6',
    family: '六和弦',
    aliases: ['六和弦', '大六和弦', '大六'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(9, '大六度'),
    ],
  ),
  ChordQuality(
    id: 'm6',
    suffix: 'm6',
    family: '六和弦',
    aliases: ['小六和弦', '小六'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(9, '大六度'),
    ],
  ),
  ChordQuality(
    id: 'sixNine',
    suffix: '6/9',
    family: '六和弦',
    aliases: ['六九和弦', '六九', '69'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(9, '大六度'),
      IntervalDef(14, '大九度'),
    ],
  ),
  // —— 七和弦 ——
  ChordQuality(
    id: 'seven',
    suffix: '7',
    family: '七和弦',
    aliases: ['七和弦', '属七和弦', '属七', '七'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
    ],
  ),
  ChordQuality(
    id: 'm7',
    suffix: 'm7',
    family: '七和弦',
    aliases: ['小七和弦', '小七', 'min7'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
    ],
  ),
  ChordQuality(
    id: 'maj7',
    suffix: 'maj7',
    family: '七和弦',
    aliases: ['大七和弦', '大七', 'major7'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(11, '大七度'),
    ],
  ),
  ChordQuality(
    id: 'm7b5',
    suffix: 'm7b5',
    family: '七和弦',
    aliases: ['半减七和弦', '半减七', '减小七和弦'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(6, '减五度'),
      IntervalDef(10, '小七度'),
    ],
  ),
  ChordQuality(
    id: 'dim7',
    suffix: 'dim7',
    family: '七和弦',
    aliases: ['减七和弦', '减七'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(6, '减五度'),
      IntervalDef(9, '减七度'),
    ],
  ),
  ChordQuality(
    id: 'mMaj7',
    suffix: 'm(maj7)',
    family: '七和弦',
    aliases: ['小大七和弦', '小大七', 'mM7'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(11, '大七度'),
    ],
  ),
  ChordQuality(
    id: 'sevenFlat5',
    suffix: '7b5',
    family: '七和弦',
    aliases: ['属七降五', '七降五'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(6, '减五度'),
      IntervalDef(10, '小七度'),
    ],
  ),
  ChordQuality(
    id: 'sevenSharp5',
    suffix: '7#5',
    family: '七和弦',
    aliases: ['属七升五', '七升五'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(8, '增五度'),
      IntervalDef(10, '小七度'),
    ],
  ),
  ChordQuality(
    id: 'sevenFlat9',
    suffix: '7b9',
    family: '七和弦',
    aliases: ['属七降九', '七降九'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(13, '小九度'),
    ],
  ),
  ChordQuality(
    id: 'sevenSharp9',
    suffix: '7#9',
    family: '七和弦',
    aliases: ['属七升九', '七升九'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(15, '增九度'),
    ],
  ),
  // —— 加音 ——
  ChordQuality(
    id: 'add9',
    suffix: 'add9',
    family: '加音和弦',
    aliases: ['加九和弦', '加九', 'add2'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(14, '大九度'),
    ],
  ),
  ChordQuality(
    id: 'add11',
    suffix: 'add11',
    family: '加音和弦',
    aliases: ['加十一和弦', '加十一'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(17, '纯十一度'),
    ],
  ),
  // —— 延伸和弦 ——
  ChordQuality(
    id: 'nine',
    suffix: '9',
    family: '延伸和弦',
    aliases: ['九和弦', '属九和弦', '属九'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(14, '大九度'),
    ],
  ),
  ChordQuality(
    id: 'm9',
    suffix: 'm9',
    family: '延伸和弦',
    aliases: ['小九和弦', '小九', 'min9'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(14, '大九度'),
    ],
  ),
  ChordQuality(
    id: 'maj9',
    suffix: 'maj9',
    family: '延伸和弦',
    aliases: ['大九和弦', '大九', 'major9'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(11, '大七度'),
      IntervalDef(14, '大九度'),
    ],
  ),
  ChordQuality(
    id: 'eleven',
    suffix: '11',
    family: '延伸和弦',
    aliases: ['十一和弦'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(14, '大九度'),
      IntervalDef(17, '纯十一度'),
    ],
  ),
  ChordQuality(
    id: 'm11',
    suffix: 'm11',
    family: '延伸和弦',
    aliases: ['小十一和弦', '小十一'],
    intervals: [
      _root,
      IntervalDef(3, '小三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(14, '大九度'),
      IntervalDef(17, '纯十一度'),
    ],
  ),
  ChordQuality(
    id: 'maj11',
    suffix: 'maj11',
    family: '延伸和弦',
    aliases: ['大十一和弦', '大十一'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(11, '大七度'),
      IntervalDef(14, '大九度'),
      IntervalDef(17, '纯十一度'),
    ],
  ),
  ChordQuality(
    id: 'thirteen',
    suffix: '13',
    family: '延伸和弦',
    aliases: ['十三和弦', '属十三'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(10, '小七度'),
      IntervalDef(14, '大九度'),
      IntervalDef(21, '大十三度'),
    ],
  ),
  ChordQuality(
    id: 'maj13',
    suffix: 'maj13',
    family: '延伸和弦',
    aliases: ['大十三和弦', '大十三'],
    intervals: [
      _root,
      IntervalDef(4, '大三度'),
      IntervalDef(7, '纯五度'),
      IntervalDef(11, '大七度'),
      IntervalDef(14, '大九度'),
      IntervalDef(21, '大十三度'),
    ],
  ),
];

/// 按 id 索引性质。
final Map<String, ChordQuality> qualitiesById = {
  for (final q in allQualities) q.id: q,
};
