import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/key_harmony.dart';
import '../../../core/theory/progression_template.dart';

/// 新建进行底部弹层：空白进行 + 7 个模板（大调区/小调区）。
///
/// 返回选中的模板；返回 null 表示选了「空白进行」。
Future<ProgressionTemplate?> showNewProgressionSheet(BuildContext context) {
  return showModalBottomSheet<ProgressionTemplate?>(
    context: context,
    backgroundColor: AppColors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NewProgressionSheet(),
  );
}

class _NewProgressionSheet extends StatelessWidget {
  const _NewProgressionSheet();

  @override
  Widget build(BuildContext context) {
    final majors = progressionTemplates
        .where((t) => t.mode == KeyMode.major)
        .toList();
    final minors = progressionTemplates
        .where((t) => t.mode == KeyMode.minor)
        .toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
              const Text('新建进行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _BlankTile(
                onTap: () => Navigator.of(context).pop(null),
              ),
              const SizedBox(height: 12),
              const _SectionLabel('大调模板'),
              for (final t in majors)
                _TemplateTile(
                  template: t,
                  onTap: () => Navigator.of(context).pop(t),
                ),
              const SizedBox(height: 8),
              const _SectionLabel('小调模板'),
              for (final t in minors)
                _TemplateTile(
                  template: t,
                  onTap: () => Navigator.of(context).pop(t),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft)),
    );
  }
}

class _BlankTile extends StatelessWidget {
  final VoidCallback onTap;
  const _BlankTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('new_blank_progression'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text('空白进行',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Spacer(),
            Text('自由添加和弦',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final ProgressionTemplate template;
  final VoidCallback onTap;

  const _TemplateTile({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('new_template_${template.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(template.numerals,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(template.hint,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
