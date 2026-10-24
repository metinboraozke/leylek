import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/json/json_reader.dart';
import 'package:leylek/features/route_search/data/datasources/sample_route_search_data_source.dart';
import 'package:leylek/features/route_search/data/models/search_result_mapper.dart';
import 'package:leylek/features/route_search/domain/entities/money.dart';
import 'package:leylek/features/route_search/domain/entities/route_option.dart';

Json _sample() => jsonDecode(sampleSearchResponse) as Json;

void main() {
  test('örnek yanıt 3 kartı fiyata göre sıralı ve doğru alanlarla okur', () {
    final result = SearchResultMapper.fromJson(_sample());

    expect(result.isSample, isTrue);
    expect(result.options.map((o) => o.rank), [1, 2, 3]);
    final prices = result.options.map((o) => o.total.price.amount).toList();
    expect(prices, [...prices]..sort());

    final first = result.options.first;
    expect(first.kind, RouteKind.via);
    expect(first.badges, {RouteBadge.cheapest, RouteBadge.recommended});
    expect(first.reason, RecommendReason.cheapest);
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
    expect(result.recommended, same(first));
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

  test('eksik zorunlu alan FormatException fırlatır', () {
    final json = _sample();
    ((json['options'] as List<dynamic>).first as Json).remove('total');
    expect(() => SearchResultMapper.fromJson(json), throwsFormatException);
  });
}
