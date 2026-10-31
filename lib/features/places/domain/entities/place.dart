import 'package:equatable/equatable.dart';

/// Ülke seçilince kalkışta ülkenin büyük şehirlerinden, varışta ülkenin
/// havalimanlarına uçuşlar aranır.
enum PlaceKind {
  city,
  airport,
  country;

  /// Backend'in yazımı: `CITY`, `AIRPORT`, `COUNTRY`. Bilinmeyen şehir sayılır.
  static PlaceKind parse(String code) => switch (code.toUpperCase()) {
    'AIRPORT' => PlaceKind.airport,
    'COUNTRY' => PlaceKind.country,
    _ => PlaceKind.city,
  };
}

/// Kullanıcının seçebileceği bir kalkış ya da varış yeri.
class Place extends Equatable {
  const Place({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.kind,
    this.iata,
  });

  /// Backend'in yer kimliği; aramada metin yerine bu gönderilir.
  final String id;
  final String name;

  /// ISO 3166-1 alfa-2, ör. `AT`.
  final String countryCode;
  final String countryName;
  final PlaceKind kind;

  /// Havalimanı ya da şehir kodu, ör. `IST`, `MIL`.
  final String? iata;

  /// Alan içinde görünen kısa ad: "İstanbul IST". Alan kodu küçük ve
  /// soluk yazar.
  String get label => iata == null ? name : '$name $iata';

  @override
  List<Object?> get props => [id, name, countryCode, countryName, kind, iata];
}
