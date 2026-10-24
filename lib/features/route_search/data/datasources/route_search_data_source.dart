import '../../../../core/json/json_reader.dart';
import '../../../../core/network/json_api.dart';
import '../../domain/entities/search_query.dart';

/// Arama yanıtının ham kaynağı. Ham JSON döndürür; eşleme depoda.
abstract interface class RouteSearchDataSource {
  Future<Json> search(SearchQuery query);
}

class ApiRouteSearchDataSource implements RouteSearchDataSource {
  const ApiRouteSearchDataSource(this._api);

  final JsonApi _api;

  @override
  Future<Json> search(SearchQuery query) => _api.getJson('/v1/search', query: {
        'from': query.from,
        'to': query.to,
        'date': query.isoDate,
        'radiusKm': query.radiusKm,
        'maxGroundHours': query.maxGroundHours,
        'currency': query.currency,
        'lang': 'tr',
      });
}
