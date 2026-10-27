import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';

/// Sonuç ekranında sağ alt köşeden başını uzatan leylek.
///
/// Düz 2D: beyaz boyun ve baş, turuncu gaga, siyah göz; kontur yok.
/// Boyun ekranın sağ alt dışından gelir, gaga sola bakar. Yazıların
/// üstüne binmesin diye küçük ve köşede. Dokununca forma dönülür.
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
    const size = 84.0;
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
              offset: Offset(size * (1 - p), size * (1 - p)),
              child: Transform.rotate(
                angle: nod,
                alignment: Alignment.bottomRight,
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

    // Köşede düz bir gök parçası: beyaz leylek açık zeminde kaybolmasın.
    canvas.drawCircle(
      const Offset(104, 104),
      92,
      Paint()..color = LeylekColors.skyLight,
    );

    // Boyun: sağ alt köşenin dışından başa uzanır.
    canvas.drawPath(
      Path()
        ..moveTo(110, 110)
        ..quadraticBezierTo(70, 86, 58, 54),
      Paint()
        ..color = LeylekColors.feather
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Baş
    canvas.drawCircle(const Offset(56, 46), 14, white);

    // Gaga: sola bakar.
    canvas.drawPath(
      Path()
        ..moveTo(46, 40)
        ..lineTo(6, 54)
        ..lineTo(46, 52)
        ..close(),
      Paint()..color = LeylekColors.beak,
    );

    // Göz
    canvas.drawCircle(
      const Offset(53, 42),
      2.8,
      Paint()..color = LeylekColors.wingtip,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
