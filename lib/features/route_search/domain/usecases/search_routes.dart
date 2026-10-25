import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/text/normalize.dart';
import '../../../../core/usecase/use_case.dart';
import '../entities/search_query.dart';
import '../entities/search_result.dart';
import '../repositories/route_search_repository.dart';

/// "Şu anki zaman"ı veren fonksiyon. Testte sabit bir gün verilir.
typedef Clock = DateTime Function();

/// Girdiyi doğrular, geçerliyse aramayı depoya devreder.
///
/// Backend de aynı kontrolleri yapıyor; burada tekrarlanmasının nedeni
/// kullanıcıya hatayı ağ isteği beklemeden, ilgili alanın altında
/// gösterebilmek.
class SearchRoutes implements UseCase<SearchResult, SearchQuery> {
  SearchRoutes(this._repository, {Clock? clock})
    : _clock = clock ?? DateTime.now;

  final RouteSearchRepository _repository;
  final Clock _clock;

  @override
  Future<Result<SearchResult>> call(SearchQuery input) async {
    final failure = validate(input);
    if (failure != null) return Err(failure);
    return _repository.search(input);
  }

  ValidationFailure? validate(SearchQuery q) {
    if (q.from.trim().isEmpty) {
      return const ValidationFailure(
        'Nereden yola çıkacağını seç.',
        field: ValidationField.from,
      );
    }
    if (q.to.trim().isEmpty) {
      return const ValidationFailure(
        'Nereye gideceğini seç.',
        field: ValidationField.to,
      );
    }
    if (normalizeForSearch(q.from) == normalizeForSearch(q.to)) {
      return const ValidationFailure(
        'Kalkış ve varış aynı olamaz.',
        field: ValidationField.to,
      );
    }

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(q.date.year, q.date.month, q.date.day);
    if (day.isBefore(today)) {
      return const ValidationFailure(
        'Geçmiş bir tarih seçilemez.',
        field: ValidationField.date,
      );
    }
    if (day.difference(today).inDays > SearchQuery.maxDaysAhead) {
      return const ValidationFailure(
        'En fazla ${SearchQuery.maxDaysAhead} gün sonrası aranabilir.',
        field: ValidationField.date,
      );
    }

    if (q.radiusKm < SearchQuery.minRadiusKm ||
        q.radiusKm > SearchQuery.maxRadiusKm) {
      return const ValidationFailure(
        'Yarıçap ${SearchQuery.minRadiusKm}–${SearchQuery.maxRadiusKm} km arasında olmalı.',
        field: ValidationField.radius,
      );
    }
    if (q.maxGroundHours < SearchQuery.minGroundHours ||
        q.maxGroundHours > SearchQuery.maxGroundHoursLimit) {
      return const ValidationFailure(
        'Kara yolculuğu 1–8 saat arasında olmalı.',
        field: ValidationField.maxGroundHours,
      );
    }
    return null;
  }
}
