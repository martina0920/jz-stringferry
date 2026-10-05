/// 练习笔记（notes 表一行，v0.5）。单文本块，按更新时间倒序展示。
class PracticeNote {
  final String id;
  final String content;
  final int updatedAt;

  const PracticeNote({
    required this.id,
    required this.content,
    required this.updatedAt,
  });

  factory PracticeNote.fromMap(Map<String, Object?> m) => PracticeNote(
        id: m['id'] as String,
        content: m['content'] as String,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'content': content,
        'updated_at': updatedAt,
      };

  PracticeNote copyWith({String? content, int? updatedAt}) => PracticeNote(
        id: id,
        content: content ?? this.content,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// 列表预览用：取第一行、限长。
  String get preview {
    final line = content.trim().isEmpty
        ? '(空笔记)'
        : content.trim().split('\n').first;
    return line.length > 40 ? '${line.substring(0, 40)}…' : line;
  }

  /// 业务 id 生成（与 ProgressionIds 同风格）。
  static String newId() =>
      'note_${DateTime.now().microsecondsSinceEpoch}_${(++_seq)}';

  static int _seq = 0;
}
