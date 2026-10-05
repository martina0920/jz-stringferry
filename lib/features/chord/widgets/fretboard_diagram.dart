import 'package:flutter/material.dart';

import '../../../core/models/chord_spec.dart';
import '../../../core/theme/app_theme.dart';

/// 竖版六弦吉他指法图。
///
/// 左→右对应 6 弦(最粗)→1 弦(最细)；
/// 支持开放 O、制音 X、按弦品位点与横按横杆；高把位自动显示起始品位。
class FretboardDiagram extends StatelessWidget {
  final FingeringSpec fingering;
  final double width;
  final double height;

  const FretboardDiagram({
    super.key,
    required this.fingering,
    this.width = 190,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _FretboardPainter(fingering),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  final FingeringSpec f;

  _FretboardPainter(this.f);

  /// 常规把位展示 5 品；指法实际跨度更大时（全库最多再多用 1 品，
  /// 见 test/theory/fingering_span_test.dart）动态加高，避免漏画最高按点。
  static const int _minFretsShown = 5;
  static const int _maxFretsShown = 6;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0;
    const top = 34.0;
    final right = size.width - 14;
    final bottom = size.height - 26;
    final gridW = right - left;
    final gridH = bottom - top;
    final colW = gridW / 5; // 6 弦 5 个间距

    final pressed = f.strings.where((v) => v > 0).toList();
    final lowest =
        pressed.isEmpty ? 1 : pressed.reduce((a, b) => a < b ? a : b);
    final highest =
        pressed.isEmpty ? 1 : pressed.reduce((a, b) => a > b ? a : b);
    final baseFret = lowest <= 2 ? 1 : lowest;
    final need = pressed.isEmpty ? _minFretsShown : highest - baseFret + 1;
    final int fretsShown = need < _minFretsShown
        ? _minFretsShown
        : (need > _maxFretsShown ? _maxFretsShown : need);
    final rowH = gridH / fretsShown;

    final linePaint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 品丝线（含顶部上枕/起始品线）。
    for (var i = 0; i <= fretsShown; i++) {
      final y = top + i * rowH;
      canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
    }

    // 开放把位：顶部画粗上枕；高把位：标起始品位数字。
    if (baseFret == 1) {
      final nut = Paint()
        ..color = AppColors.ink
        ..strokeWidth = 3.2;
      canvas.drawLine(const Offset(left - 2, top), Offset(right + 2, top), nut);
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: '$baseFret',
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - 20, top + rowH / 2 - tp.height / 2));
    }

    // 琴弦（6 根竖线）。
    for (var c = 0; c < 6; c++) {
      final x = left + c * colW;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), linePaint);
    }

    // 弦号（底部 6..1）。
    for (var c = 0; c < 6; c++) {
      _paintText(canvas, '${6 - c}', Offset(left + c * colW - 5, bottom + 6),
          10, AppColors.inkSoft);
    }

    // 横按横杆（覆盖 最粗弦号..1 弦）。
    final barre = f.barreFret;
    if (barre != null && barre >= baseFret && barre < baseFret + fretsShown) {
      final thickest = f.barreThickestString ?? 6;
      final startCol = 6 - thickest; // 6 弦 -> 0；5 弦 -> 1
      final x1 = left + startCol * colW;
      final x2 = left + 5 * colW;
      final y = top + (barre - baseFret + 0.5) * rowH;
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((x1 + x2) / 2, y),
          width: (x2 - x1) + colW * 0.62,
          height: rowH * 0.52,
        ),
        Radius.circular(rowH * 0.26),
      );
      canvas.drawRRect(
          r,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.fill);
    }

    // 每弦标记。
    for (var c = 0; c < 6; c++) {
      final v = f.strings[c];
      final x = left + c * colW;
      if (v == -1) {
        _paintText(canvas, 'X', Offset(x - 6, 8), 15, AppColors.ink);
      } else if (v == 0) {
        final o = Offset(x, top - 10);
        canvas.drawCircle(
          o,
          6.5,
          Paint()
            ..color = AppColors.paper
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          o,
          6.5,
          Paint()
            ..color = AppColors.ink
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
      } else if (v >= baseFret && v < baseFret + fretsShown) {
        // 与横按横杆重合的弦不重复画点。
        final startCol = 6 - (f.barreThickestString ?? 6);
        final onBarre = barre != null && barre == v && c >= startCol && c <= 5;
        if (!onBarre) {
          canvas.drawCircle(
            Offset(x, top + (v - baseFret + 0.5) * rowH),
            rowH * 0.26,
            Paint()
              ..color = AppColors.ink
              ..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  void _paintText(
      Canvas canvas, String text, Offset pos, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _FretboardPainter oldDelegate) =>
      oldDelegate.f != f;
}
