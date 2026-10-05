import 'package:flutter_test/flutter_test.dart';
import 'package:jz_stringferry/core/theory/chord_builder.dart';
import 'package:jz_stringferry/core/theory/chord_quality.dart';
import 'package:jz_stringferry/core/theory/fingering.dart';
import 'package:jz_stringferry/core/theory/note.dart';

void main() {
  group('人工开放表迁移', () {
    test('Am7 = X02010、F#m7b5 = 2X2210', () {
      final am7 = fingeringsFor('A', qualitiesById['m7']!);
      expect(am7.map((f) => f.toTabString()), contains('X02010'));

      final fSharpHalfDim = fingeringsFor('F#', qualitiesById['m7b5']!);
      expect(fSharpHalfDim.map((f) => f.toTabString()), contains('2X2210'));
    });
  });

  group('横按模板推算', () {
    String? firstTab(String root, String qid) {
      final list = fingeringsFor(root, qualitiesById[qid]!);
      return list.isEmpty ? null : list.first.toTabString();
    }

    test('F = 133211（一品 E 系横按）', () {
      expect(firstTab('F', 'maj'), '133211');
      final f = fingeringsFor('F', qualitiesById['maj']!).first;
      expect(f.barreFret, 1);
      expect(f.barreThickestString, 6);
    });

    test('Bb：最低把位 X13331（A 系一品），E 系六品 688766 同时提供', () {
      final tabs = fingeringsFor('Bb', qualitiesById['maj']!)
          .map((f) => f.toTabString());
      expect(tabs.first, 'X13331');
      expect(tabs, contains('688766'));
    });

    test('B = X24442（A 系横按，6 弦制音）', () {
      expect(firstTab('B', 'maj'), 'X24442');
      final b = fingeringsFor('B', qualitiesById['maj']!).first;
      expect(b.barreThickestString, 5);
    });

    test('Fm = 133111、Bm = X24432、Gm = 355333', () {
      expect(firstTab('F', 'min'), '133111');
      expect(firstTab('B', 'min'), 'X24432');
      expect(firstTab('G', 'min'), '355333');
    });
  });

  group('全库指法合法性与覆盖率', () {
    /// 标准调弦空弦音级：6 弦 -> 1 弦。
    const openPc = [4, 9, 2, 7, 11, 4];

    test('510 个和弦的每个指法都合法（音属于和弦、低音为根音）', () {
      for (final root in allRootNames) {
        for (final q in allQualities) {
          final built = ChordBuilder.build(root, q);
          final tonePcs = built.tones.map((t) => t.note.pitchClass).toSet();
          final fingerings = fingeringsFor(root, q);

          for (final f in fingerings) {
            expect(f.strings.length, 6);
            for (final v in f.strings) {
              expect(v >= -1 && v <= 14, isTrue,
                  reason: '${built.name} 出现非法品位 $v');
            }

            // 最低发声弦的音必须是根音。
            final bassIndex = f.strings.indexWhere((v) => v >= 0);
            expect(bassIndex, greaterThanOrEqualTo(0),
                reason: '${built.name} 指法全是 X');
            final bassPc = (openPc[bassIndex] + f.strings[bassIndex]) % 12;
            expect(bassPc, Note.pitchClassOf(root),
                reason: '${built.name} ${f.toTabString()} 低音不是根音');

            // 每根发声弦的音都必须属于和弦音集合。
            for (var i = 0; i < 6; i++) {
              if (f.strings[i] < 0) continue;
              final pc = (openPc[i] + f.strings[i]) % 12;
              expect(tonePcs.contains(pc), isTrue,
                  reason: '${built.name} ${f.toTabString()} 第${6 - i}弦含和弦外音');
            }
          }
        }
      }
    });

    test('指法覆盖率 >= 90%', () {
      var total = 0;
      var covered = 0;
      for (final root in allRootNames) {
        for (final q in allQualities) {
          total++;
          if (fingeringsFor(root, q).isNotEmpty) covered++;
        }
      }
      final rate = covered / total;
      // ignore: avoid_print
      print('指法覆盖率: $covered/$total = ${(rate * 100).toStringAsFixed(1)}%');
      expect(rate, greaterThanOrEqualTo(0.9), reason: '覆盖率不足 90%');
    });

    test('通用搜索兜底示例：C13 能生成包含全部 6 个和弦音的指法', () {
      final list = fingeringsFor('C', qualitiesById['thirteen']!);
      expect(list, isNotEmpty);
      final f = list.first;
      final pcs = <int>{};
      for (var i = 0; i < 6; i++) {
        if (f.strings[i] >= 0) pcs.add((openPc[i] + f.strings[i]) % 12);
      }
      expect(pcs, {0, 4, 7, 10, 2, 9}); // C E G Bb D A
    });
  });
}
