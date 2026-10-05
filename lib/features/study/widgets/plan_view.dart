import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/study_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/study_analytics.dart';
import '../../../data/study_schedule.dart';
import '../state/study_plan_store.dart';
import 'study_calendar.dart';
import 'task_editor_sheet.dart';

/// 学习计划「计划」视图：分类分组任务卡 + 月历 + 当日打卡。
class PlanView extends StatefulWidget {
  const PlanView({super.key});

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  String? _category;
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  AnalyticsReport _reportOf(
      StudyPlanStore store, List<StudyPlan> plans, List<StudyTask> tasks) {
    final taskIds = tasks.map((t) => t.id).toSet();
    return StudyAnalytics.build(
      plans: plans,
      tasks: tasks,
      checkins: store.checkinSnapshot
          .where((c) => taskIds.contains(c.taskId))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyPlanStore>();
    final categories = store.categories;
    if (_category != null && !categories.contains(_category)) {
      _category = categories.isNotEmpty ? categories.first : null;
    }
    _category ??= categories.isNotEmpty ? categories.first : null;

    if (categories.isEmpty) {
      return _EmptyPlanState(
        onRestore: () => store.restoreTemplates(),
        onCreate: () => showTaskEditorSheet(context),
      );
    }

    final plans = store.plansOf(_category!);
    final tasks = store.tasksOf(_category!);
    final report = _reportOf(store, plans, tasks);
    // 逾期/临期统一使用 StudyAnalytics 口径，避免任务卡与分析页不一致（review Minor-4）。
    final overdueIds = report.overdue.map((t) => t.id).toSet();
    final dueSoonIds = report.dueSoon.map((t) => t.id).toSet();
    final monthPrefix =
        '${_month.year}-${_month.month.toString().padLeft(2, '0')}-';

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new_task_fab'),
        onPressed: () =>
            showTaskEditorSheet(context, initialCategory: _category),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新任务'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = categories[i];
                      final active = c == _category;
                      return GestureDetector(
                        onLongPress: () => _manageCategory(store, c),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: active,
                          onSelected: (_) => setState(() => _category = c),
                          selectedColor: AppColors.ink,
                          backgroundColor: AppColors.mist,
                          labelStyle: TextStyle(
                            color: active ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('manage_category'),
                onPressed: () => _manageCategory(store, _category!),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('管理'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkSoft,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryCard(
            total: report.categories.fold(0, (n, s) => n + s.taskCount),
            completed:
                report.categories.fold(0, (n, s) => n + s.completedCount),
            minutes: report.completedMinutes,
          ),
          const SizedBox(height: 14),
          for (final t in tasks) ...[
            _TaskCard(
              key: ValueKey('task_${t.id}'),
              task: t,
              checkedToday: store.isCheckedOn(t.id, DateTime.now()),
              overdue: overdueIds.contains(t.id),
              dueSoon: dueSoonIds.contains(t.id),
              onToggle: () => store.toggleCheckin(t.id, DateTime.now()),
              onEdit: () => showTaskEditorSheet(context, existing: t),
              onDelete: () => _confirmDelete(context, store, t),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          StudyCalendar(
            visibleMonth: _month,
            selectedDay: _selectedDay,
            markedKeys: {
              for (final c in store.checkinSnapshot)
                if (c.date.startsWith(monthPrefix)) c.date,
            },
            onPrevMonth: (m) => setState(() => _month = m),
            onNextMonth: (m) => setState(() => _month = m),
            onSelectDay: (d) => setState(() => _selectedDay = d),
          ),
          const SizedBox(height: 10),
          _DayTasksCard(day: _selectedDay),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, StudyPlanStore store, StudyTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除任务「${task.title}」及其全部打卡记录？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(64, 40),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteTask(task.id);
  }

  /// 分类管理底部菜单：重命名 / 删除分类（FR-9）。
  Future<void> _manageCategory(StudyPlanStore store, String category) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('管理分类「$category」',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              key: const Key('category_rename'),
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('重命名分类'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              key: const Key('category_delete'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除分类'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _renameCategory(store, category);
    } else {
      await _confirmDeleteCategory(store, category);
    }
  }

  Future<void> _renameCategory(StudyPlanStore store, String category) async {
    final controller = TextEditingController(text: category);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分类'),
        content: TextField(
          key: const Key('rename_category_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新的分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newName == null) return;
    final error = await store.renameCategory(category, newName);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (newName.trim() != category) setState(() => _category = newName.trim());
  }

  Future<void> _confirmDeleteCategory(
      StudyPlanStore store, String category) async {
    final count = store.tasksOf(category).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除分类「$category」及其下全部计划、$count 个任务与打卡记录？'
            '此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm_delete_category'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteCategory(category);
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int completed;
  final int minutes;

  const _SummaryCard({
    required this.total,
    required this.completed,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final rate = total == 0 ? 0 : (completed * 100 / total).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(child: _Stat(label: '任务', value: '$total')),
            Container(width: 1, height: 32, color: AppColors.hairline),
            Expanded(child: _Stat(label: '已完成', value: '$completed')),
            Container(width: 1, height: 32, color: AppColors.hairline),
            Expanded(child: _Stat(label: '完成率', value: '$rate%')),
            Container(width: 1, height: 32, color: AppColors.hairline),
            Expanded(child: _Stat(label: '已练分钟', value: '$minutes')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StudyTask task;
  final bool checkedToday;
  final bool overdue;
  final bool dueSoon;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    super.key,
    required this.task,
    required this.checkedToday,
    required this.overdue,
    required this.dueSoon,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _priorityColor => switch (task.priority) {
        TaskPriority.high => const Color(0xFFB3261E),
        TaskPriority.mid => AppColors.gold,
        TaskPriority.low => AppColors.inkSoft,
      };

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _priorityColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration:
                            checkedToday ? TextDecoration.lineThrough : null,
                        color: checkedToday ? AppColors.inkSoft : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(spacing: 10, runSpacing: 3, children: [
                      if (task.repeat != RepeatRule.none)
                        _Meta(
                            icon: Icons.repeat_rounded,
                            text: task.repeat.label),
                      if (due != null)
                        _Meta(
                          icon: Icons.event_rounded,
                          text: due,
                          color: overdue
                              ? const Color(0xFFB3261E)
                              : dueSoon
                                  ? AppColors.gold
                                  : AppColors.inkSoft,
                        ),
                      _Meta(
                          icon: Icons.timer_outlined,
                          text: '${task.estimatedMinutes} min'),
                      if (task.note.isNotEmpty)
                        const _Meta(
                            icon: Icons.sticky_note_2_outlined, text: '备注'),
                    ]),
                  ],
                ),
              ),
              IconButton(
                key: Key('delete_${task.id}'),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.inkSoft,
                tooltip: '删除',
                onPressed: onDelete,
              ),
              IconButton(
                key: Key('check_${task.id}'),
                icon: Icon(
                  checkedToday
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: checkedToday ? AppColors.gold : AppColors.inkSoft,
                  size: 26,
                ),
                tooltip: checkedToday ? '取消今日打卡' : '今日打卡',
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Meta({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, color: c)),
    ]);
  }
}

/// 月历下方：所选日期当天应打卡的任务与打卡状态。
class _DayTasksCard extends StatelessWidget {
  final DateTime day;

  const _DayTasksCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyPlanStore>();
    final scheduled =
        store.tasks.where((t) => StudySchedule.isScheduledOn(t, day)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DayKey.of(day)} 当天',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (scheduled.isEmpty)
              const Text('当天没有安排',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft))
            else
              for (final t in scheduled)
                InkWell(
                  onTap: () => store.toggleCheckin(t.id, day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          store.isCheckedOn(t.id, day)
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: store.isCheckedOn(t.id, day)
                              ? AppColors.gold
                              : AppColors.inkSoft,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(t.title,
                                style: const TextStyle(fontSize: 14))),
                        Text(store.planCategory(t.planId) ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlanState extends StatelessWidget {
  final Future<void> Function() onRestore;
  final VoidCallback onCreate;

  const _EmptyPlanState({required this.onRestore, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_note_rounded,
                size: 56, color: AppColors.gold),
            const SizedBox(height: 14),
            const Text('还没有学习计划',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              '可以一键导入 2025 示例计划（编曲/混音/分轨/乐器），\n或从零新建自己的任务。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => onRestore(),
              child: const Text('导入 2025 模板'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onCreate,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('新建任务'),
            ),
          ],
        ),
      ),
    );
  }
}
