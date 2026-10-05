import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theory/progression_template.dart';
import '../state/arranger_store.dart';
import 'progression_dialogs.dart';

/// 模板条：点击用当前调实例化并二次确认后整段替换（FR-6）。
class TemplateStrip extends StatelessWidget {
  const TemplateStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ArrangerStore>();
    final p = store.current!;
    final templates = progressionTemplates
        .where((t) => t.mode == p.keyMode)
        .toList();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        key: const Key('template_strip_list'),
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = templates[i];
          final instantiated = t.instantiate(p.key);
          final same = _sameSequence(instantiated, p.chords);
          return ActionChip(
            key: Key('template_chip_${t.id}'),
            label: Text(t.name),
            onPressed: store.isPlaying
                ? null
                : () async {
                    if (same) return;
                    final ok =
                        await confirmTemplateReplace(context, t.name);
                    if (ok) await store.replaceAll(instantiated);
                  },
            backgroundColor: same ? AppColors.ink : AppColors.mist,
            side: BorderSide.none,
            labelStyle: TextStyle(
              color: same ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        },
      ),
    );
  }

  bool _sameSequence(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
