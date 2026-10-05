import 'chord_quality.dart';
import 'note.dart';

/// 吉他指法。
///
/// [strings] 长度 6，索引 0=最粗的 6 弦(E)，5=最细的 1 弦(e)；
/// 每弦取值：-1 = 制音 X；0 = 空弦 O；>=1 = 按第几品。
class Fingering {
  final List<int> strings;

  /// 横按品位（无横按为 null）。
  final int? barreFret;

  /// 横按起始的最粗弦号（E 系=6 全按；A 系=5，6 弦制音）。
  final int? barreThickestString;

  const Fingering(this.strings, {this.barreFret, this.barreThickestString = 6})
      : assert(strings.length == 6);

  /// 从 X32010 这类 6 字符谱式解析（仅支持个数品位；>9 品用 int 列表构造）。
  factory Fingering.fromTab(String tab) {
    final chars = tab.replaceAll('x', 'X').split('');
    assert(chars.length == 6, '指法谱式必须 6 位: $tab');
    final v = chars.map((c) {
      if (c == 'X') return -1;
      final n = int.tryParse(c);
      assert(n != null, '非法指法字符: $c');
      return n!;
    }).toList(growable: false);
    return Fingering(v);
  }

  /// 所有按弦品位（>0），空弦与制音不计。
  List<int> get pressedFrets => strings.where((f) => f > 0).toList();

  int? get lowestFret {
    final p = pressedFrets;
    return p.isEmpty ? null : p.reduce((a, b) => a < b ? a : b);
  }

  int? get highestFret {
    final p = pressedFrets;
    return p.isEmpty ? null : p.reduce((a, b) => a > b ? a : b);
  }

  /// 实际按弦跨度（品），0/1 品开放把位视为 0。
  int get span {
    final lo = lowestFret, hi = highestFret;
    if (lo == null || hi == null) return 0;
    return hi - lo;
  }

  /// 起始品位（指板图显示用）：最低按弦品，开放把位显示 1。
  int get displayBaseFret => (lowestFret ?? 1) <= 2 ? 1 : lowestFret!;

  /// X32010 形式的展示串（>9 品仍逐弦输出数字）。
  String toTabString() => strings.map((f) => f < 0 ? 'X' : '$f').join();

  @override
  bool operator ==(Object other) =>
      other is Fingering &&
      other.barreFret == barreFret &&
      other.barreThickestString == barreThickestString &&
      _sameList(other.strings, strings);

  @override
  int get hashCode => Object.hash(
        barreFret,
        barreThickestString,
        Object.hashAll(strings),
      );

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────
// 人工校订的开放把位指法（按完整和弦名索引）
// ─────────────────────────────────────────────────────────────

/// 26 个经人工核对的常用开放把位/特殊指型（纯横按交给模板引擎）。
const Map<String, List<String>> _openFingeringTabs = {
  // 大三
  'C': ['X32010'],
  'D': ['XX0232'],
  'E': ['022100'],
  'G': ['320003'],
  'A': ['X02220'],
  // 小三
  'Dm': ['XX0231'],
  'Em': ['022000'],
  'Am': ['X02210'],
  // 属七
  'C7': ['X32310'],
  'D7': ['XX0212'],
  'E7': ['020100'],
  'G7': ['320001'],
  'A7': ['X02020'],
  'B7': ['X21202'],
  // 小七
  'Am7': ['X02010'],
  'Dm7': ['XX0211'],
  'Em7': ['020000'],
  // 大七
  'Cmaj7': ['X32000'],
  'Fmaj7': ['XX3210'],
  'Gmaj7': ['3X0002'],
  // 半减七
  'F#m7b5': ['2X2210'],
  'Bm7b5': ['X2323X'],
  // 加九 / 挂留 / 增 / 减 / m6 / m9
  'Cadd9': ['X32030'],
  'Dsus4': ['XX0233'],
  'Asus2': ['X02200'],
  'Caug': ['X32110'],
  'Cdim': ['X3454X'],
  'Cm6': ['X35545'],
  'Cm9': ['X3133X'],
};

// ─────────────────────────────────────────────────────────────
// E/Em/A/Am 系横按母型
// ─────────────────────────────────────────────────────────────

class _BarreForm {
  final String qualityId;

