import '../../../core/l10n/strings.dart';
import '../domain/entities/route_option.dart';

/// Domain değerlerinin ekrandaki Türkçe karşılıkları.
///
/// Domain metin bilmez; çeviri sunum katmanında ve tek dosyada.
/// İngilizce desteği geldiğinde bu dosya yerelleştirmeye taşınacak.
abstract final class Labels {
  static String badge(RouteBadge badge) => switch (badge) {
    RouteBadge.cheapest => S.t('En ucuz', 'Cheapest'),
    RouteBadge.fastest => S.t('En hızlı', 'Fastest'),
    RouteBadge.recommended => S.t('Önerilen', 'Recommended'),
  };

  static String reason(RecommendReason reason) => switch (reason) {
    RecommendReason.cheapest => S.t(
      'Hem en ucuz hem de süre farkı makul.',
      'Cheapest, and the extra time is reasonable.',
    ),
    RecommendReason.bestBalance => S.t(
      'Fiyat ve süre arasında en iyi denge.',
      'Best balance of price and time.',
    ),
    RecommendReason.fastest => S.t(
      'Biraz pahalı ama belirgin şekilde hızlı.',
      'A bit pricier but clearly faster.',
    ),
  };

  static String? flag(RouteFlag flag) => switch (flag) {
    RouteFlag.separateTickets => S.t('Ayrı biletler', 'Separate tickets'),
    RouteFlag.tightConnection => S.t('Dar aktarma', 'Tight connection'),
    RouteFlag.overnightWait => S.t('Gece bekleme', 'Overnight wait'),
    RouteFlag.groundFareEstimated => S.t(
      'Kara fiyatı tahmini',
      'Ground fare estimated',
    ),
    RouteFlag.groundFarePartial => S.t(
      'Kara fiyatı kısmen tahmini',
      'Ground fare partly estimated',
    ),
    RouteFlag.groundNotVerified => S.t(
      'Kara yolu doğrulanamadı',
      'Ground route not verified',
    ),
    RouteFlag.ferry => S.t('Feribot', 'Ferry'),
    RouteFlag.priceStale => S.t('Fiyat eski olabilir', 'Price may be outdated'),
    RouteFlag.stopover => S.t('Konaklamalı', 'With stopover'),
    RouteFlag.dateShifted => S.t('Yakın günün uçuşu', 'Flight on a nearby day'),
    RouteFlag.unknown => null,
  };

  static String mode(TransitMode mode) => switch (mode) {
    TransitMode.walk => S.t('Yürüyüş', 'Walk'),
    TransitMode.suburban => S.t('Banliyö', 'Suburban rail'),
    TransitMode.subway => S.t('Metro', 'Metro'),
    TransitMode.tram => S.t('Tramvay', 'Tram'),
    TransitMode.bus => S.t('Otobüs', 'Bus'),
    TransitMode.coach => S.t('Şehirlerarası otobüs', 'Coach'),
    TransitMode.regionalRail => S.t('Bölgesel tren', 'Regional train'),
    TransitMode.longDistance => S.t('Şehirlerarası tren', 'Intercity train'),
    TransitMode.highspeedRail => S.t('Hızlı tren', 'High-speed train'),
    TransitMode.nightRail => S.t('Gece treni', 'Night train'),
    TransitMode.ferry => S.t('Feribot', 'Ferry'),
    TransitMode.other => S.t('Toplu taşıma', 'Public transport'),
  };
}
