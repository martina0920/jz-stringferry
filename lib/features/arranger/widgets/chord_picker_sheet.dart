import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/chord_spec.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theory/key_harmony.dart';
import '../state/arranger_store.dart';

/// 加和弦底部弹层：顺阶三/七和弦分段 + 全库搜索（防抖 150ms）。
Future<String?> showChordPickerSheet(BuildContext context, ArrangerStore store) {
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: AppColors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ChordPickerSheet(store: store),
    ),
  );
}

class _ChordPickerSheet extends StatefulWidget {
  final ArrangerStore store;
  const _ChordPickerSheet({required this.store});

  @override
  State<_ChordPickerSheet> createState() => _ChordPickerSheetState();
}

class _ChordPickerSheetState extends State<_ChordPickerSheet> {
  bool _seventh = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ChordSpec> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final kw = value.trim();
    if (kw.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      setState(() => _searching = true);
      final list = await widget.store.chordRepo.search(kw);
      if (!mounted) return;
      setState(() {
        _results = list.take(30).toList();
        _searching = false;
      });
    });
  }

  void _pick(String name) => Navigator.of(context).pop(name);

  @override
  Widget build(BuildContext context) {
    final key = widget.store.current!.key;
    final diatonic = _seventh ? key.diatonicSevenths() : key.diatonicTriads();
    final searching = _searchCtrl.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('chord_search_field'),
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索全库和弦，如 G7、F#m7b5',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (searching)
              _searchResults()
            else ...[
              _segmentToggle(),
              const SizedBox(height: 10),
              _diatonicGrid(diatonic, key),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segmentToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleTab(
              label: '顺阶三和弦', active: !_seventh, onTap: () => setState(() => _seventh = false)),
          _ToggleTab(
              label: '顺阶七和弦', active: _seventh, onTap: () => setState(() => _seventh = true)),
        ],
      ),
    );
  }

  Widget _diatonicGrid(List<String> chords, MusicKey key) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < chords.length; i++)
          ActionChip(
            key: Key('diatonic_chip_${chords[i]}'),
            label: Text(chords[i]),
            onPressed: () => _pick(chords[i]),
            backgroundColor: AppColors.mist,
            side: BorderSide.none,
            labelStyle: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w600),
            avatar: Text(
              romanNumeral(chords[i], key),
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _searchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('没有匹配的和弦',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _results.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.hairline),
        itemBuilder: (_, i) {
          final spec = _results[i];
          return ListTile(
            key: Key('search_result_${spec.name}'),
            dense: true,
            title: Text(spec.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(spec.family,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft)),
            onTap: () => _pick(spec.name),
          );
        },
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.all(4),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.paper : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 1)),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
