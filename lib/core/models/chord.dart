/// 和弦数据模型
class Chord {
  const Chord({
    required this.name,
    required this.tones,
    required this.intervals,
    required this.fingering,
  });

  /// 和弦名称，如 C、Am7、F#m7b5
  final String name;

  /// 组成音（音名），如 [C, E, G]
  final List<String> tones;

  /// 音程构成描述，如「根音＋大三度＋纯五度」
  final String intervals;

  /// 吉他指法（六根弦从低到高，0=空弦，x=不弹），如 X32010
  final String fingering;

  /// 和弦类型分类（大三、小三、属七……）由名称推断，供筛选使用
  String get family {
    if (name.endsWith('m7b5')) return '半减七';
    if (name.endsWith('maj7')) return '大七';
    if (name.endsWith('m7')) return '小七';
    if (name.endsWith('7')) return '属七';
    if (name.endsWith('m')) return '小三';
    if (name.endsWith('dim')) return '减三';
    if (name.endsWith('aug')) return '增三';
    if (name.endsWith('sus4')) return '挂四';
    if (name.endsWith('sus2')) return '挂二';
    return '大三';
  }

  @override
  String toString() => '$name (${tones.join(',')})';
}
