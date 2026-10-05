import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/progression.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theory/key_harmony.dart';
import 'arranger_editor_page.dart';
import 'state/arranger_store.dart';
import 'widgets/new_progression_sheet.dart';
import 'widgets/progression_dialogs.dart';

/// 模块四：编曲工作台——进行库列表（多首持久化，FR-15）。
class ArrangerLibraryPage extends StatefulWidget {
  const ArrangerLibraryPage({super.key});

  @override
  State<ArrangerLibraryPage> createState() => _ArrangerLibraryPageState();
}

class _ArrangerLibraryPageState extends State<ArrangerLibraryPage> {
  Future<void> _openEditor() async {
    await context.push(ArrangerEditorPage.route);
    if (mounted) await context.read<ArrangerStore>().loadList();
  }

  Future<void> _createNew() async {
    final store = context.read<ArrangerStore>();
    final template = await showNewProgressionSheet(context);
    if (template == null) {
      await store.createBlank();
    } else {
      final defaultKey = template.mode == KeyMode.major
          ? const MusicKey(0, KeyMode.major)
          : const MusicKey(9, KeyMode.minor);
      await store.createFromTemplate(template, defaultKey);
    }
    if (mounted) await _openEditor();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('编曲工作台'),
        actions: [
          IconButton(
            key: const Key('new_progression'),
            tooltip: '新建进行',
            icon: const Icon(Icons.add_rounded),
            onPressed: _createNew,
          ),
        ],
      ),
      body: SafeArea(
        child: store.items.isEmpty
            ? _EmptyState(onCreate: _createNew)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: store.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ProgressionCard(
                  progression: store.items[i],
                  onOpen: () async {
                    await store.open(store.items[i].id);
                    if (mounted) await _openEditor();
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_rounded,
                size: 56, color: AppColors.gold.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            const Text('还没有编曲进行',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              '从 1645、卡农等常用模板开始，或空白自由编排',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('create_first'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建第一个进行'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressionCard extends StatelessWidget {
  final Progression progression;
  final VoidCallback onOpen;

  const _ProgressionCard({required this.progression, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final store = context.read<ArrangerStore>();
    final p = progression;
    return Card(
      key: Key('prog_card_${p.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      p.chords.isEmpty ? '（空序列）' : p.chords.join('  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${p.key.displayName} · ${p.bpm} BPM · ${p.timeSignature.label} · ${p.pattern.label} · ${_formatTime(p.updatedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('prog_menu_${p.id}'),
                onSelected: (v) => _onMenu(context, store, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'duplicate', child: Text('复制一份')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(
      BuildContext context, ArrangerStore store, String value) async {
    switch (value) {
      case 'rename':
        final name =
            await promptProgressionRename(context, progression.title);
        if (name != null) await store.rename(progression.id, name);
      case 'duplicate':
        await store.duplicate(progression.id);
      case 'delete':
        if (context.mounted &&
            await confirmProgressionDelete(context, progression.title)) {
          await store.remove(progression.id);
        }
    }
  }

  static String _formatTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.month}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
