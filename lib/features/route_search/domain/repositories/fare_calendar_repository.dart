import '../../../../core/result/result.dart';

/// Tarih şeridindeki günlük fiyatlar: bir ayın her günü için varışa en
/// ucuz doğrudan uçuş. Anahtar `2026-11-24`, değer arama para biriminde.
abstract interface class FareCalendarRepository {
  Future<Result<Map<String, int>>> month(String from, String to, String month);
}
