import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 模块四：编曲工作台
///
/// 首版骨架：和弦进行编辑。
/// 后续接入：试听、转调导出、节奏搭配（已确认：全部功能）。
class ArrangerPage extends StatefulWidget {
  const ArrangerPage({super.key});

  @override
  State<ArrangerPage> createState() => _ArrangerPageState();
}

class _ArrangerPageState extends State<ArrangerPage> {
  static const _templates = ['1645', '1564', '4536251', '251'];

  final List<String> _progression = ['C', 'G', 'Am', 'F'];
  final List<String> _scale = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  String _key = 'C';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编曲工作台')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _KeySelector(
              keys: _scale,
              selected: _key,
              onSelect: (k) => setState(() => _key = k),
            ),
            const SizedBox(height: 20),
            const Text('和弦进行', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            _ProgressionStrip(
              chords: _progression,
              onRemove: (i) => setState(() => _progression.removeAt(i)),
            ),
            const SizedBox(height: 16),
            const Text('常用模板', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _templates)
                  ActionChip(
                    label: Text(t),
                    onPressed: () => _applyTemplate(t),
                    backgroundColor: AppColors.mist,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('试听与导出（二期接入）', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  void _applyTemplate(String template) {
    const t = {'1': 'C', '2': 'Dm', '3': 'Em', '4': 'F', '5': 'G', '6': 'Am'};
    final chords = template.split('').map((d) => t[d] ?? 'C').toList();
    setState(() => _progression
      ..clear()
      ..addAll(chords));
  }
}

class _KeySelector extends StatelessWidget {
  const _KeySelector({required this.keys, required this.selected, required this.onSelect});

  final List<String> keys;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('调性', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(k),
                      selected: k == selected,
                      onSelected: (_) => onSelect(k),
                      selectedColor: AppColors.ink,
                      backgroundColor: AppColors.mist,
                      labelStyle: TextStyle(
                        color: k == selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressionStrip extends StatelessWidget {
  const _ProgressionStrip({required this.chords, required this.onRemove});

  final List<String> chords;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < chords.length; i++)
          InputChip(
            label: Text(chords[i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            onDeleted: () => onRemove(i),
            deleteIconColor: AppColors.inkSoft,
            backgroundColor: AppColors.ink,
            labelStyle: const TextStyle(color: Colors.white),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: const Text('加和弦'),
          onPressed: () => _pickChord(context),
          backgroundColor: AppColors.mist,
          side: BorderSide.none,
        ),
      ],
    );
  }

  Future<void> _pickChord(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ChordPicker(),
    );
    if (picked != null && context.mounted) {
      // 由外部 State 处理追加
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已选择 $picked（追加逻辑待接入数据源）')),
      );
    }
  }
}

class _ChordPicker extends StatelessWidget {
  const _ChordPicker();

  static const _chords = ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'Am', 'Dm', 'Em', 'Fm', 'Gm', 'Bm', 'C7', 'G7', 'Am7', 'Dm7'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _chords)
              ActionChip(
                label: Text(c),
                onPressed: () => Navigator.pop(context, c),
                backgroundColor: AppColors.mist,
                side: BorderSide.none,
              ),
          ],
        ),
      ),
    );
  }
}
