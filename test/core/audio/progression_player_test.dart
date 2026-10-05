import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/progression_player.dart';
import 'package:jz_stringferry/core/audio/strum_patterns.dart';
import 'package:jz_stringferry/core/models/progression.dart';

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

/// 记录延迟但不真正计时；测试按「时长快照」手动 fire，
/// 快照在触发前固定，循环重排新加入的事件不会被本轮遍历到。
class _RecordingScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];
  final Set<ScheduledTone> _fired = {};

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }

  void fireUpTo(Duration maxDelay) {
    final snapshot = scheduled
        .where((s) =>
            !s.isCanceled && !_fired.contains(s) && s.delay <= maxDelay)
        .toList();
    for (final s in snapshot) {
      _fired.add(s);
      if (!s.isCanceled) s.callback();
    }
  }
}

void main() {
  final cStrings =
      StrumPatterns.voiceGuitarStrings(rootPc: 0, pitchClasses: [0, 4, 7]);
  final amStrings =
      StrumPatterns.voiceGuitarStrings(rootPc: 9, pitchClasses: [9, 0, 4]);

  ProgressionSchedule twoChordSchedule({int bpm = 90}) =>
      StrumPatterns.buildProgressionSchedule(
        stringVoicings: [cStrings, amStrings],
        bpm: bpm,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
      );

  group('ProgressionPlayer（FR-9，AC-5）', () {
    late _FakePlayer player;
    late _RecordingScheduler scheduler;
    late ProgressionPlayer p;

    setUp(() {
      player = _FakePlayer();
      scheduler = _RecordingScheduler();
      p = ProgressionPlayer(player, scheduler: scheduler);
    });

    test('播放一遍：8 拍点 × 5 弦 = 40 次发声，高亮 0→1', () {
      final highlights = <int>[];
      p.play(twoChordSchedule(), onChord: highlights.add);
      expect(p.isPlaying, isTrue);

      scheduler.fireUpTo(const Duration(milliseconds: 5333));

      expect(player.playedAssets.length, 40);
      expect(highlights, [0, 1]);
      // 最低音弦 C3 / A2 都在齐奏中出现。
      expect(player.playedAssets.contains('assets/audio/guitar/48.wav'), isTrue);
      expect(player.playedAssets.contains('assets/audio/guitar/45.wav'), isTrue);
    });

    test('循环：再 fire 一遍后发声翻倍、高亮回到 0（FR-9）', () {
      final highlights = <int>[];
      p.play(twoChordSchedule(), onChord: highlights.add);

      scheduler.fireUpTo(const Duration(milliseconds: 5333));
      expect(player.playedAssets.length, 40);

      scheduler.fireUpTo(const Duration(milliseconds: 5333));
      expect(player.playedAssets.length, 80);
      expect(highlights, [0, 1, 0, 1]);
      expect(p.isPlaying, isTrue);
    });

    test('stop：未触发事件全部作废并静音（FR-9）', () async {
      p.play(twoChordSchedule());
      await p.stop();
      expect(p.isPlaying, isFalse);
      expect(player.stopCount, greaterThanOrEqualTo(1));

      scheduler.fireUpTo(const Duration(milliseconds: 100000));
      expect(player.playedAssets, isEmpty);
    });

    test('重复 play：旧序列事件作废，只响新序列', () {
      p.play(twoChordSchedule());
      // 立刻换新序列重播。
      p.play(twoChordSchedule(bpm: 120));

      scheduler.fireUpTo(const Duration(milliseconds: 100000));
      // 只可能有第二序列的两遍以内发声；断言没有任何旧 delay 残留触发：
      // 已 canceled 的旧句柄数 = 第一序列 11 个（8 发声 + 2 高亮 + 1 循环）。
      final canceledOld =
          scheduler.scheduled.where((s) => s.isCanceled).length;
      expect(canceledOld, 11);
      // 新序列每遍 40 音，全部发声。
      expect(player.playedAssets.length, 40);
    });

    test('空序列 play 无效', () {
      p.play(StrumPatterns.buildProgressionSchedule(
        stringVoicings: const [],
        bpm: 90,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
      ));
      expect(p.isPlaying, isFalse);
      expect(scheduler.scheduled, isEmpty);
    });
  });
}
