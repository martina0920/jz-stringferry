import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/study_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/study_repository.dart';
import '../state/study_plan_store.dart';

/// 新建/编辑任务底部表单。
///
/// 新建分类时会连带创建一个同名「<分类> 计划」。
Future<void> showTaskEditorSheet(
  BuildContext context, {
  StudyTask? existing,
  String? initialCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TaskEditorSheet(
          existing: existing, initialCategory: initialCategory),
    ),
  );
}

class _TaskEditorSheet extends StatefulWidget {
  final StudyTask? existing;
  final String? initialCategory;

  const _TaskEditorSheet({this.existing, this.initialCategory});

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _minutes = TextEditingController(text: '20');
  final _newCategory = TextEditingController();

  String? _category;
  bool _creatingCategory = false;
  String? _dueDate;
  RepeatRule _repeat = RepeatRule.none;
  TaskPriority _priority = TaskPriority.mid;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _note.text = e.note;
      _minutes.text = '${e.estimatedMinutes}';
      _dueDate = e.dueDate;
      _repeat = e.repeat;
      _priority = e.priority;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _minutes.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = _dueDate != null ? DayKey.parse(_dueDate!) : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = DayKey.of(picked));
  }

  Future<void> _save() async {
    final store = context.read<StudyPlanStore>();
    final title = _title.text.trim();
    final category = _creatingCategory ? _newCategory.text.trim() : _category;

    if (title.isEmpty) {
      setState(() => _error = '请填写任务标题');
      return;
    }
    if (category == null || category.isEmpty) {
      setState(() => _error = '请选择或新建分类');
      return;
    }

    String planId;
    final existingPlan = store.plansOf(category).isNotEmpty
        ? store.plansOf(category).first
        : null;
    if (existingPlan != null) {
      planId = existingPlan.id;
    } else {
      planId = StudyIds.plan();
      final maxSort = store.plans.isEmpty
          ? 0
          : store.plans.map((p) => p.sortKey).reduce((a, b) => a > b ? a : b) +
              1;
      await store.savePlan(StudyPlan(
        id: planId,
        title: '$category计划',
        category: category,
        sortKey: maxSort,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    // 不允许负数耗时；超出 24h 的输入截断到 1440。
    final minutes =
        (int.tryParse(_minutes.text.trim()) ?? 0).clamp(0, 1440).toInt();
    final task = StudyTask(
      id: widget.existing?.id ?? StudyIds.task(),
      planId: planId,
      title: title,
      dueDate: _dueDate,
      repeat: _repeat,
      priority: _priority,
      estimatedMinutes: minutes,
      note: _note.text.trim(),
      createdAt:
          widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await store.saveTask(task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyPlanStore>();
    final categories = store.categories;
    _category ??= widget.existing?.planId != null
        ? store.planCategory(widget.existing!.planId)
        : (widget.initialCategory ??
            (categories.isNotEmpty ? categories.first : null));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? '新建任务' : '编辑任务',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(hintText: '任务标题'),
            ),
            const SizedBox(height: 12),
            if (!_creatingCategory)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          categories.contains(_category) ? _category : null,
                      decoration: const InputDecoration(labelText: '分类'),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _creatingCategory = true),
                    child: const Text('新分类'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategory,
                      autofocus: true,
                      decoration:
                          const InputDecoration(hintText: '新分类名称，如：乐理类'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _creatingCategory = false),
                    child: const Text('选择已有'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_dueDate ?? '设置截止日'),
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.hairline),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: '清除截止日',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _OptionRow<RepeatRule>(
              label: '周期',
              values: RepeatRule.values,
              selected: _repeat,
              textOf: (r) => r.label,
              onChanged: (r) => setState(() => _repeat = r),
            ),
            if (_repeat == RepeatRule.weekly && _dueDate != null)
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 6, left: 4),
                child: Text(
                  '每周任务以截止日为锚点，按周向前排期。',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              )
            else
              const SizedBox(height: 8),
            _OptionRow<TaskPriority>(
              label: '优先级',
              values: TaskPriority.values,
              selected: _priority,
              textOf: (p) => p.label,
              onChanged: (p) => setState(() => _priority = p),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '预计耗时（分钟）', suffixText: 'min'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(hintText: '备注（可选）'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: Text(widget.existing == null ? '创建' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) textOf;
  final ValueChanged<T> onChanged;

  const _OptionRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.textOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(textOf(v)),
                  selected: v == selected,
                  onSelected: (_) => onChanged(v),
                  selectedColor: AppColors.ink,
                  backgroundColor: AppColors.paper,
                  labelStyle: TextStyle(
                    color: v == selected ? Colors.white : AppColors.inkSoft,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                      color:
                          v == selected ? AppColors.ink : AppColors.hairline),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
