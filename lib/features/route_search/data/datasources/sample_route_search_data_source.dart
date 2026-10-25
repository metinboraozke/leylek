import 'dart:convert';

import '../../../../core/json/json_reader.dart';
import '../../domain/entities/search_query.dart';
import 'route_search_data_source.dart';

/// Backend bağlı değilken dönen örnek yanıt (İstanbul → Salzburg).
///
/// Fiyatlar gerçek değil. Yanıt `meta.sample = true` taşır ve ekran
/// bunu açıkça yazar. Biçim backend'in yanıt sözleşmesiyle birebir;
/// eşleme kodu gerçek yanıtla aynı yoldan geçer. Dört kart: en ucuz,
/// önerilen, kara yolu doğrulanamamış ve doğrudan uçuş.
class SampleRouteSearchDataSource implements RouteSearchDataSource {
  const SampleRouteSearchDataSource({
    this.latency = const Duration(milliseconds: 1200),
  });

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
  "recommendedRank": 2,
  "options": [
    {
      "rank": 1, "kind": "VIA", "badges": ["CHEAPEST"], "reason": null,
      "via": { "iata": "MUC", "name": "Münih", "country": "DE", "distanceKm": 124 },
      "flight": { "fromAirport": "IST", "toAirport": "MUC", "price": 5200, "airline": "TK", "flightNumber": "1629", "transfers": 0,
                  "departAt": "2026-11-20T08:05:00+03:00", "arriveAt": "2026-11-20T09:55:00+01:00",
                  "priceSeenHoursAgo": 31 },
      "ground": {
        "departAt": "2026-11-20T11:46:00+01:00", "arriveAt": "2026-11-20T13:58:00+01:00",
        "durationMin": 132, "waitMin": 111, "transfers": 1,
        "legs": [
          { "mode": "SUBURBAN", "from": "München Flughafen Terminal", "to": "München Hbf", "line": "S8", "operator": "MVV",
            "departAt": "2026-11-20T11:46:00+01:00", "arriveAt": "2026-11-20T12:27:00+01:00" },
          { "mode": "REGIONAL_RAIL", "from": "München Hbf", "to": "Salzburg Hbf", "line": "RE 5", "operator": "BRB",
            "departAt": "2026-11-20T12:35:00+01:00", "arriveAt": "2026-11-20T13:58:00+01:00" }
        ],
        "fare": { "amount": 1300, "currency": "TRY", "source": "estimated" }
      },
      "total": { "price": 6500, "doorToDoorMin": 473, "extraMin": 43, "savings": 3300 },
      "score": 7210,
      "flags": ["GROUND_FARE_ESTIMATED", "SEPARATE_TICKETS", "TIGHT_CONNECTION"],
      "booking": [
        { "kind": "FLIGHT", "provider": "Turkish Airlines", "url": "https://www.turkishairlines.com", "lines": ["TK 1629"] },
        { "kind": "GROUND", "provider": "MVV", "url": "https://www.mvv-muenchen.de", "lines": ["S8"] },
        { "kind": "GROUND", "provider": "BRB", "url": "https://www.brb.de", "lines": ["RE 5"] }
      ]
    },
    {
      "rank": 2, "kind": "VIA", "badges": ["RECOMMENDED"], "reason": "BEST_BALANCE",
      "via": { "iata": "INN", "name": "Innsbruck", "country": "AT", "distanceKm": 140 },
      "flight": { "fromAirport": "SAW", "toAirport": "INN", "price": 6100, "airline": "PC", "flightNumber": "1137", "transfers": 0,
                  "departAt": "2026-11-20T10:20:00+03:00", "arriveAt": "2026-11-20T12:05:00+01:00",
                  "priceSeenHoursAgo": 18 },
      "ground": {
        "departAt": "2026-11-20T13:42:00+01:00", "arriveAt": "2026-11-20T15:40:00+01:00",
        "durationMin": 118, "waitMin": 97, "transfers": 1,
        "legs": [
          { "mode": "BUS", "from": "Innsbruck Flughafen", "to": "Innsbruck Hbf", "line": "F", "operator": "IVB",
            "departAt": "2026-11-20T13:42:00+01:00", "arriveAt": "2026-11-20T14:02:00+01:00" },
          { "mode": "LONG_DISTANCE", "from": "Innsbruck Hbf", "to": "Salzburg Hbf", "line": "RJX 663", "operator": "ÖBB",
            "departAt": "2026-11-20T14:13:00+01:00", "arriveAt": "2026-11-20T15:40:00+01:00" }
        ],
        "fare": { "amount": 1450, "currency": "TRY", "source": "transitous" }
      },
      "total": { "price": 7550, "doorToDoorMin": 440, "extraMin": 10, "savings": 2250 },
      "score": 7690,
      "flags": ["SEPARATE_TICKETS", "TIGHT_CONNECTION"],
      "booking": [
        { "kind": "FLIGHT", "provider": "Pegasus", "url": "https://www.flypgs.com", "lines": ["PC 1137"] },
        { "kind": "GROUND", "provider": "ÖBB", "url": "https://www.oebb.at", "lines": ["RJX 663"] }
      ]
    },
    {
      "rank": 3, "kind": "VIA", "badges": [],
      "via": { "iata": "LNZ", "name": "Linz", "country": "AT", "distanceKm": 106 },
      "flight": { "fromAirport": "IST", "toAirport": "LNZ", "price": 7400, "airline": "OS", "flightNumber": "828", "transfers": 1,
                  "departAt": "2026-11-20T05:00:00+03:00", "arriveAt": "2026-11-20T08:40:00+01:00",
                  "priceSeenHoursAgo": null },
      "ground": {
        "departAt": "2026-11-20T10:30:00+01:00", "arriveAt": "2026-11-20T12:10:00+01:00",
        "durationMin": 100, "waitMin": 110, "transfers": 0,
        "legs": [],
        "fare": { "amount": 700, "currency": "TRY", "source": "estimated" }
      },
      "total": { "price": 8100, "doorToDoorMin": 490, "extraMin": 60, "savings": 1700 },
      "score": 8520,
      "flags": ["SEPARATE_TICKETS", "GROUND_NOT_VERIFIED", "GROUND_FARE_ESTIMATED", "TIGHT_CONNECTION"],
      "booking": [
        { "kind": "FLIGHT", "provider": "Austrian Airlines", "url": "https://www.austrian.com", "lines": ["OS 828"] }
      ]
    },
    {
      "rank": 4, "kind": "DIRECT", "badges": ["FASTEST"],
      "flight": { "airport": "SZG", "fromAirport": "SAW", "toAirport": "SZG", "price": 9800, "airline": "PC", "flightNumber": "1159", "transfers": 1,
                  "departAt": "2026-11-20T07:15:00+03:00", "arriveAt": "2026-11-20T11:40:00+01:00",
                  "priceSeenHoursAgo": 20 },
      "total": { "price": 9800, "doorToDoorMin": 430, "extraMin": 0, "savings": 0 },
      "score": 9800,
      "flags": [],
      "booking": [
        { "kind": "FLIGHT", "provider": "Pegasus", "url": "https://www.flypgs.com", "lines": ["PC 1159"] }
      ]
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
  "meta": { "generatedAt": "2026-10-22T10:00:00Z", "sample": true }
}
''';
