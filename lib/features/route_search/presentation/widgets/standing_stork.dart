import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Yere konmuş, ayakta duran leylek.
///
/// Uçuş animasyonundaki karakterle aynı renkler (beyaz tüy, turuncu gaga
/// ve bacaklar) ama bu duruş Lottie dosyasında yok; bu yüzden elle
/// çiziliyor. Hafif nefes alma, baş sallama ve ara ara göz kırpma ile
/// canlı durur.
class StandingStork extends StatefulWidget {
  const StandingStork({this.height = 220, super.key});

  /// Ayak ucundan başın tepesine yükseklik. Genişlik bunun ~0,85'i.
  final double height;

  @override
  State<StandingStork> createState() => _StandingStorkState();
}

class _StandingStorkState extends State<StandingStork>
    with SingleTickerProviderStateMixin {
  // 4 saniyelik döngü: nefes, baş ve bohça bu döngünün kesirleriyle oynar.
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
        width: h * _StorkPainter.aspect,
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

  /// Tasarım tuvali 220 × 260; ayaklar y = 258'de.
  static const double _w = 220;
  static const double _h = 260;
  static const double aspect = _w / _h;

  final double t;

  static const _feather = Color(0xFFFFFFFF);
  static const _shade = Color(0xFFE3E9ED);
  static const _shadeDeep = Color(0xFFCBD4DA);
  static const _orange = Color(0xFFE8542F);
  static const _orangeDeep = Color(0xFFC94524);
  static const _ink = Color(0xFF1A1A1A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);

    final breath = math.sin(t * 2 * math.pi); // -1..1
    final headBob = math.sin(t * 2 * math.pi + 0.8) * 2.2;
    // Göz kırpma: döngünün sonunda kısa bir an.
    final blink = t > 0.93 && t < 0.97;

    _shadow(canvas);
    _legs(canvas);

    // Gövde nefesle hafifçe yükselip alçalır; bacaklar sabit kalır.
    canvas.save();
    canvas.translate(0, -breath * 1.2);
    _tail(canvas);

    // Boyun ve baş birlikte sallanır. Boyun gövdenin arkasında çizilir ki
    // konturu gövdenin içinde görünmesin.
    final bob = Offset(headBob * 0.6, headBob);
    canvas.save();
    canvas.translate(bob.dx, bob.dy);
    _neck(canvas);
    canvas.restore();

    _body(canvas, breath);
    _wing(canvas);

    canvas.save();
    canvas.translate(bob.dx, bob.dy);
    _head(canvas, blink);
    canvas.restore();
    canvas.restore();
  }

  void _shadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(98, 257), width: 96, height: 9),
      Paint()..color = const Color(0x22000000),
    );
  }

  void _legs(Canvas canvas) {
    final leg = Paint()
      ..color = _orange
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Arka bacak hafif açılı, öndeki dik; dizler belirgin.
    canvas.drawPath(
      Path()
        ..moveTo(86, 176)
        ..lineTo(82, 214)
        ..lineTo(86, 255),
      leg..color = _orangeDeep,
    );
    canvas.drawPath(
      Path()
        ..moveTo(100, 178)
        ..lineTo(104, 216)
        ..lineTo(102, 255),
      leg..color = _orange,
    );
    // Ayak parmakları
    final toe = Paint()
      ..color = _orangeDeep
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(86, 255), const Offset(98, 257), toe);
    canvas.drawLine(const Offset(86, 255), const Offset(76, 257), toe);
    canvas.drawLine(
      const Offset(102, 255),
      const Offset(116, 257),
      toe..color = _orange,
    );
    canvas.drawLine(const Offset(102, 255), const Offset(93, 257), toe);
  }

  void _tail(Canvas canvas) {
    final tail = Path()
      ..moveTo(52, 150)
      ..lineTo(22, 176)
      ..quadraticBezierTo(30, 180, 40, 176)
      ..lineTo(64, 164)
      ..close();
    canvas.drawPath(tail, Paint()..color = _shadeDeep);
  }

  void _body(Canvas canvas, double breath) {
    canvas.save();
    canvas.translate(92, 150);
    canvas.rotate(-0.22);
    final rx = 50 + breath * 0.8;
    final ry = 31 + breath * 0.6;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()..color = _feather,
    );
    // Açık zeminde kaybolmasın diye ince kontur
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..color = _shadeDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Karın altı gölgesi
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      0.35,
      2.2,
      false,
      Paint()
        ..color = _shade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.restore();
  }

  void _wing(Canvas canvas) {
    // Katlanmış kanat: gövdenin üstünde, uçları kuyruğa doğru.
    final wing = Path()
      ..moveTo(122, 130)
      ..cubicTo(100, 118, 64, 126, 44, 160)
      ..cubicTo(70, 156, 104, 158, 128, 146)
      ..close();
    canvas.drawPath(wing, Paint()..color = _shade);
    // Tüy çizgileri
    final quill = Paint()
      ..color = _shadeDeep
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final y = 146.0 + i * 4;
      canvas.drawLine(
        Offset(60.0 + i * 6, y + 6),
        Offset(100.0 + i * 4, y - 2),
        quill,
      );
    }
  }

  void _neck(Canvas canvas) {
    final path = Path()
      ..moveTo(128, 138)
      ..cubicTo(146, 124, 134, 92, 144, 70);
    canvas.drawPath(
      path,
      Paint()
        ..color = _shadeDeep
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    final neck = Paint()
      ..color = _feather
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // S biçimli boyun: göğüsten öne kıvrılıp başa çıkar.
    canvas.drawPath(
      Path()
        ..moveTo(128, 138)
        ..cubicTo(146, 124, 134, 92, 144, 70),
      neck,
    );
  }

  void _head(Canvas canvas, bool blink) {
    canvas.drawCircle(const Offset(148, 58), 15.5, Paint()..color = _shadeDeep);
    canvas.drawCircle(const Offset(148, 58), 14, Paint()..color = _feather);
    // Gaga: iki parça, alt çene biraz koyu.
    canvas.drawPath(
      Path()
        ..moveTo(158, 52)
        ..lineTo(206, 62)
        ..lineTo(160, 60)
        ..close(),
      Paint()..color = _orange,
    );
    canvas.drawPath(
      Path()
        ..moveTo(160, 60)
        ..lineTo(206, 62)
        ..lineTo(158, 64)
        ..close(),
      Paint()..color = _orangeDeep,
    );
    // Göz
    if (blink) {
      canvas.drawLine(
        const Offset(149, 54),
        const Offset(155, 54),
        Paint()
          ..color = _ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(const Offset(152, 54), 2.8, Paint()..color = _ink);
      canvas.drawCircle(
        const Offset(152.9, 53.1),
        0.9,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StorkPainter old) => old.t != t;
}
