/// 学习计划域模型（study_plans / study_tasks / checkins）。
class StudyPlan {
  final String id;
  final String title;
  final String category;
  final int sortKey;
  final int createdAt;

  const StudyPlan({
    required this.id,
    required this.title,
    required this.category,
    this.sortKey = 0,
    required this.createdAt,
  });

  factory StudyPlan.fromMap(Map<String, Object?> m) => StudyPlan(
        id: m['id'] as String,
        title: m['title'] as String,
        category: m['category'] as String,
        sortKey: (m['sort_key'] as int?) ?? 0,
        createdAt: m['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'sort_key': sortKey,
        'created_at': createdAt,
      };

  StudyPlan copyWith({String? title, String? category, int? sortKey}) =>
      StudyPlan(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        sortKey: sortKey ?? this.sortKey,
        createdAt: createdAt,
      );
}

/// 任务周期（对应 study_tasks.repeat_rule）。
enum RepeatRule {
  none('none'),
  daily('daily'),
  weekly('weekly');

  final String wire;
  const RepeatRule(this.wire);

  static RepeatRule fromWire(String? v) => RepeatRule.values.firstWhere(
        (r) => r.wire == v,
        orElse: () => RepeatRule.none,
      );

  String get label => switch (this) {
        RepeatRule.none => '单次',
        RepeatRule.daily => '每天',
        RepeatRule.weekly => '每周',
      };
}

/// 任务优先级（study_tasks.priority）。
enum TaskPriority {
  high('high'),
  mid('mid'),
  low('low');

  final String wire;
  const TaskPriority(this.wire);

  static TaskPriority fromWire(String? v) => TaskPriority.values.firstWhere(
        (p) => p.wire == v,
        orElse: () => TaskPriority.mid,
      );

  String get label => switch (this) {
        TaskPriority.high => '高',
        TaskPriority.mid => '中',
        TaskPriority.low => '低',
      };
}

class StudyTask {
  final String id;
  final String planId;
  final String title;

  /// ISO yyyy-MM-dd，可空。
  final String? dueDate;
  final RepeatRule repeat;
  final TaskPriority priority;
  final int estimatedMinutes;
  final String note;
  final int createdAt;

  const StudyTask({
    required this.id,
    required this.planId,
    required this.title,
    this.dueDate,
    this.repeat = RepeatRule.none,
    this.priority = TaskPriority.mid,
    this.estimatedMinutes = 0,
    this.note = '',
    required this.createdAt,
  });

  factory StudyTask.fromMap(Map<String, Object?> m) => StudyTask(
        id: m['id'] as String,
        planId: m['plan_id'] as String,
        title: m['title'] as String,
        dueDate: m['due_date'] as String?,
        repeat: RepeatRule.fromWire(m['repeat_rule'] as String?),
        priority: TaskPriority.fromWire(m['priority'] as String?),
        estimatedMinutes: (m['estimated_minutes'] as int?) ?? 0,
        note: (m['note'] as String?) ?? '',
        createdAt: m['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'plan_id': planId,
        'title': title,
        'due_date': dueDate,
        'repeat_rule': repeat.wire,
        'priority': priority.wire,
        'estimated_minutes': estimatedMinutes,
        'note': note,
        'created_at': createdAt,
      };

  StudyTask copyWith({
    String? title,
    String? dueDate,
    RepeatRule? repeat,
    TaskPriority? priority,
    int? estimatedMinutes,
    String? note,
    String? planId,
  }) =>
      StudyTask(
        id: id,
        planId: planId ?? this.planId,
        title: title ?? this.title,
        dueDate: dueDate ?? this.dueDate,
        repeat: repeat ?? this.repeat,
        priority: priority ?? this.priority,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        note: note ?? this.note,
        createdAt: createdAt,
      );
}

/// 打卡记录（复合主键 task_id + date）。
class Checkin {
  final String taskId;

  /// ISO yyyy-MM-dd（自然日）。
  final String date;
  final int createdAt;

  const Checkin({
    required this.taskId,
    required this.date,
    required this.createdAt,
  });

  factory Checkin.fromMap(Map<String, Object?> m) => Checkin(
        taskId: m['task_id'] as String,
        date: m['date'] as String,
        createdAt: m['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'task_id': taskId,
        'date': date,
        'created_at': createdAt,
      };
}

/// 日期工具：统一 yyyy-MM-dd，避免时区分歧。
class DayKey {
  DayKey._();

  static String of(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime parse(String key) => DateTime.parse(key);

  static String today() => of(DateTime.now());
}
