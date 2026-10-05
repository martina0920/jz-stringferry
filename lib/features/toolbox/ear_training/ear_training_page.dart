import 'package:flutter/material.dart' hide Interval;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/ear_training.dart';
import 'state/ear_training_store.dart';

/// 音感训练页：模式切换 → 出题播放 → 选项答题 → 即时判定。
class EarTrainingPage extends StatelessWidget {
  const EarTrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EarTrainingStore>();
    final q = store.question;
    final last = store.lastCorrect;

    return Scaffold(
      appBar: AppBar(title: const Text('音感训练')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SegmentedButton<EarMode>(
              key: const Key('ear_mode_segment'),
              segments: [
                for (final m in EarMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {store.mode},
              onSelectionChanged: (s) => store.setMode(s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '本轮 ${store.correct}/${store.total}',
                  key: const Key('ear_score'),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.inkSoft),
                ),
                const Spacer(),
                if (last != null)
                  Text(
                    last ? '答对了！' : '不对，再听听',
                    key: Key('ear_result_${last ? 'ok' : 'bad'}'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: last ? AppColors.gold : AppColors.danger,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.tonal(
                key: const Key('ear_next'),
                onPressed: store.nextQuestion,
                child: Text(q == null ? '开始出题' : '下一题'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                key: const Key('ear_replay'),
                onPressed: q == null ? null : store.playQuestion,
                child: const Text('再播一遍'),
              ),
            ),
            const SizedBox(height: 16),
            if (q != null) ...[
              _AnswerGrid(store: store, question: q),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({required this.store, required this.question});

  final EarTrainingStore store;
  final EarQuestion question;

  @override
  Widget build(BuildContext context) {
    final answered = store.lastCorrect != null;
    return switch (question.mode) {
      EarMode.singleNote => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var midi = question.rootMidi - 2;
                midi <= question.rootMidi + 2;
                midi++)
              ActionChip(
                key: Key('ear_ans_$midi'),
                label: Text(_noteName(midi)),
                onPressed:
                    answered ? null : () => store.submit(midi),
              ),
          ],
        ),
      EarMode.interval => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final iv in Interval.values)
              ActionChip(
                key: Key('ear_ans_${iv.semitones}'),
                label: Text(iv.label),
                onPressed: answered ? null : () => store.submit(iv),
              ),
          ],
        ),
      EarMode.chordQuality => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ChordQualityQuiz.values)
              ActionChip(
                key: Key('ear_ans_${c.suffix}'),
                label: Text(c.label),
                onPressed: answered ? null : () => store.submit(c),
              ),
          ],
        ),
      EarMode.scale => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ScaleQuiz.values)
              ActionChip(
                key: Key('ear_ans_${s.name}'),
                label: Text(s.label),
                onPressed: answered ? null : () => store.submit(s),
              ),
          ],
        ),
      EarMode.rhythm => const _RhythmAnswer(),
    };
  }
}

class _RhythmAnswer extends StatefulWidget {
  const _RhythmAnswer();

  @override
  State<_RhythmAnswer> createState() => _RhythmAnswerState();
}

class _RhythmAnswerState extends State<_RhythmAnswer> {
  final List<bool> _grid = List<bool>.filled(8, false);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EarTrainingStore>();
    final answered = store.lastCorrect != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('凭记忆点出你听到的节奏格：',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < 8; i++)
              FilterChip(
                key: Key('ear_grid_$i'),
                label: Text('${i + 1}'),
                selected: _grid[i],
                onSelected: answered
                    ? null
                    : (_) => setState(() => _grid[i] = !_grid[i]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('ear_rhythm_submit'),
          onPressed: answered ? null : () => store.submit(_grid),
          child: const Text('提交节奏'),
        ),
      ],
    );
  }
}

const List<String> _noteNames = [
  'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B',
];

String _noteName(int midi) => _noteNames[midi % 12];
