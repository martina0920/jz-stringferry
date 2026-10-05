import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/audio/pitch_detector.dart';
import '../../../../core/theme/app_theme.dart';
import 'state/tuner_store.dart';

/// 调音器页：选弦 → 听音 → 指针/音分偏差。
///
/// 麦克风不可用时降级为「参考音模式」：播放标准音人工比对。
class TunerPage extends StatelessWidget {
  const TunerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TunerStore>();
    final string = store.string;
    final cents = store.cents;

    return Scaffold(
      appBar: AppBar(title: const Text('调音器')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 弦选择。
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < TunerTargets.strings.length; i++)
                  ChoiceChip(
                    key: Key('tuner_string_$i'),
                    label: Text(TunerTargets.strings[i].$2),
                    selected: store.stringIndex == i,
                    onSelected: (_) => store.selectString(i),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // 音名读数。
            Center(
              child: Column(
                children: [
                  Text(
                    store.listening && store.latest.hasPitch
                        ? _noteName(string.$3)
                        : '--',
                    key: const Key('tuner_note_text'),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: store.settledInTune ? AppColors.gold : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '目标 ${string.$2} · ${TunerTargets.freqOf(string.$3).toStringAsFixed(1)} Hz',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 指针。
            _GaugeBar(
              key: const Key('tuner_gauge'),
              value: store.gauge,
              inTune: store.inTune,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                cents == null
                    ? (store.listening ? '请拨响 ${string.$2}' : '未在监听')
                    : '${cents > 0 ? '+' : ''}${cents.toStringAsFixed(1)} 音分'
                        '${cents > 5 ? ' · 偏高，松一点' : cents < -5 ? ' · 偏低，紧一点' : ' · 准了'}',
                key: const Key('tuner_cents_text'),
                style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(height: 24),
            // 监听开关。
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('tuner_toggle'),
                    onPressed: store.toggleListen,
                    icon: Icon(store.listening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded),
                    label: Text(store.listening ? '停止监听' : '开始调音'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('tuner_ref'),
                    onPressed: store.playReference,
                    icon: const Icon(Icons.music_note_rounded),
                    label: const Text('播放参考音'),
                  ),
                ),
              ],
            ),
            if (store.micDenied) ...[
              const SizedBox(height: 16),
              const Text(
                '无法访问麦克风：请检查系统权限设置，或改用「播放参考音」靠耳朵比对。',
                key: Key('tuner_denied_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '拨响一根空弦，指针偏左偏低（拧紧）、偏右偏高（放松），'
              '指针居中且变金色即为调准。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  String _noteName(int midi) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    return '${names[midi % 12]}${midi ~/ 12 - 1}';
  }
}

/// 音分指针：中央刻度 + 滑动标记（-1..1）。
class _GaugeBar extends StatelessWidget {
  const _GaugeBar({super.key, required this.value, required this.inTune});

  final double value;
  final bool inTune;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 轨道。
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.hairline),
            ),
          ),
          // 中央刻度。
          Container(width: 2, height: 24, color: AppColors.inkSoft),
          // 标记。
          AnimatedAlign(
            duration: const Duration(milliseconds: 80),
            alignment: Alignment(value.clamp(-1.0, 1.0), 0),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: inTune ? AppColors.gold : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
