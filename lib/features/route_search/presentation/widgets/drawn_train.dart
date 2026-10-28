import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Uçuş sahnesindeki tren: önü ve arkası aynı burunla kapanan uzun bir
/// hızlı tren.
///
/// LottieFiles'taki tren yalnızca burnu gösteriyor ve arkası açık
/// kalıyordu; o dosyayı uzatmak yerine aynı çizgi dilinde (beyaz çizgi,
/// göğün koyu tonunda ince kontur) elle çizildi. Raylar sola akar,
/// gövde hafifçe titrer: tren sağa gidiyormuş gibi görünür.
class DrawnTrain extends StatefulWidget {
  const DrawnTrain({required this.width, super.key});

  final double width;

  /// Tuval oranı 220 × 80; raylar y = 61'de.
  static const double aspect = 80 / 220;

  /// Rayın tuvaldeki yüksekliği (kesir): küre yüzeyine oturtmak için.
  static const double groundAt = 61 / 80;

  @override
  State<DrawnTrain> createState() => _DrawnTrainState();
}

class _DrawnTrainState extends State<DrawnTrain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.width * DrawnTrain.aspect,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) =>
              CustomPaint(painter: _TrainPainter(_t.value)),
        ),
      ),
    );
  }
}

class _TrainPainter extends CustomPainter {
  _TrainPainter(this.t);

  static const double _w = 220;
  static const double _h = 80;

  static const _white = Color(0xFFFFFFFF);
  static const _outline = Color(0xE614456B);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);

    // Önce kontur (kalın mavi), sonra aynı çizgiler beyaz: Lottie
    // araçlarındaki görünümle aynı.
    _draw(canvas, _stroke(_outline, 6.6), _stroke(_outline, 5.2));
    _draw(canvas, _stroke(_white, 3.2), _stroke(_white, 2.2));
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  void _draw(Canvas canvas, Paint p, Paint thin) {
    // Gövdenin hafif titreşimi
    final shake = math.sin(t * 2 * math.pi * 2) * 0.5;
    canvas.save();
    canvas.translate(0, shake);

    // Gövde: alçak ve uzun; düz tavan, iki uçta aynı sivri hızlı tren
    // burnu (alt kenara doğru uzayan kıvrım).
    final body = Path()
      ..moveTo(52, 30)
      ..lineTo(168, 30)
      ..cubicTo(192, 30, 210, 40, 214, 54)
      ..lineTo(6, 54)
      ..cubicTo(10, 40, 28, 30, 52, 30)
      ..close();
    canvas.drawPath(body, p);

    // Ön ve arka cam: burnun üst kıvrımına paralel kısa bir çizgi.
    canvas.drawPath(
      Path()
        ..moveTo(176, 35)
        ..cubicTo(188, 36, 197, 40, 201, 45),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(44, 35)
        ..cubicTo(32, 36, 23, 40, 19, 45),
      p,
    );

    // Pencereler: Lottie trenindeki eğik "J" biçimi, alçak gövdeye göre.
    for (var i = 0; i < 7; i++) {
      final x = 64.0 + i * 15;
      canvas.drawPath(
        Path()
          ..moveTo(x, 36)
          ..lineTo(x, 41)
          ..quadraticBezierTo(x, 44, x + 4, 44),
        thin,
      );
    }

    // Farlar
    canvas.drawLine(const Offset(198, 50), const Offset(205, 50), thin);
    canvas.drawLine(const Offset(15, 50), const Offset(22, 50), thin);
    canvas.restore();

    // Ray: sabit bir çizgi ve altında sola akan kesik çizgiler.
    canvas.drawLine(const Offset(4, 61), const Offset(216, 61), thin);
    const dash = 10.0;
    const gap = 8.0;
    final shift = t * (dash + gap);
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 64, _w, 12));
    for (var x = -shift; x < _w; x += dash + gap) {
      canvas.drawLine(Offset(x + 4, 69), Offset(x + 4 + dash, 69), thin);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrainPainter old) => old.t != t;
}
