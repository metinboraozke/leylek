import '../domain/entities/route_option.dart';

/// Domain değerlerinin ekrandaki Türkçe karşılıkları.
///
/// Domain metin bilmez; çeviri sunum katmanında ve tek dosyada.
/// İngilizce desteği geldiğinde bu dosya yerelleştirmeye taşınacak.
abstract final class Labels {
  static String badge(RouteBadge badge) => switch (badge) {
    RouteBadge.cheapest => 'En ucuz',
    RouteBadge.fastest => 'En hızlı',
    RouteBadge.recommended => 'Önerilen',
  };

  static String reason(RecommendReason reason) => switch (reason) {
    RecommendReason.cheapest => 'Hem en ucuz hem de süre farkı makul.',
    RecommendReason.bestBalance => 'Fiyat ve süre arasında en iyi denge.',
    RecommendReason.fastest => 'Biraz pahalı ama belirgin şekilde hızlı.',
  };

  static String? flag(RouteFlag flag) => switch (flag) {
    RouteFlag.separateTickets => 'Ayrı biletler',
    RouteFlag.tightConnection => 'Dar aktarma',
    RouteFlag.overnightWait => 'Gece bekleme',
    RouteFlag.groundFareEstimated => 'Kara fiyatı tahmini',
    RouteFlag.groundFarePartial => 'Kara fiyatı kısmen tahmini',
    RouteFlag.groundNotVerified => 'Kara yolu doğrulanamadı',
    RouteFlag.ferry => 'Feribot',
    RouteFlag.priceStale => 'Fiyat eski olabilir',
    RouteFlag.stopover => 'Konaklamalı',
    RouteFlag.unknown => null,
  };

  static String mode(TransitMode mode) => switch (mode) {
    TransitMode.walk => 'Yürüyüş',
    TransitMode.suburban => 'Banliyö',
    TransitMode.subway => 'Metro',
    TransitMode.tram => 'Tramvay',
    TransitMode.bus => 'Otobüs',
    TransitMode.coach => 'Şehirlerarası otobüs',
    TransitMode.regionalRail => 'Bölgesel tren',
    TransitMode.longDistance => 'Şehirlerarası tren',
    TransitMode.highspeedRail => 'Hızlı tren',
    TransitMode.nightRail => 'Gece treni',
    TransitMode.ferry => 'Feribot',
    TransitMode.other => 'Toplu taşıma',
  };
}
