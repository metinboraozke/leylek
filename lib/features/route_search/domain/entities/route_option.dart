import 'package:equatable/equatable.dart';

import '../../../../core/time/zoned_time.dart';
import 'money.dart';

/// Kartın türü: aktarmalı rota ya da doğrudan uçuş.
enum RouteKind { via, direct }

/// Kartın üstündeki rozetler. Bir kart birden çok rozet alabilir.
enum RouteBadge { cheapest, fastest, recommended }

/// Önerilen kartın neden seçildiği.
enum RecommendReason { cheapest, bestBalance, fastest }

/// Kartı açıklayan uyarı etiketleri. Backend yeni bir etiket eklerse
/// uygulama çökmesin diye [unknown] var.
enum RouteFlag {
  separateTickets,
  tightConnection,
  overnightWait,
  groundFareEstimated,
  groundFarePartial,
  groundNotVerified,
  ferry,
  priceStale,
  stopover,
  unknown,
}

enum TransitMode {
  walk,
  suburban,
  subway,
  tram,
  bus,
  coach,
  regionalRail,
  longDistance,
  highspeedRail,
  nightRail,
  ferry,
  other,
}

/// Kara bacağı fiyatının nereden geldiği.
enum FareSource { transitous, partial, estimated }

class ViaAirport extends Equatable {
  const ViaAirport({
    required this.iata,
    required this.name,
    required this.countryCode,
    required this.distanceKm,
  });

  final String iata;
  final String name;
  final String countryCode;

  /// Havalimanından varış şehrine kuş uçuşu mesafe.
  final int distanceKm;

  @override
  List<Object?> get props => [iata, name, countryCode, distanceKm];
}

class Flight extends Equatable {
  const Flight({
    required this.price,
    required this.airline,
    required this.transfers,
    required this.departAt,
    required this.arriveAt,
    this.priceSeenHoursAgo,
    this.flightNumber,
    this.airportIata,
    this.fromIata,
    this.toIata,
  });

  final Money price;

  /// IATA havayolu kodu, ör. `TK`.
  final String airline;
  final String? flightNumber;
  final int transfers;
  final ZonedTime departAt;
  final ZonedTime arriveAt;

  /// Fiyat önbellekli bir kaynaktan geliyor; ne kadar eski olduğu gösterilir.
  /// Sağlayıcı yaşı vermezse `null`.
  final int? priceSeenHoursAgo;

  /// Doğrudan uçuş kartında iniş havalimanı.
  final String? airportIata;

  /// Kalkış ve iniş havalimanı kodları, ör. IST → MUC.
  final String? fromIata;
  final String? toIata;

  Duration get duration => arriveAt.difference(departAt);

  @override
  List<Object?> get props => [
    price,
    airline,
    flightNumber,
    transfers,
    departAt,
    arriveAt,
    priceSeenHoursAgo,
    airportIata,
    fromIata,
    toIata,
  ];
}

class GroundLeg extends Equatable {
  const GroundLeg({
    required this.mode,
    required this.from,
    required this.to,
    this.line,
    this.operator,
    this.departAt,
    this.arriveAt,
  });

  final TransitMode mode;
  final String from;
  final String to;

  /// Hat adı, ör. `S8`, `RE 5`.
  final String? line;
  final String? operator;
  final ZonedTime? departAt;
  final ZonedTime? arriveAt;

  @override
  List<Object?> get props => [
    mode,
    from,
    to,
    line,
    operator,
    departAt,
    arriveAt,
  ];
}

class GroundJourney extends Equatable {
  const GroundJourney({
    required this.departAt,
    required this.arriveAt,
    required this.durationMin,
    required this.waitMin,
    required this.transfers,
    required this.legs,
    required this.fare,
    required this.fareSource,
  });

  final ZonedTime departAt;
  final ZonedTime arriveAt;
  final int durationMin;

  /// İniş ile kara kalkışı arasındaki bekleme.
  final int waitMin;
  final int transfers;
  final List<GroundLeg> legs;
  final Money fare;
  final FareSource fareSource;

  @override
  List<Object?> get props => [
    departAt,
    arriveAt,
    durationMin,
    waitMin,
    transfers,
    legs,
    fare,
    fareSource,
  ];
}

class RouteTotal extends Equatable {
  const RouteTotal({
    required this.price,
    required this.doorToDoorMin,
    required this.extraMin,
    this.savings,
    int? travelMin,
  }) : travelMin = travelMin ?? doorToDoorMin;

  final Money price;
  final int doorToDoorMin;

  /// Konaklama hariç yolda geçen süre.
  final int travelMin;

  /// Doğrudan uçuşa göre fazladan geçen süre.
  final int extraMin;

  /// Doğrudan uçuşa göre fark. Negatifse bu rota daha pahalı.
  /// Doğrudan fiyat bilinmiyorsa `null`.
  final Money? savings;

  @override
  List<Object?> get props => [
    price,
    doorToDoorMin,
    travelMin,
    extraMin,
    savings,
  ];
}

/// Aktarma şehrinde bilerek kalınan günler.
class Stopover extends Equatable {
  const Stopover({required this.days, required this.city});

  final int days;
  final String city;

  @override
  List<Object?> get props => [days, city];
}

enum BookingKind { flight, ground }

/// "Rezervasyona git" kartı: sağlayıcının kendi sitesi, ortaklık işaretsiz.
class BookingLink extends Equatable {
  const BookingLink({
    required this.kind,
    required this.provider,
    required this.url,
    required this.lines,
  });

  final BookingKind kind;

  /// Havayolu ya da işletmeci adı, ör. "Turkish Airlines", "ÖBB".
  final String provider;
  final Uri url;

  /// Bu bağlantıyla alınacak hatlar, ör. ["TK 1629"].
  final List<String> lines;

  @override
  List<Object?> get props => [kind, provider, url, lines];
}

/// Sonuç listesindeki bir kart.
class RouteOption extends Equatable {
  const RouteOption({
    required this.rank,
    required this.kind,
    required this.flight,
    required this.total,
    required this.badges,
    required this.flags,
    this.reason,
    this.via,
    this.ground,
    this.booking = const [],
    this.stopover,
  });

  /// Fiyata göre sıra, 1'den başlar.
  final int rank;
  final RouteKind kind;
  final Flight flight;
  final RouteTotal total;
  final Set<RouteBadge> badges;
  final Set<RouteFlag> flags;
  final RecommendReason? reason;

  /// Yalnızca aktarmalı kartta dolu.
  final ViaAirport? via;
  final GroundJourney? ground;
  final List<BookingLink> booking;

  /// Konaklamalı aramada aktarma şehrinde kalış; yoksa `null`.
  final Stopover? stopover;

  bool get isRecommended => badges.contains(RouteBadge.recommended);
  bool get isCheapest => badges.contains(RouteBadge.cheapest);

  @override
  List<Object?> get props => [
    rank,
    kind,
    flight,
    total,
    badges,
    flags,
    reason,
    via,
    ground,
    booking,
    stopover,
  ];
}
