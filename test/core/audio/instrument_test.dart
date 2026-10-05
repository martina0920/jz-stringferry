import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/guitar_audio_service.dart';
import 'package:jz_stringferry/core/audio/instrument.dart';
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

class _RecordingScheduler implements ToneScheduler {
  final List<ScheduledTone> scheduled = [];

  @override
  ScheduledTone schedule(Duration delay, VoidCallback callback) {
    final s = ScheduledTone(delay, callback);
    scheduled.add(s);
    return s;
  }

  void fireAll() {
    final snapshot = scheduled.where((s) => !s.isCanceled).toList();
    for (final s in snapshot) {
      s.callback();
    }
  }
}

void main() {
  group('Instrument 注册表', () {
    test('v0.4 内置 5 套旋律乐器，id 唯一，默认第一项为尼龙吉他', () {
      expect(melodicInstruments.length, 5);
      expect(melodicInstruments.map((i) => i.id).toSet().length, 5);
      expect(melodicInstruments.first.id, 'guitar');
    });

    test('各乐器采样数与音区宽一致（guitar/piano/eguitar 37，ep 36，bass 30）', () {
      final expected = {
        'guitar': 37,
        'piano': 37,
        'ep': 36,
        'eguitar': 37,
        'bass': 30,
      };
      for (final i in melodicInstruments) {
        expect(i.sampleCount, expected[i.id],
            reason: '${i.id} 采样数应为 ${expected[i.id]}');
        expect(i.highMidi - i.lowMidi + 1, i.sampleCount,
            reason: '${i.id} 音区宽应与采样数一致');
      }
    });

    test('音区定义：guitar 40–76 / piano 48–84 / ep 48–83 / eguitar 40–76 / bass 35–64', () {
      expect(guitarInstrument.lowMidi, 40);
      expect(guitarInstrument.highMidi, 76);
      expect(pianoInstrument.lowMidi, 48);
      expect(pianoInstrument.highMidi, 84);
      expect(epInstrument.lowMidi, 48);
      expect(epInstrument.highMidi, 83);
      expect(eGuitarInstrument.lowMidi, 40);
      expect(eGuitarInstrument.highMidi, 76);
      expect(bassInstrument.lowMidi, 35);
      expect(bassInstrument.highMidi, 64);
    });

    test('instrumentById：已知 id 命中，未知 id 回落尼龙吉他', () {
      expect(instrumentById('piano'), same(pianoInstrument));
      expect(instrumentById('bass'), same(bassInstrument));
      expect(instrumentById('nope'), same(guitarInstrument));
    });
  });

  group('assetFor 路径', () {
    test('按乐器目录拼接，旧 assetOf 保持 guitar 不变', () {
      expect(GuitarAudioService.assetFor(pianoInstrument, 60),
          'assets/audio/piano/60.wav');
      expect(GuitarAudioService.assetFor(bassInstrument, 36),
          'assets/audio/bass/36.wav');
      expect(GuitarAudioService.assetOf(60), 'assets/audio/guitar/60.wav');
    });
  });

  group('voiceChord 泛化锚定', () {
    test('吉他默认行为与 v0.3 完全一致（C 大三和弦 → 48/52/55）', () {
      final v = GuitarAudioService.voiceChord(
          rootPc: 0, pitchClasses: [0, 4, 7]);
      expect(v, [48, 52, 55]);
    });

    test('锚定 = 音区内第一个根音同名音（各乐器）', () {
      int anchorOf(Instrument i, int rootPc) =>
          i.lowMidi + (((rootPc - i.lowMidi) % 12) + 12) % 12;
      // C（rootPc=0）
      expect(anchorOf(pianoInstrument, 0), 48);
      expect(anchorOf(bassInstrument, 0), 36);
      expect(anchorOf(eGuitarInstrument, 0), 48);
      final bassC = GuitarAudioService.voiceChord(
          rootPc: 0, pitchClasses: [0, 4, 7], instrument: bassInstrument);
      expect(bassC.first, 36);
    });

    test('严格上行且全部落在乐器音区内（全乐器 × 多组和弦）', () {
      final chords = [
        (0, [0, 4, 7]), // C
        (9, [9, 0, 4]), // Am
        (11, [11, 3, 6, 9]), // B7
        (2, [2, 6, 9, 1]), // Dm7 转位味
        (5, [5, 9, 0, 3, 7]), // Fmaj9 味
      ];
      for (final i in melodicInstruments) {
        for (final (root, pcs) in chords) {
          final v = GuitarAudioService.voiceChord(
              rootPc: root, pitchClasses: pcs, instrument: i);
          expect(v.first, greaterThanOrEqualTo(i.lowMidi),
              reason: '${i.id}/root$root 低音越界');
          for (var k = 0; k < v.length; k++) {
            expect(v[k], lessThanOrEqualTo(i.highMidi),
                reason: '${i.id}/root$root 第$k音越界');
            if (k > 0) expect(v[k], greaterThan(v[k - 1]), reason: '应严格上行');
          }
        }
      }
    });
  });

  group('voiceGuitarStrings 音区参数', () {
    test('默认与 v0.3 一致（C 和弦首音 = 锚定音）', () {
      final v = StrumPatterns.voiceGuitarStrings(
          rootPc: 0, pitchClasses: [0, 4, 7]);
      expect(v.first, 48);
      expect(v.length, 5);
      for (var k = 1; k < v.length; k++) {
        expect(v[k], greaterThan(v[k - 1]));
      }
    });

    test('bass 音区：首音 = 35 起的第一个根音同名音，5 音均在 35–64', () {
      final v = StrumPatterns.voiceGuitarStrings(
          rootPc: 9,
          pitchClasses: [9, 0, 4],
          lowMidi: bassInstrument.lowMidi,
          highMidi: bassInstrument.highMidi);
      expect(
          v.first,
          bassInstrument.lowMidi +
              (((9 - bassInstrument.lowMidi) % 12) + 12) % 12);
      for (final m in v) {
        expect(m, inInclusiveRange(35, 64));
      }
    });
  });

  group('ProgressionPlayer 音色透传', () {
    test('play 指定 piano 时按 piano 目录发声，默认仍 guitar', () {
      final player = _FakePlayer();
      final scheduler = _RecordingScheduler();
      final p = ProgressionPlayer(player, scheduler: scheduler);
      final strings = StrumPatterns.voiceGuitarStrings(
          rootPc: 0,
          pitchClasses: [0, 4, 7],
          lowMidi: pianoInstrument.lowMidi,
          highMidi: pianoInstrument.highMidi);
      final schedule = StrumPatterns.buildProgressionSchedule(
        stringVoicings: [strings],
        bpm: 90,
        pattern: AccomPattern.strum,
        timeSignature: TimeSignature.fourFour,
      );

      p.play(schedule, instrument: pianoInstrument);
      scheduler.fireAll();
      expect(player.playedAssets, isNotEmpty);
      for (final a in player.playedAssets) {
        expect(a.startsWith('assets/audio/piano/'), isTrue, reason: a);
      }

      final gPlayer = _FakePlayer();
      final gScheduler = _RecordingScheduler();
      ProgressionPlayer(gPlayer, scheduler: gScheduler)
          .play(schedule);
      gScheduler.fireAll();
      expect(gPlayer.playedAssets, isNotEmpty);
      for (final a in gPlayer.playedAssets) {
        expect(a.startsWith('assets/audio/guitar/'), isTrue, reason: a);
      }
    });
  });
}
