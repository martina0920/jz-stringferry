import 'package:flutter/foundation.dart';

import '../../../data/chord_collection_repository.dart';

/// 收藏/最近查询的应用内状态：收藏切换与最近访问即时同步到 UI。
class ChordCollectionStore extends ChangeNotifier {
  final ChordCollectionRepository repo;

  Set<int> _favoriteIds = {};
  List<int> _recentIds = [];
  bool _loaded = false;

  ChordCollectionStore(this.repo);

  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<int> get recentIds => List.unmodifiable(_recentIds);
  bool get loaded => _loaded;

  bool isFavorite(int chordId) => _favoriteIds.contains(chordId);

  Future<void> load() async {
    final results = await Future.wait([
      repo.favoriteIds(),
      repo.recentChordIds(),
    ]);
    _favoriteIds = results[0] as Set<int>;
    _recentIds = results[1] as List<int>;
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(int chordId) async {
    await repo.toggleFavorite(chordId);
    if (_favoriteIds.contains(chordId)) {
      _favoriteIds.remove(chordId);
    } else {
      _favoriteIds.add(chordId);
    }
    notifyListeners();
  }

  Future<void> recordQuery(int chordId) async {
    await repo.recordQuery(chordId);
    _recentIds
      ..remove(chordId)
      ..insert(0, chordId);
    if (_recentIds.length > ChordCollectionRepository.recentLimit) {
      _recentIds.removeRange(
          ChordCollectionRepository.recentLimit, _recentIds.length);
    }
    notifyListeners();
  }
}
