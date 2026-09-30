import '../core/models/chord.dart';

/// 和弦数据仓库
///
/// 首版内置常用和弦示例数据（验证 UI 与交互），
/// 二期按「尽量全（500+）」扩充，并迁移到 sqflite 本地数据库离线查询。
class ChordRepository {
  ChordRepository._();

  static final List<Chord> _chords = [
    // —— 大三和弦 ——
    const Chord(name: 'C', tones: ['C', 'E', 'G'], intervals: '根音＋大三度＋纯五度', fingering: 'X32010'),
    const Chord(name: 'D', tones: ['D', 'F#', 'A'], intervals: '根音＋大三度＋纯五度', fingering: 'XX0232'),
    const Chord(name: 'E', tones: ['E', 'G#', 'B'], intervals: '根音＋大三度＋纯五度', fingering: '022100'),
    const Chord(name: 'F', tones: ['F', 'A', 'C'], intervals: '根音＋大三度＋纯五度', fingering: '133211'),
    const Chord(name: 'G', tones: ['G', 'B', 'D'], intervals: '根音＋大三度＋纯五度', fingering: '320003'),
    const Chord(name: 'A', tones: ['A', 'C#', 'E'], intervals: '根音＋大三度＋纯五度', fingering: 'X02220'),
    const Chord(name: 'B', tones: ['B', 'D#', 'F#'], intervals: '根音＋大三度＋纯五度', fingering: 'X24442'),
    const Chord(name: 'C#', tones: ['C#', 'F', 'G#'], intervals: '根音＋大三度＋纯五度', fingering: 'X46664'),
    const Chord(name: 'F#', tones: ['F#', 'A#', 'C#'], intervals: '根音＋大三度＋纯五度', fingering: '244322'),
    const Chord(name: 'G#', tones: ['G#', 'C', 'D#'], intervals: '根音＋大三度＋纯五度', fingering: '466544'),
    const Chord(name: 'A#', tones: ['A#', 'D', 'F'], intervals: '根音＋大三度＋纯五度', fingering: '688666'),
    const Chord(name: 'D#', tones: ['D#', 'G', 'A#'], intervals: '根音＋大三度＋纯五度', fingering: 'XX1343'),

    // —— 小三和弦 ——
    const Chord(name: 'Cm', tones: ['C', 'Eb', 'G'], intervals: '根音＋小三度＋纯五度', fingering: 'X35543'),
    const Chord(name: 'Dm', tones: ['D', 'F', 'A'], intervals: '根音＋小三度＋纯五度', fingering: 'XX0231'),
    const Chord(name: 'Em', tones: ['E', 'G', 'B'], intervals: '根音＋小三度＋纯五度', fingering: '022000'),
    const Chord(name: 'Fm', tones: ['F', 'Ab', 'C'], intervals: '根音＋小三度＋纯五度', fingering: '133111'),
    const Chord(name: 'Gm', tones: ['G', 'Bb', 'D'], intervals: '根音＋小三度＋纯五度', fingering: '355333'),
    const Chord(name: 'Am', tones: ['A', 'C', 'E'], intervals: '根音＋小三度＋纯五度', fingering: 'X02210'),
    const Chord(name: 'Bm', tones: ['B', 'D', 'F#'], intervals: '根音＋小三度＋纯五度', fingering: 'X24432'),

    // —— 七和弦 ——
    const Chord(name: 'C7', tones: ['C', 'E', 'G', 'Bb'], intervals: '根音＋大三度＋纯五度＋小七度', fingering: 'X32310'),
    const Chord(name: 'D7', tones: ['D', 'F#', 'A', 'C'], intervals: '根音＋大三度＋纯五度＋小七度', fingering: 'XX0212'),
    const Chord(name: 'E7', tones: ['E', 'G#', 'B', 'D'], intervals: '根音＋大三度＋纯五度＋小七度', fingering: '020100'),
    const Chord(name: 'G7', tones: ['G', 'B', 'D', 'F'], intervals: '根音＋大三度＋纯五度＋小七度', fingering: '320001'),
    const Chord(name: 'A7', tones: ['A', 'C#', 'E', 'G'], intervals: '根音＋大三度＋纯五度＋小七度', fingering: 'X02020'),
    const Chord(name: 'B7', tones: ['B', 'D#', 'F#', 'A'], intervals: '根音＋大三度＋纯五度＋小七度', fingering: 'X21202'),
    const Chord(name: 'Am7', tones: ['A', 'C', 'E', 'G'], intervals: '根音＋小三度＋纯五度＋小七度', fingering: 'X02010'),
    const Chord(name: 'Dm7', tones: ['D', 'F', 'A', 'C'], intervals: '根音＋小三度＋纯五度＋小七度', fingering: 'XX0211'),
    const Chord(name: 'Em7', tones: ['E', 'G', 'B', 'D'], intervals: '根音＋小三度＋纯五度＋小七度', fingering: '020000'),
    const Chord(name: 'Cmaj7', tones: ['C', 'E', 'G', 'B'], intervals: '根音＋大三度＋纯五度＋大七度', fingering: 'X32000'),
    const Chord(name: 'Fmaj7', tones: ['F', 'A', 'C', 'E'], intervals: '根音＋大三度＋纯五度＋大七度', fingering: 'XX3210'),
    const Chord(name: 'Gmaj7', tones: ['G', 'B', 'D', 'F#'], intervals: '根音＋大三度＋纯五度＋大七度', fingering: '3X0002'),

    // —— 延伸与变化和弦 ——
    const Chord(name: 'F#m7b5', tones: ['F#', 'A', 'C', 'E'], intervals: '根音＋小三度＋减五度＋小七度', fingering: '2X2210'),
    const Chord(name: 'Bm7b5', tones: ['B', 'D', 'F', 'A'], intervals: '根音＋小三度＋减五度＋小七度', fingering: 'X2323X'),
    const Chord(name: 'Cadd9', tones: ['C', 'E', 'G', 'D'], intervals: '根音＋大三度＋纯五度＋大九度', fingering: 'X32030'),
    const Chord(name: 'Dsus4', tones: ['D', 'G', 'A'], intervals: '根音＋纯四度＋纯五度', fingering: 'XX0233'),
    const Chord(name: 'Asus2', tones: ['A', 'B', 'E'], intervals: '根音＋大二度＋纯五度', fingering: 'X02200'),
    const Chord(name: 'Caug', tones: ['C', 'E', 'G#'], intervals: '根音＋大三度＋增五度', fingering: 'X32110'),
    const Chord(name: 'Cdim', tones: ['C', 'Eb', 'Gb'], intervals: '根音＋小三度＋减五度', fingering: 'X3454X'),
    const Chord(name: 'Cm6', tones: ['C', 'Eb', 'G', 'A'], intervals: '根音＋小三度＋纯五度＋大六度', fingering: 'X35545'),
    const Chord(name: 'Cm9', tones: ['C', 'Eb', 'G', 'Bb', 'D'], intervals: '根音＋小三度＋纯五度＋小七度＋大九度', fingering: 'X3133X'),
  ];

  /// 全量和弦（后续切换 sqflite 后改为异步查询）
  static List<Chord> all() => List.unmodifiable(_chords);

  /// 模糊搜索：按名称、组成音匹配
  static List<Chord> search(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return all();
    return _chords.where((c) {
      return c.name.toLowerCase().contains(kw) ||
          c.tones.any((t) => t.toLowerCase() == kw || t.toLowerCase().contains(kw));
    }).toList();
  }

  /// 按和弦名精确查询
  static Chord? byName(String name) {
    for (final c in _chords) {
      if (c.name == name) return c;
    }
    return null;
  }
}
