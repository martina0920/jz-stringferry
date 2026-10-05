import '../core/theory/key_harmony.dart';
import '../core/theory/note.dart';
import '../core/theory/progression_template.dart';
import 'chord_repository.dart';
import 'study_analytics.dart';

/// 对话服务抽象（v0.3 可替换为云端实现，调用方无感知）。
abstract class ChatService {
  Future<String> ask(String message, {StudySnapshot? study});

  /// 识别消息中的编曲进行意图；无法识别为具体进行时返回 null（FR-21）。
  ProgressionDraft? suggestProgression(String message);
}

/// AI 识别出的、可一键发送到编曲台的进行草稿。
class ProgressionDraft {
  final String title;
  final MusicKey key;
  final List<String> chords;

  const ProgressionDraft({
    required this.title,
    required this.key,
    required this.chords,
  });
}

/// 学习进度快照（由 UI 层用 StudyAnalytics 报告映射，避免 data 层依赖状态层）。
class StudySnapshot {
  final int taskCount;
  final int completedCount;
  final int streakDays;
  final int completedMinutes;
  final int totalPlannedMinutes;
  final int overdueCount;
  final String? weakestCategory;

  const StudySnapshot({
    required this.taskCount,
    required this.completedCount,
    required this.streakDays,
    required this.completedMinutes,
    required this.totalPlannedMinutes,
    required this.overdueCount,
    this.weakestCategory,
  });

  factory StudySnapshot.fromReport(AnalyticsReport r) => StudySnapshot(
        taskCount: r.categories.fold(0, (n, s) => n + s.taskCount),
        completedCount: r.categories.fold(0, (n, s) => n + s.completedCount),
        streakDays: r.streakDays,
        completedMinutes: r.completedMinutes,
        totalPlannedMinutes: r.totalPlannedMinutes,
        overdueCount: r.overdue.length,
        weakestCategory: r.weakestCategory,
      );
}

/// v0.2 离线本地模拟：纯规则意图识别 + 本地知识库，不发起任何网络请求。
class LocalChatService implements ChatService {
  final ChordRepository? chordRepo;

  LocalChatService({this.chordRepo});

  /// 恢复示例数据后调用：清空和弦内存缓存，下次查询重新读库。
  void invalidateCaches() => chordRepo?.invalidateCache();

  static const String offlineHint = '当前为离线本地模式，我可以帮你查和弦组成音、讲解常用和弦进行、汇总学习进度。'
      'v0.3 接入 AI 后可回答更多问题。';

  @override
  Future<String> ask(String message, {StudySnapshot? study}) async {
    final msg = message.trim();
    if (msg.isEmpty) return offlineHint;

    // 进行意图必须先于和弦判定：「推荐一个 C 调的常用和弦进行」同时命中两者，
    // 若先查和弦会被句中的裸音名「C」截胡。
    if (msg.contains('进行') ||
        msg.contains('1645') ||
        msg.contains('1564') ||
        msg.contains('级数')) {
      return _answerProgression(msg);
    }

    if (msg.contains('和弦') || _looksLikeChordQuery(msg)) {
      final chordAnswer = await _answerChord(msg);
      if (chordAnswer != null) return chordAnswer;
    }

    if (msg.contains('进度') ||
        msg.contains('计划') ||
        msg.contains('统计') ||
        msg.contains('打卡')) {
      return _answerProgress(study);
    }

    return offlineHint;
  }

  /// 裸输入如「Am7」「f#m7b5」也按查和弦处理；纯调名「C 调」不算
  /// （「调」通常属于进行类问题，已在前面的分支处理）。
  bool _looksLikeChordQuery(String msg) {
    const bare = r'^\s*[A-Ga-g](?:#|b)?'
        r'(?:maj|min|dim|aug|sus|add|m|M)?[0-9]{0,2}(?:#5|b5|#9|b9|#11|b13|add\d+|sus[24])*\s*$';
    return RegExp(bare).hasMatch(msg) && !msg.contains('调');
  }

