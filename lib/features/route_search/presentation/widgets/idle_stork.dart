import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';
import 'standing_stork.dart';

/// Ekranın alt kenarına konmuş, bekleyen leylek.
///
/// Kullanıcı alanları doldururken leylek yerde durur: gagasında bohça,
/// hafifçe nefes alır, başını sallar, ara ara göz kırpar. Ayakları
/// ekranın altındaki ince çimen şeridine basar.
class IdleStork extends StatelessWidget {
  const IdleStork({super.key});

  /// Leyleğin ekran genişliğine göre boyu; form sahnesi alt alanın en
  /// küçük yüksekliğini bundan hesaplar.
  static double heightFor(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.52, 230.0);

  @override
  Widget build(BuildContext context) {
    final height = heightFor(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const ground = 22.0;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Alt kenardaki çimen şeridi; telefonun alt çentiği kadar uzar.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: ground + bottomInset,
          child: const CustomPaint(painter: _GrassPainter()),
        ),
        Positioned(
          bottom: ground + bottomInset - 6,
          child: StandingStork(height: height),
        ),
      ],
    );
  }
}

class _GrassPainter extends CustomPainter {
  const _GrassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Hafif dalgalı üst kenar
    final path = Path()..moveTo(0, 8);
    const step = 24.0;
    for (var x = 0.0; x <= size.width + step; x += step) {
      path.quadraticBezierTo(x + step / 2, 2, x + step, 8);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = LeylekColors.meadow);
    canvas.drawRect(
      Rect.fromLTWH(0, 14, size.width, size.height - 14),
      Paint()..color = LeylekColors.meadowDeep,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
