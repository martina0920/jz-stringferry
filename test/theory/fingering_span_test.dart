import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/theory/chord_quality.dart';
import 'package:jz_stringferry/core/theory/fingering.dart';
import 'package:jz_stringferry/core/theory/note.dart';

void main() {
  test('全库指法：相对画布起始品的所需格数不超过 6（review M4 回归）', () {
    // FretboardPainter 在 5 品常规窗口上动态扩展到最多 6 品；
    // 该断言保证 510 和弦的全部按点都能被完整画出。
    final dist = <int, int>{};
    final overflows = <String>[];

    for (final root in allRootNames) {
      for (final quality in allQualities) {
        for (final f in fingeringsFor(root, quality)) {
          final low = f.lowestFret;
          if (low == null) continue;
          final base = f.displayBaseFret;
          final need = f.highestFret! - base + 1;
          dist[need] = (dist[need] ?? 0) + 1;
          if (need > 6) {
            overflows.add('$root${quality.id} ${f.toTabString()} need=$need');
          }
        }
      }
    }

    // ignore: avoid_print
    print('窗口格数分布（17 根音 × 30 性质全部指法）: $dist');
    expect(overflows, isEmpty, reason: '存在画布无法完整呈现的指法: $overflows');
  });
}
