import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'globe.dart';
import 'standing_stork.dart';

/// Açılış ekranının zemini: altta yavaşça dönen dünya, tepesinde ayakta
/// bekleyen leylek.
///
/// Küre uçuş sahnesindekiyle aynı yerde ve aynı boyutta durur
/// (yarıçap genişliğin %78'i, merkez ekranın altında). Böylece arama
/// başlayınca küre yerinde kalır, yalnızca leylek havalanır.
class IdleStork extends StatefulWidget {
  const IdleStork({super.key});

  @override
  State<IdleStork> createState() => _IdleStorkState();
}

class _IdleStorkState extends State<IdleStork>
    with SingleTickerProviderStateMixin {
  // Çok yavaş, ileri geri: karalar fark edilir ama dikkat dağıtmaz.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat(reverse: true);

  LandShapes? _shapes;

  @override
  void initState() {
    super.initState();
    LandShapes.load()
        .then((s) {
          if (mounted) setState(() => _shapes = s);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final radius = w * 0.78;
          final center = Offset(w / 2, h + radius * 0.22);
          final globeTop = center.dy - radius;
          final storkHeight = math.min(w * 0.42, 190.0);
          final storkWidth = storkHeight * StandingStork.aspect;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) => CustomPaint(
                    painter: GlobePainter(
                      shapes: _shapes,
                      center: center,
                      radius: radius,
                      rotation: Curves.easeInOut.transform(_spin.value),
                    ),
                  ),
                ),
              ),
              // Ayaklar kürenin tepesine basar (birkaç piksel içeride ki
              // havada durmasın).
              Positioned(
                left: center.dx - storkWidth * 0.45,
                top: globeTop - storkHeight + 3,
                child: StandingStork(height: storkHeight),
              ),
            ],
          );
        },
      ),
    );
  }
}
