import '../../../../core/json/json_reader.dart';
import '../../domain/entities/place.dart';

/// `/v1/places` yanıtındaki tek yer.
class PlaceDto {
  const PlaceDto({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.kind,
    this.iata,
  });

  factory PlaceDto.fromJson(Json json) => PlaceDto(
        id: json.str('id'),
        name: json.str('name'),
        countryCode: json.str('countryCode'),
        countryName: json.str('countryName'),
        kind: json.str('kind'),
        iata: json.strOrNull('iata'),
      );

  final String id;
  final String name;
  final String countryCode;
  final String countryName;
  final String kind;
  final String? iata;

  Place toEntity() => Place(
        id: id,
        name: name,
        countryCode: countryCode,
        countryName: countryName,
        kind: kind == 'AIRPORT' ? PlaceKind.airport : PlaceKind.city,
        iata: iata,
      );
}
