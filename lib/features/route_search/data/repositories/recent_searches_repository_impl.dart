import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/json/json_reader.dart';
import '../../../places/domain/entities/place.dart';
import '../../domain/entities/recent_search.dart';
import '../../domain/repositories/recent_searches_repository.dart';

/// Son aramaları cihazın yerel ayar deposunda tek bir JSON dizisi olarak
/// tutar. Bozuk ya da eski biçimli kayıt sessizce yok sayılır: son aramalar
/// kaybolsa da uygulama açılır.
class PrefsRecentSearchesRepository implements RecentSearchesRepository {
  PrefsRecentSearchesRepository([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _key = 'recent_searches_v1';

  @override
  Future<List<RecentSearch>> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => _fromJson(e as Json))
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(List<RecentSearch> searches) async {
    try {
      await _prefs.setString(
        _key,
        jsonEncode(searches.map(_toJson).toList(growable: false)),
      );
    } on Object {
      // Depo yazılamıyorsa son aramalar yalnızca bu oturumda kalır.
    }
  }

  static Json _toJson(RecentSearch s) => {
    'fromText': s.fromText,
    'fromPlace': _placeToJson(s.fromPlace),
    'toText': s.toText,
    'toPlace': _placeToJson(s.toPlace),
    'date': '${s.date.year}-${s.date.month}-${s.date.day}',
    'radiusKm': s.radiusKm,
    'stopoverDays': s.stopoverDays,
  };

  static RecentSearch _fromJson(Json json) {
    final parts = json.str('date').split('-').map(int.parse).toList();
    return RecentSearch(
      fromText: json.str('fromText'),
      fromPlace: _placeFromJson(json.objOrNull('fromPlace')),
      toText: json.str('toText'),
      toPlace: _placeFromJson(json.objOrNull('toPlace')),
      date: DateTime(parts[0], parts[1], parts[2]),
      radiusKm: json.integer('radiusKm'),
      stopoverDays: json.integer('stopoverDays'),
    );
  }

  static Json? _placeToJson(Place? p) => p == null
      ? null
      : {
          'id': p.id,
          'name': p.name,
          'countryCode': p.countryCode,
          'countryName': p.countryName,
          'kind': p.kind.name,
          'iata': p.iata,
        };

  static Place? _placeFromJson(Json? json) => json == null
      ? null
      : Place(
          id: json.str('id'),
          name: json.str('name'),
          countryCode: json.str('countryCode'),
          countryName: json.str('countryName'),
          kind: json.str('kind') == PlaceKind.airport.name
              ? PlaceKind.airport
              : PlaceKind.city,
          iata: json.strOrNull('iata'),
        );
}

/// Bellekte tutan sürüm: testler ve depo kullanılamayan ortamlar için.
class InMemoryRecentSearchesRepository implements RecentSearchesRepository {
  InMemoryRecentSearchesRepository([List<RecentSearch> initial = const []])
    : _items = List.of(initial);

  List<RecentSearch> _items;

  @override
  Future<List<RecentSearch>> load() async => List.unmodifiable(_items);

  @override
  Future<void> save(List<RecentSearch> searches) async =>
      _items = List.of(searches);
}
