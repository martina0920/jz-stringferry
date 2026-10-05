import 'package:flutter/material.dart';

import '../../../core/models/study_models.dart';
import '../../../core/theme/app_theme.dart';

/// 月历打点卡：任意任务在该日有打卡即显示金色圆点。
class StudyCalendar extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final Set<String> markedKeys;
  final ValueChanged<DateTime> onPrevMonth;
  final ValueChanged<DateTime> onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  const StudyCalendar({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.markedKeys,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    // 周一为首列：weekday 周一=1 → 偏移 0。
    final leadBlanks = first.weekday - 1;
    final todayKey = DayKey.today();
    final selectedKey = DayKey.of(selectedDay);

    final cells = <Widget>[];
    for (var i = 0; i < leadBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(visibleMonth.year, visibleMonth.month, d);
      final key = DayKey.of(day);
      final isToday = key == todayKey;
      final isSelected = key == selectedKey;
      cells.add(GestureDetector(
        onTap: () => onSelectDay(day),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.ink : null,
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.gold, width: 1.4)
                    : null,
              ),
              child: Text(
                '$d',
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? Colors.white : AppColors.ink,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markedKeys.contains(key)
                    ? AppColors.gold
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => onPrevMonth(
                      DateTime(visibleMonth.year, visibleMonth.month - 1)),
                ),
                Expanded(
                  child: Text(
                    '${visibleMonth.year} 年 ${visibleMonth.month} 月',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => onNextMonth(
                      DateTime(visibleMonth.year, visibleMonth.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}
