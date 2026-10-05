import 'package:flutter/material.dart';

import '../../../core/audio/guitar_audio_service.dart';
import '../../../core/theme/app_theme.dart';

/// 试听按钮组：单音 / 琶音 / 扫弦 / 停止。
class ChordAuditionButtons extends StatelessWidget {
  final ValueChanged<PlayMode> onPlay;
  final VoidCallback onStop;

  const ChordAuditionButtons({
    super.key,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.hairline),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            button(Icons.circle_outlined, '单音', () => onPlay(PlayMode.single)),
            const SizedBox(width: 10),
            button(Icons.show_chart_rounded, '琶音', () => onPlay(PlayMode.arp)),
            const SizedBox(width: 10),
            button(
                Icons.graphic_eq_rounded, '扫弦', () => onPlay(PlayMode.strum)),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded, size: 18),
          label: const Text('停止'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkSoft,
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: AppColors.hairline),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
