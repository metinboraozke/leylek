import 'package:equatable/equatable.dart';

import 'route_option.dart';

/// Arama yanıtındaki uyarılar.
enum SearchWarning { fewerThanThree, partialResults, unknown }

/// Görünür bir yerde gösterilmesi zorunlu veri kaynağı atfı.
class Attribution extends Equatable {
  const Attribution({required this.name, this.url});

  final String name;
  final String? url;

  @override
  List<Object?> get props => [name, url];
}

class SearchResult extends Equatable {
  const SearchResult({
    required this.options,
    required this.warnings,
    required this.attribution,
    this.fromName = '',
    this.toName = '',
    this.fromIsCountry = false,
    this.toIsCountry = false,
    this.isSample = false,
  });

  /// Fiyata göre artan sırada (en ucuz başta).
  final List<RouteOption> options;
  final List<SearchWarning> warnings;
  final List<Attribution> attribution;

  /// Sunucunun çözdüğü yer adları, ör. "İstanbul", "Salzburg".
  final String fromName;
  final String toName;

  /// Kalkış ya da varış bir ülke mi ("Türkiye", "İtalya"). Öyleyse her
  /// kart kendi kalkış/varış şehrini gösterir.
  final bool fromIsCountry;
  final bool toIsCountry;

  /// Kartta yazılacak kalkış: ülke seçildiyse uçuşun kalktığı şehir.
  String fromFor(RouteOption o) => fromIsCountry
      ? (o.departureCity ?? fromName)
      : (fromName.isEmpty ? (o.flight.fromIata ?? '') : fromName);

  /// Kartta yazılacak varış: ülke seçildiyse inilen şehir.
  String toFor(RouteOption o) => toIsCountry
      ? (o.arrivalCity ?? toName)
      : (toName.isEmpty ? (o.flight.toIata ?? '') : toName);

  /// Backend bağlı değilken gösterilen örnek veri mi.
  final bool isSample;

  RouteOption? get recommended {
    for (final option in options) {
      if (option.isRecommended) return option;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    options,
    warnings,
    attribution,
    fromName,
    toName,
    fromIsCountry,
    toIsCountry,
    isSample,
  ];
}
