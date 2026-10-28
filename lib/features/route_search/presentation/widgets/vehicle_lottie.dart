import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Uçuş sahnesindeki araç animasyonları (LottieFiles; beyaz çizgiye
/// yeniden renklendirildi, bkz. `tool/recolor_lottie.py`).
///
/// [from]–[to] animasyonun döngüde oynatılacak bölümü (0–1):
///   • uçak ilk karelerde parça parça çiziliyor; tamamlanmış hâlinden başlar.
enum Vehicle {
  plane('assets/lottie/plane.json', from: 0.15, to: 1, groundAt: 0.62);

  const Vehicle(
    this.asset, {
    required this.from,
    required this.to,
    required this.groundAt,
  });

  final String asset;
  final double from;
  final double to;

  /// Aracın yere değdiği yükseklik, tuval yüksekliğinin kesri olarak.
  /// Küre yüzeyine oturtmak için kullanılır.
  final double groundAt;
}

/// Beyaz çizgi araç. Açık gök ve gri karalar üzerinde kaybolmasın diye
/// arkasına aynı animasyonun genişletilmiş, göğün koyu tonunda bir kopyası
/// kontur olarak çizilir; iki kopya aynı denetleyiciyle eş zamanlı oynar.
class VehicleLottie extends StatefulWidget {
  const VehicleLottie({
    required this.vehicle,
    required this.width,
    required this.height,
    super.key,
  });

  final Vehicle vehicle;
  final double width;
  final double height;

  @override
  State<VehicleLottie> createState() => _VehicleLottieState();
}

class _VehicleLottieState extends State<VehicleLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  LottieComposition? _composition;

  static const _outline = Color(0xE62F6E9E);

  @override
  void initState() {
    super.initState();
    AssetLottie(widget.vehicle.asset)
        .load()
        .then((composition) {
          if (!mounted) return;
          final v = widget.vehicle;
          setState(() => _composition = composition);
          _controller
            ..duration = composition.duration * (v.to - v.from)
            ..value = v.from
            ..repeat(min: v.from, max: v.to);
        })
        .catchError((Object _) {
          // Animasyon yüklenemezse araç görünmez; sahne yine oynar.
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composition = _composition;
    if (composition == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    Widget layer() => Lottie(
      composition: composition,
      controller: _controller,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            // Beyaz çizginin çevresinde göğün koyu tonunda ince kontur:
            // aynı çizim genişletilip (dilate) maviye boyanır.
            ImageFiltered(
              imageFilter: ui.ImageFilter.dilate(radiusX: 1.8, radiusY: 1.8),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(_outline, BlendMode.srcIn),
                child: layer(),
              ),
            ),
            layer(),
          ],
        ),
      ),
    );
  }
}
