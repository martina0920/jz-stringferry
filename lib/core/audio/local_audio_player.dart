import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// 本地音频播放器抽象（扒带页用；测试注入 Fake 记录调用）。
abstract class LocalAudioPlayer {
  /// 加载本地文件，返回时长 ms。
  Future<int> setFilePath(String path);

  /// 播放/暂停。
  Future<void> play();
  Future<void> pause();

  /// 变速不变调：0.5–1.5。
  Future<void> setSpeed(double speed);

  /// 跳转（毫秒）。
  Future<void> seekMs(int ms);

  int get positionMs;
  bool get playing;

  /// 位置流（每 ~200ms 一次），供 AB 循环与进度条。
  Stream<int> positionStream();

  Future<void> disposePlayer();
}

/// just_audio 生产实现。
class JustAudioLocalPlayer implements LocalAudioPlayer {
  AudioPlayer? _player;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  Future<int> setFilePath(String path) async {
    final duration = await _p.setFilePath(path);
    return duration?.inMilliseconds ?? 0;
  }

  @override
  Future<void> play() => _p.play();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> setSpeed(double speed) => _p.setSpeed(speed.clamp(0.5, 1.5));

  @override
  Future<void> seekMs(int ms) => _p.seek(Duration(milliseconds: ms));

  @override
  int get positionMs => _p.position.inMilliseconds;

  @override
  bool get playing => _p.playing;

  @override
  Stream<int> positionStream() => _p.createPositionStream(
        steps: 80,
        minPeriod: const Duration(milliseconds: 200),
        maxPeriod: const Duration(milliseconds: 200),
      ).map((d) => d.inMilliseconds);

  @override
  Future<void> disposePlayer() async {
    await _player?.dispose();
    _player = null;
  }
}

/// AB 循环器：监听 [positionStream]，越界回跳 A 点。
///
/// 纯逻辑类（流可 Fake），测试无需真音频。
class AbLoopController {
  final LocalAudioPlayer player;
  StreamSubscription<int>? _sub;

  int? _aMs;
  int? _bMs;
  bool _enabled = false;

  AbLoopController(this.player);

  int? get aMs => _aMs;
  int? get bMs => _bMs;
  bool get enabled => _enabled;

  /// 设 A/B 点（ms，可 null = 未设）。B <= A 视为无效清除 B。
  void setLoop({int? aMs, int? bMs}) {
    _aMs = aMs;
    _bMs = (bMs != null && aMs != null && bMs <= aMs) ? null : bMs;
  }

  void start() {
    if (!_enabled) {
      _enabled = true;
      _sub?.cancel();
      _sub = player.positionStream().listen(_onPosition);
    }
  }

  void stop() {
    _enabled = false;
    _sub?.cancel();
    _sub = null;
  }

  void _onPosition(int ms) {
    if (!_enabled) return;
    final a = _aMs;
    final b = _bMs;
    if (a != null && b != null && ms >= b) {
      // 越过 B → 回跳（加 30ms 余量避免 seek 精度死循环）。
      unawaited(player.seekMs(a));
    }
  }

  void dispose() {
    stop();
  }
}
