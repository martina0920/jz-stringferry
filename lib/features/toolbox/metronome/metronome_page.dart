import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/audio/metronome_engine.dart';
import 'state/metronome_store.dart';

/// 节拍器页：大播放钮 + BPM 滑杆 + tap tempo + 拍号/细分/重音。
///
/// store 由 main.dart 全局注入（播放状态离开页面后不中断）。
class MetronomePage extends StatelessWidget {
  const MetronomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MetronomeStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('节拍器')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 播放 + tap tempo 行。
            Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: FittedBox(
                    child: IconButton.filled(
                      key: const Key('metro_toggle'),
                      onPressed: store.togglePlay,
                      icon: Icon(
                        store.isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${store.bpm}',
                  key: const Key('metro_bpm_text'),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('BPM',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.inkSoft)),
              ],
            ),
            // 拍点指示灯。
            const SizedBox(height: 12),
            _BeatLampRow(
              beatsPerBar: store.beatsPerBar,
              accentBeats: store.accentBeats,
            ),
            const SizedBox(height: 12),
            // BPM 滑杆。
            Slider(
              key: const Key('metro_bpm_slider'),
              min: MetronomeStore.minBpm.toDouble(),
              max: MetronomeStore.maxBpm.toDouble(),
              divisions: MetronomeStore.maxBpm - MetronomeStore.minBpm,
              value: store.bpm.toDouble(),
              label: '${store.bpm}',
              onChanged: (v) => store.setBpm(v.round()),
            ),
            Row(
              children: [
                TextButton(
                  key: const Key('metro_tap'),
                  onPressed: () {
                    final hit = store.tap();
                    if (!hit) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('再点几次，按你心里的速度打拍子')),
                      );
                    }
                  },
                  child: const Text('TAP 打速度'),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('metro_bpm_down'),
                  onPressed: () => store.setBpm(store.bpm - 1),
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  key: const Key('metro_bpm_up'),
                  onPressed: () => store.setBpm(store.bpm + 1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 拍号。
            const _SectionLabel('拍号'),
            SegmentedButton<int>(
              key: const Key('metro_beats_segment'),
              segments: [
                for (final b in [2, 3, 4, 6])
                  ButtonSegment(value: b, label: Text('$b 拍')),
              ],
              selected: {store.beatsPerBar},
              onSelectionChanged: (s) => store.setBeatsPerBar(s.first),
            ),
            const SizedBox(height: 12),
            // 细分。
            const _SectionLabel('细分'),
            SegmentedButton<MetronomeSubdivision>(
              key: const Key('metro_sub_segment'),
              segments: [
                for (final s in MetronomeSubdivision.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {store.subdivision},
              onSelectionChanged: (s) => store.setSubdivision(s.first),
            ),
            const SizedBox(height: 12),
            // 重音拍。
            const _SectionLabel('重音拍（点击切换）'),
            Wrap(
              spacing: 8,
              children: [
                for (var b = 0; b < store.beatsPerBar; b++)
                  FilterChip(
                    key: Key('metro_accent_$b'),
                    label: Text('第 ${b + 1} 拍'),
                    selected: store.accentBeats.contains(b),
                    onSelected: (_) => store.toggleAccent(b),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatLampRow extends StatelessWidget {
  const _BeatLampRow({required this.beatsPerBar, required this.accentBeats});

  final int beatsPerBar;
  final Set<int> accentBeats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var b = 0; b < beatsPerBar; b++)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentBeats.contains(b) ? AppColors.gold : AppColors.mist,
              border: Border.all(color: AppColors.hairline),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
    );
  }
}
