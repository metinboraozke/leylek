import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';

/// Ekranın alt köşesinden başını uzatan leylek.
///
/// Düz 2D: beyaz boyun ve baş, turuncu gaga, siyah göz; kontur yok.
/// Boyun köşenin dışından gelir, gaga ekranın içine bakar.
///   • Sonuç ekranında sağ altta, küçük; dokununca forma dönülür.
///   • Açılışta sol altta, daha büyük; yalnızca süs.
class PeekStork extends StatefulWidget {
  const PeekStork({
    required this.delay,
    this.onTap,
    this.size = 84,
    this.fromLeft = false,
    this.backdrop = LeylekColors.skyLight,
    super.key,
  });

  /// Dokununca çalışır; verilmezse leylek süstür ve ekran okuyucuya
  /// görünmez.
  final VoidCallback? onTap;
  final Duration delay;
  final double size;

  /// true ise sol alt köşeden çıkar, gaga sağa bakar.
  final bool fromLeft;

  /// Köşedeki gök parçası: beyaz leylek açık zeminde kaybolmasın.
  final Color backdrop;

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

  // Ekran bu süre dolmadan kapanırsa iptal edilir.
  late final Timer _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, () {
      _in.forward().whenComplete(() {
        if (mounted) _nod.repeat();
      });
    });
  }

  @override
  void dispose() {
    _start.cancel();
    _in.dispose();
    _nod.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final left = widget.fromLeft;
    final head = AnimatedBuilder(
      animation: Listenable.merge([_in, _nod]),
      builder: (context, child) {
        final p = Curves.easeOutBack.transform(_in.value);
        final nod = math.sin(_nod.value * 2 * math.pi) * 0.04;
        final out = size * (1 - p);
        return Transform.translate(
          offset: Offset(left ? -out : out, out),
          child: Transform.rotate(
            angle: left ? -nod : nod,
            alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
            child: child,
          ),
        );
      },
      child: Transform.flip(
        flipX: left,
        child: CustomPaint(
          size: Size.square(size),
          painter: _HeadPainter(widget.backdrop),
        ),
      ),
    );
    final onTap = widget.onTap;
    if (onTap == null) return ExcludeSemantics(child: head);
    return Semantics(
      button: true,
      label: 'Yeni arama',
      child: GestureDetector(onTap: onTap, child: head),
    );
  }
}

/// Sağ alt köşeden çıkan baş; sol köşe için yatayda aynalanır.
class _HeadPainter extends CustomPainter {
  const _HeadPainter(this.backdrop);

  final Color backdrop;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 96;
    canvas.scale(s);
    final white = Paint()..color = LeylekColors.feather;

    canvas.drawCircle(const Offset(104, 104), 92, Paint()..color = backdrop);

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
  bool shouldRepaint(covariant _HeadPainter old) => old.backdrop != backdrop;
}
