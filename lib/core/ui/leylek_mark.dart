import 'package:flutter/material.dart';

import '../theme/leylek_colors.dart';

/// Leylek logosu: gök mavisi kare, beyaz baş ve boyun, turuncu gaga,
/// altta yürünen yolu anlatan kesikli çizgi.
///
/// SVG paketi eklemeden çizilsin diye CustomPainter. Koordinatlar
/// 72 birimlik orijinal çizimden ölçeklenir.
class LeylekMark extends StatelessWidget {
  const LeylekMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Leylek logosu',
        child: CustomPaint(size: Size.square(size), painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 72, 72), const Radius.circular(18)),
      Paint()..color = LeylekColors.sky,
    );

    final white = Paint()..color = LeylekColors.feather;
    canvas.drawLine(
      const Offset(27, 28),
      const Offset(26, 50),
      Paint()
        ..color = LeylekColors.feather
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(28, 25), 9, white);

    final beak = Path()
      ..moveTo(35, 22)
      ..lineTo(60, 30)
      ..lineTo(35, 28)
      ..close();
    canvas.drawPath(beak, Paint()..color = LeylekColors.beak);
    canvas.drawCircle(const Offset(29, 23), 2, Paint()..color = LeylekColors.wingtip);

    final dash = Paint()
      ..color = LeylekColors.beak
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (double x = 26; x <= 58; x += 9) {
      canvas.drawLine(Offset(x, 56), Offset(x + 3, 56), dash);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
