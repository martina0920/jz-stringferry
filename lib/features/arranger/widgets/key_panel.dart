import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/key_harmony.dart';
import '../state/arranger_store.dart';

/// 编辑器调性区：大调/小调分段 + 12 调横向 chips（FR-3/FR-4）。
class KeyPanel extends StatelessWidget {
  const KeyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    final p = store.current!;
    final keys =
        p.keyMode == KeyMode.major ? MusicKey.allMajor : MusicKey.allMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('调性',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            SegmentedButton<KeyMode>(
              key: const Key('key_mode_segment'),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStateProperty.all(BorderSide.none),
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
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              segments: const [
                ButtonSegment(value: KeyMode.major, label: Text('大调')),
                ButtonSegment(value: KeyMode.minor, label: Text('小调')),
              ],
              selected: {p.keyMode},
              onSelectionChanged: (s) =>
                  store.changeKey(MusicKey(p.keyRootPc, s.first)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            key: const Key('key_chips_list'),
            scrollDirection: Axis.horizontal,
            itemCount: keys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final key = keys[i];
              final active = key.rootPc == p.keyRootPc;
              return ChoiceChip(
                key: Key('key_chip_${key.rootName}_${key.mode.name}'),
                label: Text(key.rootName),
                selected: active,
                onSelected: (_) => store.changeKey(key),
                selectedColor: AppColors.ink,
                backgroundColor: AppColors.mist,
                labelStyle: TextStyle(
                  color: active ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
            },
          ),
        ),
      ],
    );
  }
}
