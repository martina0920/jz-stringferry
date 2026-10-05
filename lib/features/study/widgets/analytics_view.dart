import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/study_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/study_analytics.dart';
import '../state/study_plan_store.dart';

/// 学习计划「分析」视图：连续天数、近 7 天柱状、分类完成率、薄弱项、临逾期。
class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StudyPlanStore>();
    final report = StudyAnalytics.build(
      plans: store.plans,
      tasks: store.tasks,
      checkins: store.checkinSnapshot,
    );

    if (store.tasks.isEmpty) {
      return const Center(
        child: Text('暂无任务数据，先在「计划」里创建或导入模板吧',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                Text('${report.streakDays}',
                    key: const Key('streak_value'),
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        height: 1.1)),
                const SizedBox(height: 4),
                const Text('连续打卡天数',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('近 7 天打卡',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: _BarsPainter(report.last7DailyCounts),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('各分类完成率',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                for (final s in report.categories) _CategoryRateRow(stat: s),
                const Divider(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _MinutesStat(
                          label: '计划总耗时',
                          value: '${report.totalPlannedMinutes} min'),
                    ),
                    Expanded(
                      child: _MinutesStat(
                          label: '已完成耗时',
                          value: '${report.completedMinutes} min'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (report.weakestCategory != null) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '薄弱项：「${report.weakestCategory}」完成率最低，建议优先安排练习。',
                      style:
                          const TextStyle(fontSize: 13.5, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (report.dueSoon.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ReminderList(
            title: '临期任务（3 天内）',
            color: AppColors.gold,
            icon: Icons.schedule_rounded,
            tasks: report.dueSoon,
          ),
        ],
        if (report.overdue.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ReminderList(
            title: '已逾期',
            color: const Color(0xFFB3261E),
            icon: Icons.error_outline_rounded,
            tasks: report.overdue,
          ),
        ],
      ],
    );
  }
}

class _CategoryRateRow extends StatelessWidget {
  final CategoryStat stat;

  const _CategoryRateRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = (stat.completionRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.category,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              Text('${stat.completedCount}/${stat.taskCount}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const SizedBox(width: 8),
              Text('$pct%',
                  key: Key('rate_${stat.category}'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.completionRate,
              minHeight: 7,
              backgroundColor: AppColors.mist,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinutesStat extends StatelessWidget {
  final String label;
  final String value;

  const _MinutesStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _ReminderList extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<StudyTask> tasks;

  const _ReminderList({
    required this.title,
    required this.color,
    required this.icon,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
            const SizedBox(height: 8),
            for (final t in tasks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          Text(t.title, style: const TextStyle(fontSize: 13.5)),
                    ),
                    if (t.dueDate != null)
                      Text(t.dueDate!,
                          style: TextStyle(fontSize: 12, color: color)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 近 7 天打卡柱状图。
class _BarsPainter extends CustomPainter {
  final List<int> counts;

  _BarsPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    const gap = 14.0;
    final barW = (size.width - gap * (counts.length - 1)) / counts.length;
    final baseline = size.height - 22;
    final chartH = baseline - 6;

    final barPaint = Paint()..color = AppColors.ink;
    final goldPaint = Paint()..color = AppColors.gold;
    const labelStyle =
        TextStyle(color: AppColors.inkSoft, fontSize: 10, height: 1);

    for (var i = 0; i < counts.length; i++) {
      final x = i * (barW + gap);
      final h = maxCount == 0 ? 0.0 : counts[i] / maxCount * chartH;
      final isToday = i == counts.length - 1;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseline - h, barW, h == 0 ? 2 : h),
        const Radius.circular(4),
      );
      canvas.drawRRect(
          r, counts[i] > 0 ? (isToday ? goldPaint : barPaint) : barPaint);
      if (counts[i] > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${counts[i]}', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas, Offset(x + barW / 2 - tp.width / 2, baseline - h - 14));
      }
      final week = TextPainter(
        text: TextSpan(
            text: '${6 - i}天前'.replaceFirst('0天前', '今天'), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      week.paint(canvas, Offset(x + barW / 2 - week.width / 2, baseline + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.counts != counts;
}
