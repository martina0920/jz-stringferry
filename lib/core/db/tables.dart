/// 全部数据库表的 DDL 定义。
///
/// 单一定义点：建库（onCreate）与重置（resetAll）都从这里取 DDL，
/// 避免两处维护导致的结构漂移。
class Tables {
  Tables._();

  /// 建表顺序（被引用表在前）。
  static const List<String> createDdl = [
    _meta,
    _chords,
    _favorites,
    _recentQueries,
    _studyPlans,
    _studyTasks,
    _checkins,
    _progressions,
    _settings,
    _transcribeSongs,
    _transcribeSegments,
    _earTrainingStats,
  ];

  /// 删表顺序（引用表在前）。
  static const List<String> dropNames = [
    'transcribe_segments',
    'transcribe_songs',
    'ear_training_stats',
    'progressions',
    'checkins',
    'study_tasks',
    'study_plans',
    'recent_queries',
    'favorites',
    'chords',
    'meta',
    'settings',
  ];

  /// v1 → v2 增量 DDL（老库升级只执行新增部分，保护既有数据）。
  static const List<String> migrationV2Ddl = [
    _progressions,
  ];

  /// v2 → v3 增量 DDL（v0.4：设置 kv / 扒带曲库 / 音感训练统计）。
  static const List<String> migrationV3Ddl = [
    _settings,
    _transcribeSongs,
    _transcribeSegments,
    _earTrainingStats,
  ];

  /// resetUserData（恢复示例数据）不清的表：settings 存 API key，
  /// 抹掉会导致云端识别静默失效。
  static const List<String> resetExempt = ['settings'];

  /// 设置键值表（v0.4）。与 meta 的区别：meta 是种子版本信息会被
  /// resetUserData 清空重新播种，settings 必须在重置后保留。
  static const _settings = '''
CREATE TABLE settings (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
)''';

  /// 扒带曲库（v0.4）。file_path 为拷入应用文档目录后的绝对路径；
  /// source: import | record；调性/速度为人工或云端识别结果（可空）。
  static const _transcribeSongs = '''
CREATE TABLE transcribe_songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  file_path TEXT NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  bpm INTEGER,
  key_root_pc INTEGER,
  key_mode TEXT,
  source TEXT NOT NULL DEFAULT 'import',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''';

  /// 扒带分段（v0.4）。chords_text 为该段人工记下的和弦名（空格分隔）。
  static const _transcribeSegments = '''
CREATE TABLE transcribe_segments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  chords_text TEXT NOT NULL DEFAULT '',
  sort_key INTEGER NOT NULL DEFAULT 0
)''';

  /// 音感训练每日统计（v0.4），按「自然日 x 模式」累加。
  static const _earTrainingStats = '''
CREATE TABLE ear_training_stats (
  date TEXT NOT NULL,
  mode TEXT NOT NULL,
  correct INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (date, mode)
)''';

  /// 键值元信息表（种子版本等）。
  static const _meta = '''
CREATE TABLE meta (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
)''';

  /// 和弦库（乐理引擎程序化生成，>=500 条）。
  /// tones/intervals/fingerings 存 JSON 字符串。
  static const _chords = '''
CREATE TABLE chords (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  root TEXT NOT NULL,
  root_pc INTEGER NOT NULL,
  quality TEXT NOT NULL,
  family TEXT NOT NULL,
  tones TEXT NOT NULL,
  intervals TEXT NOT NULL,
  fingerings TEXT NOT NULL DEFAULT '[]',
  sort_key INTEGER NOT NULL DEFAULT 0
)''';

  /// 收藏的和弦。
  static const _favorites = '''
CREATE TABLE favorites (
  chord_id INTEGER PRIMARY KEY,
  created_at INTEGER NOT NULL
)''';

  /// 最近查询（上限 50 条，超量淘汰最旧）。
  static const _recentQueries = '''
CREATE TABLE recent_queries (
  chord_id INTEGER PRIMARY KEY,
  queried_at INTEGER NOT NULL
)''';

  /// 学习计划（一个分类下可有多个计划）。
  static const _studyPlans = '''
CREATE TABLE study_plans (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  sort_key INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''';

  /// 学习任务。due_date 为 ISO yyyy-MM-dd（可空）；
  /// repeat_rule: none / daily / weekly；priority: high / mid / low。
  static const _studyTasks = '''
CREATE TABLE study_tasks (
  id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL,
  title TEXT NOT NULL,
  due_date TEXT,
  repeat_rule TEXT NOT NULL DEFAULT 'none',
  priority TEXT NOT NULL DEFAULT 'mid',
  estimated_minutes INTEGER NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
)''';

  /// 打卡记录，按「任务 x 自然日」唯一。
  static const _checkins = '''
CREATE TABLE checkins (
  task_id TEXT NOT NULL,
  date TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (task_id, date)
)''';

  /// 编曲进行（v0.3）。chords 为和弦名有序 JSON 数组（每个和弦一小节）；
  /// key_mode: major / minor；time_signature: 4/4 | 3/4；
  /// pattern: strum | slowStrum | finger。
  static const _progressions = '''
CREATE TABLE progressions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  key_root_pc INTEGER NOT NULL,
  key_mode TEXT NOT NULL DEFAULT 'major',
  chords TEXT NOT NULL DEFAULT '[]',
  bpm INTEGER NOT NULL DEFAULT 90,
  time_signature TEXT NOT NULL DEFAULT '4/4',
  pattern TEXT NOT NULL DEFAULT 'strum',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''';
}
