import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 设置页：数据与关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _SectionTitle('数据'),
            const _SettingTile(icon: Icons.storage_rounded, title: '数据存储', subtitle: '纯本地存储，无需账号'),
            const _SettingTile(icon: Icons.restore_rounded, title: '恢复示例数据', subtitle: '重置内置计划与和弦库'),
            const Divider(),
            const _SectionTitle('关于'),
            const _SettingTile(icon: Icons.palette_rounded, title: 'J&Z 弦渡', subtitle: '一人一弦，合奏成曲'),
            _SettingTile(
              icon: Icons.info_outline_rounded,
              title: '版本',
              subtitle: 'v0.1.0 · 骨架版',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('J&Z 弦渡 v0.1.0 · 佳宇 & 泽华')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.ink),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
      onTap: onTap,
    );
  }
}
