import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'guitar_audio_service.dart';

/// 基于 just_audio 的单音播放器：每个音一个轻量实例，
/// 播完自动释放；stopAll 立即静音并回收全部实例（支持和弦叠加）。
class JustAudioTonePlayer implements TonePlayer {
  final Set<AudioPlayer> _active = {};

  /// 自然播完回调与 stopAll 可能并发，共享回收标志避免双重 dispose。
  static final Expando<bool> _released = Expando<bool>();

  Future<void> _release(AudioPlayer player, {required bool stopFirst}) async {
    if (_released[player] ?? false) return;
    _released[player] = true;
    _active.remove(player);
    try {
      if (stopFirst) await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  @override
  Future<void> playAsset(String assetPath) async {
    final player = AudioPlayer();
    _active.add(player);
    try {
      await player.setAsset(assetPath);
      unawaited(
          player.play().whenComplete(() => _release(player, stopFirst: false)));
    } catch (_) {
      await _release(player, stopFirst: false);
    }
  }

  @override
  Future<void> stopAll() async {
    final all = List<AudioPlayer>.of(_active);
    _active.clear();
    for (final p in all) {
      await _release(p, stopFirst: true);
    }
  }
}
