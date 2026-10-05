import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/progression.dart';
import '../../../core/theme/app_theme.dart';
import '../state/arranger_store.dart';

/// 底部播放控制条：播放/停止 + BPM + 拍号 + 伴奏型（FR-7/FR-8/FR-9）。
class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    final p = store.current!;
    final empty = p.chords.isEmpty;

    return Material(
      elevation: 8,
      color: AppColors.paper,
      shadowColor: const Color(0x22000000),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _PlayButton(
                    isPlaying: store.isPlaying,
                    disabled: empty,
                    onTap: () => store.isPlaying
                        ? store.stopPlay()
                        : store.playCurrent(),
                  ),
                  const SizedBox(width: 12),
                  // 鼓组伴奏轨开关（v0.5）。
                  IconButton(
                    key: const Key('playbar_drum_toggle'),
                    tooltip: '鼓组伴奏',
                    onPressed: empty ? null : () => store.toggleDrums(),
                    isSelected: p.drumTrack,
                    icon: const Icon(Icons.sports_basketball_rounded, size: 20),
                    color: AppColors.inkSoft,
                    selectedIcon: const Icon(Icons.sports_basketball_rounded,
                        size: 20, color: AppColors.gold),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text('${p.bpm} BPM',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Slider(
                      key: const Key('bpm_slider'),
                      min: 40,
                      max: 200,
                      divisions: 160,
                      value: p.bpm.toDouble(),
                      label: '${p.bpm}',
                      onChanged: empty
                          ? null
                          : (v) => context
                              .read<ArrangerStore>()
                              .setBpmLocal(v.round()),
                      onChangeEnd: empty
                          ? null
                          : (v) =>
                              store.setBpm(v.round()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<TimeSignature>(
                      key: const Key('timesig_segment'),
                      showSelectedIcon: false,
                      style: _segmentStyle(),
                      segments: const [
                        ButtonSegment(
                            value: TimeSignature.fourFour,
                            label: Text('4/4')),
                        ButtonSegment(
                            value: TimeSignature.threeFour,
                            label: Text('3/4')),
                      ],
                      selected: {p.timeSignature},
                      onSelectionChanged: empty
                          ? null
                          : (s) => store.setTimeSignature(s.first),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SegmentedButton<AccomPattern>(
                      key: const Key('pattern_segment'),
                      showSelectedIcon: false,
                      style: _segmentStyle(),
                      segments: const [
                        ButtonSegment(
                          value: AccomPattern.strum,
                          icon: Icon(Icons.bolt_rounded, size: 18),
                          tooltip: '柱式扫弦',
                        ),
                        ButtonSegment(
                          value: AccomPattern.slowStrum,
                          icon: Icon(Icons.trending_up_rounded, size: 18),
                          tooltip: '慢扫弦',
                        ),
                        ButtonSegment(
                          value: AccomPattern.finger,
                          icon: Icon(Icons.list_rounded, size: 18),
                          tooltip: '分解和弦',
                        ),
                      ],
                      selected: {p.pattern},
                      onSelectionChanged: empty
                          ? null
                          : (s) => store.setPattern(s.first),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _segmentStyle() => ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStateProperty.all(BorderSide.none),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.mist,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.inkSoft,
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool disabled;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FilledButton(
        key: const Key('play_toggle'),
        onPressed: disabled ? null : onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: AppColors.ink,
        ),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 28,
        ),
      ),
    );
  }
}
