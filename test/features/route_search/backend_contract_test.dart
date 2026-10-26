import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/json/json_reader.dart';
import 'package:leylek/features/route_search/data/models/search_result_mapper.dart';
import 'package:leylek/features/route_search/domain/entities/route_option.dart';

/// Sözleşme testi: `test/fixtures/backend_search_response.json` backend'in
/// gerçek arama hattından (sahte dış servislerle) üretildi. Backend yanıt
/// biçimi değişirse bu dosya yeniden üretilmeli ve bu test geçmeli.
void main() {
  test('backend yanıtı uygulamada hatasız okunur', () {
    final raw = File(
      'test/fixtures/backend_search_response.json',
    ).readAsStringSync();
    final result = SearchResultMapper.fromJson(jsonDecode(raw) as Json);

    expect(result.options.length, greaterThanOrEqualTo(3));
    expect(result.isSample, isFalse);
    expect(result.recommended, isNotNull);
    expect(
      result.options.where((o) => o.kind == RouteKind.direct),
      hasLength(1),
    );
    final prices = result.options.map((o) => o.total.price.amount).toList();
    expect(prices, [...prices]..sort());
    final via = result.options.firstWhere((o) => o.kind == RouteKind.via);
    expect(via.ground!.legs, isNotEmpty);
    expect(via.flags, isNot(contains(RouteFlag.unknown)));
    // Örnek 1 gün konaklamalı aramadan üretildi: hedef 4 plan.
    expect(result.options, hasLength(4));
    expect(via.stopover?.days, 1);
    expect(via.stopover?.city, 'Münih');
    expect(via.total.travelMin, lessThan(via.total.doorToDoorMin));
    expect(via.flags, contains(RouteFlag.stopover));
  });
}
