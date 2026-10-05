import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/key_harmony.dart';
import '../progression_export.dart';
import '../state/arranger_store.dart';

/// 分享导出底部弹层：可选目标调（同模式 12 调）实时转调预览，
/// 支持复制到剪贴板与系统分享（FR-18/FR-19）。
Future<void> showShareProgressionSheet(
  BuildContext context,
  ArrangerStore store,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ShareProgressionSheet(store: store),
  );
}

class _ShareProgressionSheet extends StatefulWidget {
  final ArrangerStore store;
  const _ShareProgressionSheet({required this.store});

  @override
  State<_ShareProgressionSheet> createState() => _ShareProgressionSheetState();
}

class _ShareProgressionSheetState extends State<_ShareProgressionSheet> {
  late int _rootPc = widget.store.current!.keyRootPc;

  MusicKey get _targetKey =>
      MusicKey(_rootPc, widget.store.current!.keyMode);

  /// 目标调与原调不同时整体转调，仅用于本次分享内容。
  List<String> _previewChords() {
    final p = widget.store.current!;
    if (_rootPc == p.keyRootPc) return p.chords;
    final semitones = semitonesBetween(p.key, _targetKey);
    return [
      for (final name in p.chords)
        transposeChordName(name, semitones,
            targetUseFlats: _targetKey.useFlats),
    ];
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<void> _systemShare(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统分享不可用，已改用复制')),
      );
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.store.current!;
    final keys =
        p.keyMode == KeyMode.major ? MusicKey.allMajor : MusicKey.allMinor;
    final preview = buildExportText(
      progression: p,
      overrideKey: _targetKey,
      overrideChords: _previewChords(),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const Text('分享导出',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('换个调分享？级数标注会自动跟着转换',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  key: const Key('share_key_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: keys.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final k = keys[i];
                    final active = k.rootPc == _rootPc;
                    return ChoiceChip(
                      key: Key('share_key_chip_${k.rootName}'),
                      label: Text(k.rootName),
                      selected: active,
                      onSelected: (_) =>
                          setState(() => _rootPc = k.rootPc),
                      selectedColor: AppColors.ink,
                      backgroundColor: AppColors.mist,
                      labelStyle: TextStyle(
                        color: active ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Container(
                key: const Key('share_preview'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  preview,
                  style: const TextStyle(
                      fontSize: 14, height: 1.6, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('copy_share_text'),
                      onPressed: () => _copy(preview),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const Key('system_share'),
                      onPressed: () => _systemShare(preview),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('系统分享'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
