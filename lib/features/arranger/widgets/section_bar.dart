import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/arranger_store.dart';

/// 段落标记条（v0.5）：横向展示全部段落起点，点 chip 从该段起播，× 删除标记。
class SectionBar extends StatelessWidget {
  const SectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    final marks = store.current!.sections;

    if (marks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          '无段落标记 · 点和弦卡可编辑属性、拍数与段落',
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: marks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = marks[i];
          return InputChip(
            key: Key('section_mark_${m.index}'),
            label: Text('${m.label} · ${m.index + 1}'),
            tooltip: '从此段起播',
            visualDensity: VisualDensity.compact,
            backgroundColor: AppColors.mist,
            side: BorderSide.none,
            labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink),
            onPressed: () => store.playFrom(m.index),
            onDeleted: () => store.setSectionMark(m.index, null),
            deleteIconColor: AppColors.inkSoft,
          );
        },
      ),
    );
  }
}
