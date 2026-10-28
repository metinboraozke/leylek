import 'package:equatable/equatable.dart';

import '../../../places/domain/entities/place.dart';

/// Cihazda tutulan bir önceki arama; dokununca form bununla doldurulur.
///
/// Yer listeden seçildiyse [fromPlace]/[toPlace] doludur; elle yazıldıysa
/// yalnızca metin vardır.
class RecentSearch extends Equatable {
  const RecentSearch({
    required this.fromText,
    required this.toText,
    required this.date,
    required this.radiusKm,
    required this.stopoverDays,
    this.fromPlace,
    this.toPlace,
  });

  final String fromText;
  final Place? fromPlace;
  final String toText;
  final Place? toPlace;
  final DateTime date;
  final int radiusKm;
  final int stopoverDays;

  /// Listede görünen kısa ad: "İstanbul", kod eki olmadan.
  String get fromName => fromPlace?.name ?? fromText.trim();
  String get toName => toPlace?.name ?? toText.trim();

  /// Aynı iki yer arasındaki arama yenisiyle değiştirilir.
  bool sameRouteAs(RecentSearch other) =>
      _key(fromPlace, fromText) == _key(other.fromPlace, other.fromText) &&
      _key(toPlace, toText) == _key(other.toPlace, other.toText);

  static String _key(Place? place, String text) =>
      place?.id ?? text.trim().toLowerCase();

  @override
  List<Object?> get props => [
    fromText,
    fromPlace,
    toText,
    toPlace,
    date,
    radiusKm,
    stopoverDays,
  ];
}
