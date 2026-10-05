import 'package:flutter_test/flutter_test.dart';
import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/metronome_engine.dart';
import 'package:jz_stringferry/features/toolbox/metronome/state/metronome_store.dart';

class _RecordingPlayer implements TonePlayer {
  final List<String> played = [];
  int stopAllCount = 0;

  @override
  Future<void> playAsset(String assetPath) async => played.add(assetPath);

  @override
  Future<void> stopAll() async => stopAllCount++;
}

void main() {
  test('初始状态：100 BPM / 4 拍 / 四分 / 重音第 1 拍', () {
    final store = MetronomeStore(_RecordingPlayer());
    expect(store.bpm, 100);
    expect(store.beatsPerBar, 4);
    expect(store.subdivision, MetronomeSubdivision.quarter);
    expect(store.accentBeats, {0});
    expect(store.isPlaying, isFalse);
  });

  test('setBpm 钳位到引擎范围，播放状态不变', () async {
    final store = MetronomeStore(_RecordingPlayer());
    store.setBpm(999);
    expect(store.bpm, MetronomeStore.maxBpm);
    store.setBpm(10);
    expect(store.bpm, MetronomeStore.minBpm);

    store.play();
    expect(store.isPlaying, isTrue);
    store.setBpm(120);
    expect(store.bpm, 120);
    expect(store.isPlaying, isTrue);
    await store.stop();
  });

  test('setBeatsPerBar：收窄拍号时裁掉越界重音', () async {
    final store = MetronomeStore(_RecordingPlayer());
    store.toggleAccent(2);
    store.toggleAccent(3);
    expect(store.accentBeats, {0, 2, 3});

    store.setBeatsPerBar(3);
    expect(store.accentBeats, {0, 2});
    await store.stop();
  });

  test('toggleAccent 可加可减；越界拍忽略', () async {
    final store = MetronomeStore(_RecordingPlayer());
    store.toggleAccent(1);
    expect(store.accentBeats.contains(1), isTrue);
    store.toggleAccent(1);
    expect(store.accentBeats.contains(1), isFalse);
    store.toggleAccent(9);
    expect(store.accentBeats.length, 1);
    await store.stop();
  });

  test('play/stop：播放态切换，stop 停止并静音', () async {
    final player = _RecordingPlayer();
    final store = MetronomeStore(player);
    store.play();
    expect(store.isPlaying, isTrue);
    await store.stop();
    expect(store.isPlaying, isFalse);
    expect(player.stopAllCount, 1);
  });

  test('tap：能估出速度时直接生效', () async {
    final store = MetronomeStore(_RecordingPlayer());
    // 300ms 间隔连点 ≈ 200 BPM（上限内）。
    final hit = await _tapAtIntervals(store, const Duration(milliseconds: 300), 4);
    expect(hit, isTrue);
    expect(store.bpm, inInclusiveRange(190, 210));
    await store.stop();
  });

  test('play 期间 setSubdivision 保持播放态（热改参数不中断）', () async {
    final store = MetronomeStore(_RecordingPlayer());
    store.play();
    store.setSubdivision(MetronomeSubdivision.eighth);
    expect(store.subdivision, MetronomeSubdivision.eighth);
    expect(store.isPlaying, isTrue);
    await store.stop();
  });
}

/// 以给定间隔真实点击 [n] 次，返回是否有一次估出速度。
Future<bool> _tapAtIntervals(
  MetronomeStore store,
  Duration gap,
  int n,
) async {
  var hit = false;
  for (var i = 0; i < n; i++) {
    if (i > 0) await Future<void>.delayed(gap);
    if (store.tap()) hit = true;
  }
  return hit;
}
