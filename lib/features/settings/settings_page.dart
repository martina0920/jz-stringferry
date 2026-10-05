import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../data/chat_service.dart';
import '../../data/chord_seeder.dart';
import '../../data/plan_templates.dart';
import '../../data/settings_repository.dart';
import '../chord/state/chord_collection_store.dart';
import '../study/state/study_plan_store.dart';

/// 恢复流程进行中的进程内标志：防止确认弹窗被重复触发导致并发重置。
bool _restoring = false;

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
            const _SettingTile(
                icon: Icons.storage_rounded,
                title: '数据存储',
                subtitle: '纯本地存储，无需账号，不上传任何数据'),
            _SettingTile(
              icon: Icons.restore_rounded,
              title: '恢复示例数据',
              subtitle: '清空收藏/最近/计划与打卡，恢复内置和弦库与 2025 模板',
              onTap: () => _restoreSampleData(context),
            ),
            const Divider(),
            const _SectionTitle('云端识别'),
            _ApiKeyTile(
              icon: Icons.auto_awesome_rounded,
              title: '阿里百炼 API Key',
              onChanged: () => _toast(context, 'API Key 已保存'),
            ),
            const Divider(),
            const _SectionTitle('关于'),
            _SettingTile(
              icon: Icons.graphic_eq_rounded,
              title: '关于试听采样',
              subtitle: '吉他音色的来源与许可说明',
              onTap: () => _showSamplingInfo(context),
            ),
            const _SettingTile(
                icon: Icons.palette_rounded,
                title: 'J&Z 弦渡',
                subtitle: '一人一弦，合奏成曲'),
            _SettingTile(
              icon: Icons.info_outline_rounded,
              title: '版本',
              subtitle: 'v0.4.0 · 多音色·工具箱·扒带',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('J&Z 弦渡 v0.4.0 · 佳宇 & 泽华')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _restoreSampleData(BuildContext context) async {
    // 先取齐 context 依赖，避免 async gap 后再使用 BuildContext。
    final messenger = ScaffoldMessenger.of(context);
    final collectionStore = context.read<ChordCollectionStore?>();
    final studyStore = context.read<StudyPlanStore?>();
    final chatService = context.read<ChatService?>();
    final db = AppDatabase.instance.database;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复示例数据'),
        content: const Text(
            '将清空全部收藏、最近查询、学习计划与打卡记录，并重新写入内置 510 个和弦与 2025 示例计划。此操作不可撤销，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_restoring) return;
    _restoring = true;
    try {
      await AppDatabase.instance.resetUserData();
      await ChordSeeder.seedIfEmpty(db);
      await PlanTemplates.importIfEmpty(db);
      await collectionStore?.load();
      await studyStore?.load();
      if (chatService is LocalChatService) chatService.invalidateCaches();
      messenger.showSnackBar(const SnackBar(content: Text('已恢复示例数据')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    } finally {
      _restoring = false;
    }
  }

  void _showSamplingInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于试听采样'),
        content: const Text(
          '应用内 37 个吉他单音（MIDI 40–76，E2–E5）并非真人录音，'
          '而是由 Karplus-Strong 拨弦物理建模算法在开发机构建时离线合成生成'
          '（22050Hz / 16bit / 单声道，总计约 2MB，随安装包内置）。\n\n'
          '因此不存在任何第三方采样的版权或许可问题；音色与真实吉他存在差距，'
          '仅用于和弦组成音与排列的听辨参考。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
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
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft)),
    );
  }
}

/// 阿里百炼 API Key 设置项：显示掩码，点击弹窗编辑。
///
/// 仅存本地 settings 表（恢复示例数据不会清除），不上传任何数据。
class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({
    required this.icon,
    required this.title,
    required this.onChanged,
  });

  final IconData icon;
  final String title;

  /// 保存成功后的回调（页面提示用）。
  final VoidCallback onChanged;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  String? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = SettingsRepository(AppDatabase.instance.database);
    final v = await repo.get(SettingsRepository.dashscopeApiKey);
    if (mounted) setState(() => _current = v);
  }

  String get _masked {
    final v = _current;
    if (v == null || v.isEmpty) return '未设置';
    if (v.length <= 8) return '••••${v.substring(v.length - 2)}';
    return '${v.substring(0, 4)}••••${v.substring(v.length - 4)}';
  }

  Future<void> _edit() async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController(text: _current ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('阿里百炼 API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '用于扒带助手的云端识别（Qwen-Omni）。'
              'Key 仅保存在本机数据库，识别时随音频上传到百炼接口。',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('settings_api_key_field'),
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: '粘贴 sk- 开头的 Key'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              key: const Key('settings_api_key_save'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存')),
        ],
      ),
    );
    if (saved != true) return;
    final repo = SettingsRepository(AppDatabase.instance.database);
    final v = ctrl.text.trim();
    if (v.isEmpty) {
      await repo.remove(SettingsRepository.dashscopeApiKey);
    } else {
      await repo.set(SettingsRepository.dashscopeApiKey, v);
    }
    if (mounted) setState(() => _current = v.isEmpty ? null : v);
    widget.onChanged();
    messenger.hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(widget.icon, color: AppColors.ink),
      title: Text(widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('已保存：$_masked',
          style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
      onTap: _edit,
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.ink),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
      onTap: onTap,
    );
  }
}
