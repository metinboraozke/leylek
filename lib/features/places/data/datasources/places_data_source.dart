import '../../../../core/network/json_api.dart';
import '../models/place_dto.dart';

/// Yer önerilerinin ham kaynağı. Backend ya da örnek veri olabilir;
/// depo hangisi olduğunu bilmez (LSP: ikisi de aynı sözleşmeyi tutar).
abstract interface class PlacesDataSource {
  Future<List<PlaceDto>> suggest(String query);
}

class ApiPlacesDataSource implements PlacesDataSource {
  const ApiPlacesDataSource(this._api);

  final JsonApi _api;

  @override
  Future<List<PlaceDto>> suggest(String query) async {
    final json = await _api.getJson(
      '/v1/places',
      query: {'q': query, 'lang': 'tr'},
    );
    final places = json['places'];
    if (places is! List) throw const FormatException('"places" listesi yok');
    return [
      for (final item in places)
        if (item is Map<String, dynamic>) PlaceDto.fromJson(item),
    ];
  }
}