  /// 从句中提取第一个可解析的和弦记号，如「Am7 和弦怎么按」中的 Am7。
  Future<String?> _answerChord(String msg) async {
    final repo = chordRepo;
    if (repo == null) return null;

    final matches = RegExp(r'[A-Ga-g](?:#|b)?[A-Za-z0-9]*').allMatches(msg);
    for (final m in matches) {
      final token = m.group(0)!;
      final results = await repo.search(token);
      if (results.isEmpty) continue;
      final spec = results.first;
      final flat = Note.prefersFlat(spec.root);
      final toneNames = spec.tones
          .map((t) => Note(Note.pitchClassOf(t)).name(flat: flat))
          .toSet()
          .toList();
      return '${spec.name}（${spec.family}）的组成音是：${toneNames.join('、')}。\n'
          '音程构成：${spec.intervalText}。\n'
          '共 ${spec.fingerings.length} 种指法，可在「和弦查询」中查看指法图与试听。';
    }
    return null;
  }

  /// 从句中解析调性：支持「C 调」「Bb 大调」「A 小调」；缺省 C 大调。
  MusicKey _parseKey(String msg) {
    final keyMatch = RegExp(r'([A-G][#b]?)\s*(大|小)?调').firstMatch(msg);
    final rootPc =
        keyMatch == null ? 0 : Note.pitchClassOf(keyMatch.group(1)!);
    final minor = keyMatch?.group(2) == '小' ||
        msg.toLowerCase().contains('minor');
    return MusicKey(rootPc, minor ? KeyMode.minor : KeyMode.major);
  }

  @override
  ProgressionDraft? suggestProgression(String message) {
    final msg = message.trim();
    // 仅明确的「进行/1645/1564」意图才给草稿；泛泛问「级数」不给。
    if (!msg.contains('进行') &&
        !msg.contains('1645') &&
        !msg.contains('1564')) {
      return null;
    }

    final key = _parseKey(msg);
    final String templateId;
    final String tag;
    if (key.mode == KeyMode.minor) {
      // 小调只维护一个万能模板，1564 问句同样落到它。
      templateId = 'minor1645';
      tag = msg.contains('1564') ? '1564' : '1645';
    } else if (msg.contains('1564')) {
      templateId = 'p1564';
      tag = '1564';
    } else {
      templateId = 'p1645';
      tag = '1645';
    }

    return ProgressionDraft(
      title: '${key.displayName} $tag',
      key: key,
      chords: templateById(templateId)!.instantiate(key),
    );
  }

  String _answerProgression(String msg) {
    // 调号/顺阶拼写与和弦名称统一走乐理模块（禁止在本类再维护映射表）。
    // 用户口语询问按大调作答。
    final key = MusicKey(_parseKey(msg).rootPc, KeyMode.major);

    if (msg.contains('1564')) {
      final c = templateById('p1564')!.instantiate(key);
      return '${key.rootName} 大调 1564 进行：${c[0]} → ${c[1]} → '
          '${c[2]} → ${c[3]}（级数 I–V–vi–IV）。\n'
          '大量流行抒情歌使用这一走向，适合柱式和弦入门练习。';
    }

    // 默认 / 1645
    final c = templateById('p1645')!.instantiate(key);
    final alt = templateById('p1564')!.instantiate(key);
    return '${key.rootName} 大调 1645 进行：${c[0]} → ${c[1]} → '
        '${c[2]} → ${c[3]}（级数 I–vi–IV–V）。\n'
        '这是最常见的流行走向之一，可用分解和弦或扫弦循环练习。\n'
        '另一个常见走向 1564：${alt[0]}–${alt[1]}–${alt[2]}–${alt[3]}。';
  }

  String _answerProgress(StudySnapshot? study) {
    if (study == null || study.taskCount == 0) {
      return '还没有学习数据，去「学习计划」导入 2025 模板或新建任务吧。';
    }
    final rate = study.taskCount == 0
        ? 0
        : (study.completedCount * 100 / study.taskCount).round();
    final lines = [
      '你当前共有 ${study.taskCount} 个任务，已完成 ${study.completedCount} 个（$rate%）。',
      '连续打卡 ${study.streakDays} 天，累计已练 ${study.completedMinutes} 分钟'
          '（计划总时长 ${study.totalPlannedMinutes} 分钟）。',
      if (study.weakestCategory != null)
        '薄弱分类是「${study.weakestCategory}」，建议优先安排。',
      if (study.overdueCount > 0) '有 ${study.overdueCount} 个任务已逾期，记得补卡或调整截止日。',
    ];
    return lines.join('\n');
  }
}
