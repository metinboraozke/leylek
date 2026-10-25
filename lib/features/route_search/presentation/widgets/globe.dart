import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../../../../core/theme/leylek_colors.dart';

/// Kara şekilleri (Natural Earth, sadeleştirilmiş): her halka
/// `[boylam, enlem, boylam, enlem, ...]`.
class LandShapes {
  LandShapes._(this.rings);

  final List<Float32List> rings;

  static LandShapes? _cached;
  static Future<LandShapes>? _loading;

  static const String asset = 'assets/geo/land.json';

  /// Bir kez yüklenir; eşzamanlı çağrılar aynı Future'ı paylaşır.
  static Future<LandShapes> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= rootBundle.loadString(asset).then((raw) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final rings = (json['rings'] as List<dynamic>)
          .map(
            (r) => Float32List.fromList(
              (r as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
            ),
          )
          .toList(growable: false);
      return _cached = LandShapes._(rings);
    });
  }
}

/// Ekranın altında yükselen dünya. Yalnızca üst kısmı görünür; [rotation]
/// 0→1 ilerledikçe kıtalar soldan sağa kayar.
class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.shapes,
    required this.center,
    required this.radius,
    required this.rotation,
  });

  final LandShapes? shapes;
  final Offset center;
  final double radius;
  final double rotation;

  /// Kamera enlemi: Avrupa ve Kuzey Afrika kürenin görünen tepesine düşer.
  static const double _lat0 = 15;

  /// Dönüş: merkez boylamı 50°D'den 0°'ye iner, karalar sağa akar.
  static const double _lonStart = 50;
  static const double _lonEnd = 0;

  static const double _deg = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final disc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = LeylekColors.feather.withValues(alpha: 0.35),
    );

    final land = shapes;
    if (land != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(disc));
      final lon0 = (_lonStart + (_lonEnd - _lonStart) * rotation) * _deg;
      final lat0 = _lat0 * _deg;
      final sinLat0 = math.sin(lat0);
      final cosLat0 = math.cos(lat0);
      final paint = Paint()..color = LeylekColors.land;

      for (final ring in land.rings) {
        final path = Path();
        var anyVisible = false;
        for (var i = 0; i < ring.length; i += 2) {
          final lon = ring[i] * _deg - lon0;
          final lat = ring[i + 1] * _deg;
          final cosLat = math.cos(lat);
          var x = cosLat * math.sin(lon);
          var y = cosLat0 * math.sin(lat) - sinLat0 * cosLat * math.cos(lon);
          final visible =
              sinLat0 * math.sin(lat) + cosLat0 * cosLat * math.cos(lon) > 0;
          if (visible) {
            anyVisible = true;
          } else {
            // Arka yüzdeki nokta kürenin kenarına itilir; halka kapanır.
            final len = math.sqrt(x * x + y * y);
            if (len > 0) {
              x /= len;
              y /= len;
            }
          }
          final p = Offset(center.dx + x * radius, center.dy - y * radius);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        if (anyVisible) canvas.drawPath(path..close(), paint);
      }
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = LeylekColors.feather.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant GlobePainter old) =>
      old.rotation != rotation ||
      old.shapes != shapes ||
      old.radius != radius ||
      old.center != center;
}
