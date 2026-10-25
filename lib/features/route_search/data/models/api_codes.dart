import '../../domain/entities/route_option.dart';
import '../../domain/entities/search_result.dart';

/// API'nin büyük harfli kodlarını domain enum'larına çevirir.
///
/// Domain enum'ları API yazımını bilmez; çeviri tek yerde. Bilinmeyen
/// kodlar çökme yerine güvenli bir değere düşer, çünkü backend yeni bir
/// etiket eklediğinde eski uygulama sürümleri de çalışmaya devam etmeli.
abstract final class ApiCodes {
  static RouteKind kind(String code) =>
      code == 'DIRECT' ? RouteKind.direct : RouteKind.via;

  static RouteBadge? badge(String code) => switch (code) {
    'CHEAPEST' => RouteBadge.cheapest,
    'FASTEST' => RouteBadge.fastest,
    'RECOMMENDED' => RouteBadge.recommended,
    _ => null,
  };

  static RecommendReason? reason(String? code) => switch (code) {
    'CHEAPEST' => RecommendReason.cheapest,
    'BEST_BALANCE' => RecommendReason.bestBalance,
    'FASTEST' => RecommendReason.fastest,
    _ => null,
  };

  static RouteFlag flag(String code) => switch (code) {
    'SEPARATE_TICKETS' => RouteFlag.separateTickets,
    'TIGHT_CONNECTION' => RouteFlag.tightConnection,
    'OVERNIGHT_WAIT' => RouteFlag.overnightWait,
    'GROUND_FARE_ESTIMATED' => RouteFlag.groundFareEstimated,
    'GROUND_FARE_PARTIAL' => RouteFlag.groundFarePartial,
    'GROUND_NOT_VERIFIED' => RouteFlag.groundNotVerified,
    'FERRY' => RouteFlag.ferry,
    'PRICE_STALE' => RouteFlag.priceStale,
    _ => RouteFlag.unknown,
  };

  static TransitMode mode(String code) => switch (code) {
    'WALK' => TransitMode.walk,
    'SUBURBAN' => TransitMode.suburban,
    'SUBWAY' || 'METRO' => TransitMode.subway,
    'TRAM' => TransitMode.tram,
    'BUS' => TransitMode.bus,
    'COACH' => TransitMode.coach,
    'REGIONAL_RAIL' ||
    'REGIONAL_FAST_RAIL' ||
    'RAIL' => TransitMode.regionalRail,
    'LONG_DISTANCE' => TransitMode.longDistance,
    'HIGHSPEED_RAIL' => TransitMode.highspeedRail,
    'NIGHT_RAIL' => TransitMode.nightRail,
    'FERRY' => TransitMode.ferry,
    _ => TransitMode.other,
  };

  static FareSource fareSource(String code) => switch (code) {
    'transitous' => FareSource.transitous,
    'partial' => FareSource.partial,
    _ => FareSource.estimated,
  };

  static SearchWarning warning(String code) => switch (code) {
    'FEWER_THAN_THREE' => SearchWarning.fewerThanThree,
    'PARTIAL_RESULTS' => SearchWarning.partialResults,
    _ => SearchWarning.unknown,
  };
}
