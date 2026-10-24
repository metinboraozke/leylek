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
    this.isSample = false,
  });

  /// Fiyata göre artan sırada (en ucuz başta).
  final List<RouteOption> options;
  final List<SearchWarning> warnings;
  final List<Attribution> attribution;

  /// Backend bağlı değilken gösterilen örnek veri mi.
  final bool isSample;

  RouteOption? get recommended {
    for (final option in options) {
      if (option.isRecommended) return option;
    }
    return null;
  }

  @override
  List<Object?> get props => [options, warnings, attribution, isSample];
}
