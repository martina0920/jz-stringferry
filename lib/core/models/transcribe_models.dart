/// 扒带曲库的一首歌（transcribe_songs 行）。
class TranscribeSong {
  final String id;
  final String title;

  /// 采样文件在应用文档目录下的绝对路径。
  final String filePath;

  /// 音频时长（毫秒），导入/录音后探测；0 = 未知。
  final int durationMs;

  /// 调性/速度（人工或云端识别，可空）。
  final int? bpm;
  final int? keyRootPc;

  /// major / minor（keyRootPc 非空时有意义）。
  final String? keyMode;

  /// import（本地导入）| record（应用内录音）。
  final String source;
  final int createdAt;
  final int updatedAt;

  const TranscribeSong({
    required this.id,
    required this.title,
    required this.filePath,
    this.durationMs = 0,
    this.bpm,
    this.keyRootPc,
    this.keyMode,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  static TranscribeSong fromMap(Map<String, Object?> m) => TranscribeSong(
        id: m['id'] as String,
        title: m['title'] as String,
        filePath: m['file_path'] as String,
        durationMs: (m['duration_ms'] as int?) ?? 0,
        bpm: m['bpm'] as int?,
        keyRootPc: m['key_root_pc'] as int?,
        keyMode: m['key_mode'] as String?,
        source: (m['source'] as String?) ?? 'import',
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'duration_ms': durationMs,
        'bpm': bpm,
        'key_root_pc': keyRootPc,
        'key_mode': keyMode,
        'source': source,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  TranscribeSong copyWith({
    String? title,
    String? filePath,
    int? durationMs,
    int? bpm,
    Object? keyRootPc = _unset,
    Object? keyMode = _unset,
    int? updatedAt,
  }) =>
      TranscribeSong(
        id: id,
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        durationMs: durationMs ?? this.durationMs,
        bpm: bpm ?? this.bpm,
        keyRootPc: keyRootPc == _unset ? this.keyRootPc : keyRootPc as int?,
        keyMode: keyMode == _unset ? this.keyMode : keyMode as String?,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static const Object _unset = Object();
}

/// 扒带分段（transcribe_segments 行）。
class TranscribeSegment {
  final int? id;
  final String songId;
  final int startMs;
  final int endMs;
  final String label;

  /// 该段人工记下的和弦名（空格分隔，如 "C Am F G"）。
  final String chordsText;
  final int sortKey;

  const TranscribeSegment({
    this.id,
    required this.songId,
    required this.startMs,
    required this.endMs,
    this.label = '',
    this.chordsText = '',
    required this.sortKey,
  });

  static TranscribeSegment fromMap(Map<String, Object?> m) =>
      TranscribeSegment(
        id: m['id'] as int?,
        songId: m['song_id'] as String,
        startMs: (m['start_ms'] as int?) ?? 0,
        endMs: (m['end_ms'] as int?) ?? 0,
        label: (m['label'] as String?) ?? '',
        chordsText: (m['chords_text'] as String?) ?? '',
        sortKey: (m['sort_key'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'song_id': songId,
        'start_ms': startMs,
        'end_ms': endMs,
        'label': label,
        'chords_text': chordsText,
        'sort_key': sortKey,
      };

  TranscribeSegment copyWith({
    int? startMs,
    int? endMs,
    String? label,
    String? chordsText,
    int? sortKey,
  }) =>
      TranscribeSegment(
        id: id,
        songId: songId,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        label: label ?? this.label,
        chordsText: chordsText ?? this.chordsText,
        sortKey: sortKey ?? this.sortKey,
      );
}
