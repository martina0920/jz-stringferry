import 'dart:async';
import 'dart:ui';

import 'instrument.dart';

/// 和弦试听发声方式（AC-7）。
enum PlayMode {
  /// 单音依次播放，间隔 350ms。
  single,

  /// 琶音（不截断地依次发声），间隔 120ms。
  arp,

  /// 扫弦（近似齐发），错峰 20ms。
  strum,
}

/// 一次延迟发声的句柄（默认实现内部持有 Timer）。
class ScheduledTone {
  final Duration delay;
  final VoidCallback callback;
  Timer? _timer;
  bool _canceled = false;

  ScheduledTone(this.delay, this.callback);

  void cancel() {
    _canceled = true;
    _timer?.cancel();
  }

  /// 测试用：是否已取消（假调度器据此决定是否还触发回调）。
  bool get isCanceled => _canceled;
}

/// 调度器抽象：测试可替换为记录式假调度器。
abstract class ToneScheduler {
  ScheduledTone schedule(Duration delay, VoidCallback callback);
}

class TimerToneScheduler implements ToneScheduler {
  const TimerToneScheduler();

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final scheduled = ScheduledTone(delay, callback);
    scheduled._timer = Timer(delay, () {
      if (!scheduled._canceled) callback();
    });
    return scheduled;
  }
}

/// 单音播放器抽象（生产用 just_audio，测试用 Fake）。
abstract class TonePlayer {
  Future<void> playAsset(String assetPath);
  Future<void> stopAll();
}

/// 吉他音频服务：单音/琶音/扫弦的发声调度与停止。
class GuitarAudioService {
  final TonePlayer player;
  final ToneScheduler scheduler;
  final List<ScheduledTone> _pending = [];

  GuitarAudioService(
    this.player, {
    this.scheduler = const TimerToneScheduler(),
  });

  static const int singleGapMs = 350;
  static const int arpGapMs = 120;
  static const int strumGapMs = 20;

  static String assetOf(int midi) => 'assets/audio/guitar/$midi.wav';

  /// 任意乐器的单音采样路径。
  static String assetFor(Instrument instrument, int midi) =>
      'assets/audio/${instrument.assetDir}/$midi.wav';

  /// 生成 (midi, 相对起点延迟ms) 序列（纯函数，AC-7 时序断言依据）。
  static List<(int, int)> buildSchedule(List<int> midis, PlayMode mode) {
    final gap = switch (mode) {
      PlayMode.single => singleGapMs,
      PlayMode.arp => arpGapMs,
      PlayMode.strum => strumGapMs,
    };
    return [for (var i = 0; i < midis.length; i++) (midis[i], i * gap)];
  }

  /// 播放一组和弦音（自动转 midi）。新的播放会先取消上一组。
  void playChord(
    List<int> midis, {
    PlayMode mode = PlayMode.single,
    Instrument instrument = guitarInstrument,
  }) {
    _cancelPending();
    for (final (midi, delayMs) in buildSchedule(midis, mode)) {
      _pending.add(scheduler.schedule(
        Duration(milliseconds: delayMs),
        () => player.playAsset(assetFor(instrument, midi)),
      ));
    }
  }

  /// 停止：清空待播队列并立即静音已发声的音。
  Future<void> stop() async {
    _cancelPending();
    await player.stopAll();
  }

  void _cancelPending() {
    for (final s in _pending) {
      s.cancel();
    }
    _pending.clear();
  }

  /// 把和弦音级排成以根音为低音的严格上行序列（按乐器音区锚定）。
  ///
  /// 输入 pcs 按 ChordSpec.tones 的顺序（根音起严格上行）。
  /// [instrument] 决定锚定的低音起点与钳位上限。
  static List<int> voiceChord({
    required int rootPc,
    required List<int> pitchClasses,
    Instrument instrument = guitarInstrument,
  }) {
    // 根音放在乐器音区内第一个与根音同名的音上。
    final low = instrument.lowMidi;
    final anchor = low + (((rootPc - low) % 12) + 12) % 12;
    final anchorPc = anchor % 12;
    final result = <int>[];
    var prev = -1;
    for (final pc in pitchClasses) {
      var target = anchor + (((pc - anchorPc) % 12) + 12) % 12;
      if (target < prev) target += 12;
      if (target > instrument.highMidi) target -= 12;
      result.add(target);
      prev = target;
    }
    return result;
  }
}
