import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';

/// Yere konmuş, ayakta duran leylek.
///
/// Uçuş sahnesindeki karakterle aynı dil: düz 2D, gölge, kontur ve
/// doku yok. Beyaz gövde, boyun ve baş tek renkte birleşir; gaga ve
/// bacaklar düz turuncu, göz tek siyah nokta. Yalnızca baş hafifçe
/// sallanır ve ara ara göz kırpar.
class StandingStork extends StatefulWidget {
  const StandingStork({this.height = 200, super.key});

  /// Ayak ucundan başın tepesine yükseklik.
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
    return Semantics(
      label: 'Leylek seni bekliyor',
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

  /// Tasarım tuvali 200 × 260; ayaklar y = 260'ta.
  static const double _w = 200;
  static const double _h = 260;

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);

    final white = Paint()..color = LeylekColors.feather;
    final orange = Paint()..color = LeylekColors.logoBeak;

    // Bacaklar: iki düz çizgi, dizde hafif kırılma.
    final leg = Paint()
      ..color = LeylekColors.logoBeak
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(82, 178)
        ..lineTo(78, 218)
        ..lineTo(82, 257),
      leg,
    );
    canvas.drawPath(
      Path()
        ..moveTo(98, 178)
        ..lineTo(101, 218)
        ..lineTo(100, 257),
      leg,
    );
    // Ayaklar
    canvas.drawLine(const Offset(70, 257), const Offset(92, 257), leg);
    canvas.drawLine(const Offset(90, 257), const Offset(112, 257), leg);

    // Kuyruk: gövdenin arkasında küçük bir üçgen.
    canvas.drawPath(
      Path()
        ..moveTo(52, 140)
        ..lineTo(18, 168)
        ..lineTo(60, 162)
        ..close(),
      white,
    );

    // Gövde: hafif öne eğik oval.
    canvas.save();
    canvas.translate(88, 148);
    canvas.rotate(-0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 104, height: 62),
      white,
    );
    canvas.restore();

    // Boyun ve baş birlikte hafifçe sallanır.
    final bob = math.sin(t * 2 * math.pi) * 2;
    canvas.save();
    canvas.translate(bob * 0.5, bob);

    canvas.drawPath(
      Path()
        ..moveTo(122, 136)
        ..cubicTo(140, 118, 128, 86, 138, 62),
      Paint()
        ..color = LeylekColors.feather
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(const Offset(142, 52), 15, white);

    // Gaga: tek düz üçgen.
    canvas.drawPath(
      Path()
        ..moveTo(152, 46)
        ..lineTo(198, 58)
        ..lineTo(153, 58)
        ..close(),
      orange,
    );

    // Göz: döngünün sonunda kısa bir kırpma.
    final ink = Paint()..color = LeylekColors.wingtip;
    if (t > 0.93 && t < 0.97) {
      canvas.drawLine(
        const Offset(143, 48),
        const Offset(150, 48),
        ink
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(const Offset(146, 48), 3, ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StorkPainter old) => old.t != t;
}
