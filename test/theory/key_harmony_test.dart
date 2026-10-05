import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/theory/key_harmony.dart';
void main() {
  group('调性模型与规范调名（FR-1/FR-2）', () {
    test('24 个调的 displayName 与规范名', () {
      final major = MusicKey.allMajor;
      expect(major.map((k) => k.rootName).toList(), [
        'C', 'Db', 'D', 'Eb', 'E', 'F', //
        'F#', 'G', 'Ab', 'A', 'Bb', 'B',
      ]);
      final minor = MusicKey.allMinor;
      expect(minor.map((k) => k.rootName).toList(), [
        'C', 'C#', 'D', 'Eb', 'E', 'F', //
        'F#', 'G', 'G#', 'A', 'Bb', 'B',
      ]);
      expect(const MusicKey(0, KeyMode.major).displayName, 'C 大调');
      expect(const MusicKey(10, KeyMode.minor).displayName, 'Bb 小调');
    });

    test('白键名调的降号判定：F 大调与小调关系大调', () {
      // F 大调根音名不带 b，但顺阶必须用降号（Bb）。
      expect(const MusicKey(5, KeyMode.major).useFlats, isTrue);
      // D 小调关系大调 F → 降号；C 小调关系 Eb → 降号；G 小调关系 Bb → 降号。
      expect(const MusicKey(2, KeyMode.minor).useFlats, isTrue);
      expect(const MusicKey(0, KeyMode.minor).useFlats, isTrue);
      expect(const MusicKey(7, KeyMode.minor).useFlats, isTrue);
      // A 小调（关系 C）、E 小调（关系 G）、B 小调（关系 D）用升号侧。
      expect(const MusicKey(9, KeyMode.minor).useFlats, isFalse);
      expect(const MusicKey(4, KeyMode.minor).useFlats, isFalse);
      expect(const MusicKey(11, KeyMode.minor).useFlats, isFalse);
      // 显式升降号名直接判定。
      expect(const MusicKey(1, KeyMode.major).useFlats, isTrue); // Db
      expect(const MusicKey(6, KeyMode.major).useFlats, isFalse); // F#
      expect(const MusicKey(3, KeyMode.minor).useFlats, isTrue); // Ebm
      expect(const MusicKey(1, KeyMode.minor).useFlats, isFalse); // C#m
    });

    test('相等性按 pc+mode', () {
      expect(const MusicKey(0, KeyMode.major), const MusicKey(0, KeyMode.major));
      expect(const MusicKey(0, KeyMode.major) ==
          const MusicKey(0, KeyMode.minor), isFalse);
    });
  });

  group('顺阶三和弦（FR-3，AC-1）', () {
    test('C 大调：C Dm Em F G Am Bdim', () {
      expect(const MusicKey(0, KeyMode.major).diatonicTriads(),
          ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim']);
    });

    test('A 自然小调：Am Bdim C Dm Em F G', () {
      expect(const MusicKey(9, KeyMode.minor).diatonicTriads(),
          ['Am', 'Bdim', 'C', 'Dm', 'Em', 'F', 'G']);
    });

    test('降号调：F/Bb 大调拼写', () {
      final f = const MusicKey(5, KeyMode.major).diatonicTriads();
      expect(f, ['F', 'Gm', 'Am', 'Bb', 'C', 'Dm', 'Edim']);
      final bb = const MusicKey(10, KeyMode.major).diatonicTriads();
      expect(bb, ['Bb', 'Cm', 'Dm', 'Eb', 'F', 'Gm', 'Adim']);
      // 含 Eb、Ab 的调。
      expect(const MusicKey(3, KeyMode.major).diatonicTriads(),
          ['Eb', 'Fm', 'Gm', 'Ab', 'Bb', 'Cm', 'Ddim']);
    });

    test('D 小调顺阶出现 Bb 而非 A#', () {
      final dm = const MusicKey(2, KeyMode.minor).diatonicTriads();
      expect(dm, ['Dm', 'Edim', 'F', 'Gm', 'Am', 'Bb', 'C']);
      expect(dm.join(' '), isNot(contains('A#')));
    });

    test('升号调：G 大调 F#m、A 大调 F#m/C#m', () {
      expect(const MusicKey(7, KeyMode.major).diatonicTriads(),
          ['G', 'Am', 'Bm', 'C', 'D', 'Em', 'F#dim']);
      expect(const MusicKey(9, KeyMode.major).diatonicTriads(),
          ['A', 'Bm', 'C#m', 'D', 'E', 'F#m', 'G#dim']);
    });
  });

  group('顺阶七和弦（FR-3）', () {
    test('C 大七和弦行', () {
      expect(const MusicKey(0, KeyMode.major).diatonicSevenths(),
          ['Cmaj7', 'Dm7', 'Em7', 'Fmaj7', 'G7', 'Am7', 'Bm7b5']);
    });

    test('A 小七和弦行', () {
      expect(const MusicKey(9, KeyMode.minor).diatonicSevenths(),
          ['Am7', 'Bm7b5', 'Cmaj7', 'Dm7', 'Em7', 'Fmaj7', 'G7']);
    });

    test('degreeChordName 取级', () {
      const c = MusicKey(0, KeyMode.major);
      expect(c.degreeChordName(0), 'C');
      expect(c.degreeChordName(1, seventh: true), 'Dm7');
      expect(c.degreeChordName(4, seventh: true), 'G7');
      expect(c.degreeChordName(0, seventh: true), 'Cmaj7');
    });
  });

  group('转调（FR-4，AC-2）', () {
    test('半音差', () {
      expect(
        semitonesBetween(const MusicKey(0, KeyMode.major),
            const MusicKey(10, KeyMode.major)),
        10,
      ); // C→Bb
      expect(
        semitonesBetween(const MusicKey(10, KeyMode.major),
            const MusicKey(0, KeyMode.major)),
        2,
      ); // Bb→C
      expect(
        semitonesBetween(const MusicKey(0, KeyMode.major),
            const MusicKey(3, KeyMode.major)),
        3,
      ); // C→Eb
    });

    test('C→Bb（-2，降号拼写）', () {
      int d(int from, int to) =>
          semitonesBetween(MusicKey(from, KeyMode.major), MusicKey(to, KeyMode.major));
      final s = d(0, 10);
      expect(transposeChordName('C', s, targetUseFlats: true), 'Bb');
      expect(transposeChordName('Am', s, targetUseFlats: true), 'Gm');
      expect(transposeChordName('F', s, targetUseFlats: true), 'Eb');
      expect(transposeChordName('G', s, targetUseFlats: true), 'F');
    });

    test('C–Am–F–G → Eb 调 = Eb–Cm–Ab–Bb（AC-2）', () {
      const target = MusicKey(3, KeyMode.major);
      final s = semitonesBetween(
          const MusicKey(0, KeyMode.major), target);
      final r = ['C', 'Am', 'F', 'G']
          .map((c) => transposeChordName(c, s, targetUseFlats: target.useFlats))
          .toList();
      expect(r, ['Eb', 'Cm', 'Ab', 'Bb']);
    });

    test('转回调还原（Bb→C）', () {
      final toC = semitonesBetween(
          const MusicKey(10, KeyMode.major), const MusicKey(0, KeyMode.major));
      final back = ['Bb', 'Gm', 'Eb', 'F']
          .map((c) => transposeChordName(c, toC, targetUseFlats: false))
          .toList();
      expect(back, ['C', 'Am', 'F', 'G']);
    });

    test('251 七和弦 C→F（+5）（AC-2）', () {
      const target = MusicKey(5, KeyMode.major);
      final s = semitonesBetween(
          const MusicKey(0, KeyMode.major), target);
      expect(transposeChordName('Dm7', s, targetUseFlats: target.useFlats), 'Gm7');
      expect(transposeChordName('G7', s, targetUseFlats: target.useFlats), 'C7');
      expect(transposeChordName('Cmaj7', s, targetUseFlats: target.useFlats), 'Fmaj7');
    });

    test('C→G（+7）升号拼写', () {
      const target = MusicKey(7, KeyMode.major);
      final s = semitonesBetween(
          const MusicKey(0, KeyMode.major), target);
      final r = ['C', 'Am', 'F', 'G']
          .map((c) => transposeChordName(c, s, targetUseFlats: false))
          .toList();
      expect(r, ['G', 'Em', 'C', 'D']);
    });

    test('性质后缀在转调后保持：F#m7b5 下移大二度', () {
      expect(
        transposeChordName('F#m7b5', 10, targetUseFlats: true),
        'Em7b5',
      );
      expect(transposeChordName('Csus4', 2, targetUseFlats: false), 'Dsus4');
      expect(transposeChordName('Eadd9', 5, targetUseFlats: true), 'Aadd9');
    });

    test('小调间转调：Am→Em（-5/+7）', () {
      const target = MusicKey(4, KeyMode.minor); // Em
      final s = semitonesBetween(
          const MusicKey(9, KeyMode.minor), target);
      expect(transposeChordName('Am', s, targetUseFlats: false), 'Em');
      expect(transposeChordName('F', s, targetUseFlats: false), 'C');
      expect(transposeChordName('G', s, targetUseFlats: false), 'D');
    });
  });

  group('罗马级数反推（FR-5，AC-3）', () {
    const c = MusicKey(0, KeyMode.major);

    test('C 大调三和弦', () {
      expect(romanNumeral('C', c), 'I');
      expect(romanNumeral('Dm', c), 'ii');
      expect(romanNumeral('Em', c), 'iii');
      expect(romanNumeral('F', c), 'IV');
      expect(romanNumeral('G', c), 'V');
      expect(romanNumeral('Am', c), 'vi');
      expect(romanNumeral('Bdim', c), 'vii°');
    });

    test('七和弦（AC-3）', () {
      expect(romanNumeral('G7', c), 'V7');
      expect(romanNumeral('Dm7', c), 'ii7');
      expect(romanNumeral('Cmaj7', c), 'Imaj7');
      expect(romanNumeral('Bm7b5', c), 'viiø7');
      expect(romanNumeral('Bdim7', c), 'vii°7');
    });

    test('调外变化和弦用 ♯/♭（AC-3）', () {
      expect(romanNumeral('Bb', c), '♭VII');
      expect(romanNumeral('Eb', c), '♭III');
      expect(romanNumeral('Ab', c), '♭VI');
      expect(romanNumeral('Db', c), '♭II');
      expect(romanNumeral('F#', c), '♯IV');
      // 等音异拼：同一音响不同记法。
      expect(romanNumeral('C#', c), '♯I');
    });

    test('大小写按性质：D 大三 = II（非 ii）；G 属七 V7', () {
      expect(romanNumeral('D', c), 'II');
      expect(romanNumeral('Gm', c), 'v');
    });

    test('sus/add 后缀', () {
      expect(romanNumeral('Csus4', c), 'Isus4');
      expect(romanNumeral('Gsus4', c), 'Vsus4');
      expect(romanNumeral('Cadd9', c), 'Iadd9');
    });

    test('A 自然小调级数', () {
      const am = MusicKey(9, KeyMode.minor);
      expect(romanNumeral('Am', am), 'i');
      expect(romanNumeral('Bdim', am), 'ii°');
      expect(romanNumeral('C', am), 'III');
      expect(romanNumeral('Dm', am), 'iv');
      expect(romanNumeral('Em', am), 'v');
      expect(romanNumeral('F', am), 'VI');
      expect(romanNumeral('G', am), 'VII');
      // D 小调（降号调）VI 级 Bb。
      const dm = MusicKey(2, KeyMode.minor);
      expect(romanNumeral('Bb', dm), 'VI');
    });

    test('降号调内级数：F 大调 Bb=IV', () {
      const f = MusicKey(5, KeyMode.major);
      expect(romanNumeral('Bb', f), 'IV');
      expect(romanNumeral('C7', f), 'V7');
      expect(romanNumeral('Dm', f), 'vi');
    });
  });
}
