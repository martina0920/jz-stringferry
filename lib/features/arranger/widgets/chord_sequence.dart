import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/key_harmony.dart';
import '../state/arranger_store.dart';
import 'chord_editor_sheet.dart';
import 'chord_picker_sheet.dart';

/// 和弦序列区：横向卡片（级数角标 / 删除 / 长按拖拽 / 播放高亮 / 点击编辑）。
class ChordSequence extends StatelessWidget {
  const ChordSequence({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    final p = store.current!;
    final chords = p.chords;
    final full = chords.length >= ArrangerStore.maxChords;

    return SizedBox(
      height: 108,
      child: ReorderableListView.builder(
        key: const Key('chord_sequence_list'),
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: chords.length + 1,
        // 回调必须恒非 null（SDK 断言 onReorder/onReorderItem 恰有一个非空），
        // 播放中在内部直接忽略重排。
        onReorderItem: (oldIndex, newIndex) {
          if (store.isPlaying) return;
          // 末尾「+」卡不参与重排；newIndex 已由框架完成 -1 校正。
          if (oldIndex == chords.length) return;
          final target = newIndex.clamp(0, chords.length - 1);
          if (target != oldIndex) store.reorder(oldIndex, target);
        },
        itemBuilder: (_, i) {
          if (i == chords.length) return _addCard(context, full);
          return _chordCard(context, i, chords[i]);
        },
      ),
    );
  }

  Widget _addCard(BuildContext context, bool full) {
    final store = context.read<ArrangerStore>();
    return Container(
      key: const Key('add_chord_card'),
      width: 76,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: full
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('最多 32 个和弦')),
                  );
                }
              : () async {
                  final name = await showChordPickerSheet(context, store);
                  if (name != null) {
                    final ok = await store.addChord(name);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('最多 32 个和弦')),
                      );
                    }
                  }
                },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(full ? Icons.lock_outline_rounded : Icons.add_rounded,
                  color: full ? AppColors.inkSoft : AppColors.ink, size: 26),
              const SizedBox(height: 4),
              Text(full ? '已满' : '加和弦',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chordCard(BuildContext context, int index, String name) {
    final store = context.read<ArrangerStore>();
    final highlighted = store.highlightIndex == index && store.isPlaying;
    final p = store.current!;
    final defaultBeats = p.timeSignature.beatsPerBar;
    final customBeats =
        (p.chordBeats != null && index < p.chordBeats!.length)
            ? p.chordBeats![index]
            : defaultBeats;
    String? section;
    for (final m in p.sections) {
      if (m.index == index) {
        section = m.label;
        break;
      }
    }

    return Container(
      key: ValueKey('chord_card_$index'),
      width: 92,
      margin: const EdgeInsets.only(right: 10),
      child: ReorderableDelayedDragStartListener(
        index: index,
        enabled: !store.isPlaying,
        child: GestureDetector(
          onTap: store.isPlaying
              ? null
              : () => _editChord(context, index, name, customBeats,
                  defaultBeats, section),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted ? AppColors.gold : AppColors.hairline,
                width: highlighted ? 1.6 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  top: 6,
                  child: Text(
                    romanNumeral(name, p.key),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    key: Key('remove_chord_$index'),
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        store.isPlaying ? null : () => store.removeAt(index),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.inkSoft),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                if (customBeats != defaultBeats)
                  Positioned(
                    left: 8,
                    bottom: 5,
                    child: Text('$customBeats拍',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.inkSoft)),
                  ),
                if (section != null)
                  Positioned(
                    right: 6,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(section,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.ink)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editChord(BuildContext context, int index, String name,
      int customBeats, int defaultBeats, String? section) async {
    final result = await showChordEditorSheet(
      context,
      currentName: name,
      currentBeats: customBeats,
      defaultBeats: defaultBeats,
      currentSection: section,
    );
    if (result == null) return;
    if (!context.mounted) return;
    final store = context.read<ArrangerStore>();
    await store.editChordAt(index, result.name, result.beats);
    if (result.removeSection) {
      await store.setSectionMark(index, null);
    } else if (result.sectionLabel != null) {
      await store.setSectionMark(index, result.sectionLabel);
    }
  }
}
