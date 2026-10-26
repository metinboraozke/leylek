import '../../../../core/json/json_reader.dart';
import '../../../../core/time/zoned_time.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/route_option.dart';
import '../../domain/entities/search_result.dart';
import 'api_codes.dart';

/// `/v1/search` yanıtını domain varlıklarına çevirir.
///
/// Yanıt sözleşmesi backend planındaki örnekle aynı. Ayrı DTO sınıfları
/// yazmak yerine doğrudan eşleme yapıyoruz: ara katman yalnızca aynı
/// alanları bir kez daha kopyalardı. Biçim bozuksa [FormatException]
/// fırlar ve depo bunu [UnexpectedFailure]'a çevirir.
abstract final class SearchResultMapper {
  static SearchResult fromJson(Json json) {
    final query = json.obj('query');
    final currency = query.str('currency');
    final options =
        json.objList('options').map((o) => _option(o, currency)).toList()
          ..sort((a, b) => a.rank.compareTo(b.rank));

    return SearchResult(
      options: List.unmodifiable(options),
      warnings: json
          .strList('warnings')
          .map(ApiCodes.warning)
          .toList(growable: false),
      attribution: json
          .objList('attribution')
          .map((a) => Attribution(name: a.str('name'), url: a.strOrNull('url')))
          .toList(growable: false),
      fromName: query.strOrNull('from') ?? '',
      toName: query.strOrNull('to') ?? '',
      isSample: json.objOrNull('meta')?.boolean('sample') ?? false,
    );
  }

  static RouteOption _option(Json o, String currency) {
    final via = o.objOrNull('via');
    final ground = o.objOrNull('ground');
    return RouteOption(
      rank: o.integer('rank'),
      kind: ApiCodes.kind(o.str('kind')),
      badges: o
          .strList('badges')
          .map(ApiCodes.badge)
          .whereType<RouteBadge>()
          .toSet(),
      reason: ApiCodes.reason(o.strOrNull('reason')),
      flags: o.strList('flags').map(ApiCodes.flag).toSet(),
      via: via == null ? null : _via(via),
      flight: _flight(o.obj('flight'), currency),
      ground: ground == null ? null : _ground(ground),
      total: _total(o.obj('total'), currency),
      stopover: _stopover(o.objOrNull('stopover')),
      booking: o
          .objList('booking')
          .map(_booking)
          .whereType<BookingLink>()
          .toList(growable: false),
    );
  }

  /// Yalnızca https bağlantılar kabul edilir; bozuk olan sessizce atlanır.
  static BookingLink? _booking(Json b) {
    final url = Uri.tryParse(b.strOrNull('url') ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    return BookingLink(
      kind: b.strOrNull('kind') == 'GROUND'
          ? BookingKind.ground
          : BookingKind.flight,
      provider: b.strOrNull('provider') ?? url.host,
      url: url,
      lines: b.strList('lines'),
    );
  }

  static ViaAirport _via(Json v) => ViaAirport(
    iata: v.str('iata'),
    name: v.str('name'),
    countryCode: v.str('country'),
    distanceKm: v.integer('distanceKm'),
  );

  static Flight _flight(Json f, String currency) => Flight(
    price: Money(f.number('price'), currency),
    airline: f.str('airline'),
    flightNumber: f.strOrNull('flightNumber'),
    transfers: f.integer('transfers'),
    departAt: ZonedTime.parse(f.str('departAt')),
    arriveAt: ZonedTime.parse(f.str('arriveAt')),
    priceSeenHoursAgo: f.integerOrNull('priceSeenHoursAgo'),
    airportIata: f.strOrNull('airport'),
    fromIata: f.strOrNull('fromAirport'),
    toIata: f.strOrNull('toAirport'),
  );

  static GroundJourney _ground(Json g) {
    final fare = g.obj('fare');
    return GroundJourney(
      departAt: ZonedTime.parse(g.str('departAt')),
      arriveAt: ZonedTime.parse(g.str('arriveAt')),
      durationMin: g.integer('durationMin'),
      waitMin: g.integer('waitMin'),
      transfers: g.integer('transfers'),
      legs: g
          .objList('legs')
          .map(
            (l) => GroundLeg(
              mode: ApiCodes.mode(l.str('mode')),
              from: l.str('from'),
              to: l.str('to'),
              line: l.strOrNull('line'),
              operator: l.strOrNull('operator'),
              departAt: _timeOrNull(l.strOrNull('departAt')),
              arriveAt: _timeOrNull(l.strOrNull('arriveAt')),
            ),
          )
          .toList(growable: false),
      fare: Money(fare.number('amount'), fare.str('currency')),
      fareSource: ApiCodes.fareSource(fare.str('source')),
    );
  }

  static ZonedTime? _timeOrNull(String? iso) =>
      iso == null ? null : ZonedTime.parse(iso);

  static Stopover? _stopover(Json? s) {
    if (s == null) return null;
    final days = s.integer('days');
    return days > 0
        ? Stopover(days: days, city: s.strOrNull('city') ?? '')
        : null;
  }

  static RouteTotal _total(Json t, String currency) {
    final savings = t.numberOrNull('savings');
    return RouteTotal(
      price: Money(t.number('price'), currency),
      doorToDoorMin: t.integer('doorToDoorMin'),
      travelMin: t.integerOrNull('travelMin'),
      extraMin: t.integer('extraMin'),
      savings: savings == null ? null : Money(savings, currency),
    );
  }
}
