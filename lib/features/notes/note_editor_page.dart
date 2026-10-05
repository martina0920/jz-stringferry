import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'state/notes_store.dart';

/// 笔记编辑页：多行文本，保存即返回。
class NoteEditorPage extends StatefulWidget {
  final String? noteId;

  const NoteEditorPage({super.key, this.noteId});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final id = widget.noteId;
    if (id != null) {
      final store = context.read<NotesStore>();
      for (final n in store.items) {
        if (n.id == id) {
          _ctrl.text = n.content;
          break;
        }
      }
    }
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = widget.noteId;
    if (id == null) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      // 空笔记不保存，直接删除条目（新建后未写内容就退出的场景）。
      await context.read<NotesStore>().remove(id);
    } else {
      await context.read<NotesStore>().saveContent(id, text);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑笔记'),
        actions: [
          TextButton(
            key: const Key('note_save'),
            onPressed: _ready ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('note_content_field'),
            controller: _ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            autofocus: widget.noteId == null,
            style: const TextStyle(fontSize: 15, height: 1.6),
            decoration: const InputDecoration(
              hintText: '记点什么…\n\n练习心得、乐理随想、扒歌思路都可以',
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
