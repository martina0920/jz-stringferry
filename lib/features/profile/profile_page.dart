import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// 「我的」页：品牌卡 + 设置 / AI 助手 / 关于。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const _BrandCard(),
          const SizedBox(height: 20),
          _MenuTile(
            key: const Key('profile_settings'),
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '云端识别 API Key · 数据管理',
            onTap: () => context.push(AppRouter.settings),
          ),
          _MenuTile(
            key: const Key('profile_ai'),
            icon: Icons.auto_awesome_rounded,
            title: 'AI 助手',
            subtitle: '查和弦 · 讲进行 · 离线规则问答',
            onTap: () => context.push(AppRouter.ai),
          ),
          _MenuTile(
            key: const Key('profile_about'),
            icon: Icons.info_outline_rounded,
            title: '关于',
            subtitle: '版本与制作团队',
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'J&Z 弦渡',
      applicationVersion: 'v0.5.0',
      applicationLegalese: '佳宇 & 泽华 出品 · 一人一弦，合奏成曲',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('J&Z',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
      ),
    );
  }
}

/// 品牌卡（承接首页被砍头图的品牌感，小尺寸）。
class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 1.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('J&Z',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('J&Z 弦渡',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              SizedBox(height: 2),
              Text('一人一弦，合奏成曲',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.ink),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
