import 'package:sqflite/sqflite.dart';

import '../core/models/chord_spec.dart';
import '../core/theory/chord_builder.dart';
import '../core/theory/chord_quality.dart';
import '../core/theory/note.dart';

/// 和弦数据仓库（sqflite 异步实现）。
///
/// 全库仅 510 行，首次访问后整体缓存在内存（几十 KB），
/// 名称/别名/组成音搜索全部走内存，单次耗时远低于 50ms。
class ChordRepository {
  final Database db;
  ChordRepository(this.db);

  List<ChordSpec>? _cache;

  Future<List<ChordSpec>> _allCached() async {
    final c = _cache;
    if (c != null) return c;
    final rows = await db.query('chords', orderBy: 'sort_key');
    _cache = rows.map(ChordSpec.fromMap).toList(growable: false);
    return _cache!;
  }

  /// 重置/重新导入后清缓存。
  void invalidateCache() => _cache = null;

  Future<List<ChordSpec>> all({String? family}) async {
    final list = await _allCached();
    if (family == null || family.isEmpty) return list;
    return list.where((c) => c.family == family).toList();
  }

  /// 全部家族（用于筛选 chips），按内置性质表顺序。
  Future<List<String>> families() async {
    final list = await _allCached();
    final seen = <String>{};
    final ordered = <String>[];
    for (final q in allQualities) {
      if (list.any((c) => c.family == q.family) && seen.add(q.family)) {
        ordered.add(q.family);
      }
    }
    return ordered;
  }

  /// 按 id 顺序批量解析（收藏/最近列表用，走内存缓存）。
  Future<List<ChordSpec>> byIds(Iterable<int> ids) async {
    final list = await _allCached();
    final byId = <int, ChordSpec>{};
    for (final c in list) {
      final id = c.id;
      if (id != null) byId[id] = c;
    }
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  Future<ChordSpec?> byId(int id) async {
    final rows =
        await db.query('chords', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ChordSpec.fromMap(rows.first);
  }

  Future<ChordSpec?> byName(String name) async {
    final list = await _allCached();
    for (final c in list) {
      if (c.name.toLowerCase() == name.trim().toLowerCase()) return c;
    }
    return null;
  }

  /// 多维度搜索：和弦名 / 性质与中文别名 / 组成音反查。
  Future<List<ChordSpec>> search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return _allCached();
    final list = await _allCached();
    final lower = kw.toLowerCase();

    // 尝试作为「根音 + 性质后缀」解析，如 am7、F#m7b5。
    final parsed = ChordNameParser.parse(kw);

    // 尝试作为组成音集合解析（空格/逗号/顿号分隔），如 "A C E G"。
    final tonePcs = _parseTonePcs(kw);

    final scored = <(ChordSpec, int)>[];
    for (final c in list) {
      final name = c.name.toLowerCase();

      if (name == lower) {
        scored.add((c, 0));
        continue;
      }

      // 解析出的精确和弦名（am7 等）排最前。
      if (parsed != null &&
          c.root.toLowerCase() == parsed.root.toLowerCase() &&
          c.quality.id == parsed.quality.id) {
        scored.add((c, 0));
        continue;
      }

      // 性质别名精确命中（小七、挂四、属七…）。
      final quality = qualitiesById[c.quality.id];
      if (quality != null &&
          quality.aliases.any((a) => a.toLowerCase() == lower)) {
        scored.add((c, 1));
        continue;
      }

      // 组成音完全一致优先，被包含（宽松匹配）其后。
      if (tonePcs != null && tonePcs.length >= 2) {
        final chordPcs = c.tones.map(Note.pitchClassOf).toSet();
        if (tonePcs.every(chordPcs.contains)) {
          scored.add((c, chordPcs.length == tonePcs.length ? 2 : 4));
          continue;
        }
      }

      // 名称前缀 / 包含（英文与数字后缀的模糊匹配；
      // 中文别名只走上面的精确命中，避免「小七」误命中「减小七和弦」）。
      if (name.startsWith(lower)) {
        scored.add((c, 3));
        continue;
      }
      if (name.contains(lower)) {
        scored.add((c, 6));
      }
    }

    scored.sort((a, b) {
      final byRank = a.$2.compareTo(b.$2);
      if (byRank != 0) return byRank;
      return a.$1.sortKey.compareTo(b.$1.sortKey);
    });
    return scored.map((e) => e.$1).toList();
  }

  /// 把 "A C E G" / "a,c,e,g" / "A、C、E、G" 解析为音级集合；
  /// 不足 2 个合法音名时返回 null（单词 "C" 不视为组成音搜索）。
  Set<int>? _parseTonePcs(String input) {
    final tokens =
        input.split(RegExp(r'[\s,，、]+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 2) return null;
    // 严格音名（字母 + 可选一个升降号）：Note.pitchClassOf 只看前两个字符，
    // 不做约束会把 "Am7" 这类脏 token 静默当成 A。
    final noteToken = RegExp(r'^[A-Ga-g][#b]?$');
    final pcs = <int>{};
    for (final t in tokens) {
      if (!noteToken.hasMatch(t)) return null;
      try {
        pcs.add(Note.pitchClassOf(t));
      } catch (_) {
        return null;
      }
    }
    return pcs;
  }
}
