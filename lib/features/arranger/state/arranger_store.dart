import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/progression_player.dart';
import '../../../core/audio/strum_patterns.dart';
import '../../../core/models/progression.dart';
import '../../../core/theory/chord_builder.dart';
import '../../../core/theory/key_harmony.dart';
import '../../../core/theory/note.dart';
import '../../../core/theory/progression_template.dart';
import '../../../data/chord_repository.dart';
import '../../../data/progression_repository.dart';

/// 编曲工作台全局状态：曲库 + 当前编辑对象 + 播放态。
///
/// 编辑操作立即落库（离开页面不丢数据）；播放中任何编辑都会自动停止（FR-17）。
class ArrangerStore extends ChangeNotifier {
  final ProgressionRepository repo;
  final ChordRepository chordRepo;
  final ProgressionPlayer player;

  /// 序列长度上限（FR-10）。
  static const int maxChords = 32;

  List<Progression> _items = [];
  Progression? _current;
  bool _isPlaying = false;
  int _highlightIndex = noChordHighlight;

  ArrangerStore({
    required this.repo,
    required this.chordRepo,
    required this.player,
  });

  List<Progression> get items => List.unmodifiable(_items);
  Progression? get current => _current;
  bool get isPlaying => _isPlaying;
  int get highlightIndex => _highlightIndex;

  bool get canPlay =>
      _current != null && _current!.chords.isNotEmpty && !_isPlaying;

  // ---------- 曲库 ----------

  Future<void> loadList() async {
    _items = await repo.list();
    notifyListeners();
  }

  Future<void> open(String id) async {
    await stopPlay();
    _current = await repo.byId(id);
    notifyListeners();
  }

