import '../../../../core/text/normalize.dart';
import '../models/place_dto.dart';
import 'places_data_source.dart';

/// Backend yokken kullanılan küçük, elle yazılmış yer listesi.
///
/// Gerçek liste backend'de GeoNames ve OurAirports'tan üretilecek.
class SamplePlacesDataSource implements PlacesDataSource {
  const SamplePlacesDataSource();

  static const int _limit = 8;

  @override
  Future<List<PlaceDto>> suggest(String query) async {
    final needle = normalizeForSearch(query);
    return _places
        .where((p) => _keys(p).any((key) => key.startsWith(needle)))
        .take(_limit)
        .toList(growable: false);
  }

  Iterable<String> _keys(PlaceDto p) sync* {
    yield normalizeForSearch(p.name);
    if (p.iata != null) yield p.iata!.toLowerCase();
    yield* (_aliases[p.id] ?? const <String>[]).map(normalizeForSearch);
  }

  static const Map<String, List<String>> _aliases = {
    'city:muc': ['Munich', 'München'],
    'city:vie': ['Vienna', 'Wien'],
    'city:mil': ['Milan', 'Milano'],
    'city:prg': ['Prague', 'Praha'],
    'city:szg': ['Salzburg'],
  };

  static const List<PlaceDto> _places = [
    PlaceDto(id: 'city:ist', name: 'İstanbul', countryCode: 'TR', countryName: 'Türkiye', kind: 'CITY', iata: 'IST'),
    PlaceDto(id: 'city:ank', name: 'Ankara', countryCode: 'TR', countryName: 'Türkiye', kind: 'CITY', iata: 'ESB'),
    PlaceDto(id: 'city:izm', name: 'İzmir', countryCode: 'TR', countryName: 'Türkiye', kind: 'CITY', iata: 'ADB'),
    PlaceDto(id: 'city:ayt', name: 'Antalya', countryCode: 'TR', countryName: 'Türkiye', kind: 'CITY', iata: 'AYT'),
    PlaceDto(id: 'city:szg', name: 'Salzburg', countryCode: 'AT', countryName: 'Avusturya', kind: 'CITY', iata: 'SZG'),
    PlaceDto(id: 'city:inn', name: 'Innsbruck', countryCode: 'AT', countryName: 'Avusturya', kind: 'CITY', iata: 'INN'),
    PlaceDto(id: 'city:vie', name: 'Viyana', countryCode: 'AT', countryName: 'Avusturya', kind: 'CITY', iata: 'VIE'),
    PlaceDto(id: 'city:muc', name: 'Münih', countryCode: 'DE', countryName: 'Almanya', kind: 'CITY', iata: 'MUC'),
    PlaceDto(id: 'city:mil', name: 'Milano', countryCode: 'IT', countryName: 'İtalya', kind: 'CITY', iata: 'MIL'),
    PlaceDto(id: 'city:prg', name: 'Prag', countryCode: 'CZ', countryName: 'Çekya', kind: 'CITY', iata: 'PRG'),
    PlaceDto(id: 'city:hvar', name: 'Hvar', countryCode: 'HR', countryName: 'Hırvatistan', kind: 'CITY'),
    PlaceDto(id: 'city:spu', name: 'Split', countryCode: 'HR', countryName: 'Hırvatistan', kind: 'CITY', iata: 'SPU'),
  ];
}