  /// 根音所在弦（6 或 5）。
  final int rootString;

  /// 开放母型指法（0 = 空弦/横按弦，>0 = 相对把位）。
  final List<int> shape;

  const _BarreForm(this.qualityId, this.rootString, this.shape);
}

const _barreForms = <_BarreForm>[
  _BarreForm('maj', 6, [0, 2, 2, 1, 0, 0]), // E
  _BarreForm('min', 6, [0, 2, 2, 0, 0, 0]), // Em
  _BarreForm('seven', 6, [0, 2, 0, 1, 0, 0]), // E7
  _BarreForm('m7', 6, [0, 2, 0, 0, 0, 0]), // Em7
  _BarreForm('maj7', 6, [0, 2, 1, 1, 0, 0]), // Emaj7
  _BarreForm('maj', 5, [-1, 0, 2, 2, 2, 0]), // A
  _BarreForm('min', 5, [-1, 0, 2, 2, 1, 0]), // Am
  _BarreForm('seven', 5, [-1, 0, 2, 0, 2, 0]), // A7
  _BarreForm('m7', 5, [-1, 0, 2, 0, 1, 0]), // Am7
  _BarreForm('maj7', 5, [-1, 0, 2, 1, 2, 0]), // Amaj7
];

/// 标准调弦各弦空弦音高（MIDI）与音级。
const List<int> _openMidi = [40, 45, 50, 55, 59, 64];

/// 横按模板推算：返回该根音+性质的全部移动指型（不含 shift=0 的开放形态）。
List<Fingering> _barreFingerings(int rootPc, String qualityId) {
  final result = <Fingering>[];
  for (final form in _barreForms) {
    if (form.qualityId != qualityId) continue;
    final basePc = form.rootString == 6 ? 4 : 9; // 6 弦根音 E，5 弦根音 A
    final shift = (rootPc - basePc) % 12;
    if (shift == 0) continue; // 开放形态已在人工表

    final v = form.shape.asMap().entries.map((e) {
      final rel = e.value;
      if (rel < 0) return -1;
      return shift + rel;
    }).toList(growable: false);

    result.add(Fingering(
      v,
      barreFret: shift,
      barreThickestString: form.rootString,
    ));
  }
  // 低把位优先。
  result.sort((a, b) => a.barreFret!.compareTo(b.barreFret!));
  return result;
}

// ─────────────────────────────────────────────────────────────
// 通用指型搜索（模板未覆盖的性质：sus/add9/9/11/13/变化和弦等）
// ─────────────────────────────────────────────────────────────

class _VoiceGenerator {
  final int rootPc;
  final Set<int> tonePcs;
  final int maxSpan;

  _VoiceGenerator(this.rootPc, this.tonePcs, this.maxSpan);

  List<int>? run() {
    List<int>? best;
    var bestCost = 1 << 30;

    // 根音放在 6 弦或 5 弦（5 弦根音时 6 弦必须制音）。
    for (var bassString = 0; bassString <= 1; bassString++) {
      for (var fret = 0; fret <= 14; fret++) {
        if ((_openMidi[bassString] + fret) % 12 != rootPc) continue;

        final fixed = List<int>.filled(6, -2); // -2 = 未定
        for (var i = 0; i < bassString; i++) {
          fixed[i] = -1; // 根音弦以下全部制音
        }
        fixed[bassString] = fret;

        final found = _dfs(
          strings: fixed,
          index: bassString + 1,
          covered: {rootPc},
          prevMidi: _openMidi[bassString] + fret,
        );
        if (found != null) {
          final cost = _cost(found);
          if (cost < bestCost) {
            bestCost = cost;
            best = found;
          }
        }
      }
    }
    return best;
  }

