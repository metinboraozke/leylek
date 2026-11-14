import '../../../../core/error/failure.dart';
import '../../../../core/l10n/strings.dart';
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
      return ValidationFailure(
        S.t('Nereden yola çıkacağını seç.', 'Choose where you start.'),
        field: ValidationField.from,
      );
    }
    if (q.to.trim().isEmpty) {
      return ValidationFailure(
        S.t('Nereye gideceğini seç.', 'Choose where you are going.'),
        field: ValidationField.to,
      );
    }
    if (normalizeForSearch(q.from) == normalizeForSearch(q.to)) {
      return ValidationFailure(
        S.t('Kalkış ve varış aynı olamaz.', 'From and to cannot be the same.'),
        field: ValidationField.to,
      );
    }

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(q.date.year, q.date.month, q.date.day);
    if (day.isBefore(today)) {
      return ValidationFailure(
        S.t('Geçmiş bir tarih seçilemez.', 'You cannot pick a past date.'),
        field: ValidationField.date,
      );
    }
    if (day.difference(today).inDays > SearchQuery.maxDaysAhead) {
      return ValidationFailure(
        S.t(
          'En fazla ${SearchQuery.maxDaysAhead} gün sonrası aranabilir.',
          'You can search up to ${SearchQuery.maxDaysAhead} days ahead.',
        ),
        field: ValidationField.date,
      );
    }

    if (q.stopoverDays < 0 || q.stopoverDays > SearchQuery.maxStopoverDays) {
      return ValidationFailure(
        S.t(
          'Konaklama 0–${SearchQuery.maxStopoverDays} gün olabilir.',
          'A stopover can be 0–${SearchQuery.maxStopoverDays} days.',
        ),
        field: ValidationField.stopover,
      );
    }
    if (q.radiusKm < SearchQuery.minRadiusKm ||
        q.radiusKm > SearchQuery.maxRadiusKm) {
      return ValidationFailure(
        S.t(
          'Yarıçap ${SearchQuery.minRadiusKm}–${SearchQuery.maxRadiusKm} km arasında olmalı.',
          'Radius must be ${SearchQuery.minRadiusKm}–${SearchQuery.maxRadiusKm} km.',
        ),
        field: ValidationField.radius,
      );
    }
    if (q.maxGroundHours < SearchQuery.minGroundHours ||
        q.maxGroundHours > SearchQuery.maxGroundHoursLimit) {
      return ValidationFailure(
        S.t(
          'Kara yolculuğu 1–8 saat arasında olmalı.',
          'Ground travel must be 1–8 hours.',
        ),
        field: ValidationField.maxGroundHours,
      );
    }
    return null;
  }
}
