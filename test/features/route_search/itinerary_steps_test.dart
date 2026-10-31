import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leylek/core/json/json_reader.dart';
import 'package:leylek/features/route_search/data/datasources/sample_route_search_data_source.dart';
import 'package:leylek/features/route_search/data/models/search_result_mapper.dart';
import 'package:leylek/features/route_search/domain/entities/route_option.dart';
import 'package:leylek/features/route_search/presentation/widgets/itinerary_card.dart';

/// Örnek yanıttaki ilk aktarmalı rota; [edit] ile kara kısmı değiştirilir.
RouteOption _via(void Function(Json ground) edit) {
  final json = jsonDecode(sampleSearchResponse) as Json;
  final options = (json['options'] as List<dynamic>).cast<Json>();
  final via = options.firstWhere((o) => o['kind'] == 'VIA');
  edit(via['ground'] as Json);
  return SearchResultMapper.fromJson(
    json,
  ).options.firstWhere((o) => o.rank == via['rank']);
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  test('yürüyüş yoksa adımlar uçak ve kara bacaklarından ibaret', () {
    final steps = itinerarySteps(_via((_) {}), 'İstanbul', 'Salzburg');
    expect(steps.map((s) => s.mode), isNot(contains('Yürüyüş')));
    expect(steps[1].title, 'Münih havalimanı → München Hbf');
  });

  test('uzak ilk durak ve istasyon değişimi ayrı yürüme adımı olur', () {
    final option = _via((g) {
      g['access'] = {'stop': 'Freising', 'distanceKm': 1.9, 'walkMin': 32};
      final legs = (g['legs'] as List<dynamic>).cast<Json>();
      legs[1]['walkBeforeMin'] = 7;
    });
    final steps = itinerarySteps(option, 'İstanbul', 'Salzburg');

    expect(steps.map((s) => s.mode).toList(), [
      'Uçak',
      'Havalimanından istasyona',
      'Banliyö · S8',
      'Yürüyüş',
      'Bölgesel tren · RE 5',
    ]);
    expect(steps[1].title, 'Münih havalimanı → Freising');
    expect(steps[1].detail, '~1,9 km · yürüyerek ~32 dk ya da taksi');
    expect(steps[1].travels, isFalse);
    // İlk bacak artık havalimanından değil, o duraktan başlar.
    expect(steps[2].title, 'München Flughafen Terminal → München Hbf');
    expect(steps[3].title, 'München Hbf içinde');
    expect(steps[3].detail, '~7 dk');
    // Yürüyüşler üstteki özete girmez.
    expect(steps.where((s) => s.travels).map((s) => s.kind ?? s.mode), [
      'Uçak',
      'Banliyö',
      'Bölgesel tren',
    ]);
  });
}
