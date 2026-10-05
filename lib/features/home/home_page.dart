import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// 首页：品牌头图 + 六大功能模块入口（2 列磁贴）
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
      subtitle: '查和弦·讲进行·离线汇总',
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
            const SizedBox(height: 20),
            // 两列一组排布磁贴；IntrinsicHeight 让同组两块等高。
            for (var i = 0; i < _modules.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ModuleTile(module: _modules[i])),
                      const SizedBox(width: 12),
                      Expanded(child: _ModuleTile(module: _modules[i + 1])),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const _Footer(),
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 1.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'J&Z',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '一人一弦，合奏成曲',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '从查一个和弦，到扒一首歌\n再到完成自己的编曲',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能磁贴：浅灰底、炭黑图标块，无描边无箭头。
class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final _Module module;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(module.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 12),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                module.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

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
