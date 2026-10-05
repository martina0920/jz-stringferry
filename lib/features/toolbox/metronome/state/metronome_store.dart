import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/audio/guitar_audio_service.dart';
import '../../../../core/audio/metronome_engine.dart';

/// 节拍器状态：代际作废循环调度（小节尾排下一小节，与
/// ProgressionPlayer 同一范式），BPM/拍号/细分/重音在播放中可热改。
class MetronomeStore extends ChangeNotifier {
  final TonePlayer player;
  final ToneScheduler scheduler;

  int _bpm = 100;
  int _beatsPerBar = 4;
  MetronomeSubdivision _subdivision = MetronomeSubdivision.quarter;
  Set<int> _accentBeats = {0};

  bool _playing = false;
  int _generation = 0;
  final List<ScheduledTone> _pending = [];

  /// tap tempo 的点击时间戳（毫秒 epoch）。
  final List<int> _taps = [];

  /// BPM 允许范围（页面滑杆用，透传引擎常量）。
  static const int minBpm = MetronomeEngine.minBpm;
  static const int maxBpm = MetronomeEngine.maxBpm;

  MetronomeStore(this.player, {this.scheduler = const TimerToneScheduler()});

  int get bpm => _bpm;
  int get beatsPerBar => _beatsPerBar;
  MetronomeSubdivision get subdivision => _subdivision;
  Set<int> get accentBeats => Set.unmodifiable(_accentBeats);
  bool get isPlaying => _playing;

  /// 播放中改参数：作废当前小节，按新参数重排，节拍无缝衔接。
  void setBpm(int v) {
    final next = v.clamp(MetronomeEngine.minBpm, MetronomeEngine.maxBpm);
    if (next == _bpm) return;
    _bpm = next;
    if (_playing) _restart();
    notifyListeners();
  }

  void setBeatsPerBar(int v) {
    final next = v.clamp(1, 7);
    if (next == _beatsPerBar) return;
    _beatsPerBar = next;
    _accentBeats.removeWhere((b) => b >= next);
    if (_playing) _restart();
    notifyListeners();
  }

  void setSubdivision(MetronomeSubdivision v) {
    if (v == _subdivision) return;
    _subdivision = v;
    if (_playing) _restart();
    notifyListeners();
  }

  void toggleAccent(int beat) {
    if (beat < 0 || beat >= _beatsPerBar) return;
    final next = Set<int>.of(_accentBeats);
    if (!next.add(beat)) next.remove(beat);
    _accentBeats = next;
    if (_playing) _restart();
    notifyListeners();
  }

  /// 记录一次 tap；能估计出新 BPM 时返回 true（已生效）。
  bool tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _taps.add(now);
    if (_taps.length > 16) _taps.removeRange(0, _taps.length - 16);
    final estimated = TapTempo.estimateBpm(_taps);
    if (estimated == null || estimated == _bpm) return false;
    _bpm = estimated;
    if (_playing) _restart();
    notifyListeners();
    return true;
  }

  void togglePlay() => _playing ? stop() : play();

  void play() {
    if (_playing) return;
    _playing = true;
    _scheduleBar(_generation);
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_playing && _pending.isEmpty) {
      _generation++;
      return;
    }
    _cancelPending();
    await player.stopAll();
    notifyListeners();
  }

  void _restart() {
    _cancelPending();
    _playing = true;
    _scheduleBar(_generation);
    notifyListeners();
  }

  void _scheduleBar(int gen) {
    final ticks = MetronomeEngine.buildBarTicks(
      bpm: _bpm,
      beatsPerBar: _beatsPerBar,
      subdivision: _subdivision,
      accentBeats: _accentBeats,
    );
    for (final t in ticks) {
      _pending.add(scheduler.schedule(
        Duration(milliseconds: t.timeMs),
        () {
          if (gen != _generation) return;
          unawaited(player.playAsset(t.asset));
        },
      ));
    }
    _pending.add(scheduler.schedule(
      Duration(milliseconds: MetronomeEngine.barMs(_bpm, _beatsPerBar)),
      () {
        if (gen != _generation) return;
        _scheduleBar(gen);
      },
    ));
  }

  void _cancelPending() {
    _generation++;
    _playing = false;
    for (final s in _pending) {
      s.cancel();
    }
    _pending.clear();
  }

  @override
  void dispose() {
    _cancelPending();
    unawaited(player.stopAll());
    super.dispose();
  }
}
