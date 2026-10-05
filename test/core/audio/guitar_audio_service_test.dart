import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';

class _FakePlayer implements TonePlayer {
  final List<String> playedAssets = [];
  int stopCount = 0;

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> stopAll() async => stopCount++;
}

/// 记录延迟但不真正计时；测试手动 fire 来模拟发声。
class _RecordingScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }

  void fireAll() {
    for (final s in scheduled) {
      if (!s.isCanceled) s.callback();
    }
  }
}

void main() {
  group('AC-7 发声时序', () {
    late _FakePlayer player;
    late _RecordingScheduler scheduler;
    late GuitarAudioService service;
    final midis = [49, 52, 56, 59];

    setUp(() {
      player = _FakePlayer();
      scheduler = _RecordingScheduler();
      service = GuitarAudioService(player, scheduler: scheduler);
    });

    test('单音间隔 350ms', () {
      expect(GuitarAudioService.buildSchedule(midis, PlayMode.single), [
        (49, 0),
        (52, 350),
        (56, 700),
        (59, 1050),
      ]);
    });

    test('琶音间隔 120ms', () {
      expect(GuitarAudioService.buildSchedule(midis, PlayMode.arp), [
        (49, 0),
        (52, 120),
        (56, 240),
        (59, 360),
      ]);
    });

    test('扫弦错峰 20ms', () {
      expect(GuitarAudioService.buildSchedule(midis, PlayMode.strum), [
        (49, 0),
        (52, 20),
        (56, 40),
        (59, 60),
      ]);
    });

    test('按调度顺序触发时播放器收到对应资产路径', () {
      service.playChord(midis, mode: PlayMode.arp);
      expect(player.playedAssets, isEmpty);

      scheduler.fireAll();
      expect(player.playedAssets, [
        'assets/audio/guitar/49.wav',
        'assets/audio/guitar/52.wav',
        'assets/audio/guitar/56.wav',
        'assets/audio/guitar/59.wav',
      ]);
    });

    test('stop() 清空队列并静音，未触发的音不再发声', () async {
      service.playChord(midis, mode: PlayMode.single);
      await service.stop();

      expect(player.stopCount, 1);
      expect(scheduler.scheduled.every((s) => s.isCanceled), isTrue);

      scheduler.fireAll();
      expect(player.playedAssets, isEmpty);
    });

    test('新的播放会取消上一组未触发的队列', () {
      service.playChord(midis, mode: PlayMode.single);
      final firstGroup = List<ScheduledTone>.of(scheduler.scheduled);

      service.playChord([40], mode: PlayMode.strum);
      expect(firstGroup.every((s) => s.isCanceled), isTrue);

      scheduler.fireAll();
      expect(player.playedAssets, ['assets/audio/guitar/40.wav']);
    });
  });

  group('和弦音区排列', () {
    test('Am7 = A2 C3 E3 G3 严格上行', () {
      expect(
        GuitarAudioService.voiceChord(rootPc: 9, pitchClasses: [9, 0, 4, 7]),
        [45, 48, 52, 55],
      );
    });

    test('C 大三 = C3 E3 G3（采样自 E2 起）且落在 40–76 范围内', () {
      final voiced =
          GuitarAudioService.voiceChord(rootPc: 0, pitchClasses: [0, 4, 7]);
      expect(voiced, [48, 52, 55]);
      expect(voiced.first, greaterThanOrEqualTo(40));
      expect(voiced.last, lessThanOrEqualTo(76));
    });
  });
}
