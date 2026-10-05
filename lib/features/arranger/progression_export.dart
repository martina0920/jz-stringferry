import '../../core/models/progression.dart';
import '../../core/theory/key_harmony.dart';

/// 编曲进行的分享/剪贴板文本（两行，FR-18/FR-19）。
///
/// - 首行：`J&Z 弦渡编曲分享｜C 大调（4/4 · 90BPM）`
/// - 次行：`C → Am → F → G（I → vi → IV → V）`
///
/// [overrideKey]/[overrideChords] 仅用于「换个调分享」的预览，不回写原曲；
/// 级数始终按实际输出和弦所属的目标调反推。
String buildExportText({
  required Progression progression,
  MusicKey? overrideKey,
  List<String>? overrideChords,
}) {
  final key = overrideKey ?? progression.key;
  final chords = overrideChords ?? progression.chords;

  final header = 'J&Z 弦渡编曲分享｜${key.displayName}'
      '（${progression.timeSignature.label} · ${progression.bpm}BPM）';
  final numerals =
      chords.map((c) => romanNumeral(c, key)).toList().join(' → ');
  return '$header\n${chords.join(' → ')}（$numerals）';
}
