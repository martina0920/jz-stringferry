import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/models/progression.dart';
import 'package:jz_stringferry/core/theory/key_harmony.dart';
import 'package:jz_stringferry/features/arranger/progression_export.dart';

Progression _p({
  int rootPc = 0,
  KeyMode mode = KeyMode.major,
  List<String> chords = const ['C', 'Am', 'F', 'G'],
  int bpm = 90,
  TimeSignature ts = TimeSignature.fourFour,
}) {
  final now = DateTime(2025).millisecondsSinceEpoch;
  return Progression(
    id: 't1',
    title: '测试',
    keyRootPc: rootPc,
    keyMode: mode,
    chords: chords,
    bpm: bpm,
    timeSignature: ts,
    pattern: AccomPattern.strum,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('buildExportText', () {
    test('C 大调 1645 默认参数逐字输出两行', () {
      expect(
        buildExportText(progression: _p()),
        'J&Z 弦渡编曲分享｜C 大调（4/4 · 90BPM）\n'
        'C → Am → F → G（I → vi → IV → V）',
      );
    });

    test('3/4 拍号与自定义 BPM', () {
      final text = buildExportText(
        progression: _p(bpm: 120, ts: TimeSignature.threeFour),
      );
      expect(text,
          'J&Z 弦渡编曲分享｜C 大调（3/4 · 120BPM）\nC → Am → F → G（I → vi → IV → V）');
    });

    test('换调分享：转调和弦 + 目标调级数', () {
      final text = buildExportText(
        progression: _p(),
        overrideKey: const MusicKey(10, KeyMode.major), // Bb
        overrideChords: const ['Bb', 'Gm', 'Eb', 'F'],
      );
      expect(
        text,
        'J&Z 弦渡编曲分享｜Bb 大调（4/4 · 90BPM）\n'
        'Bb → Gm → Eb → F（I → vi → IV → V）',
      );
    });

    test('小调级数：i iv V i', () {
      final text = buildExportText(
        progression: _p(
          rootPc: 9,
          mode: KeyMode.minor,
          chords: const ['Am', 'Dm', 'E', 'Am'],
        ),
      );
      expect(
        text,
        'J&Z 弦渡编曲分享｜A 小调（4/4 · 90BPM）\n'
        'Am → Dm → E → Am（i → iv → V → i）',
      );
    });
  });
}
