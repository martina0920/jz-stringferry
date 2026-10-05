import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/audio/instrument.dart';

void main() {
  test('AC-7 尼龙吉他采样覆盖 MIDI 40–76 且总体积 ≤ 8MB', () {
    var total = 0;
    for (var midi = 40; midi <= 76; midi++) {
      final f = File('assets/audio/guitar/$midi.wav');
      expect(f.existsSync(), isTrue, reason: '缺少采样 $midi.wav');
      total += f.lengthSync();
    }
    expect(total, lessThanOrEqualTo(8 * 1024 * 1024),
        reason: '采样总体积 ${(total / 1024 / 1024).toStringAsFixed(2)}MB 超 8MB');
  });

  test('v0.4 新乐器采样齐全（各 37 个）且单乐器 ≤ 6MB', () {
    for (final inst in [
      pianoInstrument,
      epInstrument,
      eGuitarInstrument,
      bassInstrument,
    ]) {
      var total = 0;
      for (var midi = inst.lowMidi; midi <= inst.highMidi; midi++) {
        final f = File('assets/audio/${inst.assetDir}/$midi.wav');
        expect(f.existsSync(), isTrue,
            reason: '${inst.label} 缺少采样 $midi.wav');
        total += f.lengthSync();
      }
      expect(total, lessThanOrEqualTo(6 * 1024 * 1024),
          reason:
              '${inst.label} 采样总体积 ${(total / 1024 / 1024).toStringAsFixed(2)}MB 超 6MB');
    }
  });

  test('节拍器鼓组三件采样存在', () {
    for (final path in ['assets/audio/drums/kick.wav',
      'assets/audio/drums/snare.wav',
      'assets/audio/drums/hat.wav']) {
      expect(File(path).existsSync(), isTrue, reason: '缺少 $path');
    }
  });

  test('pubspec.yaml 注册了全部采样目录', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    for (final dir in [
      'assets/audio/guitar/',
      'assets/audio/piano/',
      'assets/audio/ep/',
      'assets/audio/eguitar/',
      'assets/audio/bass/',
      'assets/audio/drums/',
    ]) {
      expect(yaml.contains('- $dir'), isTrue, reason: 'pubspec 缺少 $dir');
    }
  });
}
