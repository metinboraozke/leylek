import 'package:equatable/equatable.dart';

/// Kullanıcının arama isteği.
class SearchQuery extends Equatable {
  const SearchQuery({
    required this.from,
    required this.to,
    required this.date,
    this.radiusKm = defaultRadiusKm,
    this.maxGroundHours = defaultMaxGroundHours,
    this.currency = 'TRY',
  });

  static const int defaultRadiusKm = 250;
  static const int minRadiusKm = 50;
  static const int maxRadiusKm = 400;
  static const double defaultMaxGroundHours = 5;
  static const double minGroundHours = 1;
  static const double maxGroundHoursLimit = 8;
  static const int maxDaysAhead = 330;

  /// Yer kimliği ya da serbest metin (backend ikisini de çözer).
  final String from;
  final String to;

  /// Kalkış günü; saat kısmı kullanılmaz.
  final DateTime date;
  final int radiusKm;
  final double maxGroundHours;
  final String currency;

  /// API'nin beklediği `YYYY-MM-DD`.
  String get isoDate =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [from, to, isoDate, radiusKm, maxGroundHours, currency];
}
