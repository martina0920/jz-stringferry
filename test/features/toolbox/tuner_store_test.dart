import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/instrument.dart';
import 'package:jz_stringferry/features/toolbox/tuner/state/tuner_store.dart';
import 'package:jz_stringferry/features/toolbox/tuner/tuner_source.dart';

class _FakePlayer implements TonePlayer {
  final List<String> played = [];

  @override
  Future<void> playAsset(String assetPath) async => played.add(assetPath);

  @override
  Future<void> stopAll() async {}
}

class _FakeSource implements TunerSource {
  final _ctrl = StreamController<Float32List>.broadcast();
  bool? startResult; // null = 成功

  @override
  int get sampleRate => 44100;

  @override
  Future<Stream<Float32List>?> start() async {
    if (startResult == false) return null;
    return _ctrl.stream;
  }

  void emit(Float32List samples) => _ctrl.add(samples);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => _ctrl.close();
}

Float32List sine(double freq, {int samples = 4096, double amp = 0.5}) {
  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = amp * math.sin(2 * math.pi * freq * i / 44100);
  }
  return out;
}

void main() {
  test('默认选 6 弦（E2），selectString 切换', () {
    final store = TunerStore(source: _FakeSource(), player: _FakePlayer());
    expect(store.stringIndex, 5);
    expect(store.string.$3, 40);
    store.selectString(0);
    expect(store.string.$3, 64);
    store.selectString(7); // 越界忽略
    expect(store.stringIndex, 0);
  });

  test('start 失败（权限被拒）→ micDenied，不进入监听', () async {
    final source = _FakeSource()..startResult = false;
    final store = TunerStore(source: source, player: _FakePlayer());
    await store.start();
    expect(store.micDenied, isTrue);
    expect(store.listening, isFalse);
    await store.dispose();
  });

  test('收到目标频率正弦波 → 检出音高、音分≈0、判准', () async {
    final source = _FakeSource();
    final store = TunerStore(source: source, player: _FakePlayer());
    // 5 弦 A2 = midi 45 = 110 Hz。
    store.selectString(4);
    await store.start();
    expect(store.listening, isTrue);

    source.emit(sine(110.0));
    await Future<void>.delayed(Duration.zero);
    source.emit(sine(110.0));
    await Future<void>.delayed(Duration.zero);

    expect(store.latest.hasPitch, isTrue);
    expect(store.cents!, closeTo(0, 5));
    expect(store.inTune, isTrue);
    expect(store.gauge, closeTo(0, 0.2));
    await store.dispose();
  });

  test('偏高音 → 正音分、不判准；静音段 → 无音高', () async {
    final source = _FakeSource();
    final store = TunerStore(source: source, player: _FakePlayer());
    store.selectString(4); // A2 110Hz
    await store.start();

    source.emit(sine(113.5)); // 约高 54 音分
    await Future<void>.delayed(Duration.zero);
    expect(store.cents!, greaterThan(30));
    expect(store.inTune, isFalse);

    source.emit(Float32List(4096)); // 静音
    await Future<void>.delayed(Duration.zero);
    expect(store.latest.hasPitch, isFalse);
    expect(store.cents, isNull);
    await store.dispose();
  });

  test('playReference 播当前弦标准音资产', () async {
    final player = _FakePlayer();
    final store = TunerStore(source: _FakeSource(), player: player);
    store.selectString(0); // E4 midi 64
    await store.playReference();
    expect(player.played.single, GuitarAudioService.assetFor(guitarInstrument, 64));
    await store.dispose();
  });

  test('stop 后退出监听', () async {
    final source = _FakeSource();
    final store = TunerStore(source: source, player: _FakePlayer());
    await store.start();
    expect(store.listening, isTrue);
    await store.stop();
    expect(store.listening, isFalse);
    await store.dispose();
  });
}
