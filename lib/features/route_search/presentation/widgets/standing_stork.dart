import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';

/// Açılış kartının sağ üst köşesine konmuş, ayakta duran leylek.
///
/// Düz 2D, kontur yok: beyaz gövde, boyun ve baş; gövdenin altında siyah
/// kanat ucu; turuncu gaga ve bacaklar; tek siyah göz. Baş hafifçe
/// sallanır, ara ara göz kırpar. Süstür, ekran okuyucuya görünmez.
class StandingStork extends StatefulWidget {
  const StandingStork({this.height = 118, super.key});

  /// Ayak çizgisinden tuvalin tepesine yükseklik.
  final double height;

  /// Genişlik / yükseklik oranı.
  static const double aspect = _StorkPainter._w / _StorkPainter._h;

  @override
  State<StandingStork> createState() => _StandingStorkState();
}

class _StandingStorkState extends State<StandingStork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return ExcludeSemantics(
      child: SizedBox(
        width: h * StandingStork.aspect,
        height: h,
        child: AnimatedBuilder(
          animation: _idle,
          builder: (context, _) =>
              CustomPaint(painter: _StorkPainter(_idle.value)),
        ),
      ),
    );
  }
}

class _StorkPainter extends CustomPainter {
  _StorkPainter(this.t);

  /// Tasarım tuvali 200 × 260; ayak çizgisi y = 257'de.
  static const double _w = 200;
  static const double _h = 260;

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);

    final white = Paint()..color = LeylekColors.feather;
    final ink = Paint()..color = LeylekColors.ink;

    // Bacaklar: iki düz çizgi, dizde hafif kırılma; altta tek ayak çizgisi.
    final leg = Paint()
      ..color = LeylekColors.beak
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(88, 172)
        ..lineTo(86, 214)
        ..lineTo(88, 255),
      leg,
    );
    canvas.drawPath(
      Path()
        ..moveTo(104, 172)
        ..lineTo(106, 214)
        ..lineTo(105, 255),
      leg,
    );
    canvas.drawLine(const Offset(66, 257), const Offset(126, 257), leg);

    // Kuyruk: gövdenin arkasında ince bir üçgen.
    canvas.drawPath(
      Path()
        ..moveTo(60, 146)
        ..lineTo(8, 164)
        ..lineTo(64, 166)
        ..close(),
      white,
    );

    // Gövde: altında koyu kanat ucu hilal gibi görünür, üstte beyaz oval.
    canvas.save();
    canvas.translate(96, 146);
    canvas.rotate(-0.2);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-6, 9), width: 104, height: 56),
      ink,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 108, height: 60),
      Paint()..color = LeylekColors.fieldLine,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(2, -3), width: 104, height: 54),
      white,
    );
    canvas.restore();

    // Boyun ve baş birlikte hafifçe sallanır.
    final bob = math.sin(t * 2 * math.pi) * 2;
    canvas.save();
    canvas.translate(bob * 0.5, bob);

    canvas.drawPath(
      Path()
        ..moveTo(130, 138)
        ..cubicTo(146, 112, 132, 84, 138, 44),
      Paint()
        ..color = LeylekColors.feather
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(const Offset(141, 36), 14, white);

    // Gaga: uzun, ince, hafif aşağı bakan üçgen.
    canvas.drawPath(
      Path()
        ..moveTo(150, 31)
        ..lineTo(199, 44)
        ..lineTo(151, 41)
        ..close(),
      Paint()..color = LeylekColors.beak,
    );

    // Göz: döngünün sonunda kısa bir kırpma.
    if (t > 0.93 && t < 0.97) {
      canvas.drawLine(
        const Offset(140, 33),
        const Offset(147, 33),
        Paint()
          ..color = LeylekColors.ink
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(const Offset(143, 33), 3.2, ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StorkPainter old) => old.t != t;
}
