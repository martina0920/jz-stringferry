import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/models/chord_spec.dart';
import '../../core/theme/app_theme.dart';
import '../../data/chord_repository.dart';
import 'chord_detail_page.dart';
import 'state/chord_collection_store.dart';

/// 模块一：和弦查询。
///
/// 名称/中文别名/组成音即时搜索 + 家族筛选 + 收藏过滤 + 最近查询。
class ChordQueryPage extends StatefulWidget {
  const ChordQueryPage({super.key});

  @override
  State<ChordQueryPage> createState() => _ChordQueryPageState();
}

class _ChordQueryPageState extends State<ChordQueryPage> {
  late final ChordRepository _repo;
  late final Future<List<String>> _familiesFuture;

  final _controller = TextEditingController();
  Timer? _debounce;
  String _keyword = '';
  String? _family;
  bool _onlyFavorites = false;

  /// 缓存结果 Future：store 任意 notify（如最近查询变化）引发重建时
  /// 不重新订阅、不闪 loading；查询条件变化时才刷新。
  String? _resultsKey;
  Future<List<ChordSpec>>? _resultsFuture;

  @override
  void initState() {
    super.initState();
    _repo = ChordRepository(AppDatabase.instance.database);
    _familiesFuture = _repo.families();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _keyword = value.trim());
    });
  }

  Future<void> _openDetail(ChordSpec chord) async {
    final id = chord.id;
    if (id != null) {
      await context.read<ChordCollectionStore?>()?.recordQuery(id);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChordDetailPage(chord: chord)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ChordCollectionStore?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('和弦查询'),
        actions: [
          IconButton(
            tooltip: '只看收藏',
            icon: Icon(_onlyFavorites
                ? Icons.star_rounded
                : Icons.star_border_rounded),
            color: _onlyFavorites ? AppColors.gold : AppColors.ink,
            onPressed: () => setState(() => _onlyFavorites = !_onlyFavorites),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '和弦名 / 小七 / A C E G',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _keyword = '');
                          },
                        ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 10),
            // 最近查询（仅未输入关键字时展示）
            if (_keyword.isEmpty && store != null && store.recentIds.isNotEmpty)
              _RecentStrip(
                repo: _repo,
                recentIds: store.recentIds,
                onTap: _openDetail,
              ),
            // 家族筛选
            FutureBuilder<List<String>>(
              future: _familiesFuture,
              builder: (context, snap) {
                final families = snap.data ?? const [];
                return SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FamilyChip(
                        label: '全部',
                        selected: _family == null,
                        onTap: () => setState(() => _family = null),
                      ),
                      for (final f in families)
                        _FamilyChip(
                          label: f,
                          selected: _family == f,
                          onTap: () =>
                              setState(() => _family = _family == f ? null : f),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<ChordSpec>>(
                future: _resultsFor(store),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const _ErrorState();
                  }
                  final results = snap.data ?? const [];
                  if (results.isEmpty) {
                    return _EmptyState(onlyFavorites: _onlyFavorites);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ChordResultTile(
                      chord: results[i],
                      favorite: results[i].id == null
                          ? false
                          : store?.isFavorite(results[i].id!) ?? false,
                      onFavoriteTap: () {
                        final id = results[i].id;
                        if (id != null) store?.toggleFavorite(id);
                      },
                      onTap: () => _openDetail(results[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<ChordSpec>> _resultsFor(ChordCollectionStore? store) {
    final key = '$_keyword::${_family ?? ''}::$_onlyFavorites::'
        '${store?.favoriteIds.length ?? 0}';
    if (_resultsKey != key || _resultsFuture == null) {
      _resultsKey = key;
      _resultsFuture = _loadResults();
    }
    return _resultsFuture!;
  }

  Future<List<ChordSpec>> _loadResults() async {
    final favs = context.read<ChordCollectionStore?>()?.favoriteIds ?? <int>{};
    var list = await _repo.search(_keyword);
    if (_family != null) {
      list = list.where((c) => c.family == _family).toList();
    }
    if (_onlyFavorites) {
      list = list.where((c) => c.id != null && favs.contains(c.id)).toList();
    }
    return list;
  }
}

class _RecentStrip extends StatelessWidget {
  final ChordRepository repo;
  final List<int> recentIds;
  final ValueChanged<ChordSpec> onTap;

  const _RecentStrip({
    required this.repo,
    required this.recentIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20),
            child: Text('最近查过',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: FutureBuilder<List<ChordSpec>>(
              future: repo.byIds(recentIds),
              builder: (context, snap) {
                final recents = snap.data ?? const [];
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: recents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => InkWell(
                    borderRadius: BorderRadius.circular(17),
                    onTap: () => onTap(recents[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.mist,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(recents[i].name,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FamilyChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.ink,
        backgroundColor: AppColors.paper,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.inkSoft,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(color: selected ? AppColors.ink : AppColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _ChordResultTile extends StatelessWidget {
  final ChordSpec chord;
  final bool favorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;

  const _ChordResultTile({
    required this.chord,
    required this.favorite,
    required this.onFavoriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 6),
        title: Row(
          children: [
            Flexible(
              child: Text(chord.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Text(chord.family,
                style: const TextStyle(fontSize: 11, color: AppColors.gold)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(chord.tones.join('  '),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.inkSoft, height: 1.3)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded),
              color: favorite ? AppColors.gold : AppColors.inkSoft,
              onPressed: onFavoriteTap,
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 44, color: AppColors.inkSoft),
          SizedBox(height: 12),
          Text('读取和弦数据失败',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
          SizedBox(height: 4),
          Text('可在设置页尝试「恢复示例数据」',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool onlyFavorites;

  const _EmptyState({required this.onlyFavorites});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              onlyFavorites
                  ? Icons.star_border_rounded
                  : Icons.search_off_rounded,
              size: 44,
              color: AppColors.hairline),
          const SizedBox(height: 12),
          Text(onlyFavorites ? '还没有收藏的和弦' : '没有匹配的和弦',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14)),
          const SizedBox(height: 4),
          Text(onlyFavorites ? '在列表中点星标即可收藏' : '试试 Am7、小七、或 A C E G',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ],
      ),
    );
  }
}
