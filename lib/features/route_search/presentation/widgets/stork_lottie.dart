import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/ui/leylek_mark.dart';

/// Leylek animasyonu (LottieFiles "Stork with baby", 500×500, 60 fps).
///
/// [speed] 1 normal hız; duran leylek için yavaş oynatılır ki kanatlar
/// tembelce çırpsın ama ekran hareketsiz kalmasın. Animasyon yüklenemezse
/// (bozuk varlık gibi) markanın çizimi gösterilir; ekran boş kalmaz.
class StorkLottie extends StatefulWidget {
  const StorkLottie({required this.size, this.speed = 1, super.key});

  static const String asset = 'assets/lottie/stork.json';

  final double size;
  final double speed;

  @override
  State<StorkLottie> createState() => _StorkLottieState();
}

class _StorkLottieState extends State<StorkLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  Duration? _baseDuration;

  @override
  void didUpdateWidget(covariant StorkLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    final base = _baseDuration;
    if (oldWidget.speed != widget.speed && base != null) _start(base);
  }

  void _start(Duration base) {
    _baseDuration = base;
    _controller
      ..duration = base * (1 / widget.speed)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: Lottie.asset(
          StorkLottie.asset,
          controller: _controller,
          fit: BoxFit.contain,
          onLoaded: (composition) => _start(composition.duration),
          errorBuilder: (context, error, stack) =>
              Center(child: LeylekMark(size: widget.size * 0.5)),
        ),
      ),
    );
  }
}