  /// 在第 [index] 弦上继续选择；每弦可制音（一旦发声后不再允许制音）。
  List<int>? _dfs({
    required List<int> strings,
    required int index,
    required Set<int> covered,
    required int prevMidi,
  }) {
    if (index == 6) {
      if (!tonePcs.every(covered.contains)) return null;
      final sounded = strings.where((f) => f >= 0).length;
      if (sounded < 4) return null;
      return List.of(strings);
    }

    // 剩余弦数不足以覆盖剩余音 -> 剪枝。
    final missing = tonePcs.difference(covered).length;
    if (missing > 6 - index) return null;

    final List<int?> choices = [];

    // 先尝试发声品位（0=空弦，1..14），再尝试制音。
    final candidates = <int>[];
    for (var f = 0; f <= 14; f++) {
      final midi = _openMidi[index] + f;
      if (tonePcs.contains(midi % 12) && midi > prevMidi) {
        // 跨度剪枝：与既有按弦（>0）比较。
        if (_spanOk(strings, f)) candidates.add(f);
      }
    }
    choices.addAll(candidates);
    choices.add(-1); // 制音

    for (final f in choices) {
      if (f == null) continue;
      final next = List<int>.of(strings);
      next[index] = f;
      if (f >= 0) {
        final result = _dfs(
          strings: next,
          index: index + 1,
          covered: {...covered, (_openMidi[index] + f) % 12},
          prevMidi: _openMidi[index] + f,
        );
        if (result != null) return result;
      } else {
        // 制音后，后续弦全部制音（不允许发声弦之间夹 X）。
        for (var j = index + 1; j < 6; j++) {
          next[j] = -1;
        }
        final sounded = next.where((f) => f >= 0).length;
        if (tonePcs.every(covered.contains) &&
            sounded >= tonePcs.length &&
            sounded >= 3) {
          return next;
        }
      }
    }
    return null;
  }

  bool _spanOk(List<int> strings, int newFret) {
    if (newFret == 0) return true; // 空弦不参与跨度
    final pressed = <int>[
      ...strings.where((f) => f > 0),
      newFret,
    ];
    if (pressed.length < 2) return true;
    final lo = pressed.reduce((a, b) => a < b ? a : b);
    final hi = pressed.reduce((a, b) => a > b ? a : b);
    return hi - lo <= maxSpan;
  }

  int _cost(List<int> s) {
    final pressed = s.where((f) => f > 0).toList();
    final mutes = s.where((f) => f == -1).length;
    final opens = s.where((f) => f == 0).length;
    final sumFret = pressed.fold<int>(0, (a, b) => a + b);
    final span = pressed.isEmpty
        ? 0
        : pressed.reduce((a, b) => a > b ? a : b) -
            pressed.reduce((a, b) => a < b ? a : b);
    // 低把位、少制音、多空弦、小跨度优先。
    return sumFret * 10 + mutes * 6 + span * 3 - opens * 4;
  }
}

// ─────────────────────────────────────────────────────────────
// 对外入口
// ─────────────────────────────────────────────────────────────

/// 计算某个和弦的全部指法：开放优先，随后至多 2 个低把位横按；
/// 模板覆盖不到的性质用通用搜索兜底。
List<Fingering> fingeringsFor(String rootName, ChordQuality quality) {
  final rootPc = Note.pitchClassOf(rootName);
  final chordName = '$rootName${quality.suffix}';
  final result = <Fingering>{};

  // 1) 人工开放表
  final tabs = _openFingeringTabs[chordName];
  if (tabs != null) {
    result.addAll(tabs.map(Fingering.fromTab));
  }

  // 2) E/A 系横按模板（取最低把位的 2 个）
  final barre = _barreFingerings(rootPc, quality.id).take(2);
  result.addAll(barre);

  // 3) 通用指型兜底：仅在没有任何指法时启用。
  if (result.isEmpty) {
    final tonePcs =
        quality.intervals.map((iv) => (rootPc + iv.semitones) % 12).toSet();
    for (final span in [4, 5, 6]) {
      final v = _VoiceGenerator(rootPc, tonePcs, span).run();
      if (v != null) {
        result.add(Fingering(v));
        break;
      }
    }
  }

  final list = result.toList();
  // 开放把位在前，横按/搜索结果按低把位优先。
  list.sort((a, b) {
    final aOpen = a.pressedFrets.isEmpty || (a.lowestFret ?? 99) <= 4;
    final bOpen = b.pressedFrets.isEmpty || (b.lowestFret ?? 99) <= 4;
    if (aOpen != bOpen) return aOpen ? -1 : 1;
    return (a.lowestFret ?? 0).compareTo(b.lowestFret ?? 0);
  });
  return list;
}