  /// 只在内存中准备一个空白草稿（首次保存才入库），供编辑器直接进入。
  Progression draftBlank({MusicKey key = const MusicKey(0, KeyMode.major)}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Progression(
      id: ProgressionIds.newId(),
      title: '未命名进行',
      keyRootPc: key.rootPc,
      keyMode: key.mode,
      chords: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 以空白草稿进入编辑器（首次编辑时才落库，避免返回即留空记录）。
  Future<Progression> createBlank({
    MusicKey key = const MusicKey(0, KeyMode.major),
  }) async {
    await stopPlay();
    final p = draftBlank(key: key);
    _current = p;
    notifyListeners();
    return p;
  }

  /// 从模板新建（FR-6）。
  Future<Progression> createFromTemplate(
    ProgressionTemplate template,
    MusicKey key,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Progression(
      id: ProgressionIds.newId(),
      title: template.name,
      keyRootPc: key.rootPc,
      keyMode: key.mode,
      chords: template.instantiate(key),
      createdAt: now,
      updatedAt: now,
    );
    await repo.insert(p);
    _current = p;
    await loadList();
    return p;
  }

  /// AI「发送到编曲台」：按给定调与序列直接落库（FR-21）。
  Future<Progression> createFromChords({
    required String title,
    required MusicKey key,
    required List<String> chords,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Progression(
      id: ProgressionIds.newId(),
      title: title,
      keyRootPc: key.rootPc,
      keyMode: key.mode,
      chords: chords.take(maxChords).toList(),
      createdAt: now,
      updatedAt: now,
    );
    await repo.insert(p);
    _current = p;
    await loadList();
    return p;
  }

  Future<void> rename(String id, String title) async {
    final p = await repo.byId(id);
    if (p == null) return;
    final trimmed = title.trim();
    final next = trimmed.isEmpty ? p : p.copyWith(title: trimmed);
    await repo.update(next);
    if (_current?.id == id) _current = await repo.byId(id);
    await loadList();
  }

  Future<void> duplicate(String id) async {
    final p = await repo.byId(id);
    if (p == null) return;
    await repo.duplicate(p);
    await loadList();
  }

  Future<void> remove(String id) async {
    if (_current?.id == id) {
      await stopPlay();
      _current = null;
    }
    await repo.delete(id);
    await loadList();
  }

  // ---------- 编辑（立即持久化） ----------

  Future<void> setTitle(String title) =>
      _persist((p) => p.copyWith(title: title));

  Future<void> setBpm(int bpm) =>
      _persist((p) => p.copyWith(bpm: bpm.clamp(40, 200)));

  /// 滑块拖动中的临时值：只刷内存不入库（松手时 [setBpm] 落库）。
  void setBpmLocal(int bpm) {
    final cur = _current;
    if (cur == null || cur.bpm == bpm) return;
    _current = cur.copyWith(bpm: bpm.clamp(40, 200));
    notifyListeners();
  }

  Future<void> setTimeSignature(TimeSignature ts) =>
      _persist((p) => p.copyWith(timeSignature: ts));

  Future<void> setPattern(AccomPattern pattern) =>
      _persist((p) => p.copyWith(pattern: pattern));

  /// 改调：同模式 → 序列整体转调；跨模式（大↔小）只改模式不重写序列。
  Future<void> changeKey(MusicKey target) =>
      _persist((p) {
        var chords = p.chords;
        if (target.mode == p.keyMode) {
          final semitones =
              semitonesBetween(MusicKey(p.keyRootPc, p.keyMode), target);
          if (semitones != 0) {
            chords = [
              for (final name in p.chords)
                transposeChordName(name, semitones,
                    targetUseFlats: target.useFlats),
            ];
          }
        }
        return p.copyWith(
          keyRootPc: target.rootPc,
          keyMode: target.mode,
          chords: chords,
        );
      });

  /// 追加和弦；超过 32 上限返回 false（FR-10）。
  Future<bool> addChord(String name) async {
    final p = _current;
    if (p == null || p.chords.length >= maxChords) return false;
    await _persist((cur) => cur.copyWith(chords: [...cur.chords, name]));
    return true;
  }

  Future<void> removeAt(int index) =>
      _persist((p) => p.copyWith(chords: [...p.chords]..removeAt(index)));

  /// 逻辑重排（已做 ReorderableListView 的 -1 校正）。
  Future<void> reorder(int oldIndex, int newIndex) => _persist((p) {
        final next = [...p.chords];
        final moved = next.removeAt(oldIndex);
        next.insert(newIndex, moved);
        return p.copyWith(chords: next);
      });

  /// 模板套用：整段替换（UI 层负责二次确认，FR-6）。
  Future<void> replaceAll(List<String> names) =>
      _persist((p) => p.copyWith(chords: names.take(maxChords).toList()));

  Future<void> clear() => _persist((p) => p.copyWith(chords: const []));

  Future<void> _persist(Progression Function(Progression) transform) async {
    final cur = _current;
    if (cur == null) return;
    await stopPlay();
    final next = transform(cur);
    // 空白草稿首次编辑 → insert；已存在 → update（自动刷 updatedAt）。
    final Progression saved;
    if (await repo.byId(next.id) == null) {
      await repo.insert(next);
      saved = next;
    } else {
      saved = await repo.update(next);
    }
    _current = saved;
    _items.removeWhere((e) => e.id == saved.id);
    _items.insert(0, saved);
    notifyListeners();
  }

  // ---------- 播放 ----------

  Future<void> playCurrent() async {
    final cur = _current;
    if (cur == null || cur.chords.isEmpty) return;

    final voicings = <List<int>>[
      for (final name in cur.chords) await _voicingOf(name),
    ];
    final schedule = StrumPatterns.buildProgressionSchedule(
      stringVoicings: voicings,
      bpm: cur.bpm,
      pattern: cur.pattern,
      timeSignature: cur.timeSignature,
    );

    _isPlaying = true;
    _highlightIndex = noChordHighlight;
    player.play(schedule, onChord: (i) {
      _highlightIndex = i;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopPlay() async {
    if (!_isPlaying && !player.isPlaying) return;
    await player.stop();
    _isPlaying = false;
    _highlightIndex = noChordHighlight;
    notifyListeners();
  }

  /// 解析和弦为 5 弦 MIDI；库中理论必有（选择器数据全部来自库），
  /// 查不到时按根音 + 大三和弦兜底，保证 chordIndex 不错位。
  Future<List<int>> _voicingOf(String name) async {
    final spec = await chordRepo.byName(name);
    if (spec != null) {
      return StrumPatterns.voiceGuitarStrings(
        rootPc: spec.rootPc,
        pitchClasses: spec.tones.map(Note.pitchClassOf).toList(),
      );
    }
    final parsed = ChordNameParser.parse(name);
    final rootPc = parsed == null ? 0 : Note.pitchClassOf(parsed.root);
    return StrumPatterns.voiceGuitarStrings(
      rootPc: rootPc,
      pitchClasses: [rootPc, (rootPc + 4) % 12, (rootPc + 7) % 12],
    );
  }

  @override
  void dispose() {
    // 直接停播放器，不经过 stopPlay（其 notifyListeners 在 dispose 后会抛）。
    unawaited(player.stop());
    _isPlaying = false;
    super.dispose();
  }
}
