import 'package:flutter_test/flutter_test.dart';
import 'package:jz_stringferry/core/theory/chord_builder.dart';
import 'package:jz_stringferry/core/theory/chord_quality.dart';
import 'package:jz_stringferry/core/theory/note.dart';

void main() {
  group('AC-2 乐理数据正确性（10 个抽检和弦）', () {
    /// 断言：构建结果的组成音音名与音程标签完全匹配。
    void expectChord(
      String root,
      String qualityId,
      List<String> expectedTones,
      List<String> expectedIntervals,
    ) {
      final q = qualitiesById[qualityId]!;
      final chord = ChordBuilder.build(root, q);
      expect(chord.toneNames, expectedTones, reason: '$root${q.suffix} 组成音错误');
      expect(
        chord.tones.map((t) => t.intervalLabel).toList(),
        expectedIntervals,
        reason: '$root${q.suffix} 音程标签错误',
      );
    }

    test('C 大三 = C E G', () {
      expectChord('C', 'maj', ['C', 'E', 'G'], ['根音', '大三度', '纯五度']);
    });

    test('Am 小三 = A C E', () {
      expectChord('A', 'min', ['A', 'C', 'E'], ['根音', '小三度', '纯五度']);
    });

    test('Am7 = A C E G', () {
      expectChord('A', 'm7', ['A', 'C', 'E', 'G'], ['根音', '小三度', '纯五度', '小七度']);
    });

    test('Cmaj7 = C E G B', () {
      expectChord(
          'C', 'maj7', ['C', 'E', 'G', 'B'], ['根音', '大三度', '纯五度', '大七度']);
    });

    test('F#m7b5 = F# A C E（升号拼写一致）', () {
      expectChord(
          'F#', 'm7b5', ['F#', 'A', 'C', 'E'], ['根音', '小三度', '减五度', '小七度']);
    });

    test('Bdim = B D F', () {
      expectChord('B', 'dim', ['B', 'D', 'F'], ['根音', '小三度', '减五度']);
    });

    test('G7 = G B D F', () {
      expectChord(
          'G', 'seven', ['G', 'B', 'D', 'F'], ['根音', '大三度', '纯五度', '小七度']);
    });

    test('Dsus4 = D G A', () {
      expectChord('D', 'sus4', ['D', 'G', 'A'], ['根音', '纯四度', '纯五度']);
    });

    test('Aaug = A C# E#（增五度按等音显示为 F，音程标签保留增五度）', () {
      // A 的增五度严格记谱为 E#，其实际音高等同 F；
      // 吉他 App 按可弹奏音名显示 F，理论含义由「增五度」标签表达。
      expectChord('A', 'aug', ['A', 'C#', 'F'], ['根音', '大三度', '增五度']);
    });

    test('Eb9 = Eb G Bb Db F（降号拼写一致）', () {
      expectChord('Eb', 'nine', ['Eb', 'G', 'Bb', 'Db', 'F'],
          ['根音', '大三度', '纯五度', '小七度', '大九度']);
    });
  });

  group('音高与移调边界', () {
    test('B 向上一个半音为高八度 C', () {
      const b3 = Note(59); // B3
      final c4 = b3.transpose(1);
      expect(c4.midi, 60);
      expect(c4.name(), 'C');
      expect(c4.octave, 4);
    });

    test('降号根音决定全部组成音用降号拼写', () {
      final chord = ChordBuilder.build('Db', qualitiesById['maj']!);
      expect(chord.toneNames, ['Db', 'F', 'Ab']);
    });

    test('同音高异拼写：C# 与 Db 的 pitchClass 相同', () {
      expect(Note.pitchClassOf('C#'), Note.pitchClassOf('Db'));
    });
  });

  group('和弦名解析', () {
    test('Am7 / F#m7b5 / 空后缀（大三）', () {
      expect(ChordNameParser.parse('am7')?.quality.id, 'm7');
      expect(ChordNameParser.parse('Am7')?.root, 'A');
      final fSharp = ChordNameParser.parse('F#m7b5');
      expect(fSharp?.root, 'F#');
      expect(fSharp?.quality.id, 'm7b5');
      expect(ChordNameParser.parse('C')?.quality.id, 'maj');
      expect(ChordNameParser.parse('cmaj7')?.quality.id, 'maj7');
    });

    test('中文别名解析', () {
      expect(ChordNameParser.parse('C大三')?.quality.id, 'maj');
      expect(ChordNameParser.parse('A小七')?.quality.id, 'm7');
    });

    test('非法输入返回 null', () {
      expect(ChordNameParser.parse('zzz'), isNull);
      expect(ChordNameParser.parse(''), isNull);
    });
  });

  group('性质表完整性', () {
    test('共 30 种性质，且每个都含根音且音程升序', () {
      expect(allQualities.length, 30);
      for (final q in allQualities) {
        expect(q.intervals.first.semitones, 0, reason: '${q.id} 根音应为 0');
        for (var i = 1; i < q.intervals.length; i++) {
          expect(
            q.intervals[i].semitones > q.intervals[i - 1].semitones,
            isTrue,
            reason: '${q.id} 音程未升序',
          );
        }
      }
    });

    test('17 个根音名 x 30 性质 = 510 个唯一和弦名（>=500）', () {
      final names = <String>{
        for (final r in allRootNames)
          for (final q in allQualities) '$r${q.suffix}',
      };
      expect(names.length, greaterThanOrEqualTo(500));
    });
  });
}
