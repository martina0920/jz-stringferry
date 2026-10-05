import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/audio/guitar_audio_service.dart';
import '../../../../core/theory/ear_training.dart';
import '../../../../data/ear_training_repository.dart';

/// 音感训练会话状态：出题 → 播放 → 答题 → 判定 → 统计入库。
class EarTrainingStore extends ChangeNotifier {
  final EarQuizGenerator generator;
  final GuitarAudioService audio;
  final EarTrainingRepository? statsRepo;

  EarMode _mode = EarMode.singleNote;
  EarQuestion? _question;

  /// 本会话累计。
  int correct = 0;
  int total = 0;

  /// 最后一题是否答对（null = 刚出题未答）。
  bool? _lastCorrect;

  bool _playing = false;

  EarTrainingStore({
    required this.generator,
    required this.audio,
    this.statsRepo,
  });

  EarMode get mode => _mode;
  EarQuestion? get question => _question;
  bool? get lastCorrect => _lastCorrect;
  bool get playing => _playing;

  void setMode(EarMode m) {
    if (m == _mode) return;
    _mode = m;
    _question = null;
    _lastCorrect = null;
    notifyListeners();
  }

  /// 出一道新题并立即播放。
  void nextQuestion() {
    _question = generator.next(_mode);
    _lastCorrect = null;
    notifyListeners();
    playQuestion();
  }

  /// 播放当前题。
  void playQuestion() {
    final q = _question;
    if (q == null) return;
    _playing = true;
    notifyListeners();

    final midis = <(int, int)>[]; // (midi, delayMs)
    switch (q.mode) {
      case EarMode.singleNote:
        midis.add((q.rootMidi, 0));
      case EarMode.interval:
        midis.add((q.rootMidi, 0));
        midis.add((q.secondMidi!, 420));
      case EarMode.chordQuality:
        for (final off in (q.answer as ChordQualityQuiz).pcs) {
          midis.add((q.rootMidi + off, 0));
        }
      case EarMode.scale:
        final pcs = (q.answer as ScaleQuiz).pcs;
        for (var i = 0; i < pcs.length; i++) {
          midis.add((q.rootMidi + pcs[i], i * 260));
        }
        midis.add((q.rootMidi + 12, pcs.length * 260));
      case EarMode.rhythm:
        // 网格用 hat 之外的单音（固定 A3 敲点音不可用——统一用吉他高音弦）。
        for (var i = 0; i < q.rhythmGrid.length; i++) {
          if (q.rhythmGrid[i]) midis.add((67, i * q.cellMs));
        }
    }
    for (final (midi, delayMs) in midis) {
      unawaited(Future.delayed(
        Duration(milliseconds: delayMs),
        () => audio.playChord([midi], mode: PlayMode.single),
      ));
    }
    unawaited(Future.delayed(
      Duration(milliseconds: _playoutMs(midis)),
      () {
        _playing = false;
        notifyListeners();
      },
    ));
  }

  int _playoutMs(List<(int, int)> midis) {
    if (midis.isEmpty) return 0;
    final lastDelay = midis.last.$2;
    return lastDelay + 600;
  }

  /// 通用提交：判定 → 计数 → 入库 → 通知。
  Future<void> submit(Object answer) async {
    final q = _question;
    if (q == null || _lastCorrect != null) return;
    final ok = switch (q.mode) {
      EarMode.singleNote => EarJudge.singleNote(q, answer as int),
      EarMode.interval => EarJudge.interval(q, answer as Interval),
      EarMode.chordQuality =>
        EarJudge.chordQuality(q, answer as ChordQualityQuiz),
      EarMode.scale => EarJudge.scale(q, answer as ScaleQuiz),
      EarMode.rhythm => EarJudge.rhythm(q, answer as List<bool>),
    };
    _lastCorrect = ok;
    total++;
    if (ok) correct++;
    notifyListeners();

    final repo = statsRepo;
    if (repo != null) {
      await repo.record(
        date: DateTime.now().toIso8601String().substring(0, 10),
        mode: q.mode.id,
        correct: ok,
      );
    }
  }
}
