import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/json/json_reader.dart';
import 'package:leylek/features/route_search/data/datasources/sample_route_search_data_source.dart';
import 'package:leylek/features/route_search/data/models/search_result_mapper.dart';
import 'package:leylek/features/route_search/domain/entities/money.dart';
import 'package:leylek/features/route_search/domain/entities/route_option.dart';

Json _sample() => jsonDecode(sampleSearchResponse) as Json;

void main() {
  test('örnek yanıt 4 kartı fiyata göre sıralı ve doğru alanlarla okur', () {
    final result = SearchResultMapper.fromJson(_sample());

    expect(result.isSample, isTrue);
    expect(result.options.map((o) => o.rank), [1, 2, 3, 4]);
    expect(result.fromName, 'İstanbul');
    expect(result.toName, 'Salzburg');
    final prices = result.options.map((o) => o.total.price.amount).toList();
    expect(prices, [...prices]..sort());

    final first = result.options.first;
    expect(first.kind, RouteKind.via);
    expect(first.badges, {RouteBadge.cheapest});
    expect(first.reason, isNull);
    expect(first.flight.fromIata, 'IST');
    expect(first.flight.toIata, 'MUC');
    expect(first.booking.map((b) => b.provider), [
      'Turkish Airlines',
      'MVV',
      'BRB',
    ]);
    expect(first.booking.first.kind, BookingKind.flight);
    expect(first.ground!.legs.first.departAt!.wallClock.hour, 11);
    expect(first.via!.iata, 'MUC');
    expect(first.ground!.legs.first.mode, TransitMode.suburban);
    expect(first.ground!.fareSource, FareSource.estimated);
    expect(first.total.savings, const Money(3300, 'TRY'));
    expect(first.flags, contains(RouteFlag.separateTickets));
    expect(first.flight.departAt.wallClock.hour, 8);

    final direct = result.options.last;
    expect(direct.kind, RouteKind.direct);
    expect(direct.ground, isNull);
    expect(direct.flight.airportIata, 'SZG');
    expect(result.recommended, same(result.options[1]));
    expect(result.options[1].reason, RecommendReason.bestBalance);
    // Doğrulanamamış kara yolu: bacak yok, fiyat yaşı bilinmiyor
    expect(result.options[2].ground!.legs, isEmpty);
    expect(result.options[2].flight.priceSeenHoursAgo, isNull);
  });

  test('bilinmeyen rozet, etiket ve uyarı kodları çökmeden geçer', () {
    final json = _sample();
    final option = (json['options'] as List<dynamic>).first as Json;
    option['badges'] = ['CHEAPEST', 'YENI_ROZET'];
    option['flags'] = ['YENI_ETIKET'];
    json['warnings'] = ['YENI_UYARI'];

    final result = SearchResultMapper.fromJson(json);
    expect(result.options.first.badges, {RouteBadge.cheapest});
    expect(result.options.first.flags, {RouteFlag.unknown});
    expect(result.warnings, hasLength(1));
  });

  test('https olmayan rezervasyon bağlantısı atlanır', () {
    final json = _sample();
    final option = (json['options'] as List<dynamic>).first as Json;
    option['booking'] = [
      {
        'kind': 'FLIGHT',
        'provider': 'X',
        'url': 'javascript:alert(1)',
        'lines': <String>[],
      },
      {
        'kind': 'GROUND',
        'provider': 'ÖBB',
        'url': 'https://www.oebb.at',
        'lines': ['RJX 69'],
      },
    ];
    final links = SearchResultMapper.fromJson(json).options.first.booking;
    expect(links.map((l) => l.provider), ['ÖBB']);
  });

  test('eksik zorunlu alan FormatException fırlatır', () {
    final json = _sample();
    ((json['options'] as List<dynamic>).first as Json).remove('total');
    expect(() => SearchResultMapper.fromJson(json), throwsFormatException);
  });
}
