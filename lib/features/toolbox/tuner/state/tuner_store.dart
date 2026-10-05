import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/audio/guitar_audio_service.dart';
import '../../../../core/audio/instrument.dart';
import '../../../../core/audio/pitch_detector.dart';
import '../tuner_source.dart';

/// 调音器状态：监听麦克风流 → 自相关检音 → 与目标弦频比较。
///
/// 麦克风不可用（权限被拒/无设备）时给出降级提示，
/// 页面转用「参考音模式」：播放该弦标准音供人工比对。
class TunerStore extends ChangeNotifier {
  final TunerSource source;
  final TonePlayer player;

  /// 连续判准次数达到该值提示「已调准」。
  static const int inTuneStreakNeeded = 3;

  PitchDetection _latest = const PitchDetection(rms: 0);
  int _stringIndex = 5; // 默认 6 弦 E2（换弦从低到高是常见习惯）。
  bool _listening = false;
  bool _micDenied = false;
  int _streak = 0;

  StreamSubscription<Float32List>? _sub;

  TunerStore({required this.source, required this.player});

  /// 当前选中的弦（0–5，对应 1–6 弦）。
  int get stringIndex => _stringIndex;

  (int, String, int) get string => TunerTargets.strings[_stringIndex];

  PitchDetection get latest => _latest;

  bool get listening => _listening;

  /// 麦克风不可用（权限被拒/启动失败）。
  bool get micDenied => _micDenied;

  /// 最近一次检测的偏差音分（无音高时 null）。
  double? get cents {
    final f = _latest.freq;
    if (f == null || !_latest.hasPitch) return null;
    return TunerMath.centsOff(f, TunerTargets.freqOf(string.$3));
  }

  bool get inTune {
    final c = cents;
    return c != null && TunerMath.inTune(c);
  }

  /// 连续判准（过滤单次抖动）。
  bool get settledInTune => inTune && _streak >= inTuneStreakNeeded;

  /// 指针位置 -1..1（无音高时 0）。
  double get gauge {
    final c = cents;
    return c == null ? 0 : TunerMath.gauge(c);
  }

  void selectString(int index) {
    if (index < 0 || index > 5 || index == _stringIndex) return;
    _stringIndex = index;
    _streak = 0;
    notifyListeners();
  }

  Future<void> toggleListen() async {
    _listening ? await stop() : await start();
  }

  Future<void> start() async {
    if (_listening) return;
    _micDenied = false;
    final stream = await source.start();
    if (stream == null) {
      _micDenied = true;
      notifyListeners();
      return;
    }
    _listening = true;
    _streak = 0;
    _sub = stream.listen(_onChunk);
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _sub?.cancel();
    _sub = null;
    await source.stop();
    notifyListeners();
  }

  void _onChunk(Float32List samples) {
    final d = PitchDetector(sampleRate: source.sampleRate).detect(samples);
    _latest = d;
    if (inTune) {
      _streak++;
    } else if (d.hasPitch) {
      _streak = 0;
    }
    notifyListeners();
  }

  /// 参考音降级模式：播放当前弦的标准音。
  Future<void> playReference() =>
      player.playAsset(GuitarAudioService.assetFor(guitarInstrument, string.$3));

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await source.stop();
    await source.dispose();
    await player.stopAll();
    super.dispose();
  }
}
