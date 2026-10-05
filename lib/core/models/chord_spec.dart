import 'dart:convert';

/// 指法的持久化/传输形态。
class FingeringSpec {
  /// 6 弦取值：-1 制音，0 空弦，>0 品位。
  final List<int> strings;

  /// 横按品位（可空）。
  final int? barreFret;

  /// 横按起始最粗弦号（6=E 系全按，5=A 系，6 弦制音）。
  final int? barreThickestString;

  const FingeringSpec(
    this.strings, {
    this.barreFret,
    this.barreThickestString,
  });

  factory FingeringSpec.fromJson(Map<String, dynamic> json) => FingeringSpec(
        (json['strings'] as List).cast<int>(),
        barreFret: json['barre_fret'] as int?,
        barreThickestString: json['barre_thickest'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'strings': strings,
        'barre_fret': barreFret,
        'barre_thickest': barreThickestString,
      };

  String get tabString => strings.map((f) => f < 0 ? 'X' : '$f').join();
}

/// 和弦库中的一条完整和弦记录。
class ChordSpec {
  final int? id;
  final String name;
  final String root;
  final int rootPc;
  final ChordQualityRef quality;
  final String family;
  final List<String> tones;
  final List<String> intervals;
  final List<FingeringSpec> fingerings;
  final int sortKey;

  const ChordSpec({
    this.id,
    required this.name,
    required this.root,
    required this.rootPc,
    required this.quality,
    required this.family,
    required this.tones,
    required this.intervals,
    required this.fingerings,
    required this.sortKey,
  });

  factory ChordSpec.fromMap(Map<String, dynamic> map) => ChordSpec(
        id: map['id'] as int?,
        name: map['name'] as String,
        root: map['root'] as String,
        rootPc: map['root_pc'] as int,
        quality: ChordQualityRef(
          map['quality'] as String,
        ),
        family: map['family'] as String,
        tones: (jsonDecode(map['tones'] as String) as List).cast<String>(),
        intervals:
            (jsonDecode(map['intervals'] as String) as List).cast<String>(),
        fingerings: (jsonDecode(map['fingerings'] as String) as List)
            .map((e) => FingeringSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        sortKey: map['sort_key'] as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'root': root,
        'root_pc': rootPc,
        'quality': quality.id,
        'family': family,
        'tones': jsonEncode(tones),
        'intervals': jsonEncode(intervals),
        'fingerings': jsonEncode(fingerings.map((f) => f.toJson()).toList()),
        'sort_key': sortKey,
      };

  String get intervalText => intervals.join(' · ');
}

/// 性质的轻量引用（避免持久层直接依赖完整常量表）。
class ChordQualityRef {
  final String id;
  const ChordQualityRef(this.id);
}
