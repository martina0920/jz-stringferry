/// 学习计划数据模型
class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.title,
    required this.category,
    required this.tasks,
  });

  final String id;
  final String title;

  /// 分类：编曲类 / 混音类 / 分轨类 / 乐器类……
  final String category;

  final List<StudyTask> tasks;
}

class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    this.done = false,
    this.deadline,
    this.cycle,
    this.estimatedMinutes,
  });

  final String id;
  final String title;

  /// 是否已完成（打卡）
  final bool done;

  /// 截止日期
  final DateTime? deadline;

  /// 执行周期：每天 / 每周 / 自定义
  final String? cycle;

  /// 预计耗时（分钟），用于耗时统计
  final int? estimatedMinutes;

  StudyTask copyWith({bool? done}) {
    return StudyTask(
      id: id,
      title: title,
      done: done ?? this.done,
      deadline: deadline,
      cycle: cycle,
      estimatedMinutes: estimatedMinutes,
    );
  }
}
