import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// 首页：七大功能模块入口
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _modules = [
    _Module(
      icon: Icons.music_note_rounded,
      title: '和弦查询',
      subtitle: '一键查和弦·组成音·指法',
      route: AppRouter.chord,
    ),
    _Module(
      icon: Icons.event_note_rounded,
      title: '学习计划',
      subtitle: '安排与分析·打卡统计',
      route: AppRouter.study,
    ),
    _Module(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 助手',
      subtitle: '问答·扒带·编曲建议',
      route: AppRouter.ai,
    ),
    _Module(
      icon: Icons.grid_view_rounded,
      title: '编曲工作台',
      subtitle: '和弦进行·转调导出',
      route: AppRouter.arranger,
    ),
    _Module(
      icon: Icons.headphones_rounded,
      title: '扒带助手',
      subtitle: '音频导入·慢速分段',
      route: AppRouter.cover,
    ),
    _Module(
      icon: Icons.tune_rounded,
      title: '吉他工具箱',
      subtitle: '调音·节拍·音感训练',
      route: AppRouter.toolbox,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('J&Z 弦渡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRouter.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _BrandHeader(),
            const SizedBox(height: 24),
            ..._modules.map((m) => _ModuleCard(module: m)),
            const SizedBox(height: 12),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 1.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'J&Z',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '一人一弦，合奏成曲',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '从查一个和弦，到扒一首歌\n再到完成自己的编曲',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final _Module module;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(module.route),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        module.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          'J&Z 弦渡 · 佳宇 & 泽华',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
        ),
      ),
    );
  }
}

class _Module {
  const _Module({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
