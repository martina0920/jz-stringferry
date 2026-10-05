import 'package:flutter/material.dart';

import '../../../core/theory/chord_builder.dart';
import '../../../core/theory/chord_quality.dart';
import '../../../core/theme/app_theme.dart';

/// 和弦编辑结果。
class ChordEditResult {
  final String name;

  /// 每和弦拍数；null = 恢复默认一小节。
  final int? beats;

  /// 非空时在该和弦位置设段落标记。
  final String? sectionLabel;

  /// 为 true 时移除该和弦位置的段落标记。
  final bool removeSection;

  const ChordEditResult({
    required this.name,
    required this.beats,
    this.sectionLabel,
    this.removeSection = false,
  });
}

/// 内置段落名（v0.5）。
const List<String> kSectionLabels = ['前奏', '主歌', '副歌', '桥段', '间奏', '尾奏'];

/// 和弦编辑底部弹层：根音+性质构建 / 自由文本覆盖 / 拍数 / 段落标记。
Future<ChordEditResult?> showChordEditorSheet(
  BuildContext context, {
  required String currentName,
  required int currentBeats,
  required int defaultBeats,
  required String? currentSection,
}) {
  return showModalBottomSheet<ChordEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChordEditorSheet(
      currentName: currentName,
      currentBeats: currentBeats,
      defaultBeats: defaultBeats,
      currentSection: currentSection,
    ),
  );
}

class _ChordEditorSheet extends StatefulWidget {
  const _ChordEditorSheet({
    required this.currentName,
    required this.currentBeats,
    required this.defaultBeats,
    required this.currentSection,
  });

  final String currentName;
  final int currentBeats;
  final int defaultBeats;
  final String? currentSection;

  @override
  State<_ChordEditorSheet> createState() => _ChordEditorSheetState();
}

class _ChordEditorSheetState extends State<_ChordEditorSheet> {
  static const List<String> _roots = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B',
  ];

  /// 编辑器里常用的 14 种性质（其余冷门性质走自由文本）。
  static const List<String> _qualityIds = [
    'maj', 'min', '7', 'maj7', 'm7', 'm7b5', 'dim', 'aug',
    'sus2', 'sus4', 'six', 'm6', 'add9', 'nine',
  ];

  late final TextEditingController _text;
  String _root = 'C';
  ChordQuality _quality = qualitiesById['maj']!;
  bool _useFreeText = false;
  late int _beats;
  late String? _section;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.currentName);
    _text.addListener(() {
      if (!_useFreeText) setState(() => _useFreeText = true);
    });
    _beats = widget.currentBeats;
    _section = widget.currentSection;
    // 预解析当前和弦名，尽量对齐到根音+性质。
    final parsed = ChordNameParser.parse(widget.currentName);
    if (parsed != null) {
      _root = parsed.root;
      _quality = parsed.quality;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _builtName => '$_root${_quality.suffix}';
  String get _effectiveName => _useFreeText ? _text.text.trim() : _builtName;

  void _save(BuildContext context) {
    final name = _effectiveName;
    if (name.isEmpty) return;
    final beats = _beats == widget.defaultBeats ? null : _beats;
    Navigator.of(context).pop(ChordEditResult(
      name: name,
      beats: beats,
      sectionLabel: _section,
      removeSection: widget.currentSection != null && _section == null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  _effectiveName.isEmpty ? '—' : _effectiveName,
                  key: const Key('chord_editor_preview'),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ),
              const SizedBox(height: 14),
              const _Label('根音'),
              _chipWrap(
                _roots.map((r) => (r, r)).toList(),
                _root,
                (v) => setState(() {
                  _root = v;
                  _useFreeText = false;
                  _text.text = _builtName;
                }),
                keyOf: (v) => 'chord_root_$v',
              ),
              const SizedBox(height: 12),
              const _Label('性质'),
              _chipWrap(
                [
                  for (final id in _qualityIds)
                    (
                      qualitiesById[id]!.suffix.isEmpty
                          ? '大三'
                          : qualitiesById[id]!.suffix,
                      qualitiesById[id]!
                    ),
                ],
                _quality,
                (q) => setState(() {
                  _quality = q;
                  _useFreeText = false;
                  _text.text = _builtName;
                }),
                keyOf: (q) => 'chord_quality_${q.id}',
                labelOf: (q) =>
                    q.suffix.isEmpty ? '大三' : q.suffix,
              ),
              const SizedBox(height: 12),
              const _Label('和弦名（可直接改）'),
              TextField(
                key: const Key('chord_name_field'),
                controller: _text,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: '如 Am7、F#m7b5',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const _Label('拍数'),
                  const SizedBox(width: 12),
                  IconButton(
                    key: const Key('chord_beats_minus'),
                    onPressed: _beats > 1
                        ? () => setState(() => _beats--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_beats',
                      key: const Key('chord_beats_value'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(
                    key: const Key('chord_beats_plus'),
                    onPressed: _beats < 8
                        ? () => setState(() => _beats++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Text('拍（默认 ${widget.defaultBeats}）',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
              const SizedBox(height: 12),
              const _Label('段落（从此和弦起）'),
              _chipWrap(
                [for (final s in kSectionLabels) (s, s)],
                _section,
                (s) => setState(() => _section = s),
                keyOf: (s) => 'section_chip_$s',
              ),
              if (widget.currentSection != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  key: const Key('section_remove'),
                  onPressed: () => setState(() => _section = null),
                  child: const Text('移除段落标记',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('chord_editor_save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                  ),
                  onPressed: () => _save(context),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipWrap<T>(
    List<(String, T)> items,
    T? selected,
    ValueChanged<T> onTap, {
    required String Function(T) keyOf,
    String Function(T)? labelOf,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in items)
          ChoiceChip(
            key: Key(keyOf(value)),
            label: Text(labelOf?.call(value) ?? label),
            selected: selected == value,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: AppColors.ink,
            backgroundColor: AppColors.mist,
            side: BorderSide.none,
            labelStyle: TextStyle(
              fontSize: 13,
              color: selected == value ? Colors.white : AppColors.ink,
            ),
            onSelected: (_) => onTap(value),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft)),
    );
  }
}
