import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// 模块六：吉他工具箱
///
/// 调音器 / 节拍器 / 音感训练 / 指板学习四个磁贴。
class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('吉他工具箱')),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(20),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _ToolTile(
              icon: Icons.graphic_eq_rounded,
              title: '调音器',
              subtitle: '麦克风自动调音',
              onTap: () => context.push(AppRouter.toolboxTuner),
            ),
            _ToolTile(
              icon: Icons.timer_rounded,
              title: '节拍器',
              subtitle: '多拍号与节奏型',
              onTap: () => context.push(AppRouter.toolboxMetronome),
            ),
            _ToolTile(
              icon: Icons.hearing_rounded,
              title: '音感训练',
              subtitle: '单音·音程·和弦',
              onTap: () => context.push(AppRouter.toolboxEar),
            ),
            _ToolTile(
              icon: Icons.grid_4x4_rounded,
              title: '指板学习',
              subtitle: '音名与音阶',
              onTap: () => context.push(AppRouter.toolboxFretboard),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.ink, size: 28),
              const Spacer(),
              Text(title,
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
