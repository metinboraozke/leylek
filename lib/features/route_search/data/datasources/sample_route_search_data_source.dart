import 'dart:convert';

import '../../../../core/json/json_reader.dart';
import '../../domain/entities/search_query.dart';
import 'route_search_data_source.dart';

/// Backend bağlı değilken dönen örnek yanıt (İstanbul → Salzburg).
///
/// Fiyatlar gerçek değil. Yanıt `meta.sample = true` taşır ve ekran
/// bunu açıkça yazar. Biçim backend planındaki sözleşmeyle birebir;
/// eşleme kodu gerçek yanıtla aynı yoldan geçer.
class SampleRouteSearchDataSource implements RouteSearchDataSource {
  const SampleRouteSearchDataSource({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;

  @override
  Future<Json> search(SearchQuery query) async {
    await Future<void>.delayed(latency);
    return jsonDecode(sampleSearchResponse) as Json;
  }
}

const String sampleSearchResponse = r'''
{
  "query": { "from": "İstanbul", "to": "Salzburg", "date": "2026-11-20", "radiusKm": 250, "currency": "TRY" },
  "recommendedRank": 1,
  "options": [
    {
      "rank": 1, "kind": "VIA", "badges": ["CHEAPEST", "RECOMMENDED"], "reason": "CHEAPEST",
      "via": { "iata": "MUC", "name": "Münih", "country": "DE", "distanceKm": 124 },
      "flight": { "price": 5200, "airline": "TK", "flightNumber": "1629", "transfers": 0,
                  "departAt": "2026-11-20T08:05:00+03:00", "arriveAt": "2026-11-20T09:55:00+01:00",
                  "priceSeenHoursAgo": 31 },
      "ground": {
        "departAt": "2026-11-20T11:46:00+01:00", "arriveAt": "2026-11-20T13:58:00+01:00",
        "durationMin": 132, "waitMin": 111, "transfers": 1,
        "legs": [
          { "mode": "SUBURBAN", "from": "München Flughafen", "to": "München Hbf", "line": "S8", "operator": "MVV" },
          { "mode": "REGIONAL_RAIL", "from": "München Hbf", "to": "Salzburg Hbf", "line": "RE 5", "operator": "BRB" }
        ],
        "fare": { "amount": 1300, "currency": "TRY", "source": "estimated" }
      },
      "total": { "price": 6500, "doorToDoorMin": 473, "extraMin": 43, "savings": 3300 },
      "score": 7210,
      "flags": ["GROUND_FARE_ESTIMATED", "SEPARATE_TICKETS"]
    },
    {
      "rank": 2, "kind": "VIA", "badges": [],
      "via": { "iata": "INN", "name": "Innsbruck", "country": "AT", "distanceKm": 140 },
      "flight": { "price": 6100, "airline": "PC", "flightNumber": "1137", "transfers": 0,
                  "departAt": "2026-11-20T10:20:00+03:00", "arriveAt": "2026-11-20T12:05:00+01:00",
                  "priceSeenHoursAgo": 18 },
      "ground": {
        "departAt": "2026-11-20T13:42:00+01:00", "arriveAt": "2026-11-20T15:40:00+01:00",
        "durationMin": 118, "waitMin": 97, "transfers": 0,
        "legs": [
          { "mode": "BUS", "from": "Innsbruck Flughafen", "to": "Innsbruck Hbf", "line": "F", "operator": "IVB" },
          { "mode": "LONG_DISTANCE", "from": "Innsbruck Hbf", "to": "Salzburg Hbf", "line": "RJX 663", "operator": "ÖBB" }
        ],
        "fare": { "amount": 1450, "currency": "TRY", "source": "transitous" }
      },
      "total": { "price": 7550, "doorToDoorMin": 440, "extraMin": 10, "savings": 2250 },
      "score": 8380,
      "flags": ["SEPARATE_TICKETS"]
    },
    {
      "rank": 3, "kind": "DIRECT", "badges": ["FASTEST"],
      "flight": { "airport": "SZG", "price": 9800, "airline": "PC", "flightNumber": "1159", "transfers": 1,
                  "departAt": "2026-11-20T07:15:00+03:00", "arriveAt": "2026-11-20T11:40:00+01:00",
                  "priceSeenHoursAgo": 20 },
      "total": { "price": 9800, "doorToDoorMin": 430, "extraMin": 0, "savings": 0 },
      "score": 9800,
      "flags": []
    }
  ],
  "dropped": [{ "iata": "FMM", "reason": "NOT_IN_TOP_K" }],
  "warnings": [],
  "attribution": [
    { "name": "Transitous", "url": "https://transitous.org/sources/" },
    { "name": "OpenStreetMap katkıcıları", "url": "https://www.openstreetmap.org/copyright" },
    { "name": "OurAirports", "url": "https://ourairports.com/data/" },
    { "name": "GeoNames", "url": "https://www.geonames.org/" },
    { "name": "Uçuş fiyatları: Aviasales verisi, son 48 saatte görülen", "url": null }
  ],
  "meta": { "generatedAt": "2026-10-22T10:00:00Z", "transitousCalls": 0, "cached": "none", "sample": true }
}
''';
