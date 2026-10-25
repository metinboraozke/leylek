import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';
import 'drawn_train.dart';
import 'globe.dart';
import 'stork_lottie.dart';
import 'vehicle_lottie.dart';

/// Arama sürerken oynayan sahne.
///
///   • Leylek kürenin tam ortasının üstünde, ekranın yatay ortasında sabit
///     durur: kanat çırpar, hafifçe aşağı yukarı süzülür, arkasında hız
///     çizgileri var.
///   • Altta dünya yavaşça döner; kıtalar soldan sağa akar.
///   • Turun üçte birlerinde sırayla uçak (kürenin biraz üstünden), otobüs
///     ve tren (yüzeyin üstünden) kavis boyunca soldan sağa geçer.
///
/// Bir tur [duration] sürer (varsayılan 8 sn). [onCycle] her tur sonunda
/// çağrılır; veri gecikirse sahne baştan oynar.
class FlightScene extends StatefulWidget {
  const FlightScene({required this.duration, required this.onCycle, super.key});

  final Duration duration;
  final VoidCallback onCycle;

  @override
  State<FlightScene> createState() => _FlightSceneState();
}

class _FlightSceneState extends State<FlightScene>
    with TickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onCycle();
            if (mounted) _t.forward(from: 0);
          }
        })
        ..forward();

  /// Leyleğin süzülmesi turdan bağımsız, kendi ritminde.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  LandShapes? _shapes;

  @override
  void initState() {
    super.initState();
    LandShapes.load()
        .then((s) {
          if (mounted) setState(() => _shapes = s);
        })
        .catchError((Object _) {
          // Kara verisi yüklenemezse küre boş daire olarak kalır.
        });
  }

  @override
  void dispose() {
    _t.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LeylekColors.skyPale,
      child: Semantics(
        liveRegion: true,
        label: 'Rotalar aranıyor',
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final storkSize = math.min(w * 0.9, 380.0);
            final radius = w * 0.78;
            final globeCenter = Offset(w / 2, h + radius * 0.22);

            return AnimatedBuilder(
              animation: Listenable.merge([_t, _bob]),
              builder: (context, _) {
                final t = _t.value;
                final bob = math.sin(_bob.value * 2 * math.pi) * 9;
                // Kuş (kuyruktan bohçaya) Lottie tuvalinde yatayda ~%39'da ortalanıyor, dikeyde
                // ~%40'ta. Tuval, gövde kürenin dikey ekseninin (ekranın
                // ortası) tam üstüne ve ekranın üçte birine gelecek
                // şekilde yerleştirilir.
                final storkLeft = globeCenter.dx - storkSize * 0.39;
                final storkTop = h * 0.3 - storkSize * 0.4 + bob;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GlobePainter(
                          shapes: _shapes,
                          center: globeCenter,
                          radius: radius,
                          rotation: t,
                        ),
                      ),
                    ),
                    // Hız çizgileri: kuşun kuyruğunun arkasında (kuş tuvalde
                    // soldan ~%12, yukarıdan ~%38'de başlıyor).
                    Positioned(
                      left: storkLeft + storkSize * 0.12 - storkSize * 0.3,
                      top: storkTop + storkSize * 0.3,
                      child: _SpeedLines(
                        phase: _bob.value,
                        length: storkSize * 0.3,
                      ),
                    ),
                    Positioned(
                      left: storkLeft,
                      top: storkTop,
                      child: StorkLottie(size: storkSize),
                    ),
                    ..._vehicles(t, w, h, globeCenter, radius),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Turun üçte birleri: uçak, otobüs, tren; üçü de küre kavisi boyunca.
  List<Widget> _vehicles(
    double t,
    double w,
    double h,
    Offset globeCenter,
    double radius,
  ) {
    const phases = 3;
    final out = <Widget>[];

    // Üç araç da kürenin tepesindeki yay boyunca, küreyle aynı yönde
    // (soldan sağa) ilerler ve yay üzerinde teğet döner. Uçak yüzeyin
    // biraz üstünden, otobüs ve tren yüzeyin üstünde gider.
    // (anahtar, genişlik, yükseklik, yaya oturan nokta, yerden yükseklik, araç)
    const trainW = 200.0;
    final lanes = <(String, double, double, double, double, Widget)>[
      // Uçak tuvali 16:9 ve uçak ortadaki ~%30'luk alanda: ~70 px uçak.
      (
        'plane',
        230,
        230 * 9 / 16,
        0.5,
        92,
        const VehicleLottie(
          vehicle: Vehicle.plane,
          width: 230,
          height: 230 * 9 / 16,
        ),
      ),
      (
        'bus',
        130,
        130,
        Vehicle.bus.groundAt,
        0,
        const VehicleLottie(vehicle: Vehicle.bus, width: 130, height: 130),
      ),
      (
        'train',
        trainW,
        trainW * DrawnTrain.aspect,
        DrawnTrain.groundAt,
        0,
        const DrawnTrain(width: trainW),
      ),
    ];
    for (var i = 0; i < lanes.length; i++) {
      final local = ((t - i / phases) * phases).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final (key, boxW, boxH, pivotY, altitude, child) = lanes[i];
      // Görünen yay yaklaşık -40°..+40°; araç bunun biraz dışından girip çıkar.
      final angle = (-48 + 96 * local) * math.pi / 180;
      final r = radius + altitude;
      final anchor = Offset(
        globeCenter.dx + r * math.sin(angle),
        globeCenter.dy - r * math.cos(angle),
      );
      out.add(
        Positioned(
          key: ValueKey(key),
          left: anchor.dx - boxW / 2,
          top: anchor.dy - boxH * pivotY,
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment(0, pivotY * 2 - 1),
            child: child,
          ),
        ),
      );
    }
    return out;
  }
}

/// Leyleğin arkasındaki, uçuyormuş hissi veren çizgiler.
class _SpeedLines extends StatelessWidget {
  const _SpeedLines({required this.phase, required this.length});

  final double phase;
  final double length;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(length, 70), painter: _SpeedLinesPainter(phase));
}

class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    // Üç çizgi; her biri kendi hızında kısalıp uzar. Zemin açık olduğu için
    // beyaz değil, göğün orta tonunda.
    const rows = [0.15, 0.5, 0.85];
    const speeds = [2.0, 3.0, 1.0];
    for (var i = 0; i < rows.length; i++) {
      final wave = (math.sin(phase * math.pi * 2 * speeds[i] + i) + 1) / 2;
      final len = size.width * (0.45 + 0.5 * wave);
      final y = size.height * rows[i];
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i == 1 ? 3.5 : 2.5
        ..shader = LinearGradient(
          colors: [LeylekColors.sky.withValues(alpha: 0), LeylekColors.sky],
        ).createShader(Rect.fromLTWH(size.width - len, y, len, 1));
      canvas.drawLine(
        Offset(size.width - len, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter old) => old.phase != phase;
}
