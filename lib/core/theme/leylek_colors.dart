import 'package:flutter/material.dart';

/// Leylek marka paleti.
///
/// Bahar göğü zemin, gaga turuncusu vurgu, tüy beyazı yüzey, kanat ucu
/// metin, çayır yeşili tasarruf. Ekranlar bu adları kullanır; ham hex
/// yalnızca burada yazılır.
abstract final class LeylekColors {
  static const Color sky = Color(0xFF9CC9E8);
  static const Color skySoft = Color(0xFFE6F2FA);
  static const Color beak = Color(0xFFE8542F);
  // Gaga turuncusu beyaz zemin üzerinde metin için yeterince koyu değil
  // (kontrast < 4.5). Metin ve ikonlarda bu koyu ton kullanılır.
  static const Color beakText = Color(0xFFB83E1E);
  static const Color feather = Color(0xFFFFFFFF);
  static const Color wingtip = Color(0xFF1A1A1A);
  static const Color meadow = Color(0xFF7BAE5A);
  static const Color meadowText = Color(0xFF3F7A2A);
  static const Color mist = Color(0xFFF5F8FA);
  static const Color line = Color(0xFFD8E1E8);
  static const Color muted = Color(0xFF56626C);
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningSoft = Color(0xFFFBF0D9);
}
