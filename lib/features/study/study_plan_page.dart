import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 模块二：学习计划安排与分析
///
/// 首版骨架：计划分类列表 + 打卡。
/// 后续接入：耗时统计、薄弱项识别、提醒（对应已确认决策）。
class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  static const _categories = ['编曲类', '混音类', '分轨类', '乐器类'];
  String _active = '编曲类';

  static const Map<String, List<String>> _plans = {
    '编曲类': ['欧阳和杨磊的编曲课全部上完', '学会 Serum / Pro Tools / Auto-Tune', '人声编曲专题'],
    '混音类': ['Alex 的混音课全部学完', '每天一章混音指南'],
    '分轨类': ['两周完全扒带一首歌', '每天听五首歌研究编曲思路并记笔记'],
    '乐器类': ['练绝对音感', '练吉他和弦'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学习计划')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryTabs(
              categories: _categories,
              active: _active,
              onTap: (c) => setState(() => _active = c),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _SummaryCard(tasks: _plans[_active] ?? const []),
                  const SizedBox(height: 16),
                  for (final t in (_plans[_active] ?? const [])) _TaskCard(title: t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.categories, required this.active, required this.onTap});

  final List<String> categories;
  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          final isActive = c == active;
          return ChoiceChip(
            label: Text(c),
            selected: isActive,
            onSelected: (_) => onTap(c),
            selectedColor: AppColors.ink,
            backgroundColor: AppColors.mist,
            labelStyle: TextStyle(
              color: isActive ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tasks});

  final List<String> tasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _Stat(label: '任务', value: '${tasks.length}'),
            ),
            Container(width: 1, height: 32, color: AppColors.hairline),
            const Expanded(
              child: _Stat(label: '完成', value: '0'),
            ),
            Container(width: 1, height: 32, color: AppColors.hairline),
            const Expanded(
              child: _Stat(label: '完成率', value: '0%'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({required this.title});

  final String title;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: CheckboxListTile(
          value: _done,
          activeColor: AppColors.ink,
          onChanged: (v) => setState(() => _done = v ?? false),
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              decoration: _done ? TextDecoration.lineThrough : null,
              color: _done ? AppColors.inkSoft : AppColors.ink,
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}
