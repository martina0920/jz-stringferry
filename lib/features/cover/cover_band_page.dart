import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 模块五：扒带助手
///
/// 首版骨架：本地导入 + 录音两个入口。
/// 后续接入：AI 识别调式/和弦、慢速分段、扒带笔记（已确认）。
class CoverBandPage extends StatelessWidget {
  const CoverBandPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扒带助手')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _EntryCard(
              icon: Icons.library_music_rounded,
              title: '导入本地音频',
              subtitle: '从手机里选一首歌开始扒带',
              onTap: () => _notify(context, '本地音频导入（接入后支持）'),
            ),
            const SizedBox(height: 12),
            _EntryCard(
              icon: Icons.mic_rounded,
              title: '录制一段音频',
              subtitle: '用麦克风录下想扒的片段',
              onTap: () => _notify(context, '麦克风录音（接入后支持）'),
            ),
            const SizedBox(height: 24),
            const Text(
              '扒带四步：听调性 → 定速度 → 分段落 → 记和弦',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  void _notify(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Icon(icon, color: AppColors.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
