import 'package:flutter/material.dart';

/// Leylek marka paleti.
///
/// Bahar göğü zemin, gaga turuncusu vurgu, tüy beyazı yüzey, kanat ucu
/// metin, çayır yeşili tasarruf. Ekranlar bu adları kullanır; ham hex
/// yalnızca burada yazılır.
abstract final class LeylekColors {
  static const Color sky = Color(0xFF9CC9E8);
  static const Color skySoft = Color(0xFFE6F2FA);

  /// Form ekranının alt zemini: açık, duru gök.
  static const Color skyLight = Color(0xFFC4E6FA);

  /// Uçuş sahnesinin zemini: parlak beyaz leylek öne çıksın diye daha da açık.
  static const Color skyPale = Color(0xFFDDF0FC);

  /// Küredeki karalar: göğe yakın, soğuk bir gri.
  static const Color land = Color(0xFFC9D2D9);

  /// Göğün koyu tonu: "önerilen" tiki ve vurgulu bağlantılar.
  /// Beyaz zeminde metin kontrastı ≥ 4.5.
  static const Color skyDeep = Color(0xFF2F6E9E);
  static const Color beak = Color(0xFFE8542F);
  // Gaga turuncusu beyaz zemin üzerinde metin için yeterince koyu değil
  // (kontrast < 4.5). Metin ve ikonlarda bu koyu ton kullanılır.
  static const Color beakText = Color(0xFFB83E1E);
  static const Color feather = Color(0xFFFFFFFF);
  static const Color wingtip = Color(0xFF1A1A1A);

  /// Açılıştaki başlık ve alan değerleri: lacivert mürekkep.
  static const Color ink = Color(0xFF14233B);

  /// Açılış kartındaki dolgulu kutular: kart beyazından bir tık mavi.
  static const Color field = Color(0xFFEEF4FB);

  /// Kutulardaki ayırıcı çizgi ve kaydırıcının boş kısmı.
  static const Color fieldLine = Color(0xFFD9E5F0);
  static const Color meadow = Color(0xFF7BAE5A);
  static const Color meadowDeep = Color(0xFF5E9442);
  static const Color meadowText = Color(0xFF3F7A2A);
  static const Color mist = Color(0xFFF5F8FA);
  static const Color line = Color(0xFFD8E1E8);
  static const Color muted = Color(0xFF56626C);
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningSoft = Color(0xFFFBF0D9);

  /// Kartların yumuşak gölgesi (PAX'teki organik gölgeyle aynı yaklaşım:
  /// Material'in sert elevation gölgesi yerine dağınık, düşük opaklık).
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F0F3550), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x080F3550), blurRadius: 4, offset: Offset(0, 1)),
  ];
}
