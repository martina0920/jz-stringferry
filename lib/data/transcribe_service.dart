import 'dart:convert';

/// 云端识别结果中的一段（对齐 DB 的 transcribe_segments）。
class TranscribeSegmentResult {
  final int startMs;
  final int endMs;
  final String label;
  final List<String> chords;

  const TranscribeSegmentResult({
    required this.startMs,
    required this.endMs,
    this.label = '',
    this.chords = const [],
  });
}

/// 云端识别结果（对齐 DB 的 transcribe_songs 可空调性/速度字段）。
class TranscribeResult {
  final int? keyRootPc;

  /// major / minor（可空）。
  final String? keyMode;
  final int? bpm;

  /// 全曲和弦序列（按时间顺序）。
  final List<String> chords;
  final List<TranscribeSegmentResult> segments;

  const TranscribeResult({
    this.keyRootPc,
    this.keyMode,
    this.bpm,
    this.chords = const [],
    this.segments = const [],
  });
}

/// 云端识别失败（消息直接面向用户展示）。
///
/// [retryable] 为 true 表示值得重试一次（模型输出不合法）；
/// 请求层网络/超时/5xx 的重试由服务自身控制，不经此标记。
class TranscribeException implements Exception {
  final String message;
  final bool retryable;
  TranscribeException(this.message, {this.retryable = false});

  @override
  String toString() => message;
}

/// 云端识别服务抽象（生产为 Qwen-Omni，测试注入 Fake）。
abstract class TranscribeService {
  /// 识别一段本地音频。apiKey 为空时抛 [TranscribeException]。
  Future<TranscribeResult> transcribe({
    required String filePath,
    required String? apiKey,
  });
}

/// 模型返回文本 → [TranscribeResult] 的容错解析（纯函数，无 IO）。
///
/// 容错点：
/// 1. 剥 ```json 围栏与前后杂文，提取首个配平的 {...}；
/// 2. 字段缺省安全（调性/速度/分段均可缺）；
/// 3. 调性兼容数字（key_root_pc）与字符串（"C 大调"/"Am"）两种形态；
/// 4. 和弦名按正则校验，非法项直接丢弃。
class TranscribeResultParser {
  TranscribeResultParser._();

  static const _rootNames = {
    'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3,
    'E': 4, 'F': 5, 'F#': 6, 'GB': 6, 'G': 7, 'G#': 8, 'AB': 8,
    'A': 9, 'A#': 10, 'BB': 10, 'B': 11,
  };

  /// 放宽的和弦名形态：根音 + 可选 m/maj/dim/aug/sus/add/M +
  /// 可选数字 + 可选变化音（#b）+ 可选斜杠低音。
  static final _chordRe = RegExp(
      r'^[A-G][#b]?(m|maj|min|dim|aug|sus|add|M)?'
      r'[0-9]*(sus[24]|add[0-9]+|dim7|b5|#5|b9|#9|b13)?'
      r'(/[A-G][#b]?)?$');

  static TranscribeResult parse(String raw) {
    final map = _extractJsonMap(raw);
    if (map == null) {
      throw TranscribeException('模型返回内容无法解析为和弦信息',
          retryable: true);
    }

    final keyRoot = _parseKeyRoot(map);
    final keyMode = _parseKeyMode(map, keyRoot);
    final bpm = _parseInt(map['bpm']);
    final chords = _parseChords(map['chords']);
    final segments = _parseSegments(map['segments']);

    return TranscribeResult(
      keyRootPc: keyRoot,
      keyMode: keyMode,
      bpm: bpm,
      chords: chords,
      segments: segments,
    );
  }

  /// 剥围栏并提取首个配平的 {...}（忽略字符串内的括号）。
  static Map<String, dynamic>? _extractJsonMap(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();

    final start = text.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (ch == '"') inString = !inString;
      if (inString) continue;
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          final candidate = text.substring(start, i + 1);
          try {
            return jsonDecode(candidate) as Map<String, dynamic>;
          } on FormatException {
            return null;
          }
        }
      }
    }
    return null;
  }

  static int? _parseKeyRoot(Map<String, dynamic> map) {
    final direct = _parseInt(map['key_root_pc']);
    if (direct != null) return direct;
    final text = map['key'];
    if (text is! String) return null;
    final t = text.trim().toUpperCase();
    // 「C 大调」/「A MINOR」/「AM」/「F#」形态。
    final m = RegExp(r'([A-G])(#|B)?').firstMatch(t);
    if (m == null) return null;
    final name = '${m.group(1)}${m.group(2) ?? ''}';
    return _rootNames[name];
  }

  static String? _parseKeyMode(Map<String, dynamic> map, int? rootPc) {
    if (rootPc == null) return null;
    final direct = map['key_mode'];
    if (direct is String) {
      final d = direct.toLowerCase();
      if (d.startsWith('major') || d == '大调') return 'major';
      if (d.startsWith('minor') || d == '小调') return 'minor';
    }
    final text = map['key'];
    if (text is String) {
      final t = text.toLowerCase();
      if (t.contains('m') && !t.contains('maj')) return 'minor';
      if (t.contains('minor') || t.contains('小调')) return 'minor';
      if (t.contains('major') || t.contains('大调')) return 'major';
    }
    return null;
  }

  static int? _parseInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      final m = RegExp(r'-?\d+').firstMatch(v);
      if (m != null) return int.tryParse(m.group(0)!);
    }
    return null;
  }

  static List<String> _parseChords(Object? v) {
    if (v is! List) return const [];
    return [
      for (final item in v)
        if (item is String && _chordRe.hasMatch(item.trim())) item.trim(),
    ];
  }

  static List<TranscribeSegmentResult> _parseSegments(Object? v) {
    if (v is! List) return const [];
    final result = <TranscribeSegmentResult>[];
    for (final item in v) {
      if (item is! Map) continue;
      final start = _parseInt(item['start_ms'] ?? item['start']);
      final end = _parseInt(item['end_ms'] ?? item['end']);
      if (start == null || end == null || end <= start) continue;
      result.add(TranscribeSegmentResult(
        startMs: start,
        endMs: end,
        label: item['label'] is String ? item['label'] as String : '',
        chords: _parseChords(item['chords']),
      ));
    }
    return result;
  }
}
