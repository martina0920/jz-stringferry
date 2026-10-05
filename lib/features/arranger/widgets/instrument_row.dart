import 'package:flutter/material.dart';

import '../../../core/audio/guitar_audio_service.dart';
import '../../../core/audio/instrument.dart';
import '../../../core/theme/app_theme.dart';

/// 音色选择行（v0.5）：横向 ChoiceChip，选中即试听一声中音采样。
class InstrumentRow extends StatelessWidget {
  const InstrumentRow({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.previewPlayer,
  });

  final String selectedId;
  final ValueChanged<Instrument> onSelect;

  /// 选中时试听一声（可空：纯切选不发声）。
  final TonePlayer? previewPlayer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: melodicInstruments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final inst = melodicInstruments[i];
          final selected = inst.id == selectedId;
          return ChoiceChip(
            key: Key('instrument_chip_${inst.id}'),
            label: Text(inst.label),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.ink,
            ),
            selectedColor: AppColors.ink,
            backgroundColor: AppColors.mist,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            onSelected: (_) {
              onSelect(inst);
              // 试听中音区中央一声。
              final mid = (inst.lowMidi + inst.highMidi) ~/ 2;
              previewPlayer?.playAsset(GuitarAudioService.assetFor(inst, mid));
            },
          );
        },
      ),
    );
  }
}
