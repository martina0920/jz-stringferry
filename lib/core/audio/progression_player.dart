import 'dart:async';

import 'guitar_audio_service.dart';
import 'instrument.dart';
import 'strum_patterns.dart';

/// 和弦高亮回调：参数为当前小节（和弦）序号。
typedef ChordHighlightCallback = void Function(int chordIndex);

/// 编曲进行播放器：把 [ProgressionSchedule] 一遍遍地循环调度，
/// 支持按小节高亮回调与立即停止。
///
/// 所有时序都走 [ToneScheduler]（生产为 Timer，测试可注入记录式假调度器）。
class ProgressionPlayer {
  final TonePlayer player;
  final ToneScheduler scheduler;

  final List<ScheduledTone> _pending = [];
  int _generation = 0;
  bool _playing = false;

  ProgressionPlayer(
    this.player, {
    this.scheduler = const TimerToneScheduler(),
  });

  bool get isPlaying => _playing;

  /// 开始循环播放（重复调用会先无声清掉上一段排程）。
  void play(
    ProgressionSchedule schedule, {
    ChordHighlightCallback? onChord,
    Instrument instrument = guitarInstrument,
  }) {
    if (schedule.notes.isEmpty) return;
    _cancelPending();
    _playing = true;
    final gen = ++_generation;
    unawaited(player.stopAll());
    _schedulePass(schedule, gen, onChord, instrument);
  }

  void _schedulePass(
    ProgressionSchedule schedule,
    int gen,
    ChordHighlightCallback? onChord,
    Instrument instrument,
  ) {
    // 能进到本回调说明上一遍所有事件都已触发，旧句柄可整体丢弃。
    _pending.clear();

    var highlighted = -1;
    for (final note in schedule.notes) {
      if (note.chordIndex != highlighted) {
        highlighted = note.chordIndex;
        _pending.add(scheduler.schedule(
          Duration(milliseconds: note.timeMs),
          () {
            if (gen == _generation) onChord?.call(note.chordIndex);
          },
        ));
      }
      _pending.add(scheduler.schedule(
        Duration(milliseconds: note.timeMs),
        () {
          if (gen != _generation) return;
          // 鼓组采样走固定路径，其余按当前音色取 MIDI 采样（v0.5）。
          if (note.drumKind != null) {
            player.playAsset(note.drumKind!.assetPath);
            return;
          }
          for (final midi in note.midis) {
            player.playAsset(GuitarAudioService.assetFor(instrument, midi));
          }
        },
      ));
    }

    // 一遍结束 → 下一遍。
    _pending.add(scheduler.schedule(
      Duration(milliseconds: schedule.totalMs),
      () {
        if (gen == _generation) {
          _schedulePass(schedule, gen, onChord, instrument);
        }
      },
    ));
  }

  /// 停止：作废当前代、取消全部待播、立即静音。
  Future<void> stop() async {
    _cancelPending();
    await player.stopAll();
  }

  void _cancelPending() {
    _generation++;
    _playing = false;
    for (final s in _pending) {
      s.cancel();
    }
    _pending.clear();
  }
}

/// 供 widget/状态层描述「当前无高亮」。
const int noChordHighlight = -1;
