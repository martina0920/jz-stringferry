import 'instrument.dart';

/// 节拍器细分：每拍 1/2/4 个 tick。
enum MetronomeSubdivision {
  quarter(1, '四分'),
  eighth(2, '八分'),
  sixteenth(4, '十六分');

  final int perBeat;
  final String label;
  const MetronomeSubdivision(this.perBeat, this.label);
}

/// 节拍器一拍内的发声（kick=重音，hat=正拍弱位，snare=十六分反拍）。
class MetronomeTick {
  final int timeMs;
  final String asset;

  const MetronomeTick(this.timeMs, this.asset);
}

/// 节拍器排程纯函数（无音频/定时器依赖，单测友好）。
class MetronomeEngine {
  MetronomeEngine._();

  /// BPM 允许范围（tap tempo 结果同样夹紧到此区间）。
  static const int minBpm = 30;
  static const int maxBpm = 300;

  /// 一小节的 tick 表。
  ///
  /// [beatsPerBar] 1–7；[subdivision] 每拍细分数；
  /// [accentBeats] 需要重音的拍号集合（从 0 计，缺省仅第 1 拍重音）。
  /// 声音映射：重音正拍=kick，普通正拍=hat，八分反拍=hat，
  /// 十六分第 2 反拍（"and" 后的 "e"/"a" 中点）=snare。
  static List<MetronomeTick> buildBarTicks({
    required int bpm,
    required int beatsPerBar,
    MetronomeSubdivision subdivision = MetronomeSubdivision.quarter,
    Set<int>? accentBeats,
  }) {
    final accents = (accentBeats == null || accentBeats.isEmpty)
        ? const {0}
        : accentBeats;
    final beatMs = 60000 / bpm;
    final ticks = <MetronomeTick>[];

    for (var beat = 0; beat < beatsPerBar; beat++) {
      final isAccent = accents.contains(beat);
      final base = beat * beatMs;
      switch (subdivision.perBeat) {
        case 1:
          ticks.add(_tick(base, isAccent));
        case 2:
          ticks.add(_tick(base, isAccent));
          ticks.add(_tick(base + beatMs / 2, false));
        case 4:
          ticks.add(_tick(base, isAccent));
          ticks.add(_tick(base + beatMs * 0.25, false));
          ticks.add(_tick(base + beatMs * 0.5, false, snare: true));
          ticks.add(_tick(base + beatMs * 0.75, false));
      }
    }
    return ticks;
  }

  static MetronomeTick _tick(double timeMs, bool accent, {bool snare = false}) {
    final asset = snare
        ? drumSnareAsset
        : accent
            ? drumKickAsset
            : drumHatAsset;
    return MetronomeTick(timeMs.round(), asset);
  }

  /// 一小节时长（毫秒）。
  static int barMs(int bpm, int beatsPerBar) =>
      (beatsPerBar * 60000 / bpm).round();
}

/// Tap tempo 估计（纯函数）：取最近 [window] 次点击的间隔均值。
///
/// 超过 2 秒无点击的间隔视为「重新开始」，只统计其后的间隔；
/// 有效间隔不足 1 个时返回 null（尚无法估计）。
class TapTempo {
  TapTempo._();

  static const int defaultWindow = 4;
  static const int resetGapMs = 2000;

  static int? estimateBpm(
    List<int> tapTimesMs, {
    int window = defaultWindow,
  }) {
    if (tapTimesMs.length < 2) return null;
    final intervals = <int>[];
    for (var i = tapTimesMs.length - 1; i > 0; i--) {
      final gap = tapTimesMs[i] - tapTimesMs[i - 1];
      if (gap <= 0 || gap > resetGapMs) break;
      intervals.add(gap);
      if (intervals.length >= window) break;
    }
    if (intervals.isEmpty) return null;
    final avg =
        intervals.reduce((a, b) => a + b) / intervals.length;
    final bpm = (60000 / avg).round();
    return bpm.clamp(MetronomeEngine.minBpm, MetronomeEngine.maxBpm);
  }
}
