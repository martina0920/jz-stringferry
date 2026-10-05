import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/practice_note.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'state/notes_store.dart';

/// 练习笔记列表：随手记心得，点条目进编辑页，FAB 新建。
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotesStore>().load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('练习笔记')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('notes_add'),
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建笔记'),
      ),
      body: !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : store.items.isEmpty
              ? const Center(
                  child: Text('还没有笔记\n练习心得、乐理随想都可以记在这里',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkSoft)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: store.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = store.items[i];
                    return _NoteCard(
                      key: Key('note_card_${n.id}'),
                      note: n,
                      onTap: () =>
                          context.push(AppRouter.noteEdit, extra: n.id),
                    );
                  },
                ),
    );
  }

  Future<void> _create() async {
    final store = context.read<NotesStore>();
    final note = await store.createBlank();
    if (!mounted) return;
    context.push(AppRouter.noteEdit, extra: note.id);
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({super.key, required this.note, required this.onTap});

  final PracticeNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.ink, height: 1.4)),
              const SizedBox(height: 6),
              Text(_fmtDate(note.updatedAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
