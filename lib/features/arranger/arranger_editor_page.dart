import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'state/arranger_store.dart';
import 'widgets/chord_sequence.dart';
import 'widgets/key_panel.dart';
import 'widgets/play_bar.dart';
import 'widgets/progression_dialogs.dart';
import 'widgets/share_progression_sheet.dart';
import 'widgets/template_strip.dart';

/// 编曲编辑器：调性 / 和弦序列 / 模板 / 播放控制。
class ArrangerEditorPage extends StatefulWidget {
  static const String route = '/arranger/edit';

  const ArrangerEditorPage({super.key});

  @override
  State<ArrangerEditorPage> createState() => _ArrangerEditorPageState();
}

class _ArrangerEditorPageState extends State<ArrangerEditorPage> {
  ArrangerStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose 阶段不能再查 Provider 祖先，提前缓存引用。
    _store ??= context.read<ArrangerStore>();
  }

  @override
  void dispose() {
    // 离开编辑器即停止播放（FR-9）。
    _store?.stopPlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    final p = store.current;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编曲工作台')),
        body: const Center(
          child: Text('进行不存在或已删除',
              style: TextStyle(color: AppColors.inkSoft)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          key: const Key('editor_title'),
          onTap: () => _rename(store),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(p.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_rounded, size: 14, color: AppColors.inkSoft),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(v, store),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'duplicate', child: Text('复制一份')),
              if (p.chords.isNotEmpty)
                const PopupMenuItem(value: 'share', child: Text('分享导出')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const KeyPanel(),
            const SizedBox(height: 20),
            const Text('和弦序列',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            const ChordSequence(),
            if (p.chords.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('加一个和弦，或套用下方模板',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ),
            const SizedBox(height: 20),
            const Text('套用模板（将替换序列）',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            const TemplateStrip(),
          ],
        ),
      ),
      bottomNavigationBar: const PlayBar(),
    );
  }

  Future<void> _rename(ArrangerStore store) async {
    final name =
        await promptProgressionRename(context, store.current!.title);
    if (name != null) await store.setTitle(name);
  }

  Future<void> _onMenu(String value, ArrangerStore store) async {
    final id = store.current!.id;
    switch (value) {
      case 'duplicate':
        await store.duplicate(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已复制到曲库')),
          );
        }
      case 'share':
        if (context.mounted) {
          await showShareProgressionSheet(context, store);
        }
      case 'delete':
        final title = store.current!.title;
        if (await confirmProgressionDelete(context, title)) {
          await store.remove(id);
          if (mounted) context.pop();
        }
    }
  }
}
