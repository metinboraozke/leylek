import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';

/// Sonuç ekranında sol üst köşeden başını uzatan leylek.
///
/// Markanın çizimindeki baş, göz ve gaga; boyun ekranın dışından gelir.
/// Dokununca yeni aramaya dönülür.
class PeekStork extends StatefulWidget {
  const PeekStork({required this.onTap, required this.delay, super.key});

  final VoidCallback onTap;
  final Duration delay;

  @override
  State<PeekStork> createState() => _PeekStorkState();
}

class _PeekStorkState extends State<PeekStork> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _nod = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      _in.forward().whenComplete(() {
        if (mounted) _nod.repeat();
      });
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _nod.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return Semantics(
      button: true,
      label: 'Yeni arama',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _nod]),
          builder: (context, child) {
            final p = Curves.easeOutBack.transform(_in.value);
            final nod = math.sin(_nod.value * 2 * math.pi) * 0.04;
            return Transform.translate(
              offset: Offset(-size * (1 - p), -size * (1 - p)),
              child: Transform.rotate(
                angle: nod,
                alignment: Alignment.topLeft,
                child: child,
              ),
            );
          },
          child: const CustomPaint(
            size: Size.square(size),
            painter: _HeadPainter(),
          ),
        ),
      ),
    );
  }
}

class _HeadPainter extends CustomPainter {
  const _HeadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 96;
    canvas.scale(s);
    final white = Paint()..color = LeylekColors.feather;
    final outline = Paint()
      ..color = LeylekColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Boyun: sol üst köşeden başa uzanır.
    final neck = Path()
      ..moveTo(-10, -10)
      ..quadraticBezierTo(18, 8, 34, 40)
      ..lineTo(48, 34)
      ..quadraticBezierTo(30, 2, 6, -14)
      ..close();
    canvas.drawPath(neck, white);
    canvas.drawPath(neck, outline);

    // Baş
    canvas.drawCircle(const Offset(42, 44), 14, white);
    canvas.drawCircle(const Offset(42, 44), 14, outline);

    // Gaga
    final beak = Path()
      ..moveTo(52, 40)
      ..lineTo(90, 56)
      ..lineTo(52, 50)
      ..close();
    canvas.drawPath(beak, Paint()..color = LeylekColors.beak);

    // Göz
    canvas.drawCircle(
      const Offset(44, 41),
      2.6,
      Paint()..color = LeylekColors.wingtip,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
