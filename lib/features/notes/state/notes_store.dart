import 'package:flutter/foundation.dart';

import '../../../../core/models/practice_note.dart';
import '../../../../data/note_repository.dart';

/// 练习笔记全局状态：列表 + 增删改。
class NotesStore extends ChangeNotifier {
  final NoteRepository repo;

  List<PracticeNote> _items = [];
  bool _loaded = false;

  NotesStore({required this.repo});

  List<PracticeNote> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return; // 首次加载后由增删改自行刷新，避免重复查询
    _items = await repo.list();
    _loaded = true;
    notifyListeners();
  }

  /// 新建空笔记并返回 id（供编辑页定位）。
  Future<PracticeNote> createBlank() async {
    final note = PracticeNote(
      id: PracticeNote.newId(),
      content: '',
      updatedAt: 0,
    );
    final saved = await repo.save(note);
    _items = await repo.list();
    _loaded = true;
    notifyListeners();
    return saved;
  }

  Future<void> saveContent(String id, String content) async {
    final cur = await repo.byId(id);
    final note = cur ??
        PracticeNote(id: id, content: '', updatedAt: 0);
    await repo.save(note.copyWith(content: content));
    _items = await repo.list();
    _loaded = true;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await repo.delete(id);
    _items = await repo.list();
    _loaded = true;
    notifyListeners();
  }
}
